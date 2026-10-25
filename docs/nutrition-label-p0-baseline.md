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

## P2 — table reader (2026-10-25): 20/20 fields, 4/4 complete scans

iOS 26+ `RecognizeDocumentsRequest` now runs first and returns rows of cells.
`NutritionTableMapper` maps each row label to its per-100 value. The
line-based pipeline only runs when the table reading is incomplete or fails
validation.

| Photo | Baseline | P2 | Path taken |
| --- | --- | --- | --- |
| Energy drink bottle | 5/5, 7.3 s | 5/5, 8.4 s | Table unreadable (rows merged on the curved bottle), so the old pipeline ran |
| Skyr tub | 4/5 (carbs missing), 6.5 s | **5/5, 1.0 s** | Table |
| Soy drink carton | 5/5, 5.6 s | 5/5, **1.5 s** | Table (the `<0,5` fiber still goes to review) |
| Kidney beans can | 5/5, 1.0 s | 5/5, 1.8 s | No table found (no grid lines), so the old pipeline ran |

What real Vision output looks like (captured with
`--dart-define=DUMP_LABEL_TABLES=true`):

- Label and value often share one cell (`"Energie\n270 kJ/64 kcal"`). The
  value inside the label cell wins over the header column.
- On curved packs, rows can shift: the skyr tub keeps kcal in the label cell
  but every other per-100 value at the top of the next column.
- When OCR garbles a nutrient name (`Eiwejß]`) or merges rows, the mapper
  leaves the field absent. The validator then sends the photo to the old
  pipeline, which is the safe direction.
- A table without ruling lines (the beans can) is not detected as a table.

Same caveat as above: these four products were used for earlier tuning, so this
is not yet an independent score.

## Independent set: 9 new products (2026-10-25)

These nine photos were never used for tuning. They were picked to be hard:
two are sideways, two are light text on a dark background, three are curved
jars, one has the label column cut off, and one labels its rows in seven
languages.

| Photo | First run (P2) | After fixes | Remaining problem |
| --- | --- | --- | --- |
| Protein bar, sideways, blurred | 0/5 | 0/5 | No table or usable lines found in any orientation |
| Dark chocolate, ruled table | 5/5 | 5/5 | — |
| Grated cheese, sideways, 4 columns | 4/5 | **5/5** | Serving (50 g) missed: OCR read "Potion" |
| Jam jar, values one row below labels | 2/5 | 3/5 | Fat and protein row names lost by OCR |
| Pasta sauce, 7-language labels | 0/5 | 0/5 | No table detected; the line parser can't pair multilingual rows |
| Raspberry granola, dark, no grid | 5/5 | 5/5 | — |
| Basmati rice, two columns, offset | 5/5 | 5/5 | — |
| Mie noodles, labels cut off | 1/5 | 4/5 | Fat row name fully cut off |
| Chocolate granola, thin text | 5/5 | 5/5 | — |
| **Total** | **27/45, 4/9 complete** | **32/45, 5/9 complete** | |

All 13 photos together: **52/65 fields, 9/13 complete scans.** The original
four stay at 20/20.

**No wrong values in either run.** Every miss is a missing field. The review
screen then asks for it instead of logging a wrong number.

Fixes in this round:

- Row names match on distinctive fragments, so names that OCR clips or garbles
  still count (`rergie`, `ehlenhydrate`, `ciweiß`). Sub-row fragments
  (`avon`, `gesatt`, `saur`) are still excluded.
- `Brennwert kJ/kcal | 918/216`: when the units sit in the label cell, the
  second number is read as kcal.
- Table reading retries the photo turned a quarter each way when no table is
  found. That fixed the sideways cheese bag, but not the blurred bar.

What's left fits the next phases:

- **Pasta sauce, jam:** the text is all there, but the pairing is broken.
  This is the job P3 (Apple's on-device model over the OCR text) is planned
  for.
- **Protein bar:** a blurred single shot. Live scanning (P4), which reads many
  frames, is the fix.
- **Speed:** photos that fall back to the line parser still take 8–20 s; table
  hits take 2–3 s.

## P3 — on-device model (2026-10-25): 53/65 fields, 0 wrong, 10/13 complete

When the table and line readers both fail, Apple's on-device model
(`FoundationModels`, iOS 26+ with Apple Intelligence) reads the OCR text and
returns per-100 values as structured output with greedy decoding. It ran in
the iOS 27 simulator. Nothing leaves the device.

The first version scored higher, **56/65**, but **5 of its values were
wrong**: protein 0 and fiber 0 on a jam that prints neither as zero, the
protein bar's salt as its fat, and 17 g carbs on the pasta sauce. A bare
digit is not proof, because "0" and "1" appear on every package. The
shipped version is stricter:

- Every number must appear with its unit (`5,0 g`, `g 5,0`, `87 kcal`,
  `kcal 87`, or `918/216` after `kJ/kcal`).
- Fiber is only accepted when a fiber word is printed.
- A model reading is used only when it is complete and the energy matches
  the macros. It is always marked for review (`modelReading`).
- Partial model readings never prefill the review screen. An empty field is
  safer than a wrong one.

| Photo | P2 fixes | P3 | |
| --- | --- | --- | --- |
| Mie noodles, labels cut off | 4/5 draft | **5/5 complete** | Model paired the fat row the table lost |
| Jam jar | 3/5 draft | 3/5 draft | Model's reading failed the checks and was rejected |
| Pasta sauce, 7 languages | 0/5 | 0/5 | Model's reading incomplete or inconsistent; rejected |
| Protein bar, blurred | 0/5 | 0/5 | — |
| All others | 5/5 | 5/5 | Unchanged; the model never ran |

The scoreboard now counts wrong values separately (`SCORE_SUMMARY ... wrong N`).
That count should stay at 0 for every future change.

Takeaway: the model helps only at the edges. The remaining failures are
caused by the input itself: a blurred single shot and a jar the camera saw
at an angle. That points to **P4, live scanning**, as the next step.
