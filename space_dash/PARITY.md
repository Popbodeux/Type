# Grass / Space-to-dash revision: parity checklist

This separate Godot project reconstructs the user-selected, complete original grass-ground snapshot from a read-only source-inspection report. It is **not** a grass reskin of Chi Circuit. The original GameMaker executable has not been run here, and full behavioral/visual parity is not claimed.

The earlier Chi Circuit and v0.2.0 downloads are preserved. This separate `space_dash/` project now uses versioned v0.3.0 paths. Explicit user playtest requests supersede historical behavior where noted below.

## v0.3.0 requested changes

Neutral words highlight only accepted matching prefix characters. Bodies remain faint until typing; matching candidates light together and then only a unique/exact selected body stays lit. Text and body selection feedback are independent. Typo rejection preserves accepted state, Backspace updates it, and dash/reset clears it. No speculative sparks, completion pulses or per-orb glow shaders were added; existing feedback/trails remain.

All enemy kinds now wander when distant, acquire at240world pixels, and disengage beyond340, with hysteresis. Kind2's always-chase behavior is intentionally removed; wanderers face their heading. The historical ranges in the reference table below do not override this requested policy.

Prefix-set eligibility, spatial spacing checks, one coverage pass per active tick, incremental counts and bounded cached terrain replace wasteful work. Word pools, caps/targets, duplicate-entry weighting, rectangular conflicts and spacing remain. Exhausted-word retries are skipped, changing RNG consumption/layout in that case. See PERFORMANCE.md for before/after evidence and limits.

## Implemented source-derived rules

| Area | Implementation and verification |
| --- | --- |
| Runtime | Explicit 60-Hz physics reproduces source frame-based enemy movement and camera lerp. Timers use fixed 1/60-second steps. Same-seed replay is deterministic. |
| Targeting | Case-sensitive prefix matching within inclusive24px camera bounds. First exact match in array order wins; otherwise an existing matching lock survives, then a sole match locks. Backspace uses sole-match-only selection. Confirmation does not recheck visibility. |
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
| Orbs |42minimum/180maximum, viewport target18 and near ellipse target6. Cell seeding attempts220calls for10successes in24px-inset cells (12px fallback for small axes). Placement uses96/64/64samples at104/68/36spacing, two initial overwritten draws, and fresh unspaced fallback. Eligible bank entries are enumerated with duplicate weighting. Conflict checks use the encompassing bounding rectangle of region and full viewport, inclusively. |
| Coverage | Initial restock samples player±1100/850 clipped to orb bounds. Per-frame global restock uses the full arena. Local coverage prunes beyond2112, then makes up to32near-player calls and80viewport calls. Cell crossing and arrival also invoke coverage. |
| Reward | Stored at spawn: max(0.32,(1.7+word_length×0.34)×scale). Distances strictly below1271.6 use0.36/tier0; below2842.4 use0.68/tier1; otherwise1/tier2. Boundary tests included. |
| Stats | Accuracy correct/total, initially100%; gross WPM total×12/elapsed; displayed WPM gross×accuracy. Space/Backspace excluded. Best updates after1.5seconds and5keystrokes. |
| Session / save | Mouse difficulty and NEW GAME; default Normal. Escape pause/resume clears typing on entry. Mouse resume/exit. R or Enter restarts gameover; Shift+Q forces it. High score uses `user://typergame_save.ini`, section`run`, key`high_score`. Reset clears run state and returns player to center+60Y without explicitly snapping camera. |
| World / camera | World16384×10240, center(8192,5324.8), rectangular orb bounds X767–15617/Y1259.8–9389.8. Enemy spawn/movement clamp at40/35inset. Camera starts at arena center, clamps its target before0.085lerp, uses pre-update coordinates for selection/spawning, and rounds only for drawing. |
| HUD | Top-center numeric timer and240×10 bar, red below8seconds; points/WPM/accuracy/best/streak upper-left, accepted text bottom-center, red mistake flash, gameover stats and restart instructions. No three-wave victory or vitality system. |

## Deliberate fixes

- Statistics and elapsed-run time stop at gameover, rather than continuing behind the results screen. They still advance during hit-stop, as the source specifies.
- Pause Resume drawing and clicks use the **same rectangle** starting at50% of height, fixing the source's drawn50%/clickable52% mismatch. The rendered test clicks the formerly missed top edge.
- The two legacy unbounded minimum-restock loops have a256-call guard and stop when no eligible word exists. Other supplied placement/coverage budgets are preserved. This avoids a possible hang, so42 is a target rather than an unconditional guarantee under exhausted word pools.
- Active/dash targets use stable IDs. Pruning cannot silently change the selected orb or grant another orb's reward because an array index shifted. A removed active target is invalidated safely.

## Original grass: verified and integrated

The user approved publishing the three tiles and this revision. The tiles were transferred through verified asset commit `c9089c5279cfa329a7e46650415a1935d2456e66`, then merged without force updates. The original source PNGs remain unchanged in `reference_assets/original_grass/` and are copied byte-for-byte into this self-contained project.

Originals: `env_grass_plain_00.png`199bytes, `env_grass_plain_01.png`185bytes, `env_grass_plain_04.png`194bytes. File hashes,16×16 dimensions, and decoded RGBA hashes were verified and the actual pixels inspected. The loader also verifies decoded pixels when Godot exports remap PNGs to imported textures.

The ground implements the source cell hash,86%plain/7%each variant,32px world cells, nearest-neighbor sampling, RGB(178,236,136)tint, opacity1, and viewport-plus-one-tile coverage. Screenshot sampling separately checks all three variants against those original pixels and transforms, allowing for text/actor overlays. Actor art and miss audio are unavailable: actors use provisional shapes and the miss has visual feedback only. Ground verification is not a claim of full original-game visual parity.

## Resolved source helpers and remaining limitations

Follow-up source inspection resolved the prior helper gaps. Rectangular bounds, placement regions/budgets, uniform eligible-entry choice,40px enemy view margin, pre-fill visible counter, integer enemy spawn radius,78%hurt retention, max hit-stop aggregation, and initial camera position are implemented. Text entered during pause/dash/hit-stop is retained; text processing precedes Space/Backspace edges. Mouse resume skips that update; Escape resume can continue immediately.

**Historical duplicate behavior is intentionally preserved.** Far-region duplicates can enter a moving viewport together. The original has no reconciliation pass and selects the first exact match. The highlighted target/route preview identifies which orb will be used; there is no separate typed command to choose its identical counterpart. This is a known legacy limitation, not silently replaced with global deduplication.

Godot and GameMaker do not use the same RNG algorithm, so matching seeds do not imply identical random worlds across engines. Fixed60Hz behavior is deterministic within this implementation. Exact original actor rendering, menu geometry, camera shake, audio, executable comparison, and OS-specific repeat/input behavior remain unverified. No ellipse collision, distance cap, dash invulnerability, three-wave victory, or invented weak-side rule was added.

## Validation and delivery limits

Run `bash scripts/godot.sh --headless --script res://tests/test_survival.gd` from this folder. Tests generate a category breakdown under ignored `artifacts/`. Assertions include repeated per-orb/pairwise coverage checks; the assertion total is not a count of independent scenarios or human play sessions. The old root project's551assertions belong to Chi Circuit, not this revision.

The rendered playback uses actual engine mouse/key events on the normal scene and exported pack, testing mid-dash queued text, Space confirmation, pause/resume top-edge clicking, forced/natural gameover, and R/Enter restart. It records real gameplay, not a concept animation.

The versioned deliverable is a standalone Windows x86_64 ZIP with official Godot4.6.3 release templates. Export/PE/archive checks and Linux execution of its actual game pack are separate from Windows runtime testing: **the Windows executable has not been run on Windows or Wine**. Human usability, alternate layouts, and long-session checks are unrun; representative cloud performance profiles are reported separately. The older downloads are preserved at their original paths.
