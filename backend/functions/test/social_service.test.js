import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { ref, getBytes, uploadBytes } from 'firebase/storage';
import sharp from 'sharp';
import { LIMITS, SocialService, validateSnapshot, pairId } from '../src/social_service.js';
import { uploadPhoto, cleanAbandonedPhotos } from '../src/photo_service.js';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  throw new Error('Run npm run test:emulator; these tests must never use production.');
}
let environment, admin, db, service;
let now = Date.UTC(2026, 9, 7, 12);
const objects = new Map();
const bucket = { file: (path) => ({
  save: async (bytes) => objects.set(path, bytes),
  download: async () => [objects.get(path)],
  delete: async () => objects.delete(path),
}) };
const snapshot = { schemaVersion: 1, title: 'Dinner', servings: 2, items: [
  { name: 'Rice', calories: 400, protein: 8, carbs: 88, fat: 1, fiber: 2,
    portionAmount: 300, portionUnit: 'g', sourceFoodId: 'PRIVATE', apiKey: 'PRIVATE' },
] };
const post = (operationId = 'operation1', photoBlobId = null) => ({
  operationId, kind: 'meal', snapshot, nutritionVisible: true, photoBlobId,
});
const denied = (promise) => assert.rejects(promise, (error) => error.code === 'permission-denied');
async function connect(follower = 'bob', author = 'alice') {
  const invitation = await service.createInvitation(author);
  await service.requestFollow(follower, invitation.token);
  await service.approveFollow(author, follower);
}
before(async () => {
  environment = await initializeTestEnvironment({ projectId: 'demo-sophis',
    firestore: { rules: await readFile('../firestore.rules', 'utf8') },
    storage: { rules: await readFile('../storage.rules', 'utf8') },
  });
  admin = initializeApp({ projectId: 'demo-sophis' }, 'social-tests');
  db = getFirestore(admin);
  service = new SocialService(db, bucket, { clock: () => now });
});
beforeEach(async () => {
  await environment.clearFirestore();
  objects.clear();
  now = Date.UTC(2026, 9, 7, 12);
  for (const account of ['alice', 'bob', 'eve']) await service.setProfile(account, { displayName: account });
});
after(async () => { await environment?.cleanup(); if (admin) await deleteApp(admin); });

test('denied guest and authenticated direct database/storage access', async () => {
  await service.publish('alice', post());
  for (const context of [environment.unauthenticatedContext(), environment.authenticatedContext('alice'), environment.authenticatedContext('eve')]) {
    await assertFails(getDoc(doc(context.firestore(), 'socialPosts', pairId('alice', 'operation1'))));
    await assertFails(setDoc(doc(context.firestore(), 'socialProfiles', 'alice'), { displayName: 'forged' }));
    await assertFails(uploadBytes(ref(context.storage(), 'social/forged.jpg'), new Uint8Array([1])));
    await assertFails(getBytes(ref(context.storage(), 'social/forged.jpg')));
  }
});
test('required author approval and granted existing history to a new follower', async () => {
  const { id } = await service.publish('alice', post());
  const invitation = await service.createInvitation('alice');
  await service.requestFollow('bob', invitation.token);
  await denied(service.approveFollow('eve', 'bob'));
  await denied(service.readPost('bob', id));
  await service.approveFollow('alice', 'bob');
  assert.equal((await service.feed('bob')).posts[0].id, id);
  assert.equal((await service.feed('eve')).posts.length, 0);
});
test('rejected expired, revoked and consumed invitations', async () => {
  const first = await service.createInvitation('alice');
  await service.revokeInvitation('alice', first.token);
  await assert.rejects(service.requestFollow('bob', first.token), { code: 'not-found' });
  const second = await service.createInvitation('alice');
  now = second.expiresAt;
  await assert.rejects(service.requestFollow('bob', second.token), { code: 'not-found' });
  now = Date.UTC(2026, 9, 7, 12);
  const third = await service.createInvitation('alice');
  await service.requestFollow('bob', third.token);
  await assert.rejects(service.requestFollow('eve', third.token), { code: 'not-found' });
});
test('revoked reads and queued reactions immediately after removal or either-direction block', async () => {
  await connect();
  const { id } = await service.publish('alice', post());
  await service.react('bob', { postId: id, kind: 'heart' });
  await service.removeFollow('alice', 'bob', true);
  await denied(service.readPost('bob', id));
  await denied(service.react('bob', { postId: id, kind: 'yum' }));
  await connect();
  await service.blockAccount('bob', 'alice');
  await denied(service.readPost('bob', id));
  assert.equal((await service.feed('bob')).posts.length, 0);
  const invitation = await service.createInvitation('alice');
  await denied(service.requestFollow('bob', invitation.token));
});
test('published once on retries and prevented deleted posts from being recreated by stale work', async () => {
  const results = await Promise.all([service.publish('alice', post()), service.publish('alice', post())]);
  assert.equal(results[0].id, results[1].id);
  assert.equal((await db.collection('socialPosts').get()).size, 1);
  await service.deletePost('alice', results[0].id);
  assert.equal((await service.publish('alice', post())).deleted, true);
  await denied(service.readPost('alice', results[0].id));
  await assert.rejects(service.editPost('alice', { ...post(), postId: results[0].id, baseRevision: 1 }), { code: 'not-found' });
});
test('rejected non-owner edits/deletes and stale revisions', async () => {
  const { id } = await service.publish('alice', post());
  await denied(service.deletePost('eve', id));
  await denied(service.editPost('eve', { ...post(), postId: id, baseRevision: 1 }));
  assert.equal((await service.editPost('alice', { ...post(), postId: id, baseRevision: 1 })).revision, 2);
  await assert.rejects(service.editPost('alice', { ...post(), postId: id, baseRevision: 1 }), { code: 'failed-precondition' });
});
test('removed hidden nutrition and private metadata from snapshots', () => {
  const publicSnapshot = validateSnapshot(snapshot, false);
  assert.deepEqual(publicSnapshot.items[0], { name: 'Rice', portionAmount: 300, portionUnit: 'g' });
  assert.equal(validateSnapshot(snapshot, true).items[0].apiKey, undefined);
  assert.throws(() => validateSnapshot({ ...snapshot, servings: 0 }, true));
  assert.throws(() => validateSnapshot({ ...snapshot, items: [{ ...snapshot.items[0], calories: NaN }] }, true));
});
test('stored one reaction per actor and supported removing it', async () => {
  await connect();
  const { id } = await service.publish('alice', post());
  await service.react('bob', { postId: id, kind: 'heart' });
  await service.react('bob', { postId: id, kind: 'yum' });
  assert.equal((await db.collection('socialReactions').get()).size, 1);
  await service.react('bob', { postId: id, kind: null });
  assert.equal((await db.collection('socialReactions').get()).size, 0);
});
test('protected photo reads after revoke and stripped metadata during upload', async () => {
  await connect();
  const bytes = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#ffffff' } })
    .jpeg().withMetadata().toBuffer();
  const { blobId } = await uploadPhoto(service, 'alice', { operationId: 'photo1', base64: bytes.toString('base64') });
  const { id } = await service.publish('alice', post('photoPost', blobId));
  await denied(service.readPhoto('eve', blobId));
  const photo = await service.readPhoto('bob', blobId);
  assert.equal((await sharp(Buffer.from(photo.base64, 'base64')).metadata()).exif, undefined);
  await service.removeFollow('alice', 'bob', true);
  await denied(service.readPhoto('bob', blobId));
  await service.deletePost('alice', id);
  await denied(service.readPhoto('alice', blobId));
  assert.equal(await cleanAbandonedPhotos(service), 1);
  assert.equal(objects.size, 0);
});
test('refused publication until photo ready and cleaned interrupted uploads', async () => {
  await service.reservePhoto('alice', 'pending', 100);
  await assert.rejects(service.publish('alice', post('photoPost', pairId('alice', 'pending'))), { code: 'failed-precondition' });
  await assert.rejects(service.publish('bob', post('other', pairId('alice', 'pending'))), { code: 'failed-precondition' });
  now += 25 * 60 * 60 * 1000;
  assert.equal(await cleanAbandonedPhotos(service), 1);
  assert.equal(await cleanAbandonedPhotos(service), 0);
});
test('bounded chronological pages with deterministic cursor for equal timestamps', async () => {
  await connect();
  for (let n = 0; n < 25; n++) {
    // Seed validated server records to avoid account posting limit in this fixture.
    await db.collection('socialPosts').doc(`alice_${n.toString().padStart(3, '0')}`).set({
      authorId: 'alice', snapshot, publishedAt: now, deletedAt: null,
    });
  }
  const first = await service.feed('bob');
  assert.equal(first.posts.length, LIMITS.pageSize);
  const second = await service.feed('bob', { cursor: first.cursor });
  assert.equal(second.posts.length, 5);
  assert.equal(new Set([...first.posts, ...second.posts].map((p) => p.id)).size, 25);
  assert.equal(second.cursor, null);
});
test('stopped new work at quota while allowing privacy revocation', async () => {
  await connect();
  const { id } = await service.publish('alice', post());
  await service.ref('socialConfig', 'operating').set({ disabled: true });
  await assert.rejects(service.publish('alice', post('next')), { code: 'resource-exhausted' });
  await assert.rejects(service.feed('bob'), { code: 'resource-exhausted' });
  await service.deletePost('alice', id);
  await service.blockAccount('alice', 'bob');
  await service.beginDeletion('alice');
});
test('denied all reads and publication immediately after account deletion began', async () => {
  await connect();
  const { id } = await service.publish('alice', post());
  await service.beginDeletion('alice');
  await denied(service.readPost('bob', id));
  await denied(service.publish('alice', post('afterDelete')));
  assert.equal((await service.ref('socialDeletionJobs', 'alice').get()).data().state, 'pending');
});
test('production defaulted closed without an explicit operating configuration', async () => {
  const production = new SocialService(db, bucket, { production: true });
  await assert.rejects(production.feed('bob'), { code: 'resource-exhausted' });
});

test('cleaned account data retryably and prevented old tokens recreating the profile', async () => {
  const { cleanupAccount } = await import('../src/cleanup_service.js');
  await connect();
  const { id } = await service.publish('alice', post());
  await service.react('bob', { postId: id, kind: 'heart' });
  await service.beginDeletion('alice');
  let attempts = 0;
  const auth = { deleteUser: async () => {
    attempts++;
    if (attempts === 1) throw new Error('transient auth error');
  } };
  await assert.rejects(cleanupAccount(service, 'alice', auth));
  await denied(service.setProfile('alice', { displayName: 'stale token' }));
  await cleanupAccount(service, 'alice', auth);
  await cleanupAccount(service, 'alice', auth);
  assert.equal((await db.collection('socialPosts').get()).size, 0);
  assert.equal((await db.collection('socialReactions').get()).size, 0);
  assert.equal((await db.collection('socialFollows').get()).size, 0);
  assert.equal((await service.profile('alice').get()).exists, false);
  assert.equal((await service.profile('bob').get()).exists, true);
  assert.equal(attempts, 2);
});

test('kept a photo intact on concurrent idempotent retries and rejected reused upload IDs', async () => {
  const bytes = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#ffffff' } }).jpeg().toBuffer();
  const input = { operationId: 'concurrentPhoto', base64: bytes.toString('base64') };
  const results = await Promise.all([uploadPhoto(service, 'alice', input), uploadPhoto(service, 'alice', input)]);
  assert.equal(results[0].blobId, results[1].blobId);
  assert.equal(objects.size, 1);
  const different = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#000000' } }).jpeg().toBuffer();
  await assert.rejects(uploadPhoto(service, 'alice', { ...input, base64: different.toString('base64') }), { code: 'failed-precondition' });
  assert.equal(objects.size, 1);
});

test('cancelled an unpublished operation before a delayed publish without reserving another author ID', async () => {
  const cancelled = pairId('alice', 'queuedOperation');
  await service.deletePost('alice', cancelled, 'queuedOperation');
  const result = await service.publish('alice', post('queuedOperation'));
  assert.equal(result.deleted, true);
  assert.equal((await service.feed('alice')).posts.length, 0);
  await denied(service.deletePost('bob', pairId('alice', 'otherOperation'), 'otherOperation'));
  assert.equal((await service.ref('socialPosts', pairId('alice', 'otherOperation')).get()).exists, false);
  await service.beginDeletion('alice');
  await denied(service.deletePost('alice', pairId('alice', 'afterDeletion'), 'afterDeletion'));
});

test('previewed invitations privately before consumption and hid expired, blocked and other-recipient invites', async () => {
  const invitation = await service.createInvitation('alice');
  assert.equal((await service.previewInvitation('bob', invitation.token)).displayName, 'alice');
  await service.requestFollow('bob', invitation.token);
  assert.equal((await service.previewInvitation('bob', invitation.token)).audience, 'follow');
  await assert.rejects(service.previewInvitation('eve', invitation.token), { code: 'not-found' });
  await service.blockAccount('alice', 'bob');
  await denied(service.previewInvitation('bob', invitation.token));
  now = invitation.expiresAt;
  await assert.rejects(service.previewInvitation('eve', invitation.token), { code: 'not-found' });
});

test('listed only own relationship participants and required separate approval for reciprocal follows', async () => {
  const invitation = await service.createInvitation('alice');
  await service.requestFollow('bob', invitation.token);
  await denied(service.requestReciprocal('alice', 'bob'));
  assert.equal((await service.relationships('alice', { direction: 'incoming' })).relationships[0].accountId, 'bob');
  assert.equal((await service.relationships('eve', { direction: 'incoming' })).relationships.length, 0);
  await service.approveFollow('alice', 'bob');
  await service.requestReciprocal('alice', 'bob');
  await service.requestReciprocal('alice', 'bob');
  const { id } = await service.publish('bob', post());
  await denied(service.readPost('alice', id));
  await service.approveFollow('bob', 'alice');
  assert.equal((await service.readPost('alice', id)).authorId, 'bob');
  await service.blockAccount('bob', 'alice');
  assert.equal((await service.relationships('alice', { direction: 'outgoing' })).relationships.length, 0);
});

test('loaded only the authenticated own profile and allowed missing-profile onboarding', async () => {
  assert.equal((await service.ownProfile('alice')).profile.displayName, 'alice');
  assert.equal((await service.ownProfile('newAccount')).profile, null);
  await service.beginDeletion('alice');
  await denied(service.ownProfile('alice'));
});
