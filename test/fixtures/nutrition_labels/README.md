# Nutrition label regression corpus

Add anonymized captures as OCR fixtures in `manifest.json`. Each case records
the OCR text produced by a real label photo and its manually verified per-100
values. Include `unit: "milliliter"` when the label basis is volume and set
`fiberPresent: false` when fiber is absent. Remove product names, barcodes, and
unrelated package copy before committing a fixture.

When a scan has multiple columns, include `lines` with token center positions.
The data-driven test can be extended to use layout parsing for those cases.
Image fixtures for glare, blur, perspective, rotation, and camera framing
should only be committed after the capture has been anonymized and consented.

`curved_two_column_ocr.json` contains anonymized, actual ML Kit line/token
geometry from two photos of a curved German label, each read as the original,
enhanced full frame and enhanced crop. Incorrect OCR characters are deliberately
preserved. The fixture tests verify successful layout reconstruction and safe
candidate selection, rather than assuming every OCR variant is accurate.
The original photographs remain outside the repository. See
`docs/nutrition-label-photo-test.md` for the opt-in native simulator test.

`vision_photo_ocr.json` records actual Apple Vision line/word geometry from all
seven development photos, at original resolution and after resizing to 2048 px.
Product identity, barcode and unrelated copy have been removed; OCR errors and
coordinates remain intact. The tests resolve the candidate sets, assert every
tracked nutrient and basis, retain less-than qualifiers, and distinguish absent
fiber from zero. The corpus includes incorrect variants on purpose. These are
development regressions, not an independent accuracy benchmark.

`android_paddle_v6_ocr.json` captures actual Android v6 table observations,
including damaged nutrient names and g units read as trailing digits. Its
regressions verify selection using observed unit evidence without deleting
real digits or inventing decimal points. The corpus uses the same seven
development photos as the iOS tests.

Cases suffixed `_native` retain observations from native OpenCV crop variants,
including the soy row `Eimeit` and a conflicting `72 g` reading. All numeric
OCR errors remain unchanged in these regression fixtures.
