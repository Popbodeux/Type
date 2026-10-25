"""Cross-export Windows x86_64 from this cloud workspace.

Install the official 4.6.3 Windows export templates first. Exporting is not a
Windows runtime test; the target executable still needs testing on Windows.
"""
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
output = root / "artifacts"
bundle = output / "chi-circuit-windows-x86_64"
bundle.mkdir(parents=True, exist_ok=True)
subprocess.run([
    "bash", str(root / "scripts/godot.sh"), "--headless", "--export-release", "Windows",
    str(bundle / "ChiCircuit.exe"),
], check=True)
for name in ("GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"):
    shutil.copy2(root / "third_party" / name, bundle / name)
(bundle / "README.txt").write_text('''CHI CIRCUIT — Windows x86_64 prototype

Extract the entire ZIP, then double-click ChiCircuit.exe.
Keep ChiCircuit.pck in the same folder as ChiCircuit.exe.
Godot and other development tools do not need to be installed to play.
Requires a Windows x86_64 desktop with OpenGL 3.3 support.

Enter: begin / play again. Type an orb's 3-letter word: dash to that orb.
Dash through sentinels FROM their mint arc: 1 damage. Other angles: blocked.
Each sentinel takes 2 hits; clear 3 waves. Avoid the red pulse ring.
Wrong letters keep the current prefix. Backspace: correct. Escape: clear.
Tab: pause. F1: help. F5: restart at any time. Close window to quit.

Exported with official Godot 4.6.3 Windows release templates after SHA-512
verification. Export success, PE architecture, pack contents and ZIP integrity
were checked on Linux. The Windows executable was NOT run on Windows or Wine.
The source and original Linux bundle have passed rendered gameplay tests.
This prototype is unsigned.

Reconstructed from the described GameMaker design; not a source port.
Godot's license and third-party notices are included alongside this file.
''')
with zipfile.ZipFile(output / "chi-circuit-windows-x86_64.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(bundle.iterdir()):
        if path.is_file():
            zipped.write(path, f"{bundle.name}/{path.name}")
print(output / "chi-circuit-windows-x86_64.zip")
