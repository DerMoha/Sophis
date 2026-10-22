# Experimental PaddleOCR runtime

Vendored from PaddlePaddle/PaddleOCR at
`dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf`, path
`deploy/ppocr-android/ppocr-sdk/src/main` (Apache-2.0; see LICENSE).
Only compiled when `ORG_GRADLE_PROJECT_paddleOcr=true`.

Sophis modifications: standalone Gradle configuration; recognition character
alignment carried through the decoder and results for nutrition-table geometry;
BGR recognition preprocessing to match the pinned model configurations; official
OpenCV 4.12.0 dependency for compatibility with the Android emulator. The app
bridge also uses OpenCV for quality checks and crop variants.
See `docs/android-paddle-ocr-experiment.md` for setup and evaluation.
