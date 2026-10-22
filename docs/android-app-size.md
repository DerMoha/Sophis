# Android app size

## Decisions

Keep the diary, database, and navigation available without downloads. Load
Android OCR and barcode models when scanning needs them through Google Play
services. Recognition remains on device, with no cloud image upload introduced
by this change. Google Play can prefetch both models after installation.

The Android Gradle configuration substitutes the OCR plugin's bundled Latin
recognizer dependency in every project. Removing only the app's explicit
dependency would leave the plugin's bundled model in the APK. Barcode scanning
uses mobile_scanner's supported `useUnbundled` setting. Both scanner entry paths
wait for actual installation completion, with bounded waiting and retry after
failure. Devices without working Google Play services receive an explanation.

Build APKs separately by architecture or distribute an Android App Bundle
through Play. Keep Dart symbols outside the APK and archive them alongside each
release. Do not compare universal debug APKs with production downloads.

## Measured baseline (2026-10-10)

Sizes are decimal MB of APK files, not installed storage or Play download size.

| Build | APK size |
| --- | ---: |
| Universal debug | 260.7 MB |
| ARM64 release, bundled scanning | 48.8 MB |
| ARM64 release, downloadable scanning | 30.5 MB |
| ARM64 release, downloadable scanning, separate Dart symbols | 28.7 MB |

## Further changes

The image processing package accounted for about 815 KB of Dart AOT symbols in
the original analysis. It supports image quality checks, OCR preprocessing,
progress photos, and cloud image preparation. Replacing this pipeline adds
cross-platform complexity for a much smaller potential saving than model
delivery. Retain it until profiling identifies a worthwhile replacement.

Flutter's rendering engine and compiled framework are the remaining baseline.
Keep dependency additions tied to actual features and measure an ARM64 release
after native dependency changes. Avoid adding extra OCR scripts unless the
product explicitly supports them.

`python3 tool/check_android_apk_size.py` checks the ARM64 artifact against a
35 MB budget, ensures a single architecture, and rejects bundled scanning
models/pipelines. Investigate budget changes before increasing the limit.

## Verification before shipping

On a clean Android device, test first scan with a connection, subsequent scans
in airplane mode, first use offline with a retry after reconnecting, and a
device without Google Play services. Test both nutrition label entry paths and
barcode/meal QR scanning. Model-service tests and release compilation do not
replace these device checks.

References: [ML Kit model installation](https://developers.google.com/ml-kit/tips/installation-paths),
[module installation API](https://developers.google.com/android/guides/module-install-apis),
[Flutter release packaging](https://docs.flutter.dev/deployment/android).
