# Android PaddleOCR experiment

The normal Android build still uses ML Kit. PaddleOCR is an opt-in experiment
with an explicit native build switch and Dart reader switch. A Paddle failure
never silently switches to ML Kit, so benchmark results are attributable.
No photo is uploaded to an OCR service. Models are downloaded by a developer
setup script, bundled only into the experimental build, and then run offline.
This is not yet a production model-delivery implementation.

## Implementation

- Vendored official Android SDK from PaddlePaddle/PaddleOCR commit
  `dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`, Apache-2.0.
- PP-OCRv6 Small detector, with a selectable PP-OCRv6 Small or PP-OCRv5 Latin
  Mobile recognizer. Pinned model revisions and SHA-256 checksums live in
  `tool/prepare_paddle_ocr.py`; downloaded assets are gitignored.
- ONNX Runtime 1.21.1. OpenCV uses the official 4.12.0 artifact instead of the
  upstream demo's third-party 4.5.3 artifact, which failed to load on our API 37
  emulator (`__sfp_handle_exceptions` missing).
- Detection is capped at 2048 px; recognition uses BGR channels as specified by
  both pinned model configs. All crop variants are evaluated in the experiment.
- The decoder retains character emission positions from CTC. The Flutter bridge
  derives token centers from those positions and detected quadrilaterals.
  These are approximate recognition alignments, not precise character boxes.
- Android quality checks and table crop variants use native OpenCV to avoid
  Dart JPEG preprocessing timeouts. Variants include color, grayscale, inverted
  grayscale and a second grayscale scale. EXIF orientation is normalized before
  recognition. Inference is serialized
  off the UI thread; models are reused and released after pending work.
- Both engines feed the same table parser, validation and editable review.
  Candidate selection prefers observed gram units over unitless readings and
  plausible energy/macros over conflicts. Standalone alphabetic nutrient names
  inside detected tables allow a unique one-character vocabulary correction,
  or two substitutions for words of at least six letters with unchanged length
  and first two letters;
  numbers are never repaired by this rule.

## Reproduce

Use Java 17 for the Android build. Flutter may prefer Android Studio's bundled
JDK over JAVA_HOME; a task-local Flutter configuration can override it without
changing your normal settings.

```sh
python3 tool/prepare_paddle_ocr.py
python3 -m http.server 8769 --bind 127.0.0.1 --directory /tmp/sophis-all-labels
adb reverse tcp:8769 tcp:8769
# Baseline
flutter test integration_test/nutrition_label_photos_test.dart -d emulator-5554 --dart-define=REAL_LABEL_PHOTOS=true
# Experimental build and selected reader
ORG_GRADLE_PROJECT_paddleOcr=true flutter test integration_test/nutrition_label_photos_test.dart -d emulator-5554 --dart-define=REAL_LABEL_PHOTOS=true --dart-define=PADDLE_OCR=true --dart-define=PADDLE_RECOGNIZER=v6
# Repeat with PADDLE_RECOGNIZER=latin.
```

Add `PHOTO_MAX_DIMENSION=2048` as a Dart define for gallery-sized copies.
`CAPTURE_LABEL_OCR=true` logs development OCR geometry; leave it off in releases.
For an interactive experimental app, use the same Gradle environment switch and
Dart defines with `flutter run`.

## Evaluation

The seven supplied photos are development fixtures, not a holdout set. A pass
requires all tracked nutrient values, per-100 basis, fiber presence and `<`
qualifiers to match. It does not merely mean the recognizer returned text.
Physical-device camera performance and fresh products still need evaluation.

| Experiment on API 37 ARM64 emulator | Result |
| --- | --- |
| Initial ML Kit baseline, before shared parser fixes | 2/7 originals |
| Earlier v6 with Dart preprocessing | 7/7 originals and 7/7 resized copies |
| Later v6 rerun in a slower session | 3/7 originals; preprocessing/OCR timeouts |
| Latin with shared parser fixes, Dart preprocessing | 4/7 originals |
| Native quality checks and crops, before final label correction | 6/7 originals |

The native-preprocessing run took 2.2–3.0 seconds, but subsequent runs took
26–33 seconds or hit the 38-second overall timeout. Emulator timings are not
stable enough to support a device-performance claim. A final native rerun was
stopped after the first timeout. Do not interpret the earlier 14/14 as a final
ship-readiness result.

The remaining native-crop accuracy failure was soy: a complete reading had
72 g carbs, while readings with 7.2 g had a damaged protein label (`Eimeit`).
The final parser change recovers uniquely matching alphabetic row names while
leaving numbers intact. Captured native observations remain in the regression
corpus, including the incorrect candidate. Final fixture checks are recorded
below; they cannot establish native timing reliability.

Latin misread yogurt gram units as trailing digits (4.59, 5.29, 3.59), returned
6.58 fiber for beans, and failed on the energy drink. Plausibility checks alone
accepted some incorrect readings. The final selection policy now requires
review when gram-unit evidence is missing, even if values are repeated.

Timed-out/disposed attempts stop scheduling further recognition. Work already
executing cannot be interrupted by a Dart timeout; late crop files are cleaned
up when it completes. Native inference remains serialized. The emulator uses
16 KB memory pages and the libraries loaded successfully there.

The experiment remains opt-in. Production promotion needs stable device
latency, held-out product accuracy, model delivery and size decisions. Model
files alone occupy about 39.2 MB for both recognizers plus the detector; the
runtime and OpenCV add native libraries too.

## Build and regression verification (2026-10-12)

- Flutter: 490 tests passed, two skipped. Includes seven additional native-crop
  capture cases, cancellation and missing-unit review regressions.
- Targeted Dart analysis: no issues. Native CTC decoder: two JUnit tests passed.
- Experimental ARM64 release APK: **105.04 MB**, with separate Dart symbols.
  Bundles both downloaded recognizers; selecting v6 only changes inference.
  The model entries occupy 33.43 MB compressed, ONNX native libraries 17.98 MB,
  and OpenCV 23.47 MB. APK size is not Play download size or installed storage.
- Test artifact: `build/experiments/sophis-paddle-v6-arm64.apk`. It uses the
  repository's existing debug signing configuration and is for local testing.
  Installation and cold launch succeeded on the emulator; this is a launch
  smoke check, not a release-mode photo-scanning benchmark.
- The normal 35 MB budget remains unchanged. Its checker now also rejects
  Paddle model assets and ONNX/OpenCV native libraries. It correctly rejects
  this experimental APK.

Normal ARM64 release: **28.77 MB** (separate Dart symbols), within the unchanged
35 MB budget. The size/architecture/dependency check passed. The experiment
adds approximately 76.3 MB when both recognizers are bundled.
