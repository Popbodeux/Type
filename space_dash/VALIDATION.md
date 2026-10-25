# v0.4.2 validation

Tested with Godot **4.6.3.stable.official.7d41c59c4**, Linux x86_64, Compatibility rendering and Mesa llvmpipe OpenGL 4.5 software rendering. This is a source-based reconstruction with user-requested changes, not an original-executable comparison or exact reference-image match.

| Check | Result |
| --- | --- |
| Model regression | 1,390 assertions passed, zero failed |
| Typing/proximity/ground regression | 61 assertions passed, zero failed |
| Visual/audio/settings regression | 135 assertions passed, zero failed |
| Headless projection math | 1,208 assertions passed; actual GPU geometry/normals explicitly not run with Dummy |
| Actual OpenGL projection/geometry/front-back normals | 1,511 assertions passed, zero failed |
| Import/parser | Passed |
| Actual exported Windows game pack under Linux Godot | Two rendered input-driven sessions passed |
| Solid ground | 12,240/12,920 samples (94.7%) match RGB(86,120,66) in grass-Off frame; labels/actors cover remaining samples |
| Original ground PNGs | All three original hashes preserved as unused source reference |
| Full-scene actual normal framebuffer | 155,588/155,588 opaque pixels world-up |
| Windows export/ZIP | Official verified 4.6.3 template; CRC, five-member whitelist, extraction, PE x86_64 and exact official executable SHA-256 passed |
| Native Windows/Wine/GPU/audio | **Not run** |

The three core suites total **1,586 assertions**, including repeated per-orb/pairwise checks. The projection suites overlap and are not additive independent scenarios. The model suite covers source rules, selection, correction, dash, combat, timer/statistics, reset, spawning, guards and historical terrain helpers. The visual/audio suite covers fixed glyph anchors, contrast, orb states, slower nearby AI, eight sound events, cooldowns/voice limits, mute/volume/settings and actual 3D/cutout/root-wind configuration. GPU geometry assertions were moved to the real renderer test: Dummy can return identity MultiMesh transforms and cannot validate that geometry.

Projection tests cover both 800×450 and 960×540 grass viewports, five camera centers including world bounds, real player/enemy/orb/viewport/dash anchors, and three real model dashes following the eased 2D camera. Maximum screen registration error is **0.002013 pixels**, below the 0.01px threshold. Root mapping is world3D Z = world2D Y/cos(15deg). Camera target uses the same mapping; actual card dimensions are not stretched to compensate. Labels and all gameplay stay in native 2D screen coordinates.

The audit identified two concrete old defects. Global scale after yaw could widen a card by **2.2353×** and change its effective lean. Local scale now preserves intended width, height and vertical axis through yaw. Separately, an actual isometric debug frame showed back-face shading normals pointing down despite the vertex assignment. The fragment shader now enforces world-up transformed into fragment view space, after rasterizer back-face handling. Opposite-facing actual card captures pass on both faces; the full-scene normal pass also succeeds. Legacy and corrected side/isometric/gameplay diagnostics remain private. These are separate from the camera style issue: the old straight-down view projected away vertical height, making baked lean dominate the silhouette.

Private same-state captures compare 10°, 15° and 20° camera tilts. The smallest clearly useful choice was 15°; the effect is deliberately modest. The latest meadow uses much shorter original multi-blade cards, tighter coverage, smaller height variation, soft green patches/cloud tint, gentler wind and softer lighting. The user reference image was unavailable to this executor; development follows its supplied pixel-observed description and actual local render inspection. No flowers, trees, rocks, new attacks or character integration were added.

Exported-pack playback checks progressive shared/unique/completed words, exact word plus Space, rejected letters and Backspace, mid-dash queued input, pause/resume, combat, forced/natural gameover and restart. Its actual X11 video, game-bus sound recording and screenshots remain private. The current rendered run captured seven sound types and zero clipped samples (peak 7,284/32,767); no blocked hit occurred in this run. All eight model event routes are covered by unit checks, and the unchanged sound system previously captured all eight in v0.4.1. This is not native Windows audio validation. Previous public video is labeled v0.4.0. No new character or enemy assets are integrated in this revision.

PERFORMANCE.md records the initial expensive meadow and measured optimization. Final software-rendered mean/p95: Low **21.42/25.94ms**, High **36.76/44.13ms**, Off **7.26/10.80ms**. All quality/optimization runs finish with the same model/RNG fingerprint. Default Low reduces overlaps and shares a noise sample; High remains expensive on this software renderer. These are not hitch-free 60fps or Windows performance claims. Only the virtual-display V-Sync warning remains in rendered logs. The invalid headless `-- --render` test intentionally exits 2 immediately with a clear diagnostic; it is not counted as a passed render check.

Known limits remain native Windows execution, user GPU/audio behavior, alternate keyboards/OS repeats, human feel and long-session soak. Historical regional duplicate words and documented stable-ID/restock/stat-freeze/Resume safety fixes remain. No hosted deployment, visibility change, reference-image publication or private screenshot/character upload is included.
