# Firebase setup for partner sharing

Updated 2026-10-08. Hosting requirement: **Spark only, billing unlinked**.

## Registered project

- Project: `sophis-d2953` (Sophis), number `657623134154`.
- iOS bundle and Android package: `com.sophis.sophis`.
- Registered iOS app: `1:657623134154:ios:23417f8213e19b7d86a933`.
- Registered Android app: `1:657623134154:android:63c8bd942f9fd2d486a933`.
- Email/password Authentication enabled; email-link sign-in is off.
- Firestore Standard edition, `(default)`, region `us-central1`.
- Billing has not been linked. No Functions or Storage service is required.

## App configuration

Normal `flutter run` and release builds include the registered public client
options in `lib/services/social/firebase_project_options.dart`. iOS and Android
use their respective API keys and app IDs. Firebase is initialized lazily only
when the user opens optional Partner sharing; guest diary tracking stays local.

Firebase client config identifies an app/project; it does not authorize data
access. Authorization is enforced by Firebase Auth and Firestore Security Rules.
See [Firebase configuration documentation](https://firebase.google.com/docs/projects/learn-more#config-files-objects).
These client identifiers must never be replaced with a service-account key.

The ignored local `config/firebase.production.json` remains available for an
explicit registered-project build:

```sh
flutter run --dart-define-from-file=config/firebase.production.json
```

A different project requires a complete set of explicit `SOCIAL_PROJECT_ID`,
`SOCIAL_API_KEY` (or platform-specific keys), `SOCIAL_SENDER_ID`,
`SOCIAL_IOS_APP_ID` and `SOCIAL_ANDROID_APP_ID` build defines. Unsupported desktop
platforms have no implicit production registration. Release builds reject
emulator configuration.

App Check activation is opt-in (`SOCIAL_APP_CHECK=true`) after registering App
Attest/DeviceCheck and Play Integrity providers. It is not yet registered or
production-enforced. Rules enforce authorization regardless of App Check.
Register and verify providers before enabling enforcement for a broad release;
use an explicitly configured debug provider for test devices.

## Deployment status

The 2026-10-10 automatic-sharing rules were published to `sophis-d2953` through
the signed-in Firebase console at 12:56 Europe/Berlin. The console confirmed success.
Local rules and real Auth/Firestore transport emulator checks passed before publication.
The production smoke test passed on the deployed automatic-sharing rules: three isolated
synthetic accounts, invitation/acceptance, automatic meals/intake/goals, unrelated-account
denial and disconnect. The successful run removed its Auth fixtures. An earlier run’s
cleanup attempted to disconnect an already-revoked connection; this fixture bug is fixed,
and its three remaining synthetic Auth accounts were deleted through the console
after explicit user approval. The console confirmed removal of each account.
The deployment and production test results below describe the previous permission model.

The rules in `backend/firestore.rules` were published in the Firebase console
on 2026-10-08 at 11:42 local time. The console confirmed successful publication.
Both collection indexes are ready: `meals` (`CICAgOjXh4EK`) and
`contributions` (`CICAgJiUpoMK`). They use generation, localDate, timeZone and
deletedAt in ascending order, plus the automatic ascending document ID.

The production smoke test passed against `sophis-d2953`: three isolated accounts,
invitation and approval, separate sharing consent, meal/intake/goal reads,
unrelated-account denial, consent revocation and fixture cleanup. The console
still showed Spark, free at $0/month, after publication.

The default `backend/firebase.json` intentionally deploys only Firestore. The
previous Cloud Functions deployment archive and its Blaze/Cloud Shell steps are
superseded; do not use them. `firebase.legacy.json` is only for legacy emulator
regression tests, not production deployment.

## Verification

The current Spark rules and Dart transport tests cover invitation acceptance,
automatic sharing of historical food, goals and daily totals, legacy switches,
pagination, unrelated-account denial, source deletion and disconnect. Widget tests
cover the direct single-partner view, multiple partners and pending invitations.
Native and paired-device fixtures now use automatic sharing; rerun these against
the updated rules before release. The following paired production result is historical.
See [backend instructions](../backend/README.md) for exact commands.

The paired native production test also passed on 2026-10-08: Android API 37.2
author and iPhone 18 Pro / iOS 27 recipient, each with its own install, account
and diary. It verified native account creation, invitation/approval, sharing in
both directions (400/2200 kcal and 300/1800 kcal), half-portion import (200 kcal),
pause, goal revocation, disconnect and retention of the independent local copy.
Both synthetic Auth accounts were removed and the run's diary fixtures restored.
The test now keeps a local recovery checkpoint for interrupted runs.

This exposed and fixed device-clock skew around activation: the transport
calibrates against fresh Firestore commit/read timestamps before comparing local
food timestamps with server activation. Existing published origins stay immutable;
older food remains excluded and the deployed security rules are unchanged.

A deliberate production smoke test passed on 2026-10-08 and can be rerun explicitly:

```sh
SOPHIS_VERIFY_DEPLOYED_SPARK=sophis-d2953 flutter test test/services/social/firestore_partner_production_test.dart
```

It creates three synthetic accounts, verifies the deployed sharing flow, revokes
access, tombstones its source entries and deletes the temporary Auth accounts.
Its disconnected connection, invitation, synthetic profiles and inaccessible
synthetic goal record remain in Firestore; it does not purge production data.
It is skipped in ordinary test runs and never runs against an inferred project.

Physical two-phone testing remains a release gate. No physical phone is currently
available to this workspace; simulator and transport checks do not prove device
signing, distribution, or production App Check behavior.

## Free usage and retention

Firestore's free quota includes 1 GiB stored data, 50,000 document reads,
20,000 writes and 20,000 deletes daily, with network transfer limits. These are
shared project limits; rule-dependent reads also count. Queries are paginated,
there is no remote polling, and a daily total fails explicitly above the bounded
contribution count rather than displaying an incomplete total. Quota exhaustion
can interrupt sharing while local tracking continues. Billing remains unlinked.

Consent off/disconnect immediately denies partner reads; it does not run a
server purge. Source deletion sends a minimal tombstone. There are no automated
cleanup/retention jobs on Spark. Previously imported local diary copies cannot
be recalled.

References: [Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
and [Firestore quotas](https://firebase.google.com/docs/firestore/pricing).
