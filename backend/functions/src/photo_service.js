import sharp from 'sharp';
import { createHash } from 'node:crypto';
import { LIMITS, SocialError } from './social_service.js';

export async function uploadPhoto(service, uid, input) {
  await service.requireActive(uid);
  await service.consume(uid);
  if (typeof input.base64 !== 'string' || input.base64.length > Math.ceil(LIMITS.photoBytes / 3) * 4 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(input.base64)) {
    throw new SocialError('invalid-argument', 'Photo exceeds the upload limit.');
  }
  const original = Buffer.from(input.base64, 'base64');
  let bytes;
  try {
    // Decode with a pixel limit, rotate according to EXIF, re-encode without EXIF.
    bytes = await sharp(original, { limitInputPixels: 1600 * 1600 })
      .rotate().resize(1200, 1200, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 75 }).toBuffer();
  } catch {
    throw new SocialError('invalid-argument', 'Photo could not be decoded.');
  }
  if (bytes.length > LIMITS.photoBytes) throw new SocialError('invalid-argument', 'Compress the photo before uploading.');
  const blob = await service.reservePhoto(uid, input.operationId, bytes.length, createHash('sha256').update(bytes).digest('hex'));
  if (blob.state === 'ready') return { blobId: blob.id };
  if (blob.state !== 'pending') throw new SocialError('failed-precondition', 'Upload has been removed.');
  await service.bucket.file(blob.path).save(bytes, { resumable: false,
    metadata: { contentType: 'image/jpeg', cacheControl: 'private, no-store' } });
  try {
    await service.db.runTransaction(async (tx) => {
      const ref = service.ref('socialBlobs', blob.id);
      const [current, profile] = await tx.getAll(ref, service.profile(uid));
      if (!profile.exists || profile.data().deletingAt != null) {
        throw new SocialError('permission-denied', 'Upload is no longer authorized.');
      }
      if (current.data()?.state === 'ready') return;
      if (current.data()?.state !== 'pending') {
        throw new SocialError('permission-denied', 'Upload is no longer authorized.');
      }
      tx.update(ref, { state: 'ready', readyAt: service.clock() });
    });
  } catch (error) {
    if (error instanceof SocialError) {
      await service.bucket.file(blob.path).delete({ ignoreNotFound: true });
    }
    throw error;
  }
  return { blobId: blob.id };
}

// Invoke from trusted maintenance only. Reservations remain conservative on
// failed uploads; bytes are released only after the object has been removed.
export async function cleanAbandonedPhotos(service) {
  const cutoff = service.clock() - 24 * 60 * 60 * 1000;
  const records = await service.db.collection('socialBlobs')
    .where('cleanupAfter', '<', service.clock()).orderBy('cleanupAfter').limit(500).get();
  let deleted = 0;
  for (const record of records.docs) {
    const removed = await service.db.runTransaction(async (tx) => {
      const current = (await tx.get(record.ref)).data();
      if (!current || !(current.state === 'deleting' ||
          (['pending', 'ready'].includes(current.state) && current.postId == null && current.createdAt < cutoff))) return null;
      tx.update(record.ref, { state: 'deleting' });
      return current;
    });
    if (!removed) continue;
    await service.bucket.file(removed.path).delete({ ignoreNotFound: true });
    await service.db.runTransaction(async (tx) => {
      const storageRef = service.ref('socialUsage', 'storage');
      const [blob, storage] = await tx.getAll(record.ref, storageRef);
      if (!blob.exists) return;
      // Keep a tombstone: an offline upload retry cannot reuse a deleted blob ID.
      tx.set(record.ref, { ownerId: removed.ownerId, state: 'deleted', bytes: 0,
        postId: null, cleanupAfter: null, createdAt: removed.createdAt });
      tx.set(storageRef, { bytes: Math.max(0, (storage.data()?.bytes ?? 0) - blob.data().bytes) });
    });
    deleted++;
  }
  return deleted;
}
