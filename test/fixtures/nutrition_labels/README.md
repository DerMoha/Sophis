# Nutrition label regression corpus

Add anonymized captures as OCR fixtures in `manifest.json`. Each case records
the OCR text produced by a real label photo and its manually verified per-100g
values. Remove product names, barcodes, and unrelated package copy before
committing a fixture.

When a scan has multiple columns, include `lines` with token center positions.
The data-driven test will automatically use layout parsing for those cases.
