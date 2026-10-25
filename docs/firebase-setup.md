# Firebase setup for partner sharing

Hosting requirement: **Spark only, billing unlinked**.

## Registered project

- Project: `sophis-d2953` (Sophis), number `657623134154`.
- iOS bundle and Android package: `com.sophis.sophis`.
- Registered iOS app: `1:657623134154:ios:23417f8213e19b7d86a933`.
- Registered Android app: `1:657623134154:android:63c8bd942f9fd2d486a933`.
- Email/password Authentication enabled.
- Firestore Standard edition, `(default)`, region `us-central1`.

## App configuration

The public client options live in
`lib/services/partner/firebase_partner_backend.dart`. They identify the
project; Firebase Auth and Firestore Security Rules authorize access. See
[Firebase configuration documentation](https://firebase.google.com/docs/projects/learn-more#config-files-objects).

For local testing, `--dart-define=PARTNER_EMULATOR_HOST=127.0.0.1` uses the
Auth (19099) and Firestore (18080) emulators with the `demo-sophis` project. It
is ignored in release builds. App Check is not used.

## Rules and data

See [backend/README.md](../backend/README.md) for the data layout, deployment
and rules tests.
