import { SocialError } from './social_service.js';

/// Retryable cleanup: every phase can restart, and access is already revoked by
/// deletingAt before the worker runs. Imported device diary copies are untouched.
export async function cleanupAccount(service, uid, auth) {
  const profile = (await service.profile(uid).get()).data();
  if (!profile || profile.deletingAt == null) {
    // A retry after completion is safe; an arbitrary job cannot delete a profile.
    if ((await service.ref('socialDeletedAccounts', uid).get()).exists) return;
    throw new SocialError('failed-precondition', 'Account deletion was not requested.');
  }
  async function deleteMatching(collection, field, value) {
    for (;;) {
      const records = await service.db.collection(collection).where(field, '==', value).limit(100).get();
      if (records.empty) return;
      const batch = service.db.batch();
      for (const record of records.docs) batch.delete(record.ref);
      await batch.commit();
    }
  }
  for (;;) {
    const photos = await service.db.collection('socialBlobs').where('ownerId', '==', uid).limit(100).get();
    if (photos.empty) break;
    for (const photo of photos.docs) {
      const blob = photo.data();
      // Keep metadata until remote removal succeeds, so retries retain the path.
      if (blob.path) await service.bucket.file(blob.path).delete({ ignoreNotFound: true });
      await service.db.runTransaction(async (tx) => {
        const storageRef = service.ref('socialUsage', 'storage');
        const [current, storage] = await tx.getAll(photo.ref, storageRef);
        if (!current.exists) return;
        tx.delete(photo.ref);
        tx.set(storageRef, { bytes: Math.max(0, (storage.data()?.bytes ?? 0) - (current.data().bytes ?? 0)) });
      });
    }
  }
  for (;;) {
    const posts = await service.db.collection('socialPosts').where('authorId', '==', uid).limit(100).get();
    if (posts.empty) break;
    for (const post of posts.docs) {
      await deleteMatching('socialReactions', 'postId', post.id);
      await post.ref.delete();
    }
  }
  for (const [collection, field] of [
    ['socialReactions', 'actorId'], ['socialFollows', 'followerId'],
    ['socialFollows', 'followedId'], ['socialBlocks', 'blockerId'],
    ['socialBlocks', 'blockedId'], ['socialInvitations', 'inviterId'],
    ['socialDeviceTokens', 'accountId'], ['socialReports', 'reporterId'],
  ]) await deleteMatching(collection, field, uid);
  // Tombstone precedes Auth deletion: existing ID tokens may remain valid for
  // up to their expiry and must never recreate a deleted social profile.
  await service.ref('socialDeletedAccounts', uid).set({ deletedAt: service.clock() });
  try { await auth.deleteUser(uid); }
  catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
  const batch = service.db.batch();
  batch.delete(service.profile(uid));
  batch.delete(service.ref('socialDeletionJobs', uid));
  await batch.commit();
}
