# v0.4.1 solid ground and lush grass performance

Godot 4.6.3, Linux x86_64, Compatibility renderer, Mesa llvmpipe OpenGL 4.5 software rendering. Same seed, Hard bank, initial 180 orbs, 900 fixed physics ticks, 14 east/west dashes and cell crossings; first 180 ticks warm up. Audio is muted and the timer refilled only for profiling. These are uncapped frame intervals, not native Windows GPU measurements or correctness tests.

| Dense fixed route | Mean ms | p95 ms | p99 ms | Maximum ms | Catch-up frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| off | 6.50 | 9.38 | 13.17 | 29.21 | 0 |
| dense512-low | 24.15 | 29.44 | 33.65 | 67.35 | 220 |
| dense512-high | 36.74 | 45.14 | 49.19 | 71.82 | 320 |
| dense256-native-low | 21.66 | 26.27 | 30.67 | 39.91 | 167 |
| low | 17.10 | 21.42 | 25.12 | 35.53 | 32 |
| high | 32.27 | 38.25 | 44.01 | 83.11 | 330 |

`dense512` is the first dense attempt with 512px batches and the earlier local-space shader. Smaller 256px batches and a documented world-space shader remove unnecessary offscreen instances and per-vertex matrix inversions. This reduced native Low from 24.15 to 21.66ms and High from 36.74 to 32.27ms mean. Final Low further renders only grass at 640×360 and composites into the 960×540 canvas, giving **17.10ms mean / 21.42ms p95**. Actors, text, targeting and world coordinates stay native. High uses more blades and a native 960×540 grass pass, **32.27ms mean / 38.25ms p95**. It is an optional visual setting; it is expensive on this software GPU. Low is default; Off skips the 3D viewport entirely.

All recorded runs have an identical final model/RNG fingerprint. Density, culling, shader and resolution changes do not alter gameplay. The previous sparse v0.4.0 Low averaged 10.93ms and High 12.72ms; this revision intentionally spends more rendering work for the requested fuller grass. These independent runs have OS/shared-host noise and are not a controlled GPU benchmark. The new solid-ground Off averaged 6.50ms versus the prior tile-ground Off 7.54ms; ground now uses one untextured canvas rectangle, no tile loading, CPU composition or texture cache. Prior raw data and reports remain under performance/v0.4.0/.

Clumps sample a 32px grid, vary height/yaw/tint, use five cards on Low and eight on High, and leave small path/clearing gaps. Fixed-view inspection submitted 5,925 cards on Low and 11,192 on High across 24 visible 256px chunks, including offscreen cards in intersecting batches. A 48-chunk LRU bounds travel memory. The alpha-cutout mask is original, shared and generated once. Four-vertex instanced cards, shader wind, disabled shadows/MSAA and modest blade overlap bound draw/overdraw cost; no per-blade script updates or expensive postprocess glow are used. Culling is batch-wide as documented by Godot.

This is not hitch-free 60fps certification. Final Low reached 35.53ms and High 83.11ms maximum; performance on the user's Windows hardware remains untested. Camera easing and 30–75ms combat hit-stop remain intentional and separate from rendering. Physics remains 60Hz. No long-session soak or native Windows profiling was run.

Reproduce with a working display:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 bash scripts/godot.sh --audio-driver Dummy -- --profile --fixed-dense --grass=low --output=res://artifacts/profile-low.json
```

Repeat `off`/`high`. Raw intermediate/final results are in performance/v0.4.1/. Current ground and normal checks are `tests/render_scenery.gd` and `tests/check_ground_pixels.py`. Screenshots stay private and are not committed.
