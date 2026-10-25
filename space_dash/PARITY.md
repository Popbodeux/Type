# Grass / Space-to-dash revision: parity checklist

This separate Godot project reconstructs the user-selected, complete original grass-ground snapshot from a read-only source-inspection report. It is **not** a grass reskin of Chi Circuit. The original GameMaker executable has not been run here, and full behavioral/visual parity is not claimed.

The delivered Chi Circuit source and downloads remain unchanged at commit `6050a57787a0eda6d7d4644561100674e192dbd5`. This revision is local on branch `grass-space-survival`; no new export or public upload has been performed.

## Implemented source-derived rules

| Area | Implementation and verification |
| --- | --- |
| Runtime | Explicit 60-Hz physics reproduces source frame-based enemy movement and camera lerp. Timers use fixed 1/60-second steps. Same-seed replay is deterministic. |
| Targeting | Case-sensitive prefix matching; only orb centers within the camera viewport inset24 can be newly selected. A sole prefix match locks a target; an exact accepted word can lock immediately. Backspace recomputes the sole match. |
| Confirmation | Completing a word alone does not move. Space requires the complete buffer to equal the active orb's word; empty/incomplete/repeated Space does nothing. Completed-word/character/streak counters update only on successful confirmation. |
| Mid-dash input | Text is queued while dash processing is suspended, and processed on the first subsequent input tick. Backspace edits queued text. A Space press edge during dash/hit-stop is not replayed later. Explicit model tests and live keyboard playback cover this interpretation of retained GameMaker `keyboard_string`. |
| Errors | Every processed non-space/non-newline character counts; wrong characters are rejected, cost0.75 seconds, reset combat combo and word streak, and flash red for0.18 seconds. Backspace has no accuracy/time penalty. |
| Dash | Constant0.22 seconds, cubic ease-out. No dash-distance cap or wall collision. Damage resolves once immediately against the whole start-to-target segment; no second movement-time hit. |
| Combat | Hit radius = enemy radius +5.5. Kind1 uses the literal strict absolute angle difference>90 rule, not Chi Circuit's invented vulnerable-side system. One HP per valid hit; +0.65seconds/hit; kills additionally +1.5seconds and14×combo points. Reverse enemy-index iteration is tested with a case where reversing changes the kill score. |
| Push / stop | Logical push uses X18/Y12 along dash direction; initial visual offset X16/Y11. Hit-stop0.045 on surviving hit,0.075 on kill,0.03 on block. Hit-stop suspends drain, movement, and input processing while elapsed/stat time advances. |
| Blocks / contact | Blocks cost1.1seconds and reset only combat combo. Every overlapping kind0/1 drains3seconds/second; kind2 drains5seconds/second. Rates accumulate, with no contact cooldown or dash immunity. |
| Arrival | Grants the orb's stored spawn-time reward, caps timer at30, removes that orb only, and replenishes coverage. |
| Enemies | Source HP1/3/2, radii28/36/32, base speeds0.55/0.36/0.90 per60-Hz frame; chase ranges and multipliers440×1.2 and340×0.95, always-chasing kind2, chase Y×0.72, wander Y×0.55 and heading jitter±3degrees/frame. Facing updates toward player. Initial kinds[0,0,1,2]. |
| Enemy spawn | Radius280–620, elliptical Y×0.72, clamped with40inset. Difficulty population targets6/7/8 with a local supplement; helper details below remain provisional. |
| Words / difficulty | Exact supplied A/B/C/D pools, including case, apostrophes, hyphens, and Hard's duplicate entries. Easy48, Normal90, Hard208. Difficulty changes word pool/population, not initial timer or enemy base stats. |
| Orbs | Global42minimum/180maximum; viewport inset(56,42) target18; player-near ellipse(460,320) target6. Seed surrounding3×3 cells of820×620 once, up to10placements/cell. Spacing tiers104/68/36 followed by bounded random fallback. Reject case-insensitive duplicate/whole-word-prefix conflicts in placement-region/viewport union. Prune beyond2112. |
| Reward | Stored at spawn: max(0.32,(1.7+word_length×0.34)×scale). Distances strictly below1271.6 use0.36/tier0; below2842.4 use0.68/tier1; otherwise1/tier2. Boundary tests included. |
| Stats | Accuracy correct/total, initially100%; gross WPM total×12/elapsed; displayed WPM gross×accuracy. Space/Backspace excluded. Best updates after1.5seconds and5keystrokes. |
| Session / save | Mouse difficulty and NEW GAME; default Normal. Escape pause/resume clears typing on entry. Mouse resume/exit. R or Enter restarts gameover; Shift+Q forces it. High score uses `user://typergame_save.ini`, section`run`, key`high_score`. Reset clears run state and returns player to center+60Y without explicitly snapping camera. |
| World / camera | World16384×10240, arena center(8192,5324.8), radii(7480,4120); viewport960×540; camera lerp0.085 per fixed frame. |
| HUD | Top-center numeric timer and240×10 bar, red below8seconds; points/WPM/accuracy/best/streak upper-left, accepted text bottom-center, red mistake flash, gameover stats and restart instructions. No three-wave victory or vitality system. |

## Deliberate fixes

- Statistics and elapsed-run time stop at gameover, rather than continuing behind the results screen. They still advance during hit-stop, as the source specifies.
- Pause Resume drawing and clicks use the **same rectangle** starting at50% of height, fixing the source's drawn50%/clickable52% mismatch. The rendered test clicks the formerly missed top edge.

## Original grass: blocked on supported transfer

The private asset migration package is confirmed elsewhere, but **not materialized in this executor**. There is no exposed Library skill/resolver/materialization API, neither skill catalog lists Library, and no supplied ZIP exists in the local Library/shared folders. The available `download_file` accepts Sediment files only, not the supplied Library/File Service reference. No alternate fetch route or public republication was attempted.

Required originals: `env_grass_plain_00.png`199bytes, `env_grass_plain_01.png`185bytes, `env_grass_plain_04.png`194bytes. Approved hashes are encoded in `scripts/survival.gd`; the loader rejects mismatched content or non-16×16 images. Once properly materialized, actual pixels must be inspected before claiming ground fidelity.

The renderer already implements the supplied cell hash and86%/14% variant rule,32px world cells, nearest-neighbor sampling, RGB(178,236,136) tint, opacity1, and viewport-plus-one-tile coverage. While originals are absent it visibly labels and uses the source's own checkerboard fallback: RGB(78,152,88)/(98,176,102). This is **not original-grass visual parity**. Actor art and miss audio are also unavailable; actors use clearly provisional shapes and the miss has visual feedback only.

## Source details not supplied; provisional implementation choices

These cannot be called source-exact until the corresponding original helper code is inspected:

- Arena boundary helper: currently interpreted as ellipse clamping from the supplied center/radii; exact source boundary and camera-edge handling are unverified.
- Placement attempt counts:16attempts per104/68/36spacing tier, then unspaced fallback; bounded word retries and maintenance attempt budgets. The report supplies tiers/fallback, not these counts or the exact random sampling distribution.
- Global minimum restock region and near-player candidate sampling; cell/viewport/local targets themselves match the supplied values.
- Existing far-region duplicate words can later enter the moving viewport together. This was observed in the diagnostic playback; only spawn-time region/viewport conflict rejection was supplied. Post-movement duplicate reconciliation and exact-target tie ordering need the original helper before changing that behavior.
- Enemy maintenance uses a provisional180px expanded-view margin and caps local supplements at population target+2; subsequent spawn kinds are uniformly selected because source weighting was not supplied.
- Multi-hit hit-stop combines durations by maximum; assignment/aggregation order was not included in the report.
- Initial camera position, sprite/rendering geometry, hurt-offset decay, exact title/menu layout, key-repeat details, and text typed while paused need source confirmation. Paused input is currently ignored; dash/hit-stop text is explicitly retained.
- Miss sound, original actor sprites, other sound assets, and original executable rendering comparison remain unavailable.

## Validation and delivery limits

Run `bash scripts/godot.sh --headless --script res://tests/test_survival.gd` from this folder. Tests generate a category breakdown under ignored `artifacts/`. Assertions include repeated per-orb/pairwise coverage checks; the assertion total is not a count of independent scenarios or human play sessions. The old root project's551assertions belong to Chi Circuit, not this revision.

The rendered playback uses actual engine mouse/key events on the normal scene, tests mid-dash queued text, Space confirmation, pause/resume top-edge clicking, forced/natural gameover, and R/Enter restart. Its recording is internal diagnostic evidence with the fallback explicitly marked; it is not a final playtest deliverable.

**No final Windows export yet.** It remains blocked on original asset materialization/pixel inspection and parity review. No new public upload is authorized, and private asset-migration approval does not authorize publishing sprite bytes. The prior Windows download remains intact. Windows runtime, human usability, alternate input layouts, and long-session/performance checks are unrun for this revision.
