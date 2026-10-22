# Sophis

Sophis is a Flutter nutrition tracker with local-first storage (SQLite + SharedPreferences).

## Development

- Install dependencies: `flutter pub get`
- Run app: `flutter run`
- Analyze: `flutter analyze`
- Run tests: `flutter test`

## Android distribution

For direct installation on an ARM64 phone, build an optimized APK:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --split-debug-info=build/symbols/android
python3 tool/check_android_apk_size.py
```

The APK is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
For all supported architectures, omit `--target-platform android-arm64` and
distribute the matching APK from the same directory. For Google Play, use
`flutter build appbundle --release --split-debug-info=build/symbols/android`;
Play delivers the binaries appropriate to each device.
Archive `build/symbols/android` with each release to decode Dart crash traces.
These builds currently use the development signing key; configure release
signing before publishing.

Android OCR and barcode models are downloaded through Google Play services.
Play installations request model prefetch; sideloaded installations download
on the first scan. Scanning waits for model installation and supports retry.
An internet connection and working Google Play services are required for the
initial download; subsequent recognition runs locally. iOS model delivery is
unchanged. See [Android size decisions](docs/android-app-size.md).

## Optional partner sharing

Partner sharing uses the registered Sophis Firebase iOS/Android apps on the free
Spark plan. Normal `flutter run` builds include their public client identifiers;
no CLI sign-in or extra build flags are required. Firebase opens only when the
user enters Partner sharing. The local diary remains available without login.

See [Firebase setup](docs/firebase-setup.md) for deployment status and
[backend testing](backend/README.md) for security and native integration checks.
Full diary backup and cross-device synchronization are not provided by this
feature.

## OS Backup Restore (No Login Required)

Sophis now relies on native OS backup/restore to recover local data after uninstall/reinstall.

### What Is Covered

- App database (SQLite)
- SharedPreferences data
- App files in the backed-up app sandbox
- Secure storage restore is attempted; if key restoration fails, the app continues and the user can re-enter the key

### Important Limits

- This is best-effort behavior from iCloud/Google backup, not a guaranteed restore for every reinstall.
- Restore usually requires the same platform account and backup to be enabled before uninstall.
- Debug/local development reinstalls are not a reliable signal of real restore behavior.

### Why Debug Reinstall Can Differ

- Debug builds and local install/uninstall cycles often bypass normal cloud backup/restore timing.
- Production-like channels (Play release/internal testing, TestFlight/App Store) better represent real user restore behavior.

## QA Checklist For Restore Validation

Use release-like builds when validating restore behavior.

1. Install app and add representative data (goals, profile, food, water, weight, workouts, settings).
2. Confirm OS backup is enabled.
3. Trigger/allow device backup completion.
4. Uninstall and reinstall the same app package/bundle.
5. Open app and verify persisted data restored, including weight history.
6. Verify app still starts if secure storage key restore fails (API key may require re-entry).
7. Repeat with backup disabled to confirm expected clean-state reinstall behavior.
