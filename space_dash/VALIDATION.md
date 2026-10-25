# v0.3.0 validation

Observed with Godot4.6.3.stable.official.7d41c59c4 on Linux x86_64, Compatibility rendering, Mesa llvmpipe OpenGL4.5. This is a reconstruction from the selected GameMaker source-inspection reports, not an original-executable comparison.

| Check | Result |
| --- | --- |
| Model regression runner | **1390 assertions passed,0 failed** |
| New playtest-fix runner | **61 assertions passed,0 failed**: progressive feedback, faint/candidate/selected bodies, typo/Backspace/dash/reset, all-kind aggro/leash/hysteresis, optimized eligibility equivalence, terrain-cache reuse/bounds |
| Source import/parser and startup | Passed; final loader uses PNG byte decoding/imported texture fallback without the earlier image-file export warning |
| Source rendered gameplay | Two input-driven sessions passed, including Space, mid-dash queue, pause/resume, forced/natural gameover and R/Enter restart |
| Original PNGs | Three supplied file SHA-256 hashes,16×16 dimensions and decoded RGBA hashes verified; actual pixels inspected |
| Windows release export | Succeeded with checksum-verified official4.6.3 x86_64 templates |
| Windows ZIP | CRC/member whitelist/extraction passed; PE32+ x86_64 executable matches the verified official template |
| Exported Windows game pack under Linux | Headless startup and two rendered sessions passed; all three original PNGs and decoded pixels verified inside the actual pack |
| Rendered terrain | Original PNG+hash+32px scale+nearest sampling+tint checks passed separately for all three variants |
| Windows executable on Windows/Wine | **Not run** |

The combined1451assertions are not1451independent scenarios. The model assertion total includes repeated per-orb/pairwise checks. It does not mean1390 independent scenarios or human play sessions.

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

The terrain checker samples the actual rendered playfield, derives world coordinates from the captured camera, and compares against the original PNG pixels, source cell hash,2× nearest sampling and RGB(178,236,136)tint. Per-variant match rates for the exported pack were **98.1% / 97.9% / 95.6%** across12920 samples. Text/actors explain nonmatching covered samples; each variant exceeded the80% diagnostic threshold. This validates the ground component, not full original-game visual parity.

The supplementary MP4 is an actual X11 recording of the exported game pack controlled by engine mouse/key events. Only the9.167-second startup wait and trailing blank display were trimmed, then the clip was re-encoded. No gameplay was replaced by a scripted concept animation. The first run deliberately tests Shift+Q gameover; the second ends through normal timer/contact rules.

Only the virtual-display V-Sync warning remains in the final packaged rendered run. The earlier source image-loader warning was corrected before the final pack was built and tested. Package tests use an isolated writable save path rather than writing into the read-only pack.

Known limitations: original actors and audio are absent; UI geometry and camera shake are not a pixel-perfect port; GameMaker/Godot RNG sequences differ; historical duplicate words can later share a viewport and the first exact match wins. Bounded restock loops, stable IDs, frozen gameover stats and Resume hitbox alignment are deliberate documented safety fixes. See PARITY.md.

Windows OS execution, human usability, alternate keyboard layouts/OS repeat behavior and long-session/performance tests remain unrun. Export success and Linux execution of the Windows pack do not establish Windows runtime compatibility. No hosted game deployment or repository visibility change is part of this delivery.

## Playtest corrections

The source and exported pack also capture neutral idle labels, shared-prefix feedback, unique incomplete prefixes and completed words. Unit checks cover correct prefix colors/counts independently of selected body lighting, rejected typo preservation, Backspace re-expansion, dash/reset clearing and duplicate exact-target body selection. Every kind is tested wandering at distance, entering240px aggro, retaining it through340px, disengaging beyond340, re-acquiring nearby and avoiding whole-map pursuit.

PERFORMANCE.md and performance/v0.3.0/ contain before/after evidence. The measured heavy work was synchronous cell seeding/conflict scanning; it was not inferred from camera lag alone. Rendered p95 intervals improved18.1→9.1ms, with a63.5ms residual maximum. Cloud software rendering, representative profiles and the altered AI/RNG routes limit comparisons. No Windows GPU performance guarantee, native Windows execution, new per-orb shader/effect, or user display/GPU-setting change is claimed.
