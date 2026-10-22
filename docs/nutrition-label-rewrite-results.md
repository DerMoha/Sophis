# Nutrition scanner rewrite — 2026-10-11

The iOS reader now uses Apple's on-device Vision accurate text recognition,
with word geometry, instead of ML Kit by default. Android retains ML Kit. Both
readers feed the same table parser and candidate selection. No cloud service
or API key was used in this evaluation.

## What changed

- Locate the dense nutrient table before selecting its per-100 column. This
  excludes competing caffeine declarations and vitamin-table headers.
- Retry the detected table at a readable scale in color, grayscale and inverted
  grayscale. Keep the original reading available. Use full/center crops only
  when a table cannot be located.
- Associate numbers with row/column geometry, compensate for row tilt, and
  handle wrapped energy rows. Prefer printed kcal over converting printed kJ.
- Choose a complete observed candidate, prioritizing plausibility before repeat
  count. Do not average disagreeing numbers or invent missing decimal points.
  Disagreement remains a review warning. Correlated variants are not a calibrated
  probability of correctness.
- Preserve a `<` observed in any reading of the same numeric values. Review
  fields show the qualifier and require the user to enter an estimate. Missing
  fiber remains blank; it is not presented as a printed zero.
- Keep the chosen basis intact when falling back to an AI draft instead of
  combining fields from different interpretations.

## Development photo results

Actual native OCR plus `LabelIntakeFlow.processImage` ran on an iPhone 18 Pro /
iOS 27 simulator. All seven original 3072 × 4096 photos passed. The previous
ML Kit pipeline passed the first two but failed all five additional photos.

| Photo suffix | Expected kcal / protein / carbs / fat / fiber | Basis |
| --- | --- | --- |
| 091005, 090958 | 62 / 11 / 4 / 0.2 / 0 | 100 g |
| 171032, 171031 | 64 / 5 / 7.2 / 1.7 / <0.5 | 100 ml |
| 171019 | 70 / 4.5 / 5.2 / 3.5 / 0 | 100 g |
| 171017 | 95 / 6.9 / 12 / 0.7 / 6.5 | 100 g drained |
| 171024 | 47 / 0 / 12 / 0 / absent | 100 ml |

The original tub photos retain candidate-disagreement warnings. Soy fiber
requires review as an upper limit. Passing means the returned values and
qualifiers match the label; it does not mean every result is high confidence.
The app currently retains the 100 g basis for beans but does not model the
separate “drained weight” qualifier.

The additional 2048 px / JPEG quality 95 run approximates the gallery picker
settings using the Dart image encoder, not the actual platform picker. Its
first run caught a dropped `<` on the glare photo; this is now a regression
case with conservative qualifier preservation. The final native rerun passed
all seven resized photos, including bounds and missing-value assertions. Scan
time was 0.8–5.3 seconds on this simulator (excluding download and test-side
resizing). These timings are not physical-device benchmarks.

Validation: the complete Flutter suite passed 464 tests, with two skipped.
Fourteen captured-OCR regression cases cover the original and resized photos.
Widget tests cover explicit upper-limit review and preserving absent fiber.

## Reproduce

Place the seven original photographs in `/tmp/sophis-all-labels`, then run:

```sh
python3 -m http.server 8769 --bind 127.0.0.1 --directory /tmp/sophis-all-labels
flutter test integration_test/nutrition_label_photos_test.dart -d <simulator-id> --dart-define=REAL_LABEL_PHOTOS=true
flutter test integration_test/nutrition_label_photos_test.dart -d <simulator-id> --dart-define=REAL_LABEL_PHOTOS=true --dart-define=PHOTO_MAX_DIMENSION=2048
```

Optional `CAPTURE_LABEL_OCR=true` emits developer-only OCR text and geometry.
`USE_MLKIT_OCR=true` selects the old native reader for comparison. Do not enable
OCR logging in release builds. Photos stay outside the repository; sanitized
actual OCR outputs are in `test/fixtures/nutrition_labels/vision_photo_ocr.json`.

## Release limits

These seven photos were used during development, so they are regression cases,
not a holdout benchmark. This validates native image processing on Simulator,
not the live camera, autofocus, photo picker, or physical-device performance.
Android still needs a separate device evaluation: it does not receive Apple's
Vision reader. Before release, test a fresh product set on physical iOS and
Android devices, including other languages/layouts, poor focus, glare and
missing/ambiguous values. Track wrong accepted values separately from scans
that correctly request review.
