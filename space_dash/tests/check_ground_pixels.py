"""Verify the solid ground in the actual grass-Off frame, without blade occlusion.

Also verifies all three historical PNGs remain unchanged as source reference.
Needs Pillow for pixel inspection only.
"""
from pathlib import Path
import argparse, json, hashlib
from PIL import Image
root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--image', type=Path, default=root/'artifacts/v0.4.3-scenery/off.png')
args = parser.parse_args()
frame = Image.open(args.image).convert('RGB')
assert frame.size == (960,540)
expected = (86,120,66)
samples = matched = 0
for y in range(110,450,5):
    for x in range(5,955,5):
        samples += 1
        if max(abs(a-b) for a,b in zip(frame.getpixel((x,y)),expected)) <= 1:
            matched += 1
hashes = {'env_grass_plain_00.png':'d317fd92267a6d5fde8e135034caf3471e5532a292f44edae678af441bf0a941',
          'env_grass_plain_01.png':'205f875be0ff4cc4b939a2c2fcf08f50537a384b9faa6ff93cfaff39c70e6982',
          'env_grass_plain_04.png':'cef5788e5d35ec1c7895f9567a95993b6d89b6ec19f759a1ff7679a32b77a2ee'}
for name, digest in hashes.items():
    assert hashlib.sha256((root/'assets/env_tiles'/name).read_bytes()).hexdigest() == digest
result = {'passed':matched/samples >= .8,'solid_rgb':expected,'samples':samples,'matched':matched,
          'fraction':matched/samples,'reference_png_hashes_preserved':True,
          'evidence':str(args.image),'overlay_tolerance':'word backplates and actors cover some pixels; grass is Off'}
args.image.with_name('solid-ground-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
raise SystemExit(0 if result['passed'] else 1)
