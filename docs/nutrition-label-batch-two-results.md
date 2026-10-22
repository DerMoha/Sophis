# Nutrition scanning: independent photo batch 2

Historical baseline before the rewrite. See [the rewrite report](nutrition-label-rewrite-results.md) for current results.

Evaluated on 2026-10-11, after the first-batch fixes and before any tuning to
these photos. Five original 3072 × 4096 photos cover four additional products.
Actual ML Kit OCR and the existing local `LabelIntakeFlow` ran on the iPhone 18
Pro / iOS 27 simulator. Cloud assistance was disabled. Production scanner code
was not changed during this evaluation.

## Result: 0 of 5 complete scans

All five reached text recognition, preprocessing and value verification, then
returned `Failure<LabelIntakeResult>`. None returned a complete high-confidence
result. This does not validate the UI fallback: partial draft/review and meal
logging were not exercised, and several intermediate partial values were wrong.
The scanner remains below the release gate.

| Photo suffix | Product | Expected kcal / protein / carbs / fat / fiber | Basis | Result |
| --- | --- | --- | --- | --- |
| 171032 | Chocolate soy drink | 64 / 5 / 7.2 / 1.7 / <0.5 | 100 ml | No complete result |
| 171031 | Same soy drink, more glare | 64 / 5 / 7.2 / 1.7 / <0.5 | 100 ml | No complete result |
| 171019 | Yogurt | 70 / 4.5 / 5.2 / 3.5 / 0 | 100 g | No complete result |
| 171017 | Kidney beans | 95 / 6.9 / 12 / 0.7 / 6.5 | 100 g drained | No complete result |
| 171024 | Energy drink | 47 / 0 / 12 / 0 / not listed | 100 ml | No complete result |

All nutrient quantities in the table are grams. Soy drink serving size is
250 ml. The less-than qualifier and absent fiber are part of the expected
semantics, not interchangeable with exact 0.5 g and a printed zero.

## Diagnostic observations

Captured native OCR for each original and both enhanced variants (15 outputs).
Replaying those outputs through the parser showed:

- Soy drink: missing fat, incorrect row associations, and lost decimal marks.
  One enhanced reading yielded 72 g carbs; another attached 0.5 g to protein.
  There are two per-100 ml headings (nutrition and vitamins), plus nutrition
  vocabulary outside the table. Table-region selection needs investigation.
- Yogurt: original OCR read `3,5 g` as `35g`, `5,2 g` as `529`, and `4,5 g`
  as `459`. An enhanced variant yielded 45 g protein. Required fields were
  missing and calorie consistency failed, so no full result was accepted.
- Beans: OCR saw both `399 kJ` and `95 kcal` on different lines. The parser
  sometimes converted kJ to 95.361 kcal instead of selecting printed 95 kcal.
  Several g units became 8, e.g. `6,5 8`, and required macros were lost.
- Energy drink: all three captured variants parsed to null. OCR damaged
  nutrient names; text above the table also contains `30 mg/100ml` caffeine,
  which can compete with the actual per-100 ml nutrition heading.

These observations identify failure classes; they are not proof that a specific
future fix will resolve every photo. Do not insert missing decimal points or
change 8/9 to g without sufficient evidence: those can also be real digits.

## Follow-up priorities

1. Restrict header/row geometry to the actual nutrition table, excluding
   ingredients, caffeine declarations, vitamin tables and reference footers.
2. Preserve number/unit tokens and uncertainty; resolve OCR alternatives using
   independent evidence instead of silently repairing ambiguous numbers.
3. Support multiline energy rows and wrapped nutrient names.
4. Verify partial-draft behavior, bounds such as `<0.5`, and missing values.
5. Retest all seven photos after fixes, then use a fresh independent batch.
   Once used for tuning, these five become development cases, not holdout data.

## Reproduce

Place only these five originals in `/tmp/sophis-label-batch-two`, then run:

```sh
python3 -m http.server 8769 --bind 127.0.0.1 --directory /tmp/sophis-label-batch-two
flutter test integration_test/nutrition_label_batch_two_test.dart -d <simulator-id> --dart-define=REAL_LABEL_PHOTOS=true --dart-define=CAPTURE_LABEL_OCR=true
```

The opt-in tests intentionally assert the printed values and failed against the baseline implementation.
Numeric matching of soy fiber to 0.5 alone is not a complete semantic pass;
the baseline result model did not preserve its less-than qualifier.
