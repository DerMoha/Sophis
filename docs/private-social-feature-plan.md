# Private social feature — discussion draft

Status: scope agreed on 2026-10-07; ready for implementation planning. This is an additive
feature; existing local tracking remains available without an account.

## Purpose

Make it easy for partners and invited friends to share what they cooked, reuse
each other's meals, and offer encouragement. Initial success means two people
can connect, share dinner once, and log their own portions independently.

## Proposed scope

- Any person with access to the app can create an account; distribution is
  currently limited to invited friends. App installation alone grants no access
  to another person's data.
- Two distinct audiences: automatic partner sharing and deliberate follower
  posts. Partner connection requires mutual acceptance; each person controls
  their outgoing sharing independently.
- Partner receives individual meals and daily calorie/macro totals.
- Accepted scope addition: per-connection opt-in calorie/protein/carbohydrate/fat
  targets and progress against those targets. Goal consent is separate from meal
  and summary consent; no weight, profile or activity-derived data is shared.
  Progress covers only eligible shared entries and is labelled accordingly.
  Turning goals off revokes the hosted snapshot; pausing freezes it. Daily
  totals have a separate sharing toggle. Edits/deletes update the partner view;
  previously imported diary entries remain independent copies.
- Partner photo default includes an existing meal photo when enabled. It never
  prompts for a new photo during ordinary logging. Ordinary posts choose photos
  explicitly. Meal-photo attachment/storage needs implementation: the existing
  FoodEntry model has no photo field.
- Multiple mutually accepted partner connections are supported, with independent
  sharing settings per connection. Only meals logged from sharing activation
  onward are included; no historical backfill. Daily summaries must cover only
  eligible entries, including on the activation day, rather than exposing prior
  meals through aggregates.
- Pausing stops future partner updates while retaining previously shared meals.
  Disconnecting revokes access entirely. Privacy revocation, block, account
  deletion, and source deletion must still be processed while sharing is paused.
- Ordinary approved followers can see earlier deliberate posts.
- Email/password sign-in with password recovery initially; no Google/Apple
  sign-in required for the initial scope.
- Reactions initially; comments are deferred.
- Push notifications for connection/follow requests and deliberate posts; no
  notification for every automatically shared meal. User can disable push.
- Optional account, display name, optional avatar.
- Expiring, revocable invitation links and QR codes. No public directory.
- Directional follow requests requiring approval; offer a reciprocal request
  during acceptance without granting access automatically.
- Chronological feed of explicitly published meals and recipes.
- Post title, optional caption, one optional photo, item/ingredient snapshot,
  serving information, and optional visible nutrition.
- Save recipe locally or add a selected portion to the local diary.
- One simple reaction per person per post.
- Owner edit/delete, unfollow, remove follower, block, and report.
- In-app activity and the scoped push notifications above, after the core flow works.

Defer comments, messaging, public discovery, rankings,
weight/progress summaries, full diary backup, and multi-device diary sync until
their value is established. These are separate decisions rather than implied
benefits of creating an account.

## Main flows

1. Tracking without an account continues as today. Opening People explains the
   feature and offers account creation or sign-in.
2. User creates a profile and sends an invitation. Recipient signs in, previews
   the inviter, and requests access. Inviter approves.
3. Share action on a meal/recipe opens a preview: content, photo, nutrition
   visibility, and audience. Publishing creates a separate social snapshot.
4. Follower opens the feed, reacts, or chooses Add to diary. Portion, date, and
   meal category are selected before a new local entry is committed.
5. Recipe import creates an independent local copy. Author edits/deletes never
   silently change a recipient's diary or saved recipe.

## Privacy and audience semantics

- All profiles are private. Approved followers can see published posts.
- A newly approved follower can see existing deliberate posts. Selected
  recipients for individual follower posts are deferred.
- Remove/block immediately prevents future server reads. The client removes
  cached social content when it learns access has changed. Already downloaded
  content, screenshots, and deliberate diary imports cannot be recalled.
- Automatic partner sharing uploads only meals and calorie/macro summaries
  covered by explicit sharing settings, from activation onward without historical
  backfill. Followers see only deliberate posts.
- Weight, HealthKit/Health Connect source records, progress photos, credentials,
  and API keys are never implicitly uploaded.
- Server authorizes every post and photo read. Avoid permanent bearer download
  URLs for private photos. Strip photo location metadata before upload.
- Sign-out/account switch clears account-specific social caches and queued work;
  the local diary stays on the device. Warn on shared-device use.
- Account deletion removes hosted profile, posts, images, relationships,
  reactions, and tokens through a retryable cleanup job. Explain that recipient
  diary copies remain. Local delete-all-data and account deletion are distinct.
- Publish an updated privacy notice and document actual storage regions and
  deletion/backup retention before external use. Private here means access
  controlled, not end-to-end encrypted.

## Domain and data model

| Record | Essential fields |
| --- | --- |
| SocialProfile | accountId, displayName, avatarBlobId, timestamps |
| Invitation | tokenHash, inviterId, expiry, use limit, revokedAt |
| Follow | followerId, followedId, pending/accepted status, timestamps |
| PartnerConnection | id, participants, acceptance state, per-person meal/summary/photo settings, sharing start, revokedAt |
| PartnerMeal | connectionId, authorId, sourceMealId, snapshot, revision, photoBlobId, deletedAt |
| PartnerDailySummary | connectionId, authorId, localDate, timeZone, calories, protein, carbs, fat, revision |
| Block | blockerId, blockedId, createdAt |
| Post | id, authorId, kind, schemaVersion, snapshot, caption, nutritionVisible, photoBlobId, revision, timestamps |
| Reaction | postId, actorId, kind, timestamp |
| Blob | id, ownerId, postId, processing state, size, media type |
| Report | reporterId, targetId, reason, handling status |
| DeviceToken | accountId, token, platform, notification preferences |

Use stable IDs, server publication timestamps, cursor pagination, and payload
versioning. Store source portions and nutrient totals explicitly so imports scale
correctly. Imported entries get new local IDs; an import operation ID prevents
duplicate commits from retries while allowing intentional repeat logging.

## Fit with Sophis

- Keep NutritionStore/SQLite authoritative for local tracking.
- Extend the existing ShareableMeal concept with a versioned social snapshot;
  reuse validation and portion conversion after checking their assumptions.
- Introduce SocialRepository and a SocialController/Provider. Screens should not
  read Firebase documents or HTTP payloads directly.
- Store drafts, queued social commands, and bounded feed cache locally.
- Reuse outbox transaction principles, but do not connect all existing nutrition
  mutations to the cloud. Publish explicit posts and consent-filtered partner
  updates in an account-scoped
  queue separate from the private nutrition outbox unless an intentional filtered
  design proves simpler.
- Offline publication remains queued with visible status. Retry idempotently;
  recheck account and authorization on reconnect. Never send one account's queue
  under another account's identity.
- Upload and process image first; publish the post only once its photo is ready.
  Clean up abandoned uploads. Deletes take precedence over queued stale edits.
- Offline tracking and cached feed browsing work; first sign-in, invitations,
  approval, and fetching new posts require connectivity.

## Backend proposal

Selected backend: Firebase Auth, Firestore, Cloud Storage, and a minimal set of
server functions for invitation acceptance, publication validation, image
processing, feed reads, and cleanup. Add FCM only when push is included.

For a small private network, fetch a bounded chronological page across approved
authors. Prototype Firestore indexes/query limits and authorization before
settling on a feed schema. Avoid an unbounded listener per followed person.
Use a server endpoint if cross-author filtering is clearer there; enforce access
on photo delivery independently. Avoid feed fan-out until scale demands it.

Use emulator tests, App Check where suitable, server-side input validation,
per-account posting/upload limits, compressed photos and thumbnails, bounded
pagination, monitoring, and spending alerts. Alerts are not a hard cap; a strict
maximum requires enforceable service limits and a shutdown/degradation policy.

Operating requirement: target zero ongoing usage charges within applicable
no-cost allowances. This is not permission to silently accept paid overages.
Blaze is required for photos; Firebase does not provide a universal hard
zero-spend cap. Do not promise one. Validate all billable services, deployment
artifacts, storage location, operation counts, transfer and retention before
enabling production. New Storage bucket no-cost allowances depend on region;
EU residency versus eligible US-region allowances must be discussed explicitly.
User selected an eligible US photo-storage region to prioritize no-cost usage.
User understands residual Blaze charge risk from the preceding discussion;
this is a zero-cost operating target, not permission for uncontrolled overages.
Use client-side image compression/metadata stripping to avoid routine processing
functions, small feed pages, local caching, bounded subscriptions, rate limits,
and upload/storage limits. Define conservative stop thresholds and disable new
social work near them; monitoring lag and infrastructure charges remain risks.
If strict guaranteed zero charges is essential, revise photo/backend scope.

Self-hosted alternative: a maintained API/auth stack, Postgres, private object
storage, and a reverse proxy, deployed with Docker Compose. Include migrations,
session revocation, upload processing, idempotent commands, off-site encrypted
backups, tested restoration, health monitoring, and safe update procedures.
Choose this if operating the service is an intended responsibility. Ensure the
same deployment can move to a VPS. Home outages delay social actions while
local tracking continues.

## Delivery milestones

1. Decisions and backend spike: audience rules, account method, two-user feed,
   protected photos, access revocation, and measured request/upload volume.
2. Accounts and relationships: profile, invitations, approval, block/removal,
   account-scoped local cache, sign-out and account switching.
3. Sharing: explicit publication preview, versioned snapshots, one photo,
   chronological feed, owner edit/delete, offline drafts and retries.
4. Reuse and encouragement: portion-aware diary import, recipe copy, reactions,
   and activity; optional push with generic lock-screen text.
5. Hardening and two-person trial: Android/iOS device checks, access-control
   tests, deletion cleanup, cost checks, backup restoration, and updated privacy
   documentation. Then broaden to invited friends.

## Acceptance checks

- Existing data survives upgrade and guest tracking remains functional.
- Third account cannot read private posts/photos or accept another user's invite.
- Removed/blocked followers lose server access; stale queues cannot bypass this.
- New follower history visibility matches the agreed rule.
- Offline retries produce one post/reaction/import per operation, not duplicates.
- Portions scale correctly; later author edits do not alter imported diary data.
- Interrupted uploads and account deletion leave no permanently orphaned blobs.
- Account switching cannot leak cached content or send queued actions as another
  user. No diary or health record enters a social payload unintentionally.
- Shared meals, links, camera/photo flows, and optional push work on both phones.

## Implementation goal and remaining engineering decisions

Implement the agreed additive social feature on Android and iOS, preserving
existing local data and account-free tracking. Deliver optional email/password
accounts, approved follows, multiple partner connections, automatic onward-only
meal/summary sharing, deliberate photo-capable posts, reactions, independent
portion-aware imports, scoped push, and complete pause/revocation/deletion flows.
Use Firebase and eligible US photo storage; engineer for no-cost allowances with
measured limits and explicit degradation before expected overages.

Choose concrete schema, indexes, feed strategy, upload caps, retention limits,
monitoring thresholds, and minimal server functions during an emulator-first
spike. Define daily-summary behavior while paused and after resume without
backfilling paused meals. Do not implement general diary cloud sync or silently
enable production billing. Obtain necessary project configuration from the user
when unavailable, after completing independent local work.
