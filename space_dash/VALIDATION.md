# v0.4.3 fixed-axis validation

Tested with Godot **4.6.3.stable.official.7d41c59c4**, Linux x86_64, Compatibility rendering and Mesa llvmpipe OpenGL 4.5 software rendering. This is a bounded directional playtest, not an exact match to the user's meadow reference.

| Check | Result |
| --- | --- |
| Model regression | 1,390 assertions passed, zero failed |
| Typing/proximity/ground regression | 61 assertions passed, zero failed |
| Visual/audio/settings regression | 135 assertions passed, zero failed |
| Headless projection math | 1,208 passed; actual GPU geometry/normals explicitly unrun under Dummy |
| Actual OpenGL projection/geometry/front-back normals | 1,514 assertions passed, zero failed |
| Import/parser | Passed |
| Exported Windows PCK under Linux Godot | Two rendered input-driven playthroughs passed |
| Solid ground | 12,240/12,920 samples (94.7%) match RGB(86,120,66) in Off frame; labels/actors cover remaining samples |
| Original PNG source reference | All three hashes remain unchanged; no runtime tile loader or tile draw |
| Actual full-scene normal framebuffer | 270,197/270,197 opaque pixels world-up |
| Windows export/ZIP | Official verified 4.6.3 template, CRC, five-member whitelist, extraction, PE x86_64 and official executable SHA-256 passed |
| Native Windows/Wine/GPU/audio | **Not run** |

The three core suites total **1,586 assertions**, including repeated per-orb checks. Projection suites overlap and are not additional independent scenarios. Actual GPU inspection covers **17,944** cached card transforms: width axis is exactly world +X and height axis world +Y; maximum directional errors are zero. **142** sampled card widths project positively left-to-right with zero vertical delta. This verifies the requested screen-horizontal fixed axis, rather than assuming zero yaw is sufficient. Width scaling error is below 0.000002 world units; root height and bounds checks pass.

The unchanged 15-degree oblique camera maps ground roots from 2D Y to 3D Z/cos(tilt). Both viewport sizes, five camera centers including world bounds, player/enemy/orb/viewport/dash anchors and three real model dashes are tested. Maximum screen registration error remains **0.002013px**, below 0.01px. Actual card dimensions are not stretched to fake the projection; the prior local-scale fix is retained. Text/gameplay stay native 2D.

The production field uses CARD_YAW=0. Local width points world +X/screen-left-right; height points world +Y; mild baked lean stays toward world −Z. Wind now displaces tips only along positive world +X, with a bounded 0–0.7-unit breeze and coherent phase variation. Root weight stays zero. Position jitter, height/color variation, density, procedural seven-blade mask, cloud/lighting, base fill, chunk cache and camera are unchanged from v0.4.2. Cards are actual upright 3D geometry, not flattened ground planes or 2D substitutes.

Opposite-facing diagnostic cards retain the actual production mesh/material and pass **2,800/2,800** and **545/545** upward-normal pixels. These stages deliberately use yaw 0/PI to test both faces even though the field has fixed yaw. The fragment world-up override remains in correct view space after back-face rasterization handling. Headless rendering cannot prove actual MultiMesh transforms; the GPU checks are explicitly separated. Invalid headless --render exits 2 immediately, not a passed render result.

Actual same-seed/scene/camera captures compare random yaw v0.4.2 with fixed v0.4.3. Fixed orientation reads more uniformly upward and covers more ground, but faint horizontal bands remain visible. No extra polish is included. All captures and user references stay private; the reference image is not redistributed or claimed to have been viewed in this executor. The implementation uses the supplied visual direction and actual local rendered review.

Exported-pack playback verifies shared/unique/completed prefixes, exact word plus Space, mistakes/correction, buffered mid-dash text, pause/resume, combat, forced/natural gameover and restart. Its X11 recording, mixer recording and screenshots stay private. This run captured seven sound types, peak 7,284/32,767 and zero clipping; no blocked hit occurred. All eight event routes are unit-covered; the unchanged sound system previously captured all eight. Native Windows audio remains untested. No character or enemy art is integrated.

PERFORMANCE.md compares the same dense 14-dash route with v0.4.2. Final mean/p95 ms: Off 7.36/10.80, Low 21.68/27.45, High 38.11/46.77. All modes/versions have identical final model/RNG fingerprints. Single shared-host runs do not establish significance of small differences, Windows GPU performance or hitch-free 60fps. High is expensive on this software renderer. Only the virtual-display V-Sync warning remains in rendered logs; final tests have no script/shader/import errors.

Other limits remain human usability, alternate keyboards/OS repeat and long-session soak. Historical regional duplicate words, original camera easing/combat hit-stop and documented stable-ID/restock/stat-freeze/Resume fixes remain. Previous downloads are preserved. No screenshot/art publication, deployment or visibility change is included.
