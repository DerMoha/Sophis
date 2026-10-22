#!/usr/bin/env python3
"""Download pinned, checksum-verified models for the opt-in Android OCR build."""
import argparse
import hashlib
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / 'android/paddle_ocr/src/main/assets/models'
MODELS = {
    'det': ('PP-OCRv6_small_det_onnx', '28fe5895c24fd108c19eb3e8479f4ab385fbfc62',
            'd73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e'),
    'v6': ('PP-OCRv6_small_rec_onnx', 'b8f84f0b80c529de40b4fbb3544b84fa7233a513',
           '5435fd747c9e0efe15a96d0b378d5bd157e9492ed8fd80edf08f30d02fa24634'),
    'latin': ('latin_PP-OCRv5_mobile_rec_onnx', '89d3a50e2c27e2e7cceeab0e944c25c807d5db4f',
              '7888113072263cb471b93f66dd5e2ad70548dc526fa1ace760d0d973dd121498'),
}

CONFIG_SHA256 = {
    'det': '193f435274bf9f0b5f71a929bbfbcf148282df7e633b34e7c373e8f44741b516',
    'v6': 'ab078671bb49f06228eadccd34f1bb501e157f7a047095ffb943ba81512c77d1',
    'latin': '0bbe984570f597af3638e50bdf2e8276f3ab26a61966096538b3b0d1849f5c84',
}

def download(key: str, directory: str) -> None:
    model, revision, checksum = MODELS[key]
    for name in ['inference.onnx', 'inference.yml']:
        expected_hash = checksum if name == 'inference.onnx' else CONFIG_SHA256[key]
        target = ROOT / directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected_hash:
            print(f'Already prepared: {directory}/{name}')
            continue
        url = f'https://huggingface.co/PaddlePaddle/{model}/resolve/{revision}/{name}'
        temporary = target.with_suffix(target.suffix + '.part')
        try:
            with urllib.request.urlopen(url, timeout=120) as response, temporary.open('wb') as out:
                while chunk := response.read(1024 * 1024):
                    out.write(chunk)
            if hashlib.sha256(temporary.read_bytes()).hexdigest() != expected_hash:
                raise RuntimeError(f'Checksum mismatch: {model}')
            temporary.replace(target)
            print(f'Prepared {directory}/{name}: {target.stat().st_size:,} bytes')
        finally:
            temporary.unlink(missing_ok=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recognizer', choices=['v6', 'latin', 'both'], default='both')
    args = parser.parse_args()
    download('det', 'det')
    for recognizer in ['v6', 'latin'] if args.recognizer == 'both' else [args.recognizer]:
        download(recognizer, recognizer)
