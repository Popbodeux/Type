# v0.2.0 validation

Observed with Godot4.6.3.stable.official.7d41c59c4 on Linux x86_64, Compatibility rendering, Mesa llvmpipe OpenGL4.5. This is a reconstruction from the selected GameMaker source-inspection reports, not an original-executable comparison.

| Check | Result |
| --- | --- |
| Model regression runner | **1390 assertions passed,0 failed** |
| Source import/parser and startup | Passed; final loader uses PNG byte decoding/imported texture fallback without the earlier image-file export warning |
| Source rendered gameplay | Two input-driven sessions passed, including Space, mid-dash queue, pause/resume, forced/natural gameover and R/Enter restart |
| Original PNGs | Three supplied file SHA-256 hashes,16×16 dimensions and decoded RGBA hashes verified; actual pixels inspected |
| Windows release export | Succeeded with checksum-verified official4.6.3 x86_64 templates |
| Windows ZIP | CRC/member whitelist/extraction passed; PE32+ x86_64 executable matches the verified official template |
| Exported Windows game pack under Linux | Headless startup and two rendered sessions passed; all three original PNGs and decoded pixels verified inside the actual pack |
| Rendered terrain | Original PNG+hash+32px scale+nearest sampling+tint checks passed separately for all three variants |
| Windows executable on Windows/Wine | **Not run** |

The model assertion total includes repeated per-orb/pairwise checks. It does not mean1390 independent scenarios or human play sessions.

| Assertion category | Passed |
| --- | ---: |
| combat_source_expression_and_order | 22 |
| dash_buffering_and_timing | 11 |
| enemy_rates_contact_and_hitstop | 10 |
| mistakes_and_backspace | 8 |
| population_and_reset | 1251 |
| reference_constants | 14 |
| resolved_helper_parity_and_guards | 31 |
| selection_and_space_confirmation | 15 |
| stats_pause_gameover_save | 10 |
| terrain_hash_and_repeatability | 18 |

The terrain checker samples the actual rendered playfield, derives world coordinates from the captured camera, and compares against the original PNG pixels, source cell hash,2× nearest sampling and RGB(178,236,136)tint. Per-variant match rates for the exported pack were **95.1% / 96.2% / 91.2%** across12920 samples. Text/actors explain nonmatching covered samples; each variant exceeded the80% diagnostic threshold. This validates the ground component, not full original-game visual parity.

The supplementary MP4 is an actual X11 recording of the exported game pack controlled by engine mouse/key events. Only the9.2-second startup wait and trailing blank display were trimmed, then the clip was re-encoded. No gameplay was replaced by a scripted concept animation. The first run deliberately tests Shift+Q gameover; the second ends through normal timer/contact rules.

Only the virtual-display V-Sync warning remains in the final packaged rendered run. The earlier source image-loader warning was corrected before the final pack was built and tested. Package tests use an isolated writable save path rather than writing into the read-only pack.

Known limitations: original actors and audio are absent; UI geometry and camera shake are not a pixel-perfect port; GameMaker/Godot RNG sequences differ; historical duplicate words can later share a viewport and the first exact match wins. Bounded restock loops, stable IDs, frozen gameover stats and Resume hitbox alignment are deliberate documented safety fixes. See PARITY.md.

Windows OS execution, human usability, alternate keyboard layouts/OS repeat behavior and long-session/performance tests remain unrun. Export success and Linux execution of the Windows pack do not establish Windows runtime compatibility. No hosted game deployment or repository visibility change is part of this delivery.
