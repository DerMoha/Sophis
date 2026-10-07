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
