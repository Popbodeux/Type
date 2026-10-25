# Type — grass / Space-to-dash survival v0.3.0

This is a separate Godot4.6.3 project based on the inspected older GameMaker snapshot selected by the user. It preserves the earlier Chi Circuit project and downloads. It does not use Chi Circuit's invented waves or vulnerable-angle loop.

**[Download the standalone Windows ZIP](https://raw.githubusercontent.com/Popbodeux/Type/main/downloads/space-dash-v0.3.0/type-space-dash-v0.3.0-windows-x86_64.zip).** Extract the whole archive, then double-click `TypeSpaceDash.exe`. Keep `TypeSpaceDash.pck` beside it. No Godot installation is needed to play. Requires Windows x86_64 with OpenGL3.3 support. This unsigned export has **not been run on Windows or Wine**; Linux source/game-pack checks are documented in [VALIDATION.md](VALIDATION.md).


This playtest implements the requested fixes:

- Word labels start neutral. Only correctly typed matching prefix letters highlight progressively; completing the word highlights all its letters.
- Orb bodies start very faint. Matching candidates light as you type; a unique or completed target alone stays lit. Backspace updates candidates, a rejected typo retains the accepted prefix, and dash/reset clears activation. These are cheap color/alpha changes, without new glow shaders or speculative effects.
- Every enemy kind wanders when distant, acquires aggro at **240 world pixels**, and disengages beyond **340 pixels**. The hysteresis band prevents flicker. Kind2 no longer pursues across the map; wandering enemies face their own wandering direction.
- Spawn/conflict work and terrain rendering are cached and redundant maintenance passes consolidated. Representative normal/dense worst model ticks fell139/368→14/14ms; rendered p95 interval fell18.1→9.1ms. A63.5ms wall-time outlier remained. [PERFORMANCE.md](PERFORMANCE.md) contains full measurements and limitations; Windows GPU performance is not established. Intentional camera easing and combat hit-stop remain.

The three original16×16 grass PNGs are integrated unchanged, with verified hashes/pixels and the source's32px cell hash/tint/sampling. Actors remain placeholders and original audio is absent. See [PARITY.md](PARITY.md) for matched rules and deliberate fixes. Historical regional duplicate-word behavior is retained; the first exact match is highlighted.

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
bash scripts/godot.sh --headless --script res://tests/test_playtest_fixes.gd
DISPLAY=:99 python3 tests/record_gameplay.py  # needs Xvfb/X11 display and FFmpeg
```

Physics is fixed at60Hz for the original's frame-based speed and0.085camera lerp. High score persists to the Godot user-data directory as `typergame_save.ini`. Test fixtures use separate ignored save files. `python3 scripts/package_windows.py` creates the versioned Windows ZIP when official4.6.3 Windows export templates are installed. Bounded restock loops, stable target IDs, frozen gameover stats, and the Resume hitbox fix are deliberate robustness changes.
