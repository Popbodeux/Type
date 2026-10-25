# v0.3.0 movement performance

Baseline: v0.2.0 gameplay at commit91249f1a8b5cb7ba8b7d87464de6fe25300ca97d, with timing probes added before gameplay changes. After: the v0.3.0 corrections. Both used Godot4.6.3,960×540, fixed60Hz physics, Linux/Xvfb and Mesa llvmpipe OpenGL4.5. No FFmpeg capture ran during timing profiles. No user desktop/display/GPU settings were accessed.

## Measured cause

Synchronous cell seeding caused large CPU hitches, dominated by repeated word-bank×orb conflict scans and placement work. Baseline normal cell-crossing ticks reached138.7ms; dense crossings reached368.1ms. Enemy update CPU was normally only hundredths of a millisecond. The problem reproduced headlessly, independently of camera easing and GPU rendering.

The fixes cache bank prefixes and eligible relevant-word sets, use a spatial grid for spacing, reject exhausted word regions before futile positional sampling, stop retries that cannot change word eligibility, consolidate arrival/cell/global coverage into one pass per active tick, and update coverage counts incrementally. Population targets/caps, weighted bank entries, rectangular conflict checks, spacing tiers and valid placement rules remain. Exhausted-region RNG consumption can differ; matching the old random sequence is not a goal of this user-requested performance fix.

Terrain now uses24bounded512px texture chunks containing exact original pixels; unchanged areas reuse uploaded textures instead of rebuilding hundreds of per-tile draw commands. Label widths are cached. Prefix/body feedback uses inexpensive glyph colors and circle alpha; no glow shader, spark system or completion pulse was added. Compatibility rendering/export settings remain unchanged.

## CPU model timing (milliseconds)

| Workload/metric | Before | After |
| --- | ---: | ---: |
| stationary tick mean_ms | 0.206 | 0.081 |
| stationary tick p95_ms | 0.132 | 0.106 |
| stationary tick p99_ms | 2.947 | 0.311 |
| stationary tick max_ms | 13.159 | 1.362 |
| repeat_dash tick mean_ms | 2.119 | 0.298 |
| repeat_dash tick p95_ms | 4.475 | 0.636 |
| repeat_dash tick p99_ms | 9.320 | 1.898 |
| repeat_dash tick max_ms | 138.679 | 13.958 |
| dense_repeat_dash tick mean_ms | 4.584 | 0.324 |
| dense_repeat_dash tick p95_ms | 10.809 | 0.769 |
| dense_repeat_dash tick p99_ms | 49.118 | 1.994 |
| dense_repeat_dash tick max_ms | 368.149 | 14.176 |

Stationary sampled180ticks; normal and dense workloads each sampled720ticks. Dense began with180orbs, normal with90. The same seed/controller was used, but proximity AI and changed RNG consumption mean routes are not bit-identical: normal completed19dashes/7crossings before and20/11after; dense18/11before and17/11after. The harness refills the survival timer only to sustain profiling; it is not a survival/correctness test. Nested method totals overlap and must not be added.

## Rendered repeat-dash timing

These are uncapped Linux software-rendered frame intervals, not claimed Windows FPS. First3seconds were warm-up; source actor movement/typing/dashes ran normally with a profiling-only timer refill.

| Metric | Before | After |
| --- | ---: | ---: |
| Frame interval p95 ms | 18.102 | 9.079 |
| Frame interval p99 ms | 28.041 | 12.342 |
| Frame interval maximum ms | 174.665 | 63.524 |
| Model tick CPU p95 ms | 4.858 | 0.945 |
| Model tick CPU maximum ms | 166.788 | 9.923 |
| Draw submission CPU mean ms | 0.904 | 0.723 |
| Draw calls/frame mean | 389.405 | 173.780 |
| Frames with more than one physics tick | 18 | 3 |

The rendered baseline completed26dashes and seeded44cells; after completed28dashes and seeded43cells. Individual wall-time outliers remain: the after run still reached63.5ms despite much smaller script costs. Software GPU/OS scheduling can contribute, but this run does not establish the cause of that residual outlier. These are representative single profiles on a shared cloud machine, not a guarantee of hitch-free play or the performance of the user’s Windows GPU.

The original0.085per-tick camera easing (roughly0.19-second time constant) and configured30–75ms combat hit-stop remain intentional. Hit-stop freezes simulation by rule while rendering continues; it is separate from the former expensive CPU ticks. Physics remains60Hz; no slowdown was hidden by lowering simulation rate.

Raw results are in performance/v0.3.0/. Reproduce from this project using:

```sh
bash scripts/godot.sh --headless --script res://tests/profile_model.gd -- --output=res://artifacts/performance/model-after.json
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 bash scripts/godot.sh --audio-driver Dummy -- --profile --output=res://artifacts/performance/render-after.json
```

Windows native execution/GPU profiling, long-session memory/performance and human feel testing remain unrun. The standalone Windows build is provided for that desktop playtest.
