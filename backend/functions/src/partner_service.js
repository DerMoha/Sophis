import { createHash } from 'node:crypto';
import { FieldPath } from 'firebase-admin/firestore';
import { SocialError, id, number, pairId, validateSnapshot } from './social_service.js';

export const PARTNER_LIMITS = Object.freeze({ connections: 5, periods: 128, contributionsPerDate: 50, pageSize: 20 });
const fail = (code, message) => { throw new SocialError(code, message); };
const tokenHash = (value) => createHash('sha256').update(value).digest('hex');
const fields = ['meals', 'summaries', 'photos'];
export function defaultPartnerSettings() {
  return { meals: false, summaries: false, photos: false, goals: false, goalsSnapshot: null, paused: false, revision: 0,
    mealGeneration: 0, summaryGeneration: 0, photoGeneration: 0,
    mealPeriods: [], summaryPeriods: [], photoPeriods: [] };
}
const periodKey = { meals: 'mealPeriods', summaries: 'summaryPeriods', photos: 'photoPeriods' };
const generationKey = { meals: 'mealGeneration', summaries: 'summaryGeneration', photos: 'photoGeneration' };
const isWithin = (periods, instant) => periods.some((period) => instant >= period.start && (period.end == null || instant < period.end));
const activeStart = (periods) => periods.at(-1)?.end == null ? periods.at(-1)?.start : null;
function sourceFields(input, now) {
  id(input.sourceMealId);
  number(input.originallyLoggedAt, now);
  number(input.changedAt, now);
  number(input.sourceRevision, Number.MAX_SAFE_INTEGER, true);
  if (!Number.isSafeInteger(input.sourceRevision) || input.changedAt < input.originallyLoggedAt) fail('invalid-argument', 'Invalid source revision or time.');
  return { sourceMealId: input.sourceMealId, originallyLoggedAt: input.originallyLoggedAt,
    changedAt: input.changedAt, sourceRevision: input.sourceRevision };
}
function dateFields(input) {
  if (typeof input.localDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.localDate) ||
      !Number.isFinite(Date.parse(`${input.localDate}T00:00:00Z`)) ||
      new Date(`${input.localDate}T00:00:00Z`).toISOString().slice(0, 10) !== input.localDate) {
    fail('invalid-argument', 'Invalid summary date.');
  }
  if (typeof input.timeZone !== 'string' || input.timeZone.length > 64) fail('invalid-argument', 'Invalid time zone.');
  try { new Intl.DateTimeFormat('en', { timeZone: input.timeZone }); }
  catch { fail('invalid-argument', 'Invalid time zone.'); }
  return { localDate: input.localDate, timeZone: input.timeZone };
}
function eligibility(settings, kind, source, existing) {
  const periods = settings[periodKey[kind]], start = activeStart(periods);
  if (!settings[kind] || settings.paused || start == null || source.changedAt < start ||
      !isWithin(periods, source.originallyLoggedAt) ||
      (!existing && source.originallyLoggedAt < start)) {
    fail('permission-denied', 'This update is outside active sharing consent.');
  }
  if (existing && source.originallyLoggedAt !== existing.originallyLoggedAt) {
    fail('failed-precondition', 'Original logging time cannot change.');
  }
}

export class PartnerService {
  constructor(social) {
    this.social = social;
    this.db = social.db;
    social.partners = this;
  }
  ref(connectionId) { return this.social.ref('socialPartners', id(connectionId)); }
  mealRef(connectionId, authorId, sourceId) { return this.social.ref('socialPartnerMeals', pairId(connectionId, pairId(authorId, sourceId))); }
  contributionRef(connectionId, authorId, sourceId) { return this.social.ref('socialPartnerContributions', pairId(connectionId, pairId(authorId, sourceId))); }
  summaryRef(connectionId, authorId, generation, date, timeZone) {
    return this.social.ref('socialPartnerSummaries', pairId(connectionId, pairId(authorId, JSON.stringify([generation, date, timeZone]))));
  }
  async authorized(uid, connectionId, tx = null, { allowPending = false, allowRevoked = false } = {}) {
    const connection = (await (tx ? tx.get(this.ref(connectionId)) : this.ref(connectionId).get())).data();
    if (!connection || !connection.participants.includes(uid)) fail('permission-denied', 'Partner connection is unavailable.');
    if (!allowRevoked && connection.revokedAt != null) fail('permission-denied', 'Partner connection was disconnected.');
    if (!allowPending && connection.status !== 'accepted') fail('permission-denied', 'Partner connection must be mutually accepted.');
    const profiles = tx
      ? await tx.getAll(...connection.participants.map((account) => this.social.profile(account)))
      : await this.db.getAll(...connection.participants.map((account) => this.social.profile(account)));
    if (profiles.some((profile) => !profile.exists || profile.data().deletingAt != null) ||
        await this.social.blocked(...connection.participants, tx)) {
      fail('permission-denied', 'Partner connection is unavailable.');
    }
    return connection;
  }
  async request(uid, input) {
    await this.social.requireActive(uid);
    if (typeof input.token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(input.token)) fail('invalid-argument', 'Invalid invitation.');
    await this.social.consume(uid);
    const invitationId = tokenHash(input.token);
    const invitationRef = this.social.ref('socialInvitations', invitationId);
    return this.db.runTransaction(async (tx) => {
      const invitation = (await tx.get(invitationRef)).data();
      if (!invitation || invitation.audience !== 'partner' || invitation.revokedAt != null || invitation.expiresAt <= this.social.clock()) {
        fail('not-found', 'Partner invitation is unavailable.');
      }
      if (uid === invitation.inviterId) fail('invalid-argument', 'Cannot partner with yourself.');
      const connectionId = pairId(invitationId, uid);
      const ref = this.ref(connectionId);
      const existing = (await tx.get(ref)).data();
      const participants = [invitation.inviterId, uid];
      const profiles = await tx.getAll(...participants.map((account) => this.social.profile(account)));
      if (profiles.some((profile) => !profile.exists || profile.data().deletingAt != null) || await this.social.blocked(...participants, tx)) {
        fail('permission-denied', 'Partner invitation is unavailable.');
      }
      if (existing) {
        if (existing.revokedAt != null) fail('permission-denied', 'Connection was disconnected. Use a new invitation.');
        return { id: connectionId, status: existing.status };
      }
      if (invitation.uses >= invitation.maxUses) fail('not-found', 'Invitation has already been used.');
      for (const account of participants) {
        const records = await tx.get(this.db.collection('socialPartners').where('participants', 'array-contains', account).where('revokedAt', '==', null).limit(PARTNER_LIMITS.connections));
        if (records.size >= PARTNER_LIMITS.connections) fail('resource-exhausted', 'Partner connection limit reached.');
      }
      tx.create(ref, { participants, requesterId: uid, inviterId: invitation.inviterId,
        status: 'pending', createdAt: this.social.clock(), acceptedAt: null, revokedAt: null,
        settings: Object.fromEntries(participants.map((account) => [account, defaultPartnerSettings()])) });
      tx.update(invitationRef, { uses: invitation.uses + 1 });
      return { id: connectionId, status: 'pending' };
    });
  }
  async accept(uid, connectionId) {
    await this.social.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const connection = await this.authorized(uid, connectionId, tx, { allowPending: true });
      if (connection.inviterId !== uid) fail('permission-denied', 'Only the invited partner can approve this request.');
      if (connection.status !== 'accepted') tx.update(this.ref(connectionId), { status: 'accepted', acceptedAt: this.social.clock() });
      return { id: connectionId, status: 'accepted' };
    });
  }
  async list(uid) {
    await this.social.requireActive(uid);
    await this.social.consume(uid);
    const records = await this.db.collection('socialPartners').where('participants', 'array-contains', uid)
      .where('revokedAt', '==', null).limit(PARTNER_LIMITS.connections).get();
    const connections = [];
    for (const record of records.docs) {
      try {
        const connection = await this.authorized(uid, record.id, null, { allowPending: true });
        const other = connection.participants.find((account) => account !== uid);
        const profile = (await this.social.profile(other).get()).data();
        connections.push({ id: record.id, ...connection, displayName: profile.displayName,
          settings: Object.fromEntries(Object.entries(connection.settings).map(([account, settings]) => {
            const { goalsSnapshot, goalSourceRevision, ...publicSettings } = settings;
            return [account, account === uid ? { ...publicSettings, goalSourceRevision: goalSourceRevision ?? 0 } : publicSettings];
          })) });
      } catch (error) { if (!(error instanceof SocialError) || error.code !== 'permission-denied') throw error; }
    }
    return { connections };
  }
  async updateSettings(uid, input) {
    const desired = {};
    for (const field of [...fields, 'paused']) {
      if (typeof input[field] !== 'boolean') fail('invalid-argument', 'Invalid partner sharing settings.');
      desired[field] = input[field];
    }
    if (input.goals != null && typeof input.goals !== 'boolean') fail('invalid-argument', 'Invalid goal consent.');
    desired.goals = input.goals ?? false;
    number(input.baseRevision, Number.MAX_SAFE_INTEGER);
    // Individual revocations must work even if unrelated sharing stays on.
    const prior = await this.authorized(uid, input.connectionId);
    const previous = prior.settings[uid];
    const expanding = !desired.paused && [...fields, 'goals'].some((field) => desired[field] && (!previous[field] || previous.paused));
    if (expanding) await this.social.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const connection = await this.authorized(uid, input.connectionId, tx);
      const current = connection.settings[uid];
      if (current.revision !== input.baseRevision) fail('failed-precondition', 'Sharing settings changed. Refresh before retrying.');
      const next = { ...current, ...desired, revision: current.revision + 1 };
      if (!desired.goals) next.goalsSnapshot = null;
      if (!desired.summaries) delete next.summaryTimeZone;
      if (!desired.meals) delete next.mealTimeZone;
      const now = this.social.clock();
      for (const field of fields) {
        const key = periodKey[field], generation = generationKey[field];
        let periods = current[key].map((period) => ({ ...period }));
        if (current[field] && !desired[field]) {
          // A sharing toggle is privacy revocation; a pause merely freezes data.
          next[generation]++;
          periods = [];
        }
        const open = activeStart(periods) != null;
        const shouldOpen = desired[field] && !desired.paused;
        if (open && !shouldOpen) periods.at(-1).end = now;
        if (!open && shouldOpen) {
          if (periods.length >= PARTNER_LIMITS.periods) fail('resource-exhausted', 'Sharing history limit reached. Disconnect and create a new connection.');
          periods.push({ start: now, end: null });
        }
        next[key] = periods;
      }
      tx.update(this.ref(input.connectionId), { settings: { ...connection.settings, [uid]: next } });
      const generations = Object.fromEntries(fields.filter((field) => current[field] && !desired[field]).map((field) => [generationKey[field], next[generationKey[field]]]));
      if (Object.keys(generations).length) tx.create(this.social.ref('socialPartnerCleanupJobs', pairId(input.connectionId, `${uid}_${next.revision}`)), { connectionId: input.connectionId, authorId: uid, generations });
      return { settings: next };
    });
  }
  async syncGoals(uid, input) {
    const goals = {};
    for (const key of input.goals == null ? [] : ['calories', 'protein', 'carbs', 'fat']) {
      goals[key] = number(input.goals?.[key], key === 'calories' ? 100000 : 10000);
    }
    const date = input.localDate == null ? {} : dateFields(input);
    const sourceRevision = number(input.sourceRevision ?? this.social.clock(), Number.MAX_SAFE_INTEGER, true);
    if (!Number.isSafeInteger(sourceRevision)) fail('invalid-argument', 'Invalid goal revision.');
    if (input.goals != null) await this.social.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const connection = await this.authorized(uid, input.connectionId, tx);
      const settings = connection.settings[uid];
      if (settings.revision !== input.consentRevision || (input.goals != null && (!settings.goals || settings.paused))) {
        fail('permission-denied', 'Goal sharing consent changed.');
      }
      if ((settings.goalSourceRevision ?? 0) >= sourceRevision) return {};
      const next = { ...settings, goalSourceRevision: sourceRevision, goalsSnapshot: input.goals == null ? null : { ...goals, ...date, sourceRevision, updatedAt: this.social.clock() } };
      tx.update(this.ref(input.connectionId), { settings: { ...connection.settings, [uid]: next } });
      return {};
    });
  }
  async goals(uid, input) {
    await this.social.consume(uid);
    const connection = await this.authorized(uid, input.connectionId);
    return { goals: connection.participants.flatMap((authorId) => {
      const settings = connection.settings[authorId];
      return settings.goals && settings.goalsSnapshot
        ? [{ authorId, ...settings.goalsSnapshot, paused: settings.paused }] : [];
    }) };
  }
  async disconnect(uid, connectionId) {
    // Revocation has no ordinary-work quota gate and does not require the other
    // account to remain active (including blocked/deleting counterparts).
    await this.db.runTransaction(async (tx) => {
      const ref = this.ref(connectionId), connection = (await tx.get(ref)).data();
      if (!connection || !connection.participants.includes(uid)) fail('permission-denied', 'Partner connection is unavailable.');
      if (connection.revokedAt == null) {
        tx.update(ref, { revokedAt: this.social.clock(), status: 'revoked', cleanupAfter: 0 });
        tx.set(this.social.ref('socialPartnerCleanupJobs', pairId(connectionId, 'disconnect')), { connectionId });
      }
    });
    return {};
  }
  async syncMeal(uid, input) {
    const source = sourceFields(input, this.social.clock());
    const date = dateFields(input);
    const snapshot = validateSnapshot(input.snapshot, true);
    const mealCategory = input.mealCategory ?? null;
    if (mealCategory != null && (typeof mealCategory !== 'string' || !mealCategory.trim() || mealCategory.length > 128)) {
      fail('invalid-argument', 'Invalid meal category.');
    }
    const photoBlobId = input.photoBlobId == null ? null : id(input.photoBlobId);
    await this.social.requireActive(uid);
    await this.social.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const connection = await this.authorized(uid, input.connectionId, tx);
      const settings = connection.settings[uid];
      if (input.consentRevision != null && settings.revision !== input.consentRevision) fail('permission-denied', 'Sharing consent changed.');
      const ref = this.mealRef(input.connectionId, uid, source.sourceMealId);
      const old = (await tx.get(ref)).data();
      if (old?.deletedAt != null) return { id: ref.id, deleted: true, revision: old.sourceRevision };
      const existing = old?.mealGeneration === settings.mealGeneration ? old : null;
      eligibility(settings, 'meals', source, existing);
      if (existing && source.sourceRevision <= existing.sourceRevision) {
        // Upgrade old snapshots without replacing newer food content.
        if (source.sourceRevision === existing.sourceRevision && existing.mealCategory == null && mealCategory != null) {
          tx.update(ref, { mealCategory });
        }
        return { id: ref.id, revision: existing.sourceRevision };
      }
      const oldPhotoRef = old?.photoBlobId ? this.social.ref('socialBlobs', old.photoBlobId) : null;
      const newPhotoRef = photoBlobId ? this.social.ref('socialBlobs', photoBlobId) : null;
      const photoRefs = [...new Map([oldPhotoRef, newPhotoRef].filter(Boolean).map((ref) => [ref.path, ref])).values()];
      const blobs = photoRefs.length ? await tx.getAll(...photoRefs) : [];
      if (newPhotoRef) {
        const blob = blobs.find((record) => record.ref.path === newPhotoRef.path)?.data();
        if (!settings.photos || !isWithin(settings.photoPeriods, source.originallyLoggedAt) ||
            !blob || blob.ownerId !== uid || blob.state !== 'ready' || blob.postId != null ||
            (blob.partnerMealId != null && (blob.partnerMealId !== ref.id || blob.partnerMealGeneration !== settings.mealGeneration || blob.partnerPhotoGeneration !== settings.photoGeneration))) {
          fail('permission-denied', 'Photo is outside consent or unavailable.');
        }
      }
      if (oldPhotoRef && old.photoBlobId !== photoBlobId && blobs.find((record) => record.ref.path === oldPhotoRef.path)?.exists) {
        tx.update(oldPhotoRef, { state: 'deleting', partnerMealId: null, cleanupAfter: 0 });
      }
      if (newPhotoRef) tx.update(newPhotoRef, { partnerMealId: ref.id, partnerMealGeneration: settings.mealGeneration, partnerPhotoGeneration: settings.photoGeneration, connectionId: input.connectionId, cleanupAfter: null });
      tx.set(ref, { connectionId: input.connectionId, authorId: uid, ...source, ...date, snapshot, mealCategory,
        photoBlobId, photoGeneration: settings.photoGeneration, mealGeneration: settings.mealGeneration,
        publishedAt: existing?.publishedAt ?? this.social.clock(), updatedAt: this.social.clock(), deletedAt: null });
      tx.update(this.ref(input.connectionId), { settings: { ...connection.settings, [uid]: { ...settings, mealTimeZone: date.timeZone } } });
      return { id: ref.id, revision: source.sourceRevision };
    });
  }
  async readMeal(uid, mealId) {
    const record = await this.social.ref('socialPartnerMeals', id(mealId)).get();
    const meal = record.data();
    if (!meal || meal.deletedAt != null) fail('permission-denied', 'Shared meal is unavailable.');
    const connection = await this.authorized(uid, meal.connectionId);
    const settings = connection.settings[meal.authorId];
    if (!settings.meals || meal.mealGeneration !== settings.mealGeneration) fail('permission-denied', 'Meal sharing was revoked.');
    return { id: record.id, ...meal, photoBlobId: settings.photos && meal.photoGeneration === settings.photoGeneration ? meal.photoBlobId : null };
  }
  async meals(uid, input) {
    await this.social.requireActive(uid);
    await this.social.consume(uid);
    const connection = await this.authorized(uid, input.connectionId);
    let query = this.db.collection('socialPartnerMeals').where('connectionId', '==', id(input.connectionId));
    if (input.localDate != null || input.timeZone != null) {
      const date = dateFields(input);
      query = query.where('authorId', '==', connection.participants.find((participant) => participant !== uid))
        .where('localDate', '==', date.localDate).where('timeZone', '==', date.timeZone);
    }
    query = query.orderBy('publishedAt', 'desc').orderBy(FieldPath.documentId(), 'desc');
    if (input.cursor != null) {
      number(input.cursor.publishedAt, Number.MAX_SAFE_INTEGER);
      query = query.startAfter(input.cursor.publishedAt, id(input.cursor.id));
    }
    const records = await query.limit(PARTNER_LIMITS.pageSize).get();
    const meals = [];
    for (const record of records.docs) {
      try { meals.push(await this.readMeal(uid, record.id)); }
      catch (error) { if (!(error instanceof SocialError) || error.code !== 'permission-denied') throw error; }
    }
    const last = records.docs.at(-1);
    return { meals, cursor: records.size === PARTNER_LIMITS.pageSize ? { id: last.id, publishedAt: last.data().publishedAt } : null };
  }
  contributionQuery(connectionId, authorId, generation, localDate, timeZone) {
    return this.db.collection('socialPartnerContributions').where('connectionId', '==', connectionId)
      .where('authorId', '==', authorId).where('summaryGeneration', '==', generation)
      .where('localDate', '==', localDate).where('timeZone', '==', timeZone).limit(PARTNER_LIMITS.contributionsPerDate + 1);
  }
  // Only these numeric contributions are uploaded if summary sharing alone is
  // enabled. A client-computed whole-diary aggregate is never accepted.
  async syncContribution(uid, input) {
    if (input.snapshot != null || input.items != null) fail('invalid-argument', 'Summary updates must contain only nutrients.');
    const source = sourceFields(input, this.social.clock());
    const date = dateFields(input);
    const nutrients = {};
    for (const key of ['calories', 'protein', 'carbs', 'fat']) nutrients[key] = number(input[key], key === 'calories' ? 100000 : 10000);
    await this.social.requireActive(uid);
    await this.social.consume(uid);
    return this.db.runTransaction(async (tx) => {
      const connection = await this.authorized(uid, input.connectionId, tx);
      const settings = connection.settings[uid];
      if (input.consentRevision != null && settings.revision !== input.consentRevision) fail('permission-denied', 'Sharing consent changed.');
      const ref = this.contributionRef(input.connectionId, uid, source.sourceMealId);
      const old = (await tx.get(ref)).data();
      if (old?.deletedAt != null) return { id: ref.id, deleted: true, revision: old.sourceRevision };
      const existing = old?.summaryGeneration === settings.summaryGeneration ? old : null;
      eligibility(settings, 'summaries', source, existing);
      if (existing && source.sourceRevision <= existing.sourceRevision) return { id: ref.id, revision: existing.sourceRevision };
      const next = { connectionId: input.connectionId, authorId: uid, ...source, ...date, ...nutrients,
        summaryGeneration: settings.summaryGeneration, deletedAt: null };
      const groups = [next];
      if (existing && (existing.localDate !== next.localDate || existing.timeZone !== next.timeZone)) groups.push(existing);
      const updates = [];
      for (const group of groups) {
        const records = await tx.get(this.contributionQuery(input.connectionId, uid, settings.summaryGeneration, group.localDate, group.timeZone));
        const contributions = records.docs.filter((record) => record.id !== ref.id && record.data().deletedAt == null).map((record) => record.data());
        if (group === next) contributions.push(next);
        if (contributions.length > PARTNER_LIMITS.contributionsPerDate) fail('resource-exhausted', 'Daily contribution limit reached.');
        const summaryRef = this.summaryRef(input.connectionId, uid, settings.summaryGeneration, group.localDate, group.timeZone);
        const oldSummary = (await tx.get(summaryRef)).data();
        const totals = Object.fromEntries(['calories', 'protein', 'carbs', 'fat'].map((key) => [key, contributions.reduce((sum, entry) => sum + entry[key], 0)]));
        updates.push({ ref: summaryRef, data: { connectionId: input.connectionId, authorId: uid, summaryGeneration: settings.summaryGeneration,
          localDate: group.localDate, timeZone: group.timeZone, ...totals, revision: (oldSummary?.revision ?? 0) + 1, updatedAt: this.social.clock() } });
      }
      tx.set(ref, next);
      tx.update(this.ref(input.connectionId), { settings: { ...connection.settings, [uid]: { ...settings, summaryTimeZone: date.timeZone } } });
      for (const update of updates) tx.set(update.ref, update.data);
      return { id: ref.id, revision: source.sourceRevision };
    });
  }
  async summaries(uid, input) {
    const date = dateFields(input);
    await this.social.consume(uid);
    const connection = await this.authorized(uid, input.connectionId);
    const summaries = [];
    for (const authorId of connection.participants) {
      const settings = connection.settings[authorId];
      if (!settings.summaries) continue;
      const record = await this.summaryRef(input.connectionId, authorId, settings.summaryGeneration, date.localDate, date.timeZone).get();
      if (record.exists) summaries.push({ id: record.id, ...record.data() });
    }
    // A revocation during the reads must not leak the obsolete generation.
    const current = await this.authorized(uid, input.connectionId);
    return { summaries: summaries.filter((summary) => current.settings[summary.authorId].summaries &&
      summary.summaryGeneration === current.settings[summary.authorId].summaryGeneration) };
  }
  async deleteSource(uid, input) {
    id(input.sourceMealId);
    number(input.sourceRevision, Number.MAX_SAFE_INTEGER, true);
    if (!Number.isSafeInteger(input.sourceRevision)) fail('invalid-argument', 'Invalid source revision.');
    return this.db.runTransaction(async (tx) => {
      // Source deletion remains valid while paused, disabled, blocked or
      // disconnected. Membership and authorship still come from server state.
      const connection = (await tx.get(this.ref(input.connectionId))).data();
      if (!connection || !connection.participants.includes(uid)) fail('permission-denied', 'Partner connection is unavailable.');
      const mealRef = this.mealRef(input.connectionId, uid, input.sourceMealId);
      const nutritionRef = this.contributionRef(input.connectionId, uid, input.sourceMealId);
      const [mealRecord, nutritionRecord] = await tx.getAll(mealRef, nutritionRef);
      const meal = mealRecord.data(), contribution = nutritionRecord.data();
      const photoRef = meal?.photoBlobId ? this.social.ref('socialBlobs', meal.photoBlobId) : null;
      const photo = photoRef ? await tx.get(photoRef) : null;
      let summary = null;
      if (contribution && contribution.deletedAt == null) {
        const ref = this.summaryRef(input.connectionId, uid, contribution.summaryGeneration, contribution.localDate, contribution.timeZone);
        const prior = (await tx.get(ref)).data();
        if (prior) summary = { ref, data: { ...prior,
          ...Object.fromEntries(['calories', 'protein', 'carbs', 'fat'].map((key) => [key, Math.max(0, prior[key] - contribution[key])])),
          revision: prior.revision + 1, updatedAt: this.social.clock() } };
      }
      const tombstone = { connectionId: input.connectionId, authorId: uid, sourceMealId: input.sourceMealId,
        sourceRevision: Math.max(input.sourceRevision, meal?.sourceRevision ?? 0, contribution?.sourceRevision ?? 0), deletedAt: this.social.clock() };
      tx.set(mealRef, { ...tombstone, publishedAt: meal?.publishedAt ?? this.social.clock(), photoBlobId: null });
      tx.set(nutritionRef, tombstone);
      if (photo?.exists) tx.update(photoRef, { state: 'deleting', partnerMealId: null, cleanupAfter: 0 });
      if (summary) tx.set(summary.ref, summary.data);
      return { id: mealRef.id, deleted: true };
    });
  }
}
