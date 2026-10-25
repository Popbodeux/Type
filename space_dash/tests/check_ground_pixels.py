"""Check actual rendered terrain against the original PNGs, source hash, tint and2x sampling.

Allows overlaid actors/text by measuring match fractions over the clear playfield,
separately for each of the three variants. Needs Pillow only for this diagnostic.
"""
from pathlib import Path
import argparse
import json
import math
from PIL import Image

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--artifacts", type=Path, default=root / "artifacts")
args = parser.parse_args()
report = json.loads((args.artifacts / "render-playtest.json").read_text())
capture = report["captures"]["02-survival"]
assert capture["phase"] == "playing"
cam_x, cam_y = capture["camera"]
frame = Image.open(args.artifacts / "02-survival.png").convert("RGB")
tiles = [Image.open(root / "assets/env_tiles" / name).convert("RGB") for name in (
    "env_grass_plain_00.png", "env_grass_plain_01.png", "env_grass_plain_04.png",
)]
samples = [0, 0, 0]
matched = [0, 0, 0]
for screen_y in range(110, 450, 5):
    for screen_x in range(5, 955, 5):
        world_x = screen_x + cam_x - 480
        world_y = screen_y + cam_y - 270
        cell_x, cell_y = math.floor(world_x / 32), math.floor(world_y / 32)
        h = abs(cell_x * 928371 + cell_y * 52377) % 100
        index = 1 + h % 2 if h >= 86 else 0
        pixel_x = math.floor((world_x - cell_x * 32) / 2)
        pixel_y = math.floor((world_y - cell_y * 32) / 2)
        original = tiles[index].getpixel((pixel_x, pixel_y))
        expected = tuple(round(color * tint / 255) for color, tint in zip(original, (178, 236, 136)))
        observed = frame.getpixel((screen_x, screen_y))
        samples[index] += 1
        if max(abs(a - b) for a, b in zip(expected, observed)) <= 2:
            matched[index] += 1
fractions = [good / count if count else 0 for good, count in zip(matched, samples)]
result = {"passed": min(fractions) >= 0.8, "samples_by_variant": samples,
          "matched_by_variant": matched, "matched_fraction_by_variant": fractions,
          "tint_rgb": [178, 236, 136], "source_pixels_per_world_tile": [16, 16],
          "world_tile_size": 32, "overlay_tolerance": "actors/text may cover samples",
          "evidence": "actual rendered02-survival.png and capture camera metadata"}
(args.artifacts / "ground-pixel-verification.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
raise SystemExit(0 if result["passed"] else 1)
