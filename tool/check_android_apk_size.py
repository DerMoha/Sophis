#!/usr/bin/env python3
"""Check the distribution APK budget and prevent bundled scanning regressions."""

import argparse
from pathlib import Path
import sys
import zipfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        'apk', nargs='?',
        default='build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    )
    parser.add_argument('--max-mb', type=float, default=35.0)
    args = parser.parse_args()
    path = Path(args.apk)
    if not path.is_file():
        parser.error(f'APK does not exist: {path}')
    size_mb = path.stat().st_size / 1_000_000
    problems = []
    if size_mb > args.max_mb:
        problems.append(f'exceeded {args.max_mb:.1f} MB budget')
    with zipfile.ZipFile(path) as apk:
        names = apk.namelist()
        architectures = {
            name.split('/')[1] for name in names if name.startswith('lib/')
        }
        if len(architectures) != 1:
            problems.append(f'expected one architecture, found {sorted(architectures)}')
        if any(
            marker in name for name in names for marker in (
                'libmlkit_google_ocr_pipeline.so', 'libbarhopper',
                'mlkit-google-ocr-models/', 'mlkit_barcode_models/',
                'libonnxruntime', 'libopencv_java', 'assets/models/',
            )
        ):
            problems.append('bundled scanning models or native pipelines found')
    print(f'{path}: {size_mb:.2f} MB')
    for problem in problems:
        print(f'FAIL: {problem}', file=sys.stderr)
    if not problems:
        print('PASS: size budget, architecture split, downloadable scanning')
    return int(bool(problems))


if __name__ == '__main__':
    sys.exit(main())
