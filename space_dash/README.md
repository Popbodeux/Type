# Type: grass / Space-to-dash survival v0.4.2

A Godot 4.6.3 reconstruction of the selected older GameMaker snapshot, with requested playtest improvements. The ground is a single untextured muted-green canvas rectangle. It uses original procedural 3D grass and synthesized sound effects. The original three ground PNGs remain unchanged as source reference and are not loaded or drawn during gameplay. Actors remain placeholders. This is not a pixel-perfect port or an original-executable parity claim.

Download the versioned Windows ZIP from the repository root README, extract the entire folder to your desktop, and double-click `TypeSpaceDash.exe`. Keep `TypeSpaceDash.pck` beside it. No Godot installation is needed. Windows x86_64/OpenGL 3.3 is required. The executable is unsigned and has not been run on Windows or Wine; Linux execution of its actual game pack is checked separately.

Choose a difficulty with the mouse, then NEW GAME. Type an orb's exact case-sensitive word and press **Space** to dash through enemies to it. Backspace edits; Escape pauses/resumes; R or Enter restarts gameover. The timer starts at 30 seconds. Orbs, hits and kills add time; rejected letters, blocked hits and contact remove it. Text entered during dash or pause is queued. Shift+Q forces gameover for debugging.

Words stay at a fixed 18-pixel size. Matching words gain a dark backplate; only accepted prefix letters turn gold. Idle orb bodies are 50% opaque, active candidates 98%; a unique target alone stays lit. All enemies wander until within 140 world pixels, disengage beyond 190, pursue at 65% and wander at 70% of their prior rates. No global alert chaining.

**F8** cycles grass Off/Low/High (default Low). **F10** toggles sound. Title, pause and gameover menus offer mute, volume and grass options; settings persist separately from high score. Eight original synthesized sounds use cooldowns, conservative volumes and at most four voices. Ready suppresses the typing sound on completion. Muting drops events, so unmuting cannot replay a backlog.

Short multi-blade clusters form a continuous meadow with small natural gaps, restrained height variation, broad green color patches and gentle wind. The grass consists of actual chunked `MultiMeshInstance3D` alpha-cutout cards rendered by an orthographic `SubViewport` behind the existing 2D gameplay. It is not a 2D sprite substitute. The orthographic grass camera tilts 15 degrees from straight down. Ground-root positions map 2D Y to 3D Z/cos(tilt), while card geometry keeps its local dimensions. The 2D gameplay and screen-facing text retain their original coordinates. Tips bend in mild world-space wind while roots stay anchored. The shader uses Godot's documented world_vertex_coords mode and UV height to anchor roots. It enforces world-up normals in fragment view space too, correcting double-sided back-face flips. This avoids per-vertex matrix inversions. Separate 256px chunks have local bounds including wind/lean, with a 48-chunk cache cap. Low renders only the grass viewport at 800×450 before compositing; text and actors stay at native 960×540. High uses more blades and a native-resolution grass viewport. Paths and clearings preserve open ground; labels/actors always composite above grass. Original art and code only; no third-party reference screenshots are distributed. See [performance](PERFORMANCE.md), [validation](VALIDATION.md) and [source parity](PARITY.md).

## Develop and verify

Open `project.godot` in Godot **4.6.3 stable**, or:

```sh
bash scripts/godot.sh
bash scripts/godot.sh --headless --editor --import --quit
bash scripts/godot.sh --headless --script tests/test_survival.gd
bash scripts/godot.sh --headless --script tests/test_playtest_fixes.gd
bash scripts/godot.sh --headless --script tests/test_visual_audio.gd
DISPLAY=:99 bash scripts/godot.sh --audio-driver Dummy --script tests/test_projection.gd -- --render
```

The wrapper keeps caches/config in ignored `.local/`; generated evidence goes in ignored `artifacts/`. No credentials or network are needed to play. Rendered tests require X11/FFmpeg. `tests/render_scenery.gd` captures Off/Low/High and verifies actual upward normals; `tests/record_gameplay.py` records two engine-input playthroughs and captures the game's own audio bus (not a microphone). Original WAVs can be reproduced with `python3 tests/generate_sfx.py`. `python3 scripts/package_windows.py` needs the official 4.6.3 export templates installed in the wrapper's XDG data directory.

Official implementation references: [spatial shader coordinates](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html), [MultiMesh batch culling](https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html), [orthographic camera](https://docs.godotengine.org/en/4.6/classes/class_camera3d.html).
