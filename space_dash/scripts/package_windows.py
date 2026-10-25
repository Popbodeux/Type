"""Cross-export the versioned standalone Windows playtest. Runtime is not tested by exporting."""
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
VERSION = "0.4.3"
bundle = root / f"artifacts/type-space-dash-v{VERSION}-windows-x86_64"
bundle.mkdir(parents=True, exist_ok=True)
subprocess.run([
    "bash", str(root / "scripts/godot.sh"), "--headless", "--export-release", "Windows",
    str(bundle / "TypeSpaceDash.exe"),
], check=True)
for name in ("GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"):
    shutil.copy2(root / "third_party" / name, bundle / name)
(bundle / "PLAY-ME.txt").write_text(f'''TYPE — GRASS / SPACE-TO-DASH SURVIVAL v{VERSION}

1. Extract this entire ZIP into a folder on your Windows desktop.
2. Double-click TypeSpaceDash.exe.
3. Keep TypeSpaceDash.pck next to TypeSpaceDash.exe.

Godot installation is NOT required to play. Windows x86_64 and OpenGL3.3
support are required. This prototype is unsigned.

Choose a difficulty with the mouse, then click NEW GAME.
Type an orb's exact case-sensitive word, then press SPACE to dash to it.
Backspace edits; Escape pauses/resumes. R or Enter restarts gameover.
Survive the draining30-second timer. Orbs/hits/kills add time;
wrong letters, blocked hits, and enemy contact remove time.
Typing while dashing or paused is queued for processing afterward.
Shift+Q is the original's debug shortcut to force gameover.

PLAYTEST REVISION:
Matching words use larger fixed-size lettering and a darker backplate. Only
correctly accepted prefix letters turn gold. Untouched orbs are 50% opaque;
matching candidates brighten as you type. Backspace updates this feedback.
Enemies acquire within 140 world pixels, disengage beyond 190, pursue at
65% and wander at 70% of their former base rates. No global alert chaining.
Eight original synthesized effects have a four-voice limit and cooldowns.
F10 toggles sound; Escape opens settings with mute and master volume.
F8 cycles grass Off/Low/High. Low is the default. Real chunked 3D alpha-cutout
cards sway behind the 2D gameplay; Off stops that extra rendering pass.

This reconstructs the selected older GameMaker snapshot from inspected source.
The old textured ground is replaced by one flat muted-green canvas fill.
Original tiles remain unchanged in source reference. Short dense 3D meadow clusters
have softer color patches and wind. A 15-degree oblique camera maps ground
roots to preserve 2D gameplay alignment. Low renders grass at 800x450 while actors
and labels stay native; High has more blades and native-resolution grass.
All card widths are fixed along world +X/screen-left-right instead of random
yaw; height stays world +Y and gentle wind moves tips along +X only. Small
position/height/color/phase variation remains. Faint horizontal bands remain
visible; this is a bounded direction playtest. Card width scaling and
two-sided upward shading fixes are retained.
Actors remain placeholders; sound effects are new original synthesized audio.
Historical regional duplicate-word behavior is preserved.
Stable target IDs and bounded restock loops deliberately fix stale-index/hang
hazards; gameover statistics freeze and Resume hitbox fixes are also retained.

Exported with verified official Godot4.6.3 Windows templates. Linux model and
rendered game-pack checks were performed. The Windows executable has NOT been
run on Windows or Wine; this is a desktop playtest build, not a certified port.
Godot license and third-party notices are included.
''')
archive = root / f"artifacts/type-space-dash-v{VERSION}-windows-x86_64.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(bundle.iterdir()):
        if path.is_file():
            zipped.write(path, f"{bundle.name}/{path.name}")
print(archive)
