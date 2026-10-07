# Social backend spike — implementation status

Prepared 2026-10-07. The product scope remains authoritative in
[private-social-feature-plan.md](private-social-feature-plan.md).

## Implemented and isolated

This implements backend/access control and local persistence foundations,
**not a finished People feature**. NutritionStore now supports transactional
social imports and a local immutable logging-origin ledger. Existing application
and iOS edits remain preserved in the working tree.
No Firebase project, billing account, bucket, production resources or deployment
was created. The existing guest app does not initialize this code yet. Firebase Core/Auth/
App Check packages are installed; the optional named social app is initialized
only through an explicit configuration factory.

- `backend/functions/src/social_service.js`: private profiles, hashed expiring
  one-use invitations, approved directional follows, removal/block, versioned
  explicit post publication, revision-checked editing, deletion tombstones,
  bounded chronological feed and one reaction per actor/post.
- Firestore and Storage rules deny all direct client access. The callable API
  authenticates the caller and performs authorization itself using the Admin
  SDK. Rules do **not** protect an Admin SDK function; every server path needs
  the service checks. Production callable requests require App Check.
- Feed access is checked against current profiles, approvals and both block
  directions. New followers see existing deliberate posts. Read authorization
  is independent of client caches and is rechecked for every photo delivery.
- Private photos are re-encoded as JPEG with metadata stripped, uploaded before
  publication, and delivered as authenticated bytes. No download or signed URLs
  are returned. Inputs are bounded to 256 KiB and 2.56 million decoded pixels;
  clients should compress first to avoid unnecessary processing/transfer.
- Privacy deletion remains available when ordinary work is disabled. Account
  deletion first marks the profile unavailable, creates a durable cleanup job,
  then removes photos, posts, reactions, relationships, invitations and tokens.
  Auth deletion can retry after partial cleanup. A minimal account-ID tombstone
  prevents unexpired tokens recreating the removed profile.
- `SocialSnapshot` whitelists social fields, preserves source quantities and
  explicit servings, and scales independent import entries. It generates
  deterministic import IDs. NutritionStore commits the whole import with a durable
  operation receipt; retries preserve recipient edits and deletion. Recipe copies
  receive independent recipe and ingredient IDs.
  Nutrition-hidden snapshots cannot be imported as zero-calorie diary entries.
- `SocialLocalStore` uses a separate SQLite database with its own schema; the
  private nutrition outbox remains independent of social transport. Queues/cache are invalidated in one
  transaction on account change. Old session generations cannot insert queued
  work or overwrite caches after switching. Cache is bounded to 100 posts.
- `SocialQueueRunner` bounds replay, backs off network/rate failures, and parks
  invalid/unauthorized work for user review. `SocialCallableClient` sends the
  documented callable envelope with explicit captured ID and App Check tokens.
  Account/generation checks occur around asynchronous credential work and after
  responses. It disables redirects, bounds response size and hides backend error
  details. Transient credential failures remain retryable.
- `FirebaseSocialAuth` handles email/password creation/sign-in, recovery and
  sign-out. It checks the actual JWT subject returned by native token refresh,
  tracks authentication epochs and clears persisted account content on changes,
  including rapid logout/login under the same UID. Auth SDK operations and HTTP
  transport are unit-tested through mocks; real native authentication still needs
  emulator/device validation.
- `CallableSocialRepository` converts feed payloads to domain records, caches
  bounded first-page content, queues explicit publication/reactions/deletion and
  sends relationship removals. Publication IDs match the server's structured
  hash. Cancelling a queued publication removes its queued upload-independent
  publish command and supplies operation proof for a server tombstone, so a late
  publish cannot resurrect it. The server rejects proof for another author's ID.
- `PartnerService` requires mutual connection acceptance and per-person outgoing
  consent. Server timestamps define onward-only meal/summary/photo periods.
  Pausing preserves frozen views; disabled categories revoke prior generations.
  Disconnect, block and account deletion immediately deny reads. Source deletion
  bypasses ordinary limits and pause. Cleanup jobs purge revoked content and
  private photo objects, with retries and checks against newer consent changes.
- Summary-only sharing accepts bounded per-meal numeric contributions and builds
  aggregates on the server; it receives no ingredient details or wholesale diary
  totals. Moving a source meal updates both affected daily aggregates atomically.
- Schema v13 adds a local logging-origin ledger, alongside the existing working
  tree's v12 portion migration. New logs receive immutable actual logging times;
  edits cannot make historical meals eligible. Legacy/restore rows are unclassified.
  Revisions and incremental sequence cursors commit with diary writes. Minimal
  deletion facts survive removal so paused partner copies can be deleted later.
  This ledger still needs consent-filtered projection and social queue integration.

## Emulator workflow

Use Node 22 and a supported Java runtime. The installed host currently uses
Node 26 and Java 25; tests also ran there, with dependency-engine and Java runtime
warnings. The declared deployment runtime is Node 22.

```sh
cd backend/functions
npm ci
npm run check
npm run test:emulator
```

The script hardcodes the `demo-sophis` demo project and starts local Auth,
Firestore and Storage emulators. Tests refuse to run without emulator environment
variables. They exercise the service against real emulated Firestore, direct
client rule denials against Firestore/Storage, and photo lifecycle with an
in-memory object-storage test double. Native clients, the callable HTTP wrapper,
actual Storage upload/download behavior and deployed cleanup triggers still
need integration/device tests; passing these tests is not a production release
claim. The functions emulator can be included during the next wiring milestone.

```sh
flutter analyze
flutter test --no-pub
```

## Initial schema/query choices

All collections are prefixed `social`. Profile IDs are Auth UIDs. Follow/block
IDs and post/blob operation IDs are SHA-256 hashes of structured ID pairs,
avoiding concatenation collisions. Invitation documents contain only token
hashes; raw random tokens are returned once. Invitations expire after 48 hours.

A follower is limited to 20 followed authors, including pending requests.
This bounds one `in` feed query to 21 authors including self. The server reads
at most 20 candidate posts in timestamp/document-ID order. Tombstones can make a
page shorter or empty; a non-null cursor still means another page can be fetched.
No fan-out or listener-per-author is used. Required production indexes are in
`backend/firestore.indexes.json`; emulator success alone does not validate that
production indexes have finished building.

Posts whitelist items, nutrient totals, source quantities and servings. Hidden
nutrition is removed on the server too. Publication IDs survive deletion as
tombstones so an offline retry cannot recreate the post. Edits use a base
revision, so conflicting retries must refresh rather than overwrite silently.

## Operating limits and cost envelope

Checked against official documentation on 2026-10-07:

- [Firebase pricing](https://firebase.google.com/pricing): standard Firestore
  no-cost allowances include 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day,
  1 GiB stored and 10 GiB/month egress. Functions, builds and artifact storage have
  their own allowances. FCM is listed as no-cost.
- [Storage billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024):
  Storage requires Blaze. Eligible locations for new-bucket no-cost allowances
  are `us-central1`, `us-east1`, `us-west1`.
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing): eligible
  region allowances include 5 GB-month storage, 5,000 Class A operations/month,
  50,000 Class B operations/month and qualifying transfer. Check destination
  restrictions and the billing account's shared usage before configuring it.
- [Function controls](https://firebase.google.com/docs/functions/manage-functions):
  instance caps and minimum instances are resource controls, not spending caps.

Initial code limits are deliberately conservative for a two-person trial:

| Control | Limit |
| --- | --- |
| Candidate feed page | 20 posts |
| Followed authors, including pending | 20/account |
| Post snapshot | 50 items |
| Final uploaded photo | 256 KiB |
| New posts/edits | 10/account/UTC day |
| Ordinary requests | 100/account/UTC day and 100/project/UTC day |
| Upload reservations | 1,000/project/UTC month |
| Reserved stored photo bytes | 512 MiB/project |
| Delivered photo bytes | 256 MiB/project/UTC month |
| Callable instance settings | minimum 0, maximum 1, concurrency 8 |

The server transaction reserves usage before new work. Upload retries can
conservatively consume more reserved bytes/operations than eventual stored
objects; this favors stopping early. Download retries count again. Privacy
removal and cleanup bypass ordinary publication/feed limits. No client is
trusted to enforce these caps. The project operating document defaults closed
in production and can disable ordinary work without stopping privacy cleanup.

For a maximally populated page, successful feed work has a conservative upper
bound around 251 Firestore document reads (profile, quota records, follows,
current authorization checks and 20 candidate posts). At 100 ordinary project
requests/day, this stays around 25,100 reads before cleanup, failed attempts,
transaction retries and other project use. A 256 KiB upload and private photo
response each represent one bounded object operation in the successful path.
These are source-derived bounds, not measured production billing.

**Residual charge risk remains:** rejected invocations, invalid requests,
transaction retries, abuse, auth traffic, cleanup, functions CPU/memory,
Cloud Build, Artifact Registry, logging, deployment artifacts and other
applications sharing an allowance are not all capped by these logical counters.
Alert delivery can lag. These controls do not guarantee a zero bill on Blaze.
The privacy endpoints must also receive abuse controls before production.

Before enabling production, configure budget alerts, service quotas where
available, artifact cleanup, log exclusions/retention, bucket lifecycle/soft-delete
retention, and monitoring. Use 50% allowance warnings and disable ordinary social
work at 70% of relevant observed usage, with headroom for cleanup and monitoring
lag. A trusted monitor/operator must implement that stop action; it is not
currently connected automatically. Do not deploy by simply setting `enabled`.
No TTL policy, paid backup feature, scheduler or budget automation is enabled.

Photo metadata retains `cleanupAfter` for unbound/removed blobs. The trusted
`cleanAbandonedPhotos` helper handles up to 500 due objects per invocation and
is retryable; scheduling/maintenance integration remains required. Published
photos are excluded from that queue. Permanent object tombstones prevent stale
upload IDs from being reused. Account-deletion cleanup is wired to a retryable
Firestore job-created trigger; Auth is deleted only after hosted data cleanup.

## Verification on this working tree

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 379 tests passed on the current working tree.
- Backend emulator suite: 37 tests passed.
- iPhone 18 Pro / iOS 27 simulator: native integration test passed using actual
  Firebase Auth/Functions emulators and the SQLite stores. It exercised account
  creation, profile saving, empty feed, Connections, invitation creation/revocation,
  and sign-out, asserting that diary entries stayed unchanged. Notification plugin
  calls were stubbed to isolate an unrelated startup permission prompt.
- Signed builds, physical devices, Android, two-person screens, native OCR and
  notification delivery remain unvalidated.

## Next implementation work

1. Complete the initial People screens: queued-operation review, account deletion,
   profile editing/avatar and localization. Account creation/sign-in/recovery,
   profile creation, feed loading, directional connections, invitations/QR,
   reciprocal requests, remove/block and sign-out now have initial UI. The native
   simulator test covers only the single-account flow above; separate-user
   acceptance/removal/block screens still need device tests.
2. Connect server partner consent and local logging-origin facts to filtered
   events, durable per-connection queues and meal-photo attachment modeling.
   Never feed the entire existing nutrition outbox into this social transport.
3. Publication preview/photo compressor, feed/photo UI, profile/invite QR routes,
   owner controls, import/recipe-copy UI and activity.
4. Reports, avatars, optional generic-text FCM, revoke/cache refresh integration,
   account deletion UI, automated orphan maintenance and abuse controls.
5. Updated privacy notice and verified region/backup/deletion retention,
   restore tests, Android/iOS native integration and two-device trial.

The actual Firebase project configuration is still absent. Native integration
will need the project ID, Android/iOS app registrations and configuration files,
actual bucket name/location, and a deliberate production billing/deployment step.
No credentials or billing authorization should be inferred from this spike.

## Firebase client configuration

`SocialFirebaseConfiguration` accepts platform-specific registered FirebaseOptions.
It does not infer a project or initialize at application startup. A named
`sophis-social` app keeps authentication scoped to this feature. Production uses
Play Integrity and App Attest with DeviceCheck fallback; registrations/enforcement
must be configured and verified before release. Explicit debug emulator mode
requires a `demo-` project, uses Auth port 9099 and Functions port 5001, and never
uses production App Check. Release builds reject emulator mode.

The captured-token transport follows the
[official callable protocol](https://firebase.google.com/docs/functions/callable-reference).
This is intentional because native Auth token refresh is scoped to the Firebase
app; the adapter verifies the returned token subject and rechecks the account
before sending, rather than allowing a callable adapter to substitute credentials.
Firebase SDK versions are pinned through the application lockfile. The analyzer
excludes generated `build/**` package copies and example apps; application source
and tests remain analyzed. Native dependency resolution/builds remain a separate
validation step; adding Dart packages alone does not prove either phone works.


## Native simulator setup

The application opens People from Settings; Firebase starts only when People is
opened. Missing production dart defines show the guest explanation and a return
path to tracking. Explicit emulator runs use:

```sh
flutter run -t integration_test/social_screens_test.dart --no-pub \
  -d <simulator-id> --dart-define=SOCIAL_EMULATOR_HOST=127.0.0.1 \
  --dart-define=SOCIAL_SCREENSHOTS=true
```

Start the Auth, Firestore, Storage and Functions emulators for `demo-sophis` first.
The test refuses any other project. `flutter run` leaves the tested app open for
review; use `flutter test` with the same target and emulator define for the
automated validation run. That command removes its test app at completion.
Optional screenshots are written under the simulator app's Application Support
`social-test-screenshots` directory while it is installed. Synthetic
accounts are emulator-only; diary entries are compared before/after, never reset.

Three native compatibility issues were exposed during real simulator launches:

- Xcode 27 builds require the scene lifecycle. AppDelegate now registers plugins
  through the implicit-engine callback and Info.plist declares FlutterSceneDelegate,
  following [Flutter's migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).
- Firebase SwiftPM and ML Kit CocoaPods duplicated native symbols. The app now uses
  one CocoaPods dependency path through the documented
  [project-level SwiftPM setting](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#how-to-turn-off-swift-package-manager).
  This is a current compatibility measure; those plugins need a future SwiftPM
  migration when Flutter stops supporting this fallback.
- ML Kit lacks a native ARM64 simulator slice. Upgraded the text-recognition plugin
  to 0.17.1 (commons 0.13.0) and opted into its
  [maintainer-provided simulator helper](https://github.com/flutter-ml/google_ml_kit_flutter/blob/develop/packages/google_mlkit_commons/README.md).
  The helper relabels vendored Pods per build platform; Debug.xcconfig overrides
  Flutter's podspec-derived ARM64 exclusion. The simulator app launched with this
  setup, but physical-device builds and native OCR still need validation.

The account, profile, empty feed, Connections, invitation/QR and signed-out
screens were captured and visually reviewed on the simulator. No layout overflow
was observed at its default text size. Narrow and larger text layouts still need
a social-specific accessibility pass.

Production uses `SOCIAL_PROJECT_ID`, `SOCIAL_API_KEY`, `SOCIAL_SENDER_ID` and the
platform-specific `SOCIAL_IOS_APP_ID` / `SOCIAL_ANDROID_APP_ID` dart defines. These
are registered-app configuration, not authorization to deploy or enable billing.
Production App Check setup and real configuration remain required before release.
