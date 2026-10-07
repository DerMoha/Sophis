import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { SocialService, pairId } from '../src/social_service.js';
import { PartnerService } from '../src/partner_service.js';
import { uploadPhoto, cleanAbandonedPhotos } from '../src/photo_service.js';
import sharp from 'sharp';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) throw new Error('Emulator-only tests.');
let environment, admin, db, social, partners, now;
const day = '2026-10-07';
const objects = new Map();
const bucket = { file: (path) => ({ save: async (bytes) => objects.set(path, bytes),
  download: async () => [objects.get(path)], delete: async () => objects.delete(path) }) };
const snapshot = { schemaVersion: 1, title: 'Dinner', servings: 1, items: [
  { name: 'Rice', calories: 100, protein: 2, carbs: 20, fat: 1, fiber: 0, portionAmount: 100, portionUnit: 'g' },
] };
function meal(connectionId, sourceMealId = 'meal1', overrides = {}) {
  return { connectionId, sourceMealId, sourceRevision: 1, originallyLoggedAt: now,
    changedAt: now, localDate: day, timeZone: 'Europe/Berlin', snapshot, ...overrides };
}
function contribution(connectionId, sourceMealId = 'meal1', overrides = {}) {
  const { snapshot: ignored, ...data } = meal(connectionId, sourceMealId);
  return { ...data, calories: 100, protein: 2, carbs: 20, fat: 1, ...overrides };
}
const denied = (promise) => assert.rejects(promise, { code: 'permission-denied' });
async function connect(first = 'alice', second = 'bob') {
  const invite = await social.createInvitation(first, 'partner');
  const request = await partners.request(second, { token: invite.token });
  await partners.accept(first, request.id);
  return request.id;
}
async function settings(uid, connectionId, overrides = {}) {
  const connection = (await partners.ref(connectionId).get()).data();
  const old = connection.settings[uid];
  return (await partners.updateSettings(uid, { connectionId, meals: old.meals,
    summaries: old.summaries, photos: old.photos, paused: old.paused,
    baseRevision: old.revision, ...overrides })).settings;
}
before(async () => {
  environment = await initializeTestEnvironment({ projectId: 'demo-sophis' });
  admin = initializeApp({ projectId: 'demo-sophis' }, 'partner-tests');
  db = getFirestore(admin);
  social = new SocialService(db, bucket, { clock: () => now });
  partners = new PartnerService(social);
});
beforeEach(async () => {
  await environment.clearFirestore(); objects.clear();
  now = Date.UTC(2026, 9, 7, 10);
  for (const uid of ['alice', 'bob', 'eve']) await social.setProfile(uid, { displayName: uid });
});
after(async () => { await environment?.cleanup(); if (admin) await deleteApp(admin); });

test('required mutual approval and separate outgoing consent without granting follow access', async () => {
  const invite = await social.createInvitation('alice', 'partner');
  const { id } = await partners.request('bob', { token: invite.token });
  await denied(partners.accept('bob', id));
  await denied(partners.accept('eve', id));
  await denied(partners.syncMeal('alice', meal(id)));
  await partners.accept('alice', id);
  await denied(partners.syncMeal('alice', meal(id)));
  await settings('alice', id, { meals: true });
  const shared = await partners.syncMeal('alice', meal(id));
  assert.equal((await partners.readMeal('bob', shared.id)).authorId, 'alice');
  await denied(partners.readMeal('eve', shared.id));
  await denied(partners.syncMeal('bob', meal(id)));
  const post = await social.publish('alice', { operationId: 'post1', kind: 'meal', nutritionVisible: true, snapshot });
  await denied(social.readPost('bob', post.id));
  assert.equal((await social.feed('bob')).posts.length, 0);
});
test('kept ordinary follower access separate from partner access', async () => {
  const invite = await social.createInvitation('alice');
  await assert.rejects(partners.request('bob', { token: invite.token }), { code: 'not-found' });
  await social.requestFollow('bob', invite.token); await social.approveFollow('alice', 'bob');
  const id = await connect('alice', 'eve');
  await settings('alice', id, { meals: true });
  const shared = await partners.syncMeal('alice', meal(id));
  await denied(partners.readMeal('bob', shared.id));
});
test('retried a partner request without another connection and rejected another invite recipient', async () => {
  const invite = await social.createInvitation('alice', 'partner');
  const first = await partners.request('bob', { token: invite.token });
  const retried = await partners.request('bob', { token: invite.token });
  assert.equal(first.id, retried.id);
  assert.equal((await db.collection('socialPartners').get()).size, 1);
  await assert.rejects(partners.request('eve', { token: invite.token }), { code: 'not-found' });
  await assert.rejects(social.requestFollow('eve', invite.token), { code: 'not-found' });
});
test('excluded earlier meals and summary contributions on activation day', async () => {
  const id = await connect();
  const oldTime = now - 1000;
  await settings('alice', id, { meals: true, summaries: true });
  await denied(partners.syncMeal('alice', meal(id, 'historic', { originallyLoggedAt: oldTime })));
  await denied(partners.syncContribution('alice', contribution(id, 'historic', { originallyLoggedAt: oldTime })));
  await partners.syncMeal('alice', meal(id));
  await partners.syncContribution('alice', contribution(id));
  const summaries = await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' });
  assert.equal(summaries.summaries[0].calories, 100);
});
test('froze paused meals and totals, resumed without backfilling paused sources or mutations', async () => {
  const id = await connect(); await settings('alice', id, { meals: true, summaries: true });
  const initial = now;
  const shared = await partners.syncMeal('alice', meal(id));
  await partners.syncContribution('alice', contribution(id));
  now += 1000; await settings('alice', id, { paused: true });
  const pauseTime = now;
  await denied(partners.syncMeal('alice', meal(id, 'paused')));
  assert.equal((await partners.readMeal('bob', shared.id)).snapshot.items[0].calories, 100);
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 100);
  now += 1000; await settings('alice', id, { paused: false });
  await denied(partners.syncMeal('alice', meal(id, 'paused', { originallyLoggedAt: pauseTime })));
  await denied(partners.syncContribution('alice', contribution(id, 'paused', { originallyLoggedAt: pauseTime })));
  await denied(partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, changedAt: pauseTime, sourceRevision: 2 })));
  await partners.syncContribution('alice', contribution(id, 'meal2'));
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 200);
  await partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 2, snapshot: { ...snapshot, title: 'Edited dinner' } }));
  assert.equal((await partners.readMeal('bob', shared.id)).snapshot.title, 'Edited dinner');
});
test('computed summary-only totals without accepting meal details or client whole-diary totals', async () => {
  const id = await connect(); await settings('alice', id, { summaries: true });
  await denied(partners.syncMeal('alice', meal(id)));
  await assert.rejects(partners.syncContribution('alice', { ...contribution(id), snapshot }), { code: 'invalid-argument' });
  await partners.syncContribution('alice', contribution(id, 'one', { totalCalories: 9999 }));
  await partners.syncContribution('alice', contribution(id, 'two', { calories: 50 }));
  const result = await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' });
  assert.equal(result.summaries[0].calories, 150);
  const data = (await partners.contributionRef(id, 'alice', 'one').get()).data();
  assert.equal(data.snapshot, undefined); assert.equal(data.totalCalories, undefined);
});
test('retried sources once and preserved immutable logging time and revision ordering', async () => {
  const id = await connect(); await settings('alice', id, { meals: true, summaries: true });
  const initial = now;
  const shared = await partners.syncMeal('alice', meal(id));
  await partners.syncMeal('alice', meal(id));
  await partners.syncContribution('alice', contribution(id));
  await partners.syncContribution('alice', contribution(id));
  assert.equal((await db.collection('socialPartnerMeals').get()).size, 1);
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 100);
  now += 1000;
  await assert.rejects(partners.syncMeal('alice', meal(id, 'meal1', { sourceRevision: 2 })), { code: 'failed-precondition' });
  await partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 3, snapshot: { ...snapshot, title: 'New title' } }));
  await partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 2 }));
  assert.equal((await partners.readMeal('bob', shared.id)).snapshot.title, 'New title');
});
test('processed source deletion while paused and disabled and prevented stale resurrection', async () => {
  const id = await connect(); await settings('alice', id, { meals: true, summaries: true });
  const initial = now;
  const shared = await partners.syncMeal('alice', meal(id));
  await partners.syncContribution('alice', contribution(id));
  now += 1000; await settings('alice', id, { paused: true });
  await social.ref('socialConfig', 'operating').set({ disabled: true });
  await denied(partners.deleteSource('eve', { connectionId: id, sourceMealId: 'meal1', sourceRevision: 2 }));
  await partners.deleteSource('alice', { connectionId: id, sourceMealId: 'meal1', sourceRevision: 2 });
  await partners.deleteSource('alice', { connectionId: id, sourceMealId: 'meal1', sourceRevision: 2 });
  await denied(partners.readMeal('bob', shared.id));
  await social.ref('socialConfig', 'operating').delete();
  await settings('alice', id, { paused: false });
  assert.equal((await partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 9 }))).deleted, true);
  assert.equal((await partners.syncContribution('alice', contribution(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 9 }))).deleted, true);
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 0);
});
test('revoked disabled categories even during pause and did not re-expose old data on re-enable', async () => {
  const id = await connect(); await settings('alice', id, { meals: true, summaries: true });
  const initial = now;
  const shared = await partners.syncMeal('alice', meal(id));
  await partners.syncContribution('alice', contribution(id));
  now += 1000; await settings('alice', id, { paused: true, meals: false, summaries: false });
  await denied(partners.readMeal('bob', shared.id));
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries.length, 0);
  now += 1000; await settings('alice', id, { paused: false, meals: true, summaries: true });
  await denied(partners.readMeal('bob', shared.id));
  await denied(partners.syncMeal('alice', meal(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 2 })));
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries.length, 0);
});
test('kept multiple connections and each person settings independent', async () => {
  const bob = await connect('alice', 'bob'); const eve = await connect('alice', 'eve');
  await settings('alice', bob, { meals: true });
  now += 1000; const bobMeal = await partners.syncMeal('alice', meal(bob));
  await denied(partners.syncMeal('alice', meal(eve)));
  await settings('eve', eve, { meals: true });
  const eveMeal = await partners.syncMeal('eve', meal(eve));
  await denied(partners.readMeal('bob', eveMeal.id));
  await denied(partners.readMeal('eve', bobMeal.id));
  assert.equal((await partners.list('alice')).connections.length, 2);
});
test('disconnected immediately, denied blocked/deleting accounts and used a fresh reconnect ID', async () => {
  const id = await connect(); await settings('alice', id, { meals: true });
  const shared = await partners.syncMeal('alice', meal(id));
  await partners.disconnect('bob', id);
  await denied(partners.readMeal('bob', shared.id));
  const fresh = await connect(); assert.notEqual(fresh, id);
  await settings('alice', fresh, { meals: true });
  const second = await partners.syncMeal('alice', meal(fresh));
  await social.blockAccount('bob', 'alice');
  await denied(partners.readMeal('alice', second.id));
  await denied(partners.readMeal('bob', second.id));
  await social.beginDeletion('bob');
  await denied(partners.meals('alice', { connectionId: fresh }));
  await partners.disconnect('alice', fresh);
});
test('protected partner photo reads independently and revoked photos without revoking meals', async () => {
  const id = await connect(); await settings('alice', id, { meals: true, photos: true });
  const bytes = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#ffffff' } }).jpeg().toBuffer();
  const { blobId } = await uploadPhoto(social, 'alice', { operationId: 'partnerPhoto', base64: bytes.toString('base64') });
  const shared = await partners.syncMeal('alice', meal(id, 'meal1', { photoBlobId: blobId }));
  assert.equal((await social.readPhoto('bob', blobId)).mediaType, 'image/jpeg');
  await denied(social.readPhoto('eve', blobId));
  await settings('alice', id, { paused: true });
  assert.equal((await social.readPhoto('bob', blobId)).mediaType, 'image/jpeg');
  await settings('alice', id, { photos: false });
  await denied(social.readPhoto('bob', blobId));
  assert.equal((await partners.readMeal('bob', shared.id)).photoBlobId, null);
  await partners.deleteSource('alice', { connectionId: id, sourceMealId: 'meal1', sourceRevision: 2 });
  assert.equal(await cleanAbandonedPhotos(social), 1);
  assert.equal(objects.size, 0);
});
test('updated both daily summaries when an eligible entry moved dates', async () => {
  const id = await connect(); await settings('alice', id, { summaries: true });
  const initial = now; await partners.syncContribution('alice', contribution(id));
  now += 1000;
  await partners.syncContribution('alice', contribution(id, 'meal1', { originallyLoggedAt: initial, sourceRevision: 2, localDate: '2026-10-08', calories: 150 }));
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 0);
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: '2026-10-08', timeZone: 'Europe/Berlin' })).summaries[0].calories, 150);
});
test('rejected invalid times, revisions, dates and time zones before writing', async () => {
  const id = await connect(); await settings('alice', id, { summaries: true });
  for (const fields of [{ changedAt: now + 1 }, { sourceRevision: 1.5 }, { localDate: '2026-02-31' }, { timeZone: 'invalid' }]) {
    await assert.rejects(partners.syncContribution('alice', contribution(id, 'meal1', fields)), { code: 'invalid-argument' });
  }
  assert.equal((await db.collection('socialPartnerContributions').get()).size, 0);
});

test('cleaned disconnected partner payloads and blobs retryably', async () => {
  const { cleanupPartnerContent } = await import('../src/partner_cleanup.js');
  const id = await connect(); await settings('alice', id, { meals: true, photos: true, summaries: true });
  const bytes = await sharp({ create: { width: 10, height: 10, channels: 3, background: '#ffffff' } }).jpeg().toBuffer();
  const { blobId } = await uploadPhoto(social, 'alice', { operationId: 'disconnectedPhoto', base64: bytes.toString('base64') });
  await partners.syncMeal('alice', meal(id, 'meal1', { photoBlobId: blobId }));
  await partners.syncContribution('alice', contribution(id));
  await partners.disconnect('bob', id);
  await cleanupPartnerContent(social, { connectionId: id });
  await cleanupPartnerContent(social, { connectionId: id });
  for (const name of ['socialPartners', 'socialPartnerMeals', 'socialPartnerContributions', 'socialPartnerSummaries']) assert.equal((await db.collection(name).get()).size, 0);
  assert.equal(objects.size, 0);
});
test('purged revoked details without deleting new consent-generation data', async () => {
  const { cleanupPartnerContent } = await import('../src/partner_cleanup.js');
  const id = await connect(); await settings('alice', id, { meals: true, summaries: true });
  const shared = await partners.syncMeal('alice', meal(id, 'old')); await partners.syncContribution('alice', contribution(id, 'old'));
  now += 1000; await settings('alice', id, { meals: false, summaries: false });
  const job = (await db.collection('socialPartnerCleanupJobs').get()).docs[0].data();
  now += 1000; await settings('alice', id, { meals: true, summaries: true });
  const newer = await partners.syncMeal('alice', meal(id, 'new')); await partners.syncContribution('alice', contribution(id, 'new'));
  await cleanupPartnerContent(social, job); await cleanupPartnerContent(social, job);
  assert.equal((await social.ref('socialPartnerMeals', shared.id).get()).data().snapshot, undefined);
  assert.equal((await partners.readMeal('bob', newer.id)).snapshot.title, 'Dinner');
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries[0].calories, 100);
});
test('removed both directions of hosted partner data during account deletion', async () => {
  const { cleanupAccount } = await import('../src/cleanup_service.js');
  const id = await connect(); await settings('alice', id, { meals: true }); await settings('bob', id, { meals: true, summaries: true });
  await partners.syncMeal('alice', meal(id)); await partners.syncMeal('bob', meal(id)); await partners.syncContribution('bob', contribution(id));
  await social.beginDeletion('alice');
  await cleanupAccount(social, 'alice', { deleteUser: async () => {} });
  for (const name of ['socialPartners', 'socialPartnerMeals', 'socialPartnerContributions', 'socialPartnerSummaries']) assert.equal((await db.collection(name).get()).size, 0);
  assert.equal((await social.profile('bob').get()).exists, true);
});

test('shared whitelisted goals only under current independent partner consent', async () => {
  const id = await connect();
  const goals = { calories: 2000, protein: 120, carbs: 250, fat: 70, weight: 80 };
  await denied(partners.syncGoals('alice', { connectionId: id, consentRevision: 0, goals }));
  let consent = await settings('alice', id, { goals: true });
  await partners.syncGoals('alice', { connectionId: id, consentRevision: consent.revision, goals });
  const shared = (await partners.goals('bob', { connectionId: id })).goals[0];
  assert.equal(shared.calories, 2000); assert.equal(shared.weight, undefined);
  await denied(partners.goals('eve', { connectionId: id }));
  assert.equal((await partners.summaries('bob', { connectionId: id, localDate: day, timeZone: 'Europe/Berlin' })).summaries.length, 0);
  consent = await settings('alice', id, { goals: true, paused: true });
  await denied(partners.syncGoals('alice', { connectionId: id, consentRevision: consent.revision, goals }));
  assert.equal((await partners.goals('bob', { connectionId: id })).goals[0].paused, true);
  await settings('alice', id, { goals: false, paused: true });
  assert.equal((await partners.goals('bob', { connectionId: id })).goals.length, 0);
  assert.equal((await partners.ref(id).get()).data().settings.alice.goalsSnapshot, null);
  consent = await settings('alice', id, { goals: true, paused: false });
  await denied(partners.syncGoals('alice', { connectionId: id, consentRevision: 1, goals }));
  assert.equal((await partners.goals('bob', { connectionId: id })).goals.length, 0);
  await partners.syncGoals('alice', { connectionId: id, consentRevision: consent.revision, goals });
  await partners.disconnect('bob', id);
  await denied(partners.goals('bob', { connectionId: id }));
});
