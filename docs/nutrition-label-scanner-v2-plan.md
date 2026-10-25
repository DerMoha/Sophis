# Nutrition label scanner v2 — plan (2026-10-25)

Goal: point the phone at a label and get the values logged with as few steps
as possible. Accuracy comes from reading many camera frames and using Apple's
table structure. Hand-tuned guessing from a single photo goes away.

## Today vs. target

| Step | Today | Target |
| --- | --- | --- |
| Capture | One shutter photo. It must be sharp, glare-free and straight | Live camera reads continuously and captures by itself once the values are stable |
| Reading | Vision text lines, then preprocessed crops read again | Live text per frame, plus one high-resolution still read with `RecognizeDocumentsRequest` (tables) |
| Interpretation | About 700 lines of geometry and regex in `nutrition_label_parser.dart` | Table rows mapped directly, then the on-device Apple model when needed, then the current parser as fallback |
| Cloud | A consent pop-up on every uncertain scan | One setting, off by default, no pop-ups |
| After scan | Preview sheet, save dialog (removed already), portion picker | One review screen: values, portion and **Log** |

## User flow (target)

1. Add food → **Nährwerte**. The native scanner opens straight away.
2. The live view shows a checklist strip: kcal · Fett · Kohlenhydrate · Eiweiß
   (plus Zucker, Ballaststoffe and Salz when found). Each item turns green with
   its value once it is stable.
3. When the four required values are stable, the phone gives a haptic tap and
   captures by itself. A shutter button stays available as a manual fallback,
   and so does the gallery.
4. The review screen opens:
   - Product name (prefilled when found), basis toggle `100 g` / `100 ml`, and
     editable value rows. A row the scan was unsure about is highlighted.
   - The portion slider (the existing component) and one **Log** button.
   - Logging also saves the food as a custom food (dedupe already exists).
5. Done. The app returns to where the user started.

If values never stabilise (about 8 s): the hint changes to "Hold still / move
closer / avoid glare". After about 15 s it offers "Take photo anyway" and
"Enter manually".

## Architecture

```
Flutter                         iOS native (Swift)
───────                         ──────────────────
NutritionLabelScannerScreen ──► sophis/label_scanner  "scan"
                                 ├─ LiveLabelScannerViewController
                                 │    DataScannerViewController (.text)
                                 │    LiveRowParser → FieldStabilizer
                                 │    capturePhoto() on lock
                                 ├─ DocumentTableReader (iOS 26+)
                                 │    RecognizeDocumentsRequest → rows
                                 └─ LabelInterpreter (iOS 26+, AI device)
                                      FoundationModels @Generable
◄── ScanResult JSON ─────────────┘
LabelScanResolver (Dart)
  validate (NutritionLabelValidator) → optional Gemini (setting)
LabelReviewScreen → log + save custom food
```

### Native result contract (`ScanResult`)

```json
{
  "status": "ok | cancelled | manual | unsupported",
  "imagePath": "/tmp/…jpg",
  "basis": "g | ml | unknown",
  "productName": "string?",
  "fields": {
    "kcal":    { "value": 64.0, "source": "table|live|model", "agreement": 0.9 },
    "fat":     { "value": 1.7, "lessThan": false, "source": "table" },
    "carbs": {}, "sugar": {}, "protein": {}, "fiber": {}, "salt": {}
  },
  "rows": [["Energie", "268 kJ / 64 kcal", "…"]],
  "ocrText": "full text for fallbacks"
}
```

`rows` and `ocrText` are always returned, so the Dart fallbacks (the current
parser and Gemini) work without re-reading the image.

### Interpretation tiers (first success wins, all validated)

1. **Table mapper (deterministic):** find the per-100 column from the header
   cells (`100 g`, `100 ml`, `pro 100`, `per 100`). Map row labels through a
   DE/EN keyword dictionary (Brennwert/Energie, Fett, davon gesättigte,
   Kohlenhydrate, davon Zucker, Ballaststoffe, Eiweiß/Protein, Salz). Prefer
   printed kcal over kJ conversion. Keep `<` qualifiers.
2. **On-device Apple model:** used only when tier 1 misses a required field or
   is ambiguous, and only when `SystemLanguageModel.default.availability ==
   .available`. Input is the table rows as tab-separated text plus `ocrText`.
   Output is a `@Generable struct NutritionFacts` with optional fields and a
   basis. **Hallucination guard:** every number returned must appear in the
   OCR text, allowing for a comma or point as decimal separator and the kJ→kcal
   conversion. Otherwise that field is dropped.
3. **Current Dart parser:** for iOS < 26, unsupported devices, and Android.
4. **Gemini:** only when the new setting is on and a required field is still
   missing. No dialog.
5. **Manual:** the review screen with the missing fields empty and focused.

`NutritionLabelValidator` runs after every tier. The energy-vs-macros check is
4/4/9 within tolerance. A failed check marks the rows for review; it never
blocks logging.

### Live stabilisation

- DataScanner emits recognised text items with bounds. Throttle to about 4 Hz.
- `LiveRowParser` groups items into rows by vertical overlap. Each label row
  takes the number in the per-100 column (once that header has been seen).
  Before the header is seen, it takes the first number.
- `FieldStabilizer`: a field locks when the same value appears in 3 of the
  last 5 readings. A new value that wins 4 of 5 replaces it. The lock state
  drives the checklist strip.
- When the required four lock: `capturePhoto()`, then the table read. If the
  table result disagrees with a live lock, the table value wins only when it
  passes validation. Either way the row is flagged for review.

## Availability matrix

| Device | Live scan | Table reader | Apple model | Fallback |
| --- | --- | --- | --- | --- |
| iOS 26+, Apple Intelligence on | ✅ | ✅ | ✅ | — |
| iOS 26+, no Apple Intelligence | ✅ | ✅ | ❌ | current parser |
| iOS 17–25 | ✅ (DataScanner iOS 16+) | ❌ | ❌ | current parser on stills |
| Simulator | ❌ (DataScanner unsupported) | ✅ (gallery) | depends on host Mac | photo camera / gallery |
| Android | unchanged photo flow | — | — | current parser |

## Phases (each one can ship on its own)

**P0 — Baseline (about 1 day)**
- Collect 20–30 real label photos, including the ones that fail today.
  Record the expected values in `test/fixtures/nutrition_labels/manifest.json`.
- Add a debug-only harness that runs a folder of photos through the pipeline
  on the simulator and prints per-field accuracy. This is the scoreboard for
  every later phase.

**P1 — Review screen + cloud setting (Dart only)**
- `LabelReviewScreen` replaces the preview sheet, draft sheet and portion
  picker hop for label scans.
- Settings → AI: "Cloud help for nutrition labels" (default off), with the
  disclosure text moved there. Delete `_confirmCloudAssist` and its strings.
- This is a UX win immediately, even with the current reader.

**P2 — Table reader on stills (iOS 26+)**
- Swift `DocumentTableReader` behind the existing `sophis/nutrition_text`
  channel (new method `recognizeDocument`). Dart table mapper as tier 1.
- Compare against the P0 baseline. Ship if it's better.

**P3 — On-device interpreter**
- Swift `LabelInterpreter` with the hallucination guard, plus channel method
  `interpret`.
- Unit tests in Dart for the guard logic, using mocked channel responses.
  Native tests in a small XCTest target using the fixture rows.

**P4 — Live auto-capture**
- `LiveLabelScannerViewController`, presented natively, returning `ScanResult`.
  The Flutter `NutritionLabelCameraScreen` stays as the fallback when
  DataScanner is unsupported.
- Haptic feedback on lock, checklist strip, timeout hints.
- Can only be tested on a real device.

**P5 — Cleanup**
- On iOS 26+, skip `NutritionImagePreprocessor` candidates and the quality
  pre-check (the live view replaces them).
- Keep the parser for Android and older iOS. Update
  `docs/streamlined-food-flow.md` (its "Scan product chooser" section is
  already outdated).

## Risks

- **Small or curved print:** the live view helps (the user moves closer), but
  can't fully fix it. The review screen is the safety net.
- **Apple model availability:** it's limited to newer iPhones with Apple
  Intelligence on and a supported language. It's tier 2 by design, never
  required.
- **Model invents numbers:** the hallucination guard plus the validator. Values
  the model reports are always shown as "check".
- **Two camera implementations on iOS:** acceptable while the fallback screen
  exists. Revisit when the minimum iOS version is raised.

## Open questions

1. Which iPhone and iOS version do you use day to day? This decides whether P3
   helps you directly.
2. When scanning fails today, does it find nothing, or fill in wrong numbers?
3. Can you share 10+ photos of labels it got wrong (for P0)?
4. Should Android get live scanning too, or stay on the photo flow for now?
