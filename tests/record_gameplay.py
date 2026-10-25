"""Record the real Godot window and run the keyboard-driven rendered smoke test.

Needs a working DISPLAY and FFmpeg. Example after starting Xvfb:
DISPLAY=:99 python3 tests/record_gameplay.py
No staged frames or replacement gameplay logic are used.
"""
import os
from pathlib import Path
import signal
import subprocess

root = Path(__file__).resolve().parent.parent
artifacts = root / "artifacts"
artifacts.mkdir(exist_ok=True)
for name in ("01-title", "02-arena", "03-target-selection", "04-blocked-hit", "05-wave-two", "06-victory"):
    (artifacts / f"{name}.png").unlink(missing_ok=True)
(artifacts / "render-playtest.json").unlink(missing_ok=True)
env = os.environ.copy()
env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
with (artifacts / "recording.log").open("w") as recording, (artifacts / "render.log").open("w") as log:
    capture = subprocess.Popen([
        "ffmpeg", "-y", "-f", "x11grab", "-video_size", "1280x800", "-framerate", "30",
        "-i", env["DISPLAY"], "-an", "-c:v", "libx264", "-preset", "ultrafast",
        "-crf", "23", "-pix_fmt", "yuv420p", str(artifacts / "gameplay.mp4"),
    ], env=env, stdout=recording, stderr=subprocess.STDOUT)
    game = subprocess.Popen([
        "bash", str(root / "scripts/godot.sh"), "--rendering-method", "gl_compatibility",
        "--audio-driver", "Dummy", "--position", "0,0", "--", "--playtest",
    ], env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = game.wait(timeout=80)
    except subprocess.TimeoutExpired:
        game.terminate()
        game.wait(timeout=10)
        code = 124
    finally:
        capture.send_signal(signal.SIGINT)
        capture.wait(timeout=20)
print((artifacts / "render.log").read_text())
if code == 0:
    import json
    result = json.loads((artifacts / "render-playtest.json").read_text())
    if not result["passed"]:
        code = 1
raise SystemExit(code)
