import { createHash, randomBytes } from 'node:crypto';
import { FieldPath } from 'firebase-admin/firestore';

export const LIMITS = Object.freeze({
  pageSize: 20,
  followedAuthors: 20,
  items: 50,
  photoBytes: 256 * 1024,
  postsPerAccountDay: 10,
  requestsPerAccountDay: 100,
  requestsPerProjectDay: 100,
  uploadsPerProjectMonth: 1000,
  storedPhotoBytes: 512 * 1024 * 1024,
  downloadedBytesPerProjectMonth: 256 * 1024 * 1024,
});

export class SocialError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const fail = (code, message) => { throw new SocialError(code, message); };
const hash = (value) => createHash('sha256').update(value).digest('hex');
export const pairId = (a, b) => hash(JSON.stringify([a, b]));
export const id = (value) => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    fail('invalid-argument', 'Invalid identifier.');
  }
  return value;
};
export const text = (value, maximum, optional = false) => {
  if (optional && (value === undefined || value === null)) return null;
  if (typeof value !== 'string' || !value.trim() || value.length > maximum) {
    fail('invalid-argument', 'Invalid text.');
  }
  return value.trim();
};
export const number = (value, maximum, positive = false) => {
  if (typeof value !== 'number' || !Number.isFinite(value) ||
      value < 0 || value > maximum || (positive && value === 0)) {
    fail('invalid-argument', 'Invalid measurement.');
  }
  return value;
};

// Whitelist serialization: source IDs, health data and local file paths never pass.
export function validateSnapshot(value, nutritionVisible) {
  if (!value || value.schemaVersion !== 1 ||
      !Array.isArray(value.items) || !value.items.length ||
      value.items.length > LIMITS.items) {
    fail('invalid-argument', 'Unsupported meal snapshot.');
  }
  const servings = number(value.servings, 1000, true);
  const items = value.items.map((item) => {
    const result = { name: text(item.name, 160) };
    if (item.portionAmount != null) {
      result.portionAmount = number(item.portionAmount, 100000, true);
      if (!['g', 'ml'].includes(item.portionUnit)) {
        fail('invalid-argument', 'Unsupported portion unit.');
      }
      result.portionUnit = item.portionUnit;
    }
    if (item.portionLabel != null) result.portionLabel = text(item.portionLabel, 100);
    if (item.portionQuantity != null) {
      result.portionQuantity = number(item.portionQuantity, 10000, true);
    }
    if (nutritionVisible) {
      for (const key of ['calories', 'protein', 'carbs', 'fat', 'fiber']) {
        result[key] = number(item[key], key === 'calories' ? 100000 : 10000);
      }
    }
    return result;
  });
  return { schemaVersion: 1, title: text(value.title, 160), servings, items };
}

export class SocialService {
  constructor(db, bucket, { clock = () => Date.now(), production = false } = {}) {
    this.db = db;
    this.bucket = bucket;
    this.clock = clock;
    this.production = production;
  }
  ref(collection, key) { return this.db.collection(collection).doc(key); }
  profile(uid) { return this.ref('socialProfiles', uid); }
  follow(a, b) { return this.ref('socialFollows', pairId(a, b)); }
  block(a, b) { return this.ref('socialBlocks', pairId(a, b)); }
  async requireActive(uid) {
    id(uid);
    const account = await this.profile(uid).get();
    if (!account.exists || account.data().deletingAt != null) {
      fail('permission-denied', 'An active social profile is required.');
    }
  }
  async blocked(a, b, transaction = null) {
    const refs = [this.block(a, b), this.block(b, a)];
    const records = transaction
      ? await transaction.getAll(...refs)
      : await this.db.getAll(...refs);
    return records.some((record) => record.exists);
  }
  async canRead(uid, authorId, transaction = null) {
    const refs = [this.profile(uid), this.profile(authorId), this.follow(uid, authorId)];
    const [viewer, author, follow] = transaction
      ? await transaction.getAll(...refs)
      : await this.db.getAll(...refs);
    return viewer.exists && author.exists && viewer.data().deletingAt == null &&
      author.data().deletingAt == null && !await this.blocked(uid, authorId, transaction) &&
      (uid === authorId || follow.data()?.status === 'accepted');
  }
  async consume(uid, { posting = false, uploading = false, bytes = 0 } = {}) {
    const now = new Date(this.clock());
    const day = now.toISOString().slice(0, 10);
    const month = day.slice(0, 7);
    const account = this.ref('socialUsage', `a_${pairId(uid, day)}`);
    const daily = this.ref('socialUsage', `d_${day}`);
    const monthly = this.ref('socialUsage', `m_${month}`);
    const storage = this.ref('socialUsage', 'storage');
    const config = this.ref('socialConfig', 'operating');
    await this.db.runTransaction(async (tx) => {
      const [a, d, m, s, c] = await tx.getAll(account, daily, monthly, storage, config);
      if (c.data()?.disabled === true || (this.production && c.data()?.enabled !== true)) {
        fail('resource-exhausted', 'Social sharing is temporarily unavailable.');
      }
      const av = a.data() ?? {}, dv = d.data() ?? {}, mv = m.data() ?? {}, sv = s.data() ?? {};
      if ((av.requests ?? 0) >= LIMITS.requestsPerAccountDay ||
          (dv.requests ?? 0) >= LIMITS.requestsPerProjectDay ||
          (posting && (av.posts ?? 0) >= LIMITS.postsPerAccountDay) ||
          (uploading && (mv.uploads ?? 0) >= LIMITS.uploadsPerProjectMonth) ||
          (uploading && (sv.bytes ?? 0) + bytes > LIMITS.storedPhotoBytes) ||
          (!uploading && (mv.downloadedBytes ?? 0) + bytes > LIMITS.downloadedBytesPerProjectMonth)) {
        fail('resource-exhausted', 'Social usage limit reached. Try again later.');
      }
      tx.set(account, { requests: (av.requests ?? 0) + 1, posts: (av.posts ?? 0) + (posting ? 1 : 0) });
      tx.set(daily, { requests: (dv.requests ?? 0) + 1 });
      tx.set(monthly, { uploads: (mv.uploads ?? 0) + (uploading ? 1 : 0),
        downloadedBytes: (mv.downloadedBytes ?? 0) + (uploading ? 0 : bytes) });
      if (uploading) tx.set(storage, { bytes: (sv.bytes ?? 0) + bytes });
    });
  }
  async setProfile(uid, input) {
    id(uid);
    const displayName = text(input.displayName, 60);
    await this.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const ref = this.profile(uid);
      const [record, deleted] = await tx.getAll(ref, this.ref('socialDeletedAccounts', uid));
      if (deleted.exists) fail('permission-denied', 'Account was deleted.');
      if (record.data()?.deletingAt != null) fail('permission-denied', 'Account deletion is in progress.');
      tx.set(ref, { accountId: uid, displayName, createdAt: record.data()?.createdAt ?? this.clock(), updatedAt: this.clock() });
      return { accountId: uid, displayName };
    });
  }
  async createInvitation(uid, audience = 'follow') {
    if (!['follow', 'partner'].includes(audience)) fail('invalid-argument', 'Invalid invitation audience.');
    await this.requireActive(uid);
    await this.consume(uid);
    const token = randomBytes(32).toString('base64url');
    const expiresAt = this.clock() + 48 * 60 * 60 * 1000;
    await this.ref('socialInvitations', hash(token)).create({ inviterId: uid, audience, expiresAt, uses: 0, maxUses: 1, revokedAt: null });
    return { token, expiresAt };
  }
  async revokeInvitation(uid, token) {
    text(token, 100);
    const ref = this.ref('socialInvitations', hash(token));
    await this.db.runTransaction(async (tx) => {
      const invitation = await tx.get(ref);
      if (invitation.data()?.inviterId !== uid) fail('permission-denied', 'Only the inviter can revoke this invitation.');
      tx.update(ref, { revokedAt: this.clock() });
    });
    return {};
  }
  async requestFollow(uid, token) {
    await this.requireActive(uid);
    text(token, 100);
    await this.consume(uid);
    const ref = this.ref('socialInvitations', hash(token));
    return this.db.runTransaction(async (tx) => {
      const invitation = (await tx.get(ref)).data();
      if (!invitation || (invitation.audience ?? 'follow') !== 'follow' || invitation.revokedAt != null || invitation.expiresAt <= this.clock()) {
        fail('not-found', 'Invitation is unavailable.');
      }
      const authorId = invitation.inviterId;
      if (uid === authorId) fail('invalid-argument', 'Cannot follow yourself.');
      const followRef = this.follow(uid, authorId);
      const [follow, author, viewer] = await tx.getAll(followRef, this.profile(authorId), this.profile(uid));
      if (!viewer.exists || viewer.data().deletingAt != null || !author.exists || author.data().deletingAt != null || await this.blocked(uid, authorId, tx)) {
        fail('permission-denied', 'Invitation is unavailable.');
      }
      if (follow.exists) return { authorId, status: follow.data().status, displayName: author.data().displayName };
      if (invitation.uses >= invitation.maxUses) fail('not-found', 'Invitation has already been used.');
      // A fixed cap makes one Firestore `in` query sufficient for feed reads.
      const follows = await tx.get(this.db.collection('socialFollows').where('followerId', '==', uid));
      if (follows.size >= LIMITS.followedAuthors) fail('resource-exhausted', 'Connection limit reached.');
      tx.set(followRef, { followerId: uid, followedId: authorId, status: 'pending', createdAt: this.clock() });
      tx.update(ref, { uses: invitation.uses + 1 });
      return { authorId, status: 'pending', displayName: author.data().displayName };
    });
  }
  async approveFollow(uid, followerId) {
    id(followerId);
    await this.requireActive(uid);
    await this.consume(uid);
    await this.db.runTransaction(async (tx) => {
      const ref = this.follow(followerId, uid), follow = await tx.get(ref);
      const [follower, author] = await tx.getAll(this.profile(followerId), this.profile(uid));
      if (!author.exists || author.data().deletingAt != null || !follow.exists || !follower.exists || follower.data().deletingAt != null ||
          await this.blocked(uid, followerId, tx)) fail('permission-denied', 'Follow request is unavailable.');
      tx.update(ref, { status: 'accepted', acceptedAt: this.clock() });
    });
    return {};
  }
  async removeFollow(uid, otherId, incoming) {
    id(otherId);
    await this.follow(incoming ? otherId : uid, incoming ? uid : otherId).delete();
    return {};
  }
  async blockAccount(uid, otherId) {
    id(uid); id(otherId);
    if (uid === otherId) fail('invalid-argument', 'Cannot block yourself.');
    const batch = this.db.batch();
    batch.set(this.block(uid, otherId), { blockerId: uid, blockedId: otherId, createdAt: this.clock() });
    batch.delete(this.follow(uid, otherId));
    batch.delete(this.follow(otherId, uid));
    await batch.commit();
    return {};
  }
  async publish(uid, input) {
    await this.requireActive(uid);
    const postId = pairId(uid, id(input.operationId));
    if (!['meal', 'recipe'].includes(input.kind) || typeof input.nutritionVisible !== 'boolean') {
      fail('invalid-argument', 'Invalid post.');
    }
    const snapshot = validateSnapshot(input.snapshot, input.nutritionVisible);
    const caption = text(input.caption, 1000, true);
    const blobId = input.photoBlobId == null ? null : id(input.photoBlobId);
    const ref = this.ref('socialPosts', postId);
    // A deleted ID is retained as a tombstone so stale publication cannot recreate it.
    const existing = await ref.get();
    if (existing.exists) return { id: postId, revision: existing.data().revision, deleted: existing.data().deletedAt != null };
    await this.consume(uid, { posting: true });
    return this.db.runTransaction(async (tx) => {
      const [record, account] = await tx.getAll(ref, this.profile(uid));
      if (!account.exists || account.data().deletingAt != null) fail('permission-denied', 'Account is unavailable.');
      if (record.exists) return { id: postId, revision: record.data().revision, deleted: record.data().deletedAt != null };
      if (blobId) {
        const blob = (await tx.get(this.ref('socialBlobs', blobId))).data();
        if (!blob || blob.ownerId !== uid || blob.state !== 'ready' || blob.postId != null || blob.partnerMealId != null) {
          fail('failed-precondition', 'Photo must be ready and belong to this account.');
        }
        tx.update(this.ref('socialBlobs', blobId), { postId, cleanupAfter: null });
      }
      const now = this.clock();
      tx.create(ref, { authorId: uid, kind: input.kind, snapshot, caption, nutritionVisible: input.nutritionVisible,
        photoBlobId: blobId, revision: 1, publishedAt: now, updatedAt: now, deletedAt: null });
      return { id: postId, revision: 1, deleted: false };
    });
  }
  async editPost(uid, input) {
    const ref = this.ref('socialPosts', id(input.postId));
    if (typeof input.nutritionVisible !== 'boolean') fail('invalid-argument', 'Invalid nutrition visibility.');
    const snapshot = validateSnapshot(input.snapshot, input.nutritionVisible);
    const caption = text(input.caption, 1000, true);
    await this.requireActive(uid);
    await this.consume(uid, { posting: true });
    return this.db.runTransaction(async (tx) => {
      const [record, account] = await tx.getAll(ref, this.profile(uid));
      const post = record.data();
      if (!account.exists || account.data().deletingAt != null || !post || post.authorId !== uid) fail('permission-denied', 'Post is unavailable.');
      if (post.deletedAt != null) fail('not-found', 'Post was deleted.');
      if (post.revision !== input.baseRevision) fail('failed-precondition', 'Post changed. Refresh before editing.');
      const revision = post.revision + 1;
      tx.update(ref, { snapshot, caption, nutritionVisible: input.nutritionVisible, revision, updatedAt: this.clock() });
      return { id: ref.id, revision };
    });
  }
  async deletePost(uid, postId) {
    const ref = this.ref('socialPosts', id(postId));
    await this.db.runTransaction(async (tx) => {
      const post = (await tx.get(ref)).data();
      if (!post || post.authorId !== uid) fail('permission-denied', 'Post is unavailable.');
      tx.set(ref, { authorId: uid, revision: post.revision + (post.deletedAt == null ? 1 : 0),
        deletedAt: post.deletedAt ?? this.clock(), publishedAt: post.publishedAt, photoBlobId: null });
      if (post.photoBlobId) tx.update(this.ref('socialBlobs', post.photoBlobId), { state: 'deleting', postId: null, cleanupAfter: 0 });
    });
    return {};
  }
  async readPost(uid, postId) {
    const record = await this.ref('socialPosts', id(postId)).get();
    if (!record.exists || record.data().deletedAt != null || !await this.canRead(uid, record.data().authorId)) {
      fail('permission-denied', 'Post is unavailable.');
    }
    return { id: record.id, ...record.data() };
  }
  async feed(uid, input = {}) {
    await this.requireActive(uid);
    await this.consume(uid);
    const follows = await this.db.collection('socialFollows').where('followerId', '==', uid).where('status', '==', 'accepted').limit(LIMITS.followedAuthors).get();
    const authors = [uid];
    for (const follow of follows.docs) {
      if (await this.canRead(uid, follow.data().followedId)) authors.push(follow.data().followedId);
    }
    let query = this.db.collection('socialPosts').where('authorId', 'in', authors)
      .orderBy('publishedAt', 'desc').orderBy(FieldPath.documentId(), 'desc');
    if (input.cursor != null) {
      number(input.cursor.publishedAt, Number.MAX_SAFE_INTEGER);
      query = query.startAfter(input.cursor.publishedAt, id(input.cursor.id));
    }
    const records = await query.limit(LIMITS.pageSize).get();
    const posts = [];
    for (const record of records.docs) {
      const post = record.data();
      if (post.deletedAt == null && await this.canRead(uid, post.authorId)) posts.push({ id: record.id, ...post });
    }
    const last = records.docs.at(-1);
    return { posts, cursor: records.size === LIMITS.pageSize ? { id: last.id, publishedAt: last.data().publishedAt } : null };
  }
  async react(uid, input) {
    const postId = id(input.postId);
    if (input.kind !== null && !['heart', 'encourage', 'yum'].includes(input.kind)) fail('invalid-argument', 'Invalid reaction.');
    await this.requireActive(uid);
    await this.consume(uid);
    await this.db.runTransaction(async (tx) => {
      const post = (await tx.get(this.ref('socialPosts', postId))).data();
      if (!post || post.deletedAt != null || !await this.canRead(uid, post.authorId, tx)) {
        fail('permission-denied', 'Post is unavailable.');
      }
      const ref = this.ref('socialReactions', pairId(postId, uid));
      if (input.kind === null) tx.delete(ref);
      else tx.set(ref, { postId, actorId: uid, kind: input.kind, updatedAt: this.clock() });
    });
    return {};
  }
  async reservePhoto(uid, operationId, bytes, contentHash = null) {
    await this.requireActive(uid);
    number(bytes, LIMITS.photoBytes, true);
    const blobId = pairId(uid, id(operationId));
    const ref = this.ref('socialBlobs', blobId), previous = await ref.get();
    if (previous.exists) {
      if (previous.data().contentHash !== contentHash) fail('failed-precondition', 'Upload ID was already used for another photo.');
      return { id: blobId, ...previous.data() };
    }
    await this.consume(uid, { uploading: true, bytes });
    await this.db.runTransaction(async (tx) => {
      const [record, account] = await tx.getAll(ref, this.profile(uid));
      if (!account.exists || account.data().deletingAt != null) {
        fail('permission-denied', 'Account is unavailable.');
      }
      if (record.exists && record.data().contentHash !== contentHash) fail('failed-precondition', 'Upload ID was already used for another photo.');
      if (!record.exists) tx.create(ref, { contentHash, ownerId: uid, postId: null, state: 'pending', bytes,
        createdAt: this.clock(), cleanupAfter: this.clock() + 24 * 60 * 60 * 1000, path: `social/${uid}/${blobId}.jpg` });
    });
    return { id: blobId, ...(await ref.get()).data() };
  }
  async readPhoto(uid, blobId) {
    const blob = (await this.ref('socialBlobs', id(blobId)).get()).data();
    if (!blob || blob.state !== 'ready' || (!blob.postId && !blob.partnerMealId)) fail('permission-denied', 'Photo is unavailable.');
    const authorize = async () => {
      if (blob.postId) return this.readPost(uid, blob.postId);
      if (!this.partners) fail('permission-denied', 'Photo is unavailable.');
      const meal = await this.partners.readMeal(uid, blob.partnerMealId);
      if (meal.photoBlobId !== blobId) fail('permission-denied', 'Photo is unavailable.');
    };
    await authorize();
    await this.consume(uid, { bytes: blob.bytes });
    const [bytes] = await this.bucket.file(blob.path).download();
    // Access checked again after I/O; no reusable URL is returned.
    await authorize();
    return { mediaType: 'image/jpeg', base64: bytes.toString('base64') };
  }
  async beginDeletion(uid) {
    id(uid);
    await this.db.runTransaction(async (tx) => {
      const ref = this.profile(uid), profile = await tx.get(ref);
      tx.set(ref, { accountId: uid, deletingAt: profile.data()?.deletingAt ?? this.clock() });
      tx.set(this.ref('socialDeletionJobs', uid), { accountId: uid, state: 'pending' });
    });
    return { state: 'pending' };
  }
}
