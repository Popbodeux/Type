# v0.4.0 validation

Tested with **Godot 4.6.3.stable.official.7d41c59c4**, Linux x86_64, Compatibility rendering and Mesa llvmpipe OpenGL 4.5. This is a reconstruction from inspected GameMaker source plus requested changes, not a comparison against a running original executable.

| Check | Result |
| --- | --- |
| Model regression | 1,390 assertions passed, zero failed |
| Typing/proximity/cache regression | 61 assertions passed, zero failed |
| New visual/audio/3D/settings regression | 136 assertions passed, zero failed |
| Import/parser | Passed |
| Source rendered gameplay | Two input-driven sessions passed |
| Actual exported Windows game pack under Linux Godot | Two rendered sessions passed: Space confirmation, shared/unique/completed prefixes, typo, buffered mid-dash input, pause/resume, combat, forced/natural gameover and restart |
| Actual 3D quality/normal rendering | Off/Low/High captured; all 9,631 opaque pixels in the raw normal-debug framebuffer pointed upward |
| Original ground | All three PNG byte hashes, dimensions and decoded RGBA hashes verified in exported pack; rendered pixel checks passed |
| Audio mixer capture | All eight sound types occurred during exported-pack play; peak 7,284/32,767, zero clipped samples |
| Windows export/ZIP | Official checksum-verified 4.6.3 template; ZIP CRC, five-member whitelist, extraction, PE x86_64 and executable-template SHA-256 passed |
| Native Windows/Wine execution | **Not run** |

The **1,587 assertions** are not 1,587 independent scenarios or human play sessions. The model total includes repeated per-orb/pairwise checks. Its categories are: reference constants 14; selection/Space 15; mistakes/Backspace 8; dash buffering/timing 11; directional combat/order 22; enemy/contact/hit-stop 10; stats/pause/gameover/save 10; population/reset 1,251; terrain repeatability 18; helper parity/guards 31. The 61-check suite covers progressive prefix and body feedback through shared/unique/completed/typo/Backspace/dash/reset states, duplicate exact selection, all-kind hysteresis and optimized eligibility/cache equivalence. Its expected thresholds intentionally follow this revision's requested calmer AI.

The 136 new assertions check fixed glyph anchors and stronger matching backplates, 50%/98% orb alpha, initial enemies outside aggro across 20 seeds, slower acquisition/disengagement for every kind, real model events for all eight sounds, loaded streams, rate limiting, four voices, immediate mute, no unmute backlog, volume clamps/settings round trip, real 3D node/projection/isolated world, local chunk bounds, normal transforms, root wind weighting, alpha cutout, bounded cache and Off disabling the viewport. Rendered checks supplement shader-string/numeric checks with the actual normal-debug framebuffer. This is not a claim that numeric assertions alone prove visual quality.

The ground-pixel diagnostic compares 12,920 actual rendered samples against the original PNGs, source tile hash, 2× nearest sampling and RGB(178,236,136) tint. Variant match rates were **92.6% / 91.8% / 88.8%**, all above the unchanged 80% threshold. New grass, plates and actors cover some samples; underlying tile fidelity remains verified. This is ground-component validation, not full visual parity.

The MP4 records the actual exported game pack's X11 window controlled through engine mouse/key events. It includes the game's own captured audio bus, not a synthetic soundtrack or microphone. The first 9.2 seconds of startup wait were trimmed. The audio was aligned using measured video/audio capture-start times (174 ms delay after trimming), then encoded as AAC. Frame timing, capture startup and audio driver buffering can leave small synchronization error. No replacement gameplay animation was rendered. The first run deliberately uses Shift+Q; the second ends by timer/contact rules.

PERFORMANCE.md compares the same dense 14-dash route with grass Off/Low/High and the v0.3 baseline. Low/High have measurable render cost; identical final model fingerprints confirm grass does not alter gameplay. Cloud software rendering cannot establish the user's Windows GPU performance. The virtual X11 V-Sync warning remains; final tests have no script/shader/import errors. The headless audio regression lets the asynchronous mixer settle for one second before teardown, preventing an intermittent shutdown resource warning after rapid voice replacement.

Known limitations: Windows OS/audio/GPU behavior, alternate keyboards/OS repeat, human usability and long-session soak are untested. Actors remain placeholders; the separate private character blockout is not integrated. Original audio is replaced by new original synthesis. GameMaker/Godot RNG sequences differ. Regional duplicate words may later share a viewport; first exact match wins as in the reference. Stable target IDs, bounded restocking, frozen gameover stats and aligned Resume hitbox are documented safety fixes. See PARITY.md. No hosted game deployment or visibility change is included.
