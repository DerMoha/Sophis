# Spark partner sharing

Production uses Firebase Authentication and Firestore Security Rules. The app
calls Firestore directly with the captured user's ID token. No Cloud Functions,
Cloud Storage, service-account key or billing account is needed.

`firebase.json` intentionally deploys **only Firestore**. After CLI sign-in works:

```sh
firebase deploy --project sophis-d2953 --only firestore
```

Alternatively paste `firestore.rules` into the Firebase console and publish it,
then create the two collection indexes from `firestore.spark.indexes.json`.
Each index uses generation, localDate, timeZone and deletedAt ascending, followed
by the automatically added ascending document ID. Scope: Collection.

Run security and actual Dart transport tests against isolated emulators:

```sh
cd functions
npm ci
npm run test:spark
```

The script uses a demo project and isolated ports (19099/18080). It tests private
profiles, invitation capabilities, atomic consumption, mutual acceptance,
automatic full-history sharing, schema validation, legacy generations, bounded
queries, deletion, disconnection, pagination and local portion-aware imports.
Never point these fixtures at production.

For native UI integration, start the emulators from this directory:

```sh
functions/node_modules/.bin/firebase emulators:start --project demo-sophis --only auth,firestore
```

Then, from the application root:

```sh
flutter test integration_test/social_partner_screens_test.dart -d <device-id> \
  --dart-define=SOCIAL_EMULATOR_HOST=127.0.0.1 \
  --dart-define=SOCIAL_AUTH_EMULATOR_PORT=19099 \
  --dart-define=SOCIAL_FIRESTORE_EMULATOR_PORT=18080
```

On an Android emulator use `10.0.2.2` for the host. Release builds never enable
emulator configuration. The separate `firebase.legacy.json` is retained only
for regression tests of the previous Functions implementation; it must not be
deployed to the Spark project. Its historical tests run with `npm run test:emulator`.

## Local Android toolchain

Gradle 8.14/Kotlin in this project cannot run on the installed Java 25 runtime.
On this workstation a Java 21 build succeeds without changing global settings:

```sh
GRADLE_OPTS='-Dorg.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home' flutter build apk --debug
```

On another workstation use its installed compatible JDK path.

## Two-platform production integration

`integration_test/partner_cross_platform_test.dart` runs two installed apps
together against the registered Spark project. It is opt-in and uses synthetic
accounts and food. Each device keeps a separate local diary and account. Start
the local event relay from the repository root:

```sh
caffeinate -i -s python3 tool/partner_test_coordinator.py
```

In two terminals, start the Android author and iOS recipient. Use a new matching
run ID each time and replace the device IDs with those from `flutter devices`:

```sh
GRADLE_OPTS='-Dorg.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home' \
  flutter test integration_test/partner_cross_platform_test.dart -d emulator-5554 \
  --dart-define=PARTNER_TEST_PRODUCTION=true \
  --dart-define=PARTNER_TEST_ROLE=author \
  --dart-define=PARTNER_TEST_RUN=unique-run-id \
  --dart-define=PARTNER_TEST_HOST=10.0.2.2

flutter test integration_test/partner_cross_platform_test.dart -d <ios-simulator-id> \
  --dart-define=PARTNER_TEST_PRODUCTION=true \
  --dart-define=PARTNER_TEST_ROLE=recipient \
  --dart-define=PARTNER_TEST_RUN=unique-run-id
```

The relay only coordinates test steps and transfers the invitation between the
two tests. Account creation, sharing and reads use the real native Firebase Auth
and production Firestore transport. It checks both directions, goal/progress
values, automatic updates, portion import, disconnect and local copy retention.
Temporary Auth accounts are deleted and local diary fixtures restored in cleanup;
the local recovery checkpoint also restores fixtures when restarting an
interrupted run. `caffeinate` prevents idle system sleep during the paired test.
disconnected synthetic Firestore records remain inaccessible. Stop the relay
with Ctrl-C after both tests finish. These are debug simulator builds, not signed
iOS distribution artifacts or an Android store release.
