# Real nutrition label photo test

## Scope

Tested on 2026-10-11 using the iPhone 18 Pro / iOS 27 simulator,
actual ML Kit OCR and `LabelIntakeFlow`, with cloud assistance disabled.
Original 3072 × 4096 photos were used without manual cropping.
This tests image analysis, not gallery UI, camera capture or meal logging.

Both photos show the same label. Expected per 100 g:
62 kcal, 11 g protein, 4 g carbohydrate, 0.2 g fat, 0 g fiber.
Printed serving size: 125 g.

## Original failures

| Photo | kcal | Protein | Carbs | Fat | Fiber | High confidence |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| MVIMG_20261011_091005.jpg | 78 | 0 | 0.1 | 48 | 0 | false |
| MVIMG_20261011_090958.jpg | 78 | 11 | 4 | 0.2 | 0 | true |

The straighter photo mixed portion calories with per-100 g macros without a
warning. The angled photo reported calorie/macro mismatch and candidate
disagreement.

## Verified after correction

Both original photos pass the native simulator assertions:
62 kcal, 11 g protein, 4 g carbs, 0.2 g fat, 0 g fiber per 100 g,
and serving size 125 g. Both retain a candidate-disagreement warning because
some enhanced/native OCR variants still disagree on digits. No AI was used.

Validation: 2 native photo tests and 87 related service/widget tests pass;
targeted static analysis reports no issues. Gallery resizing/compression,
camera UI and physical-device accuracy remain outside this run's scope.

## Corrections

- Recognize bare and average-symbol per-100 headings, including OCR's `o/100 g`.
- Select a column before reconstructing nutrient rows. Keep split numbers and
  units together, excluding reference-intake percentages and footer energy.
- Use token coordinates to account for tilted rows. Bound row matching and
  leave missing/ambiguous values absent instead of borrowing distant values.
- Compare every field and its presence across OCR candidates. Do not average
  conflicting values into a number that was never printed.
- Rank complete, plausible nutrition readings rather than the quantity of
  surrounding package text; prefer the original capture on ties.
- Keep uncertain readings marked for review. Multiple disagreeing readings
  cannot silently become high confidence, even if the selected reading is
  numerically plausible.
- Tighten calorie/macro consistency checks for low-energy products. This is a
  warning heuristic, not an alternative source of nutrition values; polyols,
  alcohol and label conventions can legitimately differ.
- Keep draft recovery based on layout, so it does not reintroduce unsafe OCR
  text ordering after a layout failure.

Six anonymized native OCR variants are saved in
`test/fixtures/nutrition_labels/curved_two_column_ocr.json`. Regression tests
cover correct extraction, degraded variants, selection without averaging,
coordinate scaling, reversed OCR block order and a missing nutrient value.
Original photos remain outside the repository.

## Release gate — not yet satisfied

Passing these two photos does not establish general accuracy. Before release:

1. Collect a separate evaluation set, initially at least 100 photos across at
   least 30 distinct products; keep it out of parser tuning. Include g/ml,
   serving-only and reversed columns, decimal commas, small print, flat/curved
   packs, languages we claim to support, glare, blur and rotation.
2. Manually verify column basis, all required nutrients, optional-field
   presence and serving size. Record native OCR, selected values, confidence,
   corrections/abstentions and timing separately.
3. Require zero unflagged wrong results in that evaluation set. A proposed
   initial usability target is at least 95% complete correct local extraction
   on clear, supported labels. Report difficult-photo results separately.
   These are release targets, not achieved measurements or guarantees.
4. Run on physical iOS and Android devices, using actual gallery import and
   camera capture. Exercise first-use model downloads/offline behavior and
   manual/cloud fallback separately; cloud must not hide local failures.
5. Any silent wrong result blocks release and becomes a regression case.
   Expand the independent evaluation set after fixes; do not call the same
   development photos independent validation.

## Rerun

Keep original photos outside the repository. Serve a directory containing only
these two photos on the host:

```sh
python3 -m http.server 8769 --bind 127.0.0.1 --directory /tmp/sophis-label-photos
```

Run against a booted iOS simulator:

```sh
flutter test integration_test/nutrition_label_photos_test.dart -d <simulator-id> --dart-define=REAL_LABEL_PHOTOS=true
```

Add `--dart-define=CAPTURE_LABEL_OCR=true` to print raw OCR geometry for diagnosis.
The test is opt-in because it requires the external photos and local server.
The native assertions check all five values, serving size, and retained
uncertainty. Photos are also imported into the current simulator's photo library
for manual follow-up.

## Independent batch follow-up

The five-photo second batch produced **0/5 complete scans** without further
scanner changes. See [batch-two results](nutrition-label-batch-two-results.md)
for printed ground truth, OCR failure evidence and next priorities. The original
two passing examples did not generalize to these four additional products.
