# v0.4.1 validation

Tested with Godot **4.6.3.stable.official.7d41c59c4**, Linux x86_64, Compatibility rendering and Mesa llvmpipe OpenGL 4.5 software rendering. This is an inspected-source reconstruction plus requested changes, not a running-original comparison.

| Check | Result |
| --- | --- |
| Model regression | 1,390 assertions passed, zero failed |
| Typing/proximity/ground regression | 61 assertions passed, zero failed |
| Visual/audio/3D/settings regression | 134 assertions passed, zero failed |
| Import/parser and headless startup | Passed |
| Source Off/Low/High render | Captured and visually inspected privately |
| Exported Windows game pack under Linux Godot | Two input-driven rendered sessions passed, including progressive prefixes, Space, mid-dash queue, pause/resume, combat, forced/natural gameover and restart |
| Solid ground | 12,240/12,920 samples (94.7%) match RGB(82,107,67) in actual grass-Off render; remaining samples include actors/labels |
| Original PNG source reference | All three original byte hashes preserved; no runtime tile loader, CPU tile composition or texture chunk cache remains |
| Actual normal-debug 3D framebuffer | All 194,285 opaque pixels point world-up |
| Audio | All eight sound events occurred in captured exported-pack play; own-bus PCM capture checked for clipping |
| Windows export/ZIP | Official verified 4.6.3 template; CRC, five-member whitelist, extraction, PE x86_64 and exact official executable SHA-256 passed |
| Native Windows/Wine runtime | **Not run** |

The total **1,585 assertions** includes repeated per-orb/pairwise checks, not 1,585 independent scenarios. The inherited model suite covers constants, selection/Space, correction, dash timing/buffering, directional combat/order, enemy/contact/hit-stop, statistics/pause/save/reset, population, source helper guards and historical terrain hash repeatability. Source PNG assertions now verify preserved reference files rather than drawing obsolete terrain. The 61-check suite replaces obsolete texture-cache checks with the flat-ground contract while retaining feedback, hysteresis and eligibility equivalence. The 134-check suite covers fixed glyph anchors, contrast, orb alpha, initial/nearby enemy states, sound event routing, voice limits/cooldowns, mute/volume/settings, real 3D nodes/camera, bounds/cache/Off, UV-root wind and world-space normal/scissor configuration. Actual framebuffer checks supplement source assertions.

The shader uses Godot's documented `world_vertex_coords` mode. Both VERTEX and NORMAL are in world space in vertex(); assigning world up directly avoids model-matrix inversions. UV height fixes root weight at zero. Actual normal-debug rendering verifies the resulting view/world normal transform rather than assuming a copied reference fragment is correct. Original procedural cutout artwork is used; no third-party screenshot assets are distributed.

Private scenery captures submit 5,925 Low cards and 11,192 High cards across 24 intersecting 256px chunks, including offscreen instances within those batches. Low grass renders at 640×360 before compositing; actors and text stay 960×540. High grass is native resolution. The cache is bounded to 48 chunks. PERFORMANCE.md includes the initial expensive dense attempt, culling/shader optimization and final resolution tradeoff. Final Low mean/p95 is 17.10/21.42ms; High 32.27/38.25ms on software rendering. The model/RNG fingerprint is identical across all tested modes and optimizations. These are not Windows GPU guarantees.

The rendered playback uses the normal exported scene and engine mouse/key input. Its X11 recording and game-bus audio capture remain private alongside screenshots. No new screenshot or recording is publicly published in this revision; the README's old video is explicitly labeled v0.4.0. The private character blockout is separate and not integrated or published. Only the virtual-display V-Sync warning remains in rendered logs; final checks have no script/shader/import errors. The audio unit test allows the asynchronous mixer to settle before teardown.

Known limits: Windows OS/GPU/audio execution, alternate keyboard/OS repeat, human feel and long-session soak remain untested. Actors remain placeholders. Historical regional duplicate words can later share a viewport; first exact match wins. Bounded restocking, stable IDs, frozen gameover statistics and aligned Resume hitbox remain documented safety fixes. The flat ground and denser scenery intentionally supersede original ground visuals; no new combat mechanics or AI changes were introduced in v0.4.1. Sound and 140px/190px proximity thresholds remain from v0.4.0. No deployment or visibility change is included.
