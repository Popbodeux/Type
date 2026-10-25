# v0.4.0 performance

Godot 4.6.3, Compatibility renderer, Mesa llvmpipe OpenGL 4.5 on Linux. These are uncapped cloud software-rendered frame intervals, not Windows GPU measurements. Each run uses the same seed, Hard bank, initial 180 orbs, 900 physics ticks, 14 commanded dashes and east/west cell crossings. The first 180 ticks warm up; audio is muted and the timer refilled only for profiling. Correctness and normal survival are tested separately.

| Fixed dense route | Mean ms | p95 ms | p99 ms | Maximum ms | Catch-up frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| baseline-v0.3.0 | 6.50 | 11.00 | 14.88 | 20.43 | 0 |
| 3d-off | 7.54 | 11.04 | 14.37 | 21.58 | 0 |
| 3d-low | 10.93 | 14.89 | 17.32 | 26.15 | 1 |
| 3d-high | 12.72 | 16.42 | 20.45 | 26.92 | 1 |

Low adds 3.39 ms mean and 3.84 ms p95 over Off; High adds 5.18 ms mean and 5.37 ms p95. All three v0.4 modes finish with the identical model/RNG fingerprint, so grass quality does not alter gameplay. The v0.3 baseline has the same route commands but a different model fingerprint because calmer AI intentionally changes enemy positions and RNG consumption. Larger lettering/backplates and the entity-layer split also add some work even with grass Off.

The default is Low. High remains optional; Off disables the 3D viewport and releases its chunks. The 512-pixel chunk cache is capped at 24; only chunks intersecting the view plus a 64-pixel margin are visible. The fixed-view visual check submitted 792 cards on Low and 2598 on High (whole visible batches, including cards outside the actual screen). Four vertices per card, binary alpha cutout, no shadows/MSAA/postprocess, one shared shader/material and instancing keep the cost bounded. Noise and mask textures are generated once. No per-blade script updates occur: wind runs in the vertex shader. Separate chunks matter because Godot culls each MultiMesh as one batch.

The prior expensive spawn/conflict loops and terrain rebuilding remain optimized; see [v0.3 report](performance/v0.3.0/REPORT.md). No new spawn budgets or simulation slowdown hide render cost. Physics stays at 60 Hz. Camera easing and combat hit-stop remain intentional; neither is GPU lag. Single runs on shared hardware cannot guarantee a hitch-free Windows experience. Windows native execution, GPU profiling and long-session soak remain unrun.

Reproduce with a working X11 display:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 bash scripts/godot.sh --audio-driver Dummy -- --profile --fixed-dense --grass=low --output=res://artifacts/profile-low.json
```

Repeat for `off` and `high`. Raw results are in `performance/v0.4.0/`. The earlier 2D grass prototype was discarded; these final files measure the real 3D layer.
