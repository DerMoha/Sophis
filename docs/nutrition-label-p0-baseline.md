# Nutrition label scanner — P0 baseline (2026-10-25)

This is the first scoreboard run for [the v2 plan](nutrition-label-scanner-v2-plan.md).
It used the current pipeline with no changes: Apple Vision OCR, preprocessing,
the parser and the validator. Cloud help was off.

## Setup

- Four everyday photos of different packages: a bottle, a tub, a carton and a
  can. Each is 1500 × 2000 JPEG, compressed as phones share them. The photos
  stay local in `test/fixtures/nutrition_labels/photos/` (gitignored). The
  expected values are in the committed `manifest.json` in that folder.
- Harness: `integration_test/nutrition_label_accuracy_test.dart` on the
  iPhone 18 Pro / iOS 27 simulator (command in the file header). For each
  photo it scores what the review screen would show: the full result, or the
  partial draft when the flow fails.

## Result: 19/20 fields, 3/4 complete scans

| Photo | Complete | kcal | Protein | Carbs | Fat | Fiber | Basis / serving | Time |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Energy drink bottle | ✅ high confidence | ✅ 47 | ✅ 0 | ✅ 12 | ✅ 0 | ✅ absent | ✅ ml | 7.3 s |
| Skyr tub (two columns, offset rows) | ❌ draft only | ✅ 62 | ✅ 11 | ❌ missing | ✅ 0.2 | ✅ 0 | ✅ g / 125 g | 6.5 s |
| Soy drink carton (two columns) | ✅ needs review (<0.5) | ✅ 64 | ✅ 5 | ✅ 7.2 | ✅ 1.7 | ✅ <0.5 | ✅ ml / 250 ml | 5.6 s |
| Kidney beans can | ✅ high confidence | ✅ 95 | ✅ 6.9 | ✅ 12 | ✅ 0.7 | ✅ 6.5 | ✅ g | 1.0 s |

## What this does and doesn't tell us

- **These are not independent photos.** The same four products were part of
  the October development set that the parser was tuned against. The result
  shows that the tuning holds on recompressed, smaller copies. It does not show
  how the scanner does on new packaging. P0 needs **new products** that were
  never used for tuning before the score means much.
- **Still photos work well; speed is weak.** 5–7 s per scan, mostly spent on
  preprocessing and repeated OCR passes. The live scanner (P4) and the table
  reader (P2) should remove most of this.
- **The skyr miss is the known hard case:** labels and numbers are printed
  offset from each other, so row matching loses carbs. With P1, the review
  screen opens with carbs empty and marked as required, so the user isn't
  blocked.
- **The gap is probably the camera, not the parser.** All four photos were
  taken carefully. On device, the difference is the capture itself: a single
  shutter shot, blur, glare and the quality check. Measuring that needs photos
  taken with the in-app camera on a phone, which the simulator can't do.

## Next steps

1. Add 10+ new products to the photo folder and manifest. Include some taken
   with the in-app camera, saved via the debug OCR trace.
2. Re-run the harness after each phase (P2 table reader, P3 on-device model)
   and append the score here.
