import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp,
  setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

let env;
const code = 'ABCD2345';
const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const profile = (uid, owner = uid) => doc(db(uid), 'partnerProfiles', owner);
const invite = (uid, c = code) => doc(db(uid), 'partnerInvites', c);
const day = (uid, cid, owner = uid, date = '2026-10-25') => doc(db(uid), `partnerConnections/${cid}/days/${owner}_${date}`);
const dayData = (patch = {}) => ({
  date: '2026-10-25', goals: { calories: 2000 }, burned: 0,
  entries: [{ id: '1', name: 'Rice', meal: 'lunch', calories: 200 }], updatedAt: serverTimestamp(), ...patch,
});

async function createInvite(uid = 'alice', patch = {}) {
  await setDoc(invite(uid), {
    inviterId: uid, displayName: 'Alice', expiresAt: Timestamp.fromMillis(Date.now() + 3600e3), ...patch,
  });
}

async function accept(uid = 'bob', patch = {}, inviter = 'alice', name = 'Bob') {
  const store = db(uid);
  const connection = doc(collection(store, 'partnerConnections'));
  const batch = writeBatch(store);
  batch.set(connection, {
    participants: [inviter, uid], names: { [inviter]: 'Alice', [uid]: name }, invite: code,
    createdAt: serverTimestamp(), ...patch,
  });
  batch.update(doc(store, 'partnerProfiles', inviter), { connectionId: connection.id });
  batch.update(doc(store, 'partnerProfiles', uid), { connectionId: connection.id });
  batch.delete(doc(store, 'partnerInvites', code));
  await batch.commit();
  return connection.id;
}

async function disconnect(uid, cid, other) {
  const store = db(uid);
  const batch = writeBatch(store);
  batch.delete(doc(store, 'partnerConnections', cid));
  batch.update(doc(store, 'partnerProfiles', uid), { connectionId: null });
  batch.update(doc(store, 'partnerProfiles', other), { connectionId: null });
  await batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sophis',
    firestore: { rules: await readFile('../firestore.rules', 'utf8') },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  for (const [uid, name] of [['alice', 'Alice'], ['bob', 'Bob'], ['eve', 'Eve']]) {
    await setDoc(profile(uid), { displayName: name, connectionId: null });
  }
});
after(async () => { await env?.cleanup(); });

test('kept profiles private and validated', async () => {
  await assertFails(getDoc(profile('bob', 'alice')));
  await assertFails(getDoc(profile(null, 'alice')));
  await assertFails(setDoc(profile('eve'), { displayName: 'Eve', connectionId: null, weight: 50 }));
  await assertFails(updateDoc(profile('eve'), { connectionId: 'forged' }));
  await assertFails(updateDoc(profile('eve', 'alice'), { displayName: 'Hacked' }));
  await assertSucceeds(updateDoc(profile('alice'), { displayName: 'Ali' }));
});

test('paired two people through an invite code', async () => {
  await createInvite();
  await assertSucceeds(getDoc(invite('bob')));
  const cid = await accept();
  await assertSucceeds(getDoc(doc(db('alice'), 'partnerConnections', cid)));
  await assertSucceeds(getDoc(doc(db('bob'), 'partnerConnections', cid)));
  await assertFails(getDoc(doc(db('eve'), 'partnerConnections', cid)));
  assert.equal((await getDoc(invite('bob'))).exists(), false);
  await assertFails(accept('eve', {}, 'alice', 'Eve'));
});

test('rejected forged, expired and self pairings', async () => {
  await assertFails(createInvite('alice', { displayName: 'Forged' }));
  await assertFails(createInvite('alice', { expiresAt: Timestamp.fromMillis(Date.now() + 5 * 86400e3) }));
  await assertFails(setDoc(invite('alice', 'short'), { inviterId: 'alice', displayName: 'Alice', expiresAt: Timestamp.fromMillis(Date.now() + 3600e3) }));
  await createInvite();
  await assertFails(accept('alice', {}, 'alice', 'Alice'));
  await assertFails(accept('bob', { participants: ['alice', 'eve'] }));
  await assertFails(accept('bob', { names: { alice: 'Alice', bob: 'Robert' } }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'partnerInvites', code), { expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
  });
  await assertFails(accept());
});

test('allowed only one partner per person', async () => {
  await createInvite();
  await accept();
  await assertFails(createInvite());
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'partnerInvites', code), {
      inviterId: 'eve', displayName: 'Eve', expiresAt: Timestamp.fromMillis(Date.now() + 3600e3),
    });
  });
  await assertFails(accept('bob', { names: { eve: 'Eve', bob: 'Bob' } }, 'eve'));
});

test('let partners read and only authors write their days', async () => {
  await createInvite();
  const cid = await accept();
  await assertSucceeds(setDoc(day('alice', cid), dayData()));
  await assertSucceeds(getDoc(day('bob', cid, 'alice')));
  await assertFails(getDoc(day('eve', cid, 'alice')));
  await assertFails(setDoc(day('bob', cid, 'alice'), dayData()));
  await assertFails(setDoc(day('eve', cid), dayData()));
  await assertFails(setDoc(day('alice', cid, 'alice', '2026-10-24'), dayData()));
  await assertFails(setDoc(day('alice', cid), dayData({ secret: true })));
});

test('ended all access on disconnect', async () => {
  await createInvite();
  const cid = await accept();
  await setDoc(day('alice', cid), dayData());
  await assertSucceeds(getDocs(query(collection(db('bob'), `partnerConnections/${cid}/days`))));
  await assertSucceeds(deleteDoc(day('bob', cid, 'alice')));
  await assertFails(disconnect('eve', cid, 'alice'));
  await assertSucceeds(disconnect('bob', cid, 'alice'));
  await assertFails(getDoc(day('alice', cid)));
  await assertFails(setDoc(day('alice', cid), dayData()));
  await assertSucceeds(createInvite());
});

test('let inviters list and withdraw their own invites', async () => {
  await createInvite();
  await assertSucceeds(getDocs(query(collection(db('alice'), 'partnerInvites'), where('inviterId', '==', 'alice'))));
  await assertFails(getDocs(query(collection(db('eve'), 'partnerInvites'), where('inviterId', '==', 'alice'))));
  await assertFails(deleteDoc(invite('eve')));
  await assertSucceeds(deleteDoc(invite('alice')));
});

test('allowed profile deletion only without a partner', async () => {
  await createInvite();
  const cid = await accept();
  await assertFails(deleteDoc(profile('alice')));
  await disconnect('alice', cid, 'bob');
  await assertSucceeds(deleteDoc(profile('alice')));
});
