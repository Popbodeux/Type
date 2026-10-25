# v0.4.2 short meadow and oblique camera performance

Godot 4.6.3, Linux x86_64, Compatibility renderer, Mesa llvmpipe OpenGL 4.5 software rendering. Each run uses the same seed, Hard bank, initial 180 orbs, 900 fixed physics ticks, 14 east/west dashes and cell crossings. First 180 ticks warm up. Audio is muted and the timer is refilled only for profiling; normal survival/input is verified separately. These are uncapped frame intervals, not native Windows measurements.

| Fixed dense route | Mean ms | p95 ms | p99 ms | Maximum ms | Catch-up frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| off | 7.26 | 10.80 | 14.52 | 25.45 | 0 |
| initial-low | 27.68 | 34.25 | 36.14 | 45.91 | 286 |
| initial-high | 38.61 | 47.63 | 53.88 | 68.83 | 306 |
| low | 21.42 | 25.94 | 29.58 | 38.40 | 160 |
| high | 36.76 | 44.13 | 48.86 | 55.89 | 318 |

The first short-meadow attempt used three cluster cards per Low cell and separate cloud/wind noise lookups. Final Low uses two cluster cards per cell, each original mask containing seven fine blades, and shares the broad gust/cloud lookup. This cut Low mean 27.68→21.42ms and p95 34.25→25.94ms. High retains four cluster cards per cell; the shader change reduced mean 38.61→36.76ms. Low grass renders at 800×450 to avoid losing fine blades; High is 960×540. Actors/text remain native 960×540 in both. About 98–100 percent of 16px cells are eligible before tiny random gaps; broad bare clearings are removed.

The current 15-degree orthographic camera maps roots from 2D Y to 3D Z/cos(tilt), preserving screen-ground anchors without stretching actual cards. Card height 18×0.90–1.12 is much shorter than the previous 38×0.74–1.42. Mild lean 0.18, smaller height variation, softened ambient/direct lighting, static multiscale green patches and slow coherent wind/cloud tint produce the requested meadow direction. Color noise is evaluated once per clump on chunk creation; there is no per-blade CPU animation. All batches remain real MultiMeshInstance3D, 256px chunks, 48-chunk cache, alpha scissor, no shadows/MSAA/postprocess. Ground is still one untextured flat canvas rectangle; no old pixel tile texture is used.

Every initial/final quality run has an identical final model/RNG fingerprint. Camera/scenery changes do not alter simulation. The previous v0.4.1 Low mean 17.10ms was cheaper but used taller isolated card tufts and a lower 640×360 grass resolution. This revision deliberately trades some scenery cost for finer continuous grass. Reports/raw data for earlier versions remain in performance/v0.4.1/ and v0.4.0/.

These are individual shared-host software-rendered runs, not controlled hardware benchmarks. Final Low reached 38.40ms maximum; High 55.89ms. High is expensive on this software GPU and is optional. Off skips the 3D pass. There is no claim of hitch-free 60fps, Windows GPU/audio execution or long-session soak. Fixed physics stays 60Hz; original camera easing and combat hit-stop remain separate intentional behavior. Recording with FFmpeg adds load and was not running during these profiles.

Reproduce with a working display:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 bash scripts/godot.sh --audio-driver Dummy -- --profile --fixed-dense --grass=low --output=res://artifacts/profile-low.json
```

Repeat off/high. Projection and actual front/back normals are independently verified with `tests/test_projection.gd -- --render`. Raw numeric results are public in performance/v0.4.2/; all screenshots, diagnostics, user references, new recording and character assets stay private.
