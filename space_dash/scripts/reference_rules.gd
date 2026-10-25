extends RefCounted
## Constants transcribed from the inspected, complete grass/Space-dash snapshot.
const DT := 1.0 / 60.0
const VIEW := Vector2(960, 540)
const WORLD := Vector2(16384, 10240)
const ARENA_CENTER := Vector2(8192, 5324.8)
const ARENA_RADII := Vector2(7480, 4120)
const PLAYER_RADIUS := 10.0
const DASH_TIME := 0.22
const TIMER_MAX := 30.0
const MISTYPE_PENALTY := 0.75
const CAMERA_LERP := 0.085
const CELL := Vector2(820, 620)
const ORB_MIN := 42
const ORB_MAX := 180
const VIEW_TARGET := 18
const NEAR_TARGET := 6
const NEAR_RADII := Vector2(460, 320)
const PRUNE_DISTANCE := 2112.0
const ENEMY_HP := [1, 3, 2]
const ENEMY_SPEED := [0.55, 0.36, 0.90]
const ENEMY_RADIUS := [28.0, 36.0, 32.0]
const ENEMY_TARGET := [6, 7, 8]
const A := "ash beam bird blue boat book calm cloud coast dawn dream drift field flame float glow grain grass green grove heart hill house light meadow mist moon moss north ocean path pearl river shade shore smile spark sprout star stone storm stream sun trail water wave wind wood"
const B := "amber anchor autumn baker banner beacon border branch breeze bridge candle canyon captain castle cedar circle copper corner crystal doctor dragon ember engine feather forest garden gentle glimmer golden harbor hidden hollow island journey keeper lantern legend marble meadow memory mirror morning needle number orange planet pocket prairie puzzle quartz rocket shadow signal silver spirit spring stream summer thunder timber travel velvet violet wander whisper window winter wonder yellow"
const C := "Atlas Jasper London Mercury Monday Neptune October Saturn you're we'll don't can't isn't it's we've co-op x-ray re-entry well-made high-rise sun-lit"
const D := "afterglow archway ballad bellwether bookkeeper breakwater cathedral chrysalis clockwork crosswind daughter-in-law daybreak downstream Evergreen everything firelight goldsmith grandfather hardshell headstrong hearthstone hinterland icebound inkwell journeyman keyboard lighthouse long-form masterwork meantime midwinter moonlight newfound nightfall northbound November offshore oncoming overland paintbrush playwright pocketbook postmark raindrop roadway sailcloth schoolhouse seafaring silver-lined somewhere songbird southwest spellbound starboard stonework storyteller sunflower therefore throughout timekeeper torchlight trackside underway upstream wayfinder weathered well-known windborne wonderland workbench"

static func word_pool(difficulty: int) -> PackedStringArray:
	if difficulty == 0:
		return A.split(" ")
	if difficulty == 1:
		return (B + " " + C).split(" ")
	return (A + " " + B + " " + C + " " + D).split(" ")

static func segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))

static func directional_hit(dash_direction: float, facing: float) -> bool:
	# GML angles have reversed Y; negating BOTH angles preserves absolute difference.
	# Exact reference: abs(angle_difference(dash_dir, enemy.facing)) > 90.
	return absf(wrapf(dash_direction - facing, -PI, PI)) > PI / 2.0

static func dash_position(from: Vector2, to: Vector2, progress: float) -> Vector2:
	return from.lerp(to, 1.0 - pow(1.0 - clampf(progress, 0, 1), 3))

static func reward(word: String, distance_at_spawn: float) -> Dictionary:
	var tier := 0 if distance_at_spawn < 1271.6 else (1 if distance_at_spawn < 2842.4 else 2)
	var scale: float = [0.36, 0.68, 1.0][tier]
	return {"reward": maxf(0.32, (1.7 + word.length() * 0.34) * scale), "tier": tier}

static func words_conflict(first: String, second: String) -> bool:
	var a := first.to_lower()
	var b := second.to_lower()
	return a.begins_with(b) or b.begins_with(a)

static func tile_index(cell: Vector2i) -> int:
	# fmod/GDScript remainder follows dividend sign, matching GML before abs.
	var h := absi((cell.x * 928371 + cell.y * 52377) % 100)
	return 1 + h % 2 if h >= 86 else 0

static func arena_clamp(pos: Vector2, inset: float = 40.0) -> Vector2:
	# Elliptical interpretation of the supplied center/radii; boundary helper pending.
	var radii := ARENA_RADII - Vector2.ONE * inset
	var relative := (pos - ARENA_CENTER) / radii
	if relative.length_squared() > 1.0:
		return ARENA_CENTER + relative.normalized() * radii
	return pos
