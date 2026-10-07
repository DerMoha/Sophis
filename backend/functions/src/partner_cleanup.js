import { FieldPath } from 'firebase-admin/firestore';
import { id, SocialError } from './social_service.js';

async function removeBlob(service, blobId) {
  const ref = service.ref('socialBlobs', blobId);
  const initial = (await ref.get()).data();
  if (!initial || initial.state === 'deleted') return;
  // The consent/connection has already been revoked; block any racing upload
  // before removing the object. Keep its path until object deletion succeeds.
  await ref.update({ state: 'deleting', cleanupAfter: 0 });
  if (initial.path) await service.bucket.file(initial.path).delete({ ignoreNotFound: true });
  await service.db.runTransaction(async (tx) => {
    const storageRef = service.ref('socialUsage', 'storage');
    const [blob, storage] = await tx.getAll(ref, storageRef);
    if (!blob.exists) return;
    tx.set(ref, { ownerId: initial.ownerId, state: 'deleted', bytes: 0,
      postId: null, partnerMealId: null, cleanupAfter: null, createdAt: initial.createdAt });
    tx.set(storageRef, { bytes: Math.max(0, (storage.data()?.bytes ?? 0) - (blob.data().bytes ?? 0)) });
  });
}

// A job may be retried after new sharing settings have been enabled. Its captured
// generations only revoke older payloads; it cannot delete newly shared meals.
export async function cleanupPartnerContent(service, job) {
  const connectionId = id(job.connectionId);
  const connection = (await service.ref('socialPartners', connectionId).get()).data();
  if (!connection) return;
  const profiles = await service.db.getAll(...connection.participants.map((uid) => service.profile(uid)));
  const disconnected = connection.revokedAt != null ||
    profiles.some((record) => !record.exists || record.data().deletingAt != null) ||
    await service.blocked(...connection.participants);
  if (!disconnected && (!connection.participants.includes(job.authorId) ||
      !job.generations || Object.entries(job.generations).some(([key, value]) =>
        !['mealGeneration', 'summaryGeneration', 'photoGeneration'].includes(key) ||
        !Number.isSafeInteger(value) || value > connection.settings[job.authorId][key]))) {
    throw new SocialError('failed-precondition', 'Cleanup job is not authorized by current consent.');
  }
  for (const collection of ['socialPartnerMeals', 'socialPartnerContributions', 'socialPartnerSummaries']) {
    let query = service.db.collection(collection).where('connectionId', '==', connectionId);
    if (!disconnected) query = query.where('authorId', '==', job.authorId);
    let cursor = null;
    for (;;) {
      let page = query.orderBy(FieldPath.documentId()).limit(50);
      if (cursor) page = page.startAfter(cursor);
      const records = await page.get();
      if (records.empty) break;
      for (const record of records.docs) {
        // Read again after object deletion to avoid overwriting a newer generation
        // published while the cleanup worker was awaiting storage.
        const initial = record.data();
        const oldMeal = collection === 'socialPartnerMeals' &&
          initial.mealGeneration < (job.generations?.mealGeneration ?? -1);
        const oldPhoto = collection === 'socialPartnerMeals' &&
          initial.photoGeneration < (job.generations?.photoGeneration ?? -1);
        const oldSummary = collection !== 'socialPartnerMeals' &&
          initial.summaryGeneration < (job.generations?.summaryGeneration ?? -1);
        if (!(disconnected || oldMeal || oldPhoto || oldSummary)) continue;
        if (initial.photoBlobId) await removeBlob(service, initial.photoBlobId);
        await service.db.runTransaction(async (tx) => {
          const current = (await tx.get(record.ref)).data();
          if (!current) return;
          if (disconnected) tx.delete(record.ref);
          else if (collection === 'socialPartnerMeals' && current.mealGeneration < (job.generations.mealGeneration ?? -1)) {
            tx.set(record.ref, { connectionId, authorId: current.authorId, sourceMealId: current.sourceMealId,
              sourceRevision: current.sourceRevision, mealGeneration: current.mealGeneration,
              originallyLoggedAt: current.originallyLoggedAt, publishedAt: current.publishedAt,
              revokedAt: service.clock(), photoBlobId: null });
          } else if (collection === 'socialPartnerMeals' && current.photoGeneration < (job.generations.photoGeneration ?? -1)) {
            tx.update(record.ref, { photoBlobId: null });
          } else if (collection !== 'socialPartnerMeals' && current.summaryGeneration < (job.generations.summaryGeneration ?? -1)) {
            tx.delete(record.ref);
          }
        });
      }
      cursor = records.docs.at(-1).id;
      if (records.size < 50) break;
    }
  }
  if (disconnected) await service.ref('socialPartners', connectionId).delete();
}
