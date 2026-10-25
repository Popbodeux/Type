"""Build a portable Linux x86_64 bundle using the installed official Godot binary.

Includes the editor-capable binary, rather than requiring export-template downloads.
The actual game is the exported PCK; launching it never opens the editor.
"""
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
output = root / "artifacts"
bundle = output / "chi-circuit-linux-x86_64"
bundle.mkdir(parents=True, exist_ok=True)
subprocess.run(["bash", str(root / "scripts/godot.sh"), "--headless", "--export-pack", "Linux", str(output / "chi-circuit.pck")], check=True)
engine = shutil.which("godot")
if not engine:
    raise SystemExit("Godot is required to package the game")
shutil.copy2(Path(engine).resolve(), bundle / "godot")
shutil.copy2(output / "chi-circuit.pck", bundle / "chi-circuit.pck")
for name in ("GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"):
    shutil.copy2(root / "third_party" / name, bundle / name)
(bundle / "run.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$app_dir/.local/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$app_dir/.local/cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$app_dir/.local/share}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
exec "$app_dir/godot" --main-pack "$app_dir/chi-circuit.pck" "$@"
''')
(bundle / "run.sh").chmod(0o755)
(bundle / "README.txt").write_text('''CHI CIRCUIT — Godot reconstruction prototype

Linux x86_64: extract this folder and run ./run.sh
If your archive extractor removes executable permissions:
  chmod +x run.sh godot
  bash run.sh

Requires a Linux desktop, X11 or Wayland, and OpenGL 3.3 (software Mesa works).
Godot is included; no separate installation or network connection is needed.
This portable bundle includes the official Godot 4.6.3 editor-capable binary
running an exported game pack. It is not a size-optimized template export.

Enter: begin / play again. Type an orb's 3-letter word: dash to that orb.
Dash through sentinels FROM their mint arc: 1 damage. Other angles: blocked.
Each sentinel takes 2 hits; clear 3 waves. Avoid the red pulse ring.
Wrong letters keep the current prefix. Backspace: correct. Escape: clear.
Tab: pause. F1: help. F5: restart at any time. Close window to quit.

Reconstructed from the described GameMaker design; not a source port.
Godot's license and third-party notices are included alongside this file.
''')
archive = output / "chi-circuit-linux-x86_64.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(bundle.iterdir()):
        if path.is_file():
            zipped.write(path, f"{bundle.name}/{path.name}")
print(archive)
