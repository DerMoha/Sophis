import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { cleanupAccount } from './cleanup_service.js';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { cleanupPartnerContent } from './partner_cleanup.js';
import { PartnerService } from './partner_service.js';
import { SocialError, SocialService } from './social_service.js';

initializeApp();
const emulator = process.env.FUNCTIONS_EMULATOR === 'true';
const service = new SocialService(getFirestore(), getStorage().bucket(process.env.SOCIAL_STORAGE_BUCKET || (emulator ? 'demo-sophis.firebasestorage.app' : undefined)), { production: !emulator });

const partners = new PartnerService(service);

// One bounded endpoint. Production remains disabled until operating config is set
// after review of region, App Check, retention and budget controls.
export const social = onCall({
  region: 'us-central1',
  minInstances: 0,
  maxInstances: 1,
  concurrency: 8,
  memory: '256MiB',
  timeoutSeconds: 30,
  enforceAppCheck: !emulator,
}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in to use Partner sharing.');
  const data = request.data;
  if (!data || typeof data.action !== 'string') throw new HttpsError('invalid-argument', 'An action is required.');
  try {
    switch (data.action) {
      case 'ownProfile': return await service.ownProfile(uid);
      case 'previewInvitation': return await service.previewInvitation(uid, data.token);
      case 'setProfile': return await service.setProfile(uid, data);
      case 'createInvitation': {
        if (data.audience != null && data.audience !== 'partner') throw new HttpsError('failed-precondition', 'Only partner invitations are supported.');
        return await service.createInvitation(uid, 'partner');
      }
      case 'revokeInvitation': return await service.revokeInvitation(uid, data.token);
      case 'removeFollower': return await service.removeFollow(uid, data.otherId, true);
      case 'unfollow': return await service.removeFollow(uid, data.otherId, false);
      case 'block': return await service.blockAccount(uid, data.otherId);
      case 'deletePost': return await service.deletePost(uid, data.postId, data.operationId);
      case 'requestPartner': return await partners.request(uid, data);
      case 'acceptPartner': return await partners.accept(uid, data.connectionId);
      case 'partners': return await partners.list(uid);
      case 'syncPartnerGoals': return await partners.syncGoals(uid, data);
      case 'partnerGoals': return await partners.goals(uid, data);
      case 'partnerSettings': return await partners.updateSettings(uid, data);
      case 'disconnectPartner': return await partners.disconnect(uid, data.connectionId);
      case 'syncPartnerMeal': return await partners.syncMeal(uid, data);
      case 'syncPartnerContribution': return await partners.syncContribution(uid, data);
      case 'deletePartnerSource': return await partners.deleteSource(uid, data);
      case 'partnerMeals': return await partners.meals(uid, data);
      case 'partnerSummaries': return await partners.summaries(uid, data);
      case 'deleteAccount': return await service.beginDeletion(uid);
      default: throw new HttpsError('invalid-argument', 'Unsupported action.');
    }
  } catch (error) {
    if (error instanceof SocialError) throw new HttpsError(error.code, error.message);
    if (error instanceof HttpsError) throw error;
    // Do not expose payloads, tokens or backend error details to callers/logs.
    throw new HttpsError('internal', 'Social action failed. Try again.');
  }
});

export const deleteSocialAccount = onDocumentCreated({
  document: 'socialDeletionJobs/{accountId}', region: 'us-central1',
  minInstances: 0, maxInstances: 1, concurrency: 1,
  timeoutSeconds: 120, retry: true,
}, async (event) => {
  await cleanupAccount(service, event.params.accountId, getAuth());
});

export const cleanupPartnerSharing = onDocumentCreated({
  document: 'socialPartnerCleanupJobs/{jobId}', region: 'us-central1',
  minInstances: 0, maxInstances: 1, concurrency: 1,
  timeoutSeconds: 120, retry: true,
}, async (event) => {
  await cleanupPartnerContent(service, event.data.data());
  await event.data.ref.delete();
});
