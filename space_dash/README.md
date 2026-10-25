# Type — grass / Space-to-dash survival revision

This is a separate, local Godot4.6.3 project based on the inspected older GameMaker snapshot selected by the user. It preserves the previously delivered Chi Circuit project and downloads in the parent folder. It does not use Chi Circuit's invented waves or vulnerable-angle loop.

**Original grass assets are not available in this executor yet.** The game is visibly marked as using the source checkerboard fallback. Do not label it visually faithful or export it as the final Windows playtest until the originals are materialized, inspected, and parity-reviewed. See [PARITY.md](PARITY.md) for exact matched rules, deliberate fixes, and remaining source gaps.

Open this folder's `project.godot` in Godot4.6.3, or run:

```sh
cd space_dash  # from the repository root
bash scripts/godot.sh
```

Choose Easy/Normal/Hard with the mouse and click **NEW GAME**. Type the exact case-sensitive word of an on-screen orb, then press **Space** to dash to it. Passing through enemies attacks them. Orbs and successful combat refill the continuously draining30-second timer. Wrong characters cost0.75seconds and reset combos. Backspace edits. Escape pauses/resumes; R or Enter restarts gameover. Shift+Q is the source's force-gameover shortcut. Exit buttons close the game.

Characters typed during a dash remain queued and process afterward; completing a word never automatically dashes. A Space edge pressed during the suspended dash/hit-stop interval is not replayed. No contact immunity is added during a dash.

```sh
bash scripts/godot.sh --headless --editor --import --quit
bash scripts/godot.sh --headless --script res://tests/test_survival.gd
DISPLAY=:99 python3 tests/record_gameplay.py  # needs Xvfb/X11 display and FFmpeg
```

Physics is explicitly fixed at60Hz for the original's frame-based speed and0.085camera lerp. High score persists to the Godot user-data directory as `typergame_save.ini`. Test fixtures use separate ignored save files. No final export or public upload has been performed for this revision; the intended delivery format remains a standalone Windows ZIP after the blockers are resolved.
