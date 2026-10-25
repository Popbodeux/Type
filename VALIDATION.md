# Observed validation

Tested with **Godot 4.6.3.stable.official.7d41c59c4**, Linux x86_64, the Compatibility renderer, and Mesa llvmpipe OpenGL 4.5. No source from the GameMaker project was available for comparison.

| Check | Observed outcome |
| --- | --- |
| Headless editor import / parser | Passed; final `artifacts/import.log` contains no script errors or engine errors |
| Normal game startup, headless | Passed; 20 frames, normal main scene, exit 0 |
| Regression suite | **551 passed, 0 failed**; includes three complete repeated encounters |
| Source project, actual rendered gameplay | Passed; two full keyboard-driven runs with victory restart, 6 strikes per run and an intentionally blocked attack |
| Rendered screenshots | Reviewed title, arena, selection, blocked-hit feedback, wave two, and victory; camera fixed after an initial HUD overlap was observed |
| Portable Linux pack generation | Passed; exported PCK and official engine binary bundled with licenses |
| ZIP integrity / extraction | Passed; CRC verified, then the extracted package was tested in a separate directory |
| Extracted Linux package startup | Passed; normal main scene, headless, exit 0 |
| Extracted Linux package rendered play | Passed; two full keyboard-driven runs, victory restart, 6 strikes, 1 intentional armored hit, 3 vitality remaining |
| Official Windows templates | Complete official archive matched published SHA-512; extracted release/debug x86_64 templates passed ZIP CRC checks |
| Windows x86_64 release export | Passed on Linux using official Godot templates; no export errors or warnings |
| Windows ZIP / executable structure | Passed CRC and extraction checks; PE32+ x86_64; executable SHA-256 matches the verified official release template |
| Windows-exported PCK under Linux | Headless startup and two rendered runs passed using the Linux Godot engine; this is **not** Windows executable/runtime validation |

The test scripts generate JSON results, logs, and screenshots in the ignored `artifacts/` directory. The published `media/gameplay.mp4` is actual X11 capture of Godot being played by keyboard events, including movement and combat. Its 9.34-second initial display/engine startup wait was trimmed. No gameplay was replaced or animated in post-production.

The only remaining renderer warning is that changing V-Sync mode is unsupported by the virtual software display. It did not prevent rendering, screenshot capture, or completed gameplay. Writable XDG paths are set by `scripts/godot.sh`. TLS, signatures, and checksum validation were not disabled during setup.

## What the 551 checks mean

These are **551 assertions in one regression runner**, not 551 distinct test cases, human play sessions, or randomized scenarios. Layout assertions repeat across orbs and waves; camera assertions repeat after landing. All passed, with no skipped or expected-failure assertions.

| Category | Passed assertions | Scope |
| --- | ---: | --- |
| Orb layout and unique words | 272 | Three-letter words, unique words/initials, count cap, arena bounds, player/enemy clearance, and pairwise label spacing across three wave layouts |
| Camera label framing | 203 | Target labels fit a safe HUD-free rectangle after simulated dash landings; rendered screenshots separately checked actual framing |
| Repeated full encounters | 45 | Available safe routes, victory with six strikes, preserved vitality, and restart state across three complete runs |
| Typing selection and correction | 7 | Uppercase input, prefix selection, rejected wrong letter, Backspace including empty prefix, Escape, and no space attack |
| Dash motion and live hit | 7 | Trigger, non-teleporting start, input gated during dash, interpolation, exact landing, one clean strike, surviving labels stable |
| Combat geometry | 5 | Vulnerable crossing, armored crossing, miss distance, and just inside/outside the vulnerable cone |
| Pulse, loss, restart | 4 | Grounded pulse damage, damage cooldown, defeat, and Enter restart after defeat |
| Pause and help | 3 | Paused simulation, hazards frozen in help, Escape closing help |
| Live blocked hit | 2 | No damage from armored approach and explicit feedback |
| Startup | 2 | Intro gates play and Enter starts |
| Manual reset | 1 | F5 clears partial input and run state |
| **Total** | **551** | Machine-readable breakdown: `artifacts/test-results.json` |

Rendered runs are **separate** from those 551 assertions: two source-project runs, two runs of the extracted Linux package, and two runs of the Windows-exported PCK using the Linux engine completed through actual engine keyboard events. They exercise the normal game scene, movement, combat, victory, and restart. Their route logs identify each typed target. They are automated play, not human usability testing. All rendering used Linux and Mesa llvmpipe; the Windows `.exe` was never executed.

The Windows executable has **not** been run on Windows or Wine. Cross-exporting and checking PE/ZIP structure do not establish Windows runtime, driver, or keyboard compatibility. macOS/browser exports, original GameMaker source parity, human playtesting, alternate keyboard layouts/IME, focus-loss and held-key behavior, non-default window sizes/aspect ratios, reset during an active dash, separate dash-immunity coverage, and long-session/performance testing remain unrun. Hazard damage is regression-tested by putting the normal game state in the pulse area; the recorded solver avoids damage and does not demonstrate a human reacting to the pulse.

This is a short silent prototype with stationary enemies and placeholder art, not a complete roguelite. The repository contains source, a Windows download, and the actual gameplay recording; no hosted game deployment is included.
