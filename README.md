# Type — Space-to-dash survival

The latest desktop playtest reconstructs the selected older grass-ground GameMaker version in Godot4.6.3.

**[Download Windows v0.2.0](https://raw.githubusercontent.com/Popbodeux/Type/main/downloads/space-dash-v0.2.0/type-space-dash-v0.2.0-windows-x86_64.zip)** — extract the entire ZIP, then double-click `TypeSpaceDash.exe`. Keep `TypeSpaceDash.pck` beside it. Godot installation is not required to play.

- [Source ZIP v0.2.0](https://raw.githubusercontent.com/Popbodeux/Type/main/downloads/space-dash-v0.2.0/type-space-dash-v0.2.0-source.zip), or open `space_dash/project.godot` from this repository.
- [Actual gameplay recording](https://raw.githubusercontent.com/Popbodeux/Type/main/media/space-dash-v0.2.0/gameplay.mp4).
- [Controls and source-parity notes](space_dash/README.md), [validation](space_dash/VALIDATION.md), and [checksums](downloads/space-dash-v0.2.0/SHA256SUMS.txt).

Choose a difficulty and **NEW GAME**. Type an orb's exact case-sensitive word, then press **Space** to dash to it. Backspace edits; Escape pauses; R or Enter restarts gameover. Survive the30-second timer using orb/combat rewards. The original three grass tiles are included unchanged. Actors are placeholders and original audio is absent. Historical regional duplicate-word behavior is preserved.

**The Windows executable has not been run on Windows or Wine.** Export/structure checks and Linux game-pack playthroughs are documented separately. This is a source-based reconstruction with documented safety fixes, not a claim of full original-executable parity.

## Earlier Chi Circuit prototype

The original project and downloads below remain available at their existing paths.

A small, playable **Godot 4.6.3** reconstruction of the described GameMaker typing-action game. The original source is unavailable in this cloud task, so this is a new implementation of the described loop, not a source port or a claim of feature parity.

Type an orb's three-letter word to dash to it. Choose a route that carries you through a sentinel **from its mint marked side**. Other approach angles deal no damage. Reposition using the other orbs, then strike again. Clear three waves of two-hit sentinels. Red rings telegraph a pulse; dash to safety before it fires.

## Downloads

- [Windows x86_64 ZIP](https://raw.githubusercontent.com/Popbodeux/Type/main/downloads/chi-circuit-windows-x86_64.zip) — extract everything, then open `ChiCircuit.exe`. Keep `ChiCircuit.pck` beside it.
- [Godot source ZIP](https://raw.githubusercontent.com/Popbodeux/Type/main/downloads/chi-circuit-source.zip) — open `project.godot` in Godot 4.6.3.
- [Actual gameplay video](https://raw.githubusercontent.com/Popbodeux/Type/main/media/gameplay.mp4) — 35 seconds of the real Godot game controlled by automated keyboard input.
- [SHA-256 checksums](downloads/SHA256SUMS.txt)

**Windows runtime has not been tested on Windows or Wine.** The Windows release export, official-template checksum, PE architecture, and ZIP integrity checks passed on Linux. Its game pack also completed rendered Linux playthroughs. See [validation details](VALIDATION.md).

## Run

Open `project.godot` in Godot **4.6.3 stable**, then press **F6/F5** to run the main scene/project. Or, from this repository:

```sh
bash scripts/godot.sh
```

The wrapper places Godot's configuration and font caches in an ignored `.local/` directory when XDG paths are unset. It works in this restricted cloud workspace without writing to the home directory. No packages, external assets, services, credentials, or network access are required for gameplay.

The Windows download includes the engine; no Godot installation is required to play. It is an unsigned x86_64 release export made with official Godot 4.6.3 templates after archive SHA-512 verification.

Linux users can run the source with Godot or build a portable Linux bundle using the script below. That bundle includes an editor-capable engine, not a size-optimized release template. macOS and web builds have not been produced or tested.

## Controls

| Input | Result |
| --- | --- |
| Enter | Begin; restart after victory or defeat |
| A–Z | Build a target's word; completing it starts the dash |
| Backspace | Remove the most recent accepted letter |
| Escape | Clear the prefix / close help |
| Tab | Pause or resume |
| F1 | Open or close help; hazards freeze while help is open |
| F5 | Restart the run at any time |

Words use unique starting letters as well as unique full words. Typing is case insensitive. A wrong letter flashes feedback and increments the correction counter without changing the valid prefix or damaging the player. Key repeat and typing during a dash are ignored. No timeout or mistake damage applies. Surviving orb labels remain stable; consumed targets refill at safe positions after landing, up to eight orbs. No orb spawns on the player or sentinel. Space has no attack function.

These correction rules, fixed arena layouts, three waves, 48-degree vulnerable half-angle, 0.3-second dash, two-hit sentinel health, dash immunity, and pulse timing are **provisional prototype choices**, since the original behavior was not specified. The camera follows the player with encounter look-ahead so targets stay clear of the fixed HUD.

## Verify

```sh
# Import/parser check. Also inspect the log: Godot can exit 0 on some script errors.
bash scripts/godot.sh --headless --editor --import --quit

# Live game smoke check without a display.
bash scripts/godot.sh --headless --quit-after 20

# Regression suite; prints checks/passed/failed and exits nonzero on failure.
bash scripts/godot.sh --headless --script res://tests/test_game.gd

# Build the pack and portable Linux ZIP using the installed Godot binary.
python3 scripts/package_linux.py

# Cross-export Windows after installing the official Windows 4.6.3 templates.
python3 scripts/package_windows.py

# Rendered keyboard-driven playtest on an available X display; also records it.
DISPLAY=:99 python3 tests/record_gameplay.py
```

The regression suite covers deterministic word selection, case handling, errors, correction/cancel controls, orb bounds and spacing, labels clear of HUD after landing, interpolated dash motion, one hit per dash, valid/blocked/missed geometry, pulse damage, invulnerability, loss, pause/help, full reset, and three complete repeated runs. The rendered driver uses actual `InputEventKey` events and the same gameplay scene to complete two runs, including an armored hit and victory restart. It does not replace combat/movement with an animation. It writes screenshots, a route log, and a result JSON to `artifacts/`. For an exported pack, set `CHI_ARTIFACT_DIR` to a writable absolute output directory.

For rendered tests on a headless Linux machine, install Xvfb and FFmpeg, then start a local display when needed:

```sh
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp -ac
```

This is an isolated local display with no TCP listener. It is for internal rendering checks, not a published preview. See `VALIDATION.md` for observed results and limitations.

## Files and scope

`scripts/game.gd` owns input, run state, camera, procedural placeholder art, orbs, dash simulation, and enemy hazards. `scripts/combat.gd` provides the shared segment-distance and angle calculations. `scripts/hud.gd` draws the screen-space UI. The scene is intentionally minimal so the combat rules can be changed easily.

This prototype has stationary sentinels, one encounter repeated with different vulnerable directions, no audio, and no progression/save system. It establishes the typing, routing, and directional-combat loop; it is not the full roguelite. Art is generated with Godot's drawing primitives and built-in font. Godot's MIT license and third-party notices are in `third_party/` and the playable bundles.
