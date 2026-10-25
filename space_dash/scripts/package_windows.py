"""Cross-export the versioned standalone Windows playtest. Runtime is not tested by exporting."""
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
VERSION = "0.3.0"
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

PLAYTEST FIXES:
Words start neutral and only accepted matching prefix letters turn gold.
Orb bodies start faint. Matching candidates light as you type; a unique or
complete target alone stays lit. Backspace updates this feedback.
Every enemy kind wanders outside nearby aggro: acquire at240world pixels,
disengage beyond340, with hysteresis to prevent flicker. Kind2 no longer
pursues across the map. Timing and cached terrain/spawn optimizations reduce
the measured movement hitches; camera easing/combat hit-stop are unchanged.

This reconstructs the selected older GameMaker snapshot from inspected source.
The three original ground tiles are included unchanged, rendered at2x with
the source tint and hash pattern. Actors are placeholders; original audio is
not included. Historical regional duplicate-word behavior is preserved.
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
