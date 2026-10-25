# v0.4.3 fixed-axis grass performance

Godot 4.6.3, Linux x86_64, Compatibility renderer and Mesa llvmpipe OpenGL 4.5 software rendering. Same seed, Hard bank, initial 180 orbs, 900 fixed physics ticks, 14 east/west dashes/cell crossings, 180 warm-up ticks. Audio is muted and survival time refilled only for profiling; FFmpeg is not running. These are uncapped frame intervals, not Windows hardware measurements.

| Quality | Random yaw mean ms | Fixed axis mean ms | Random p95 ms | Fixed p95 ms | Fixed maximum ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| off | 7.26 | 7.36 | 10.80 | 10.80 | 24.81 |
| low | 21.42 | 21.68 | 25.94 | 27.45 | 42.71 |
| high | 36.76 | 38.11 | 44.13 | 46.77 | 63.55 |

Low remains default at 800×450 for grass, while actors/text stay native 960×540. High uses native grass resolution and twice as many cluster cards per eligible cell. Off skips the 3D pass. Low mean changed 21.42→21.68ms; High 36.76→38.11ms. Shared-host/single-run noise prevents strong claims about these small differences. High is expensive on software rendering; no hitch-free 60fps or Windows performance guarantee is claimed. Maximum intervals and raw numeric evidence remain visible above and under performance/v0.4.3/.

No additional cards, density, mask, lighting, ground shader, camera or rendering pass was added. Only field yaw and wind displacement changed. All widths align world +X, heights stay world +Y and baked lean stays toward world −Z. World +X is screen-left/right under the unchanged 15-degree camera. Tips now receive a mild positive +X breeze, retaining coherent phase variation and anchored roots. The same number of cards face the camera more uniformly, increasing visible leaf coverage. Source fixed-view High normal-debug coverage was 270,197 opaque pixels versus 155,588 for random yaw; both passed all world-up pixels. This is a visible-coverage diagnostic, not an overdraw count or timing attribution.

All new quality runs and v0.4.2 baselines end with the identical model/RNG fingerprint. Gameplay, spawning and physics remain unchanged. Existing alpha cutout, 256px batch culling, 48-chunk cache, local scale, world-up fragment normals and source spawn optimizations are retained. There is no extra polish or renderer redesign in this direction test.

Actual same-camera/seed private frames show more uniformly upward grass with fewer sideways/edge-on cards, but faint horizontal bands remain visible. This is a bounded playtest hypothesis rather than an exact match to the user's reference. Previous reports/data are preserved in performance/v0.4.2/ and earlier. Screenshots and references remain private.

Reproduce with a display:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 bash scripts/godot.sh --audio-driver Dummy -- --profile --fixed-dense --grass=low --output=res://artifacts/profile-low.json
```

Repeat off/high. `tests/test_projection.gd -- --render` separately verifies actual card orientation, projection and both-face normals. Native Windows OS/GPU/audio, human usability and long-session soak remain untested. Original camera easing and combat hit-stop remain intentional behavior, distinct from frame cost.
