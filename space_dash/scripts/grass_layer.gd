extends Node2D
## Real 3D cards composited behind the existing 2D entities and HUD.
const CELL := 256
const MAX_CHUNKS := 48
const CARD_WIDTH := 20.0
const CARD_HEIGHT := 18.0
const CARD_LEAN := 0.18
const CARD_YAW := 0.0 # Width along world +X, which is screen-left/right.
var camera_tilt_degrees := 15.0
var patch_noise: FastNoiseLite
var game
var quality := 1
var texture: Texture2D
var chunks: Dictionary = {}
var order: Array[Vector2i] = []
var last_keys: Array[Vector2i] = []
var last_cpu_us := 0
var visible_instances := 0
var card_mesh: ArrayMesh
var viewport_3d: SubViewport
var world_root: Node3D
var camera_3d: Camera3D
var grass_material: ShaderMaterial

static func hash_cell(x: int, y: int, salt: int = 0) -> int:
	return absi((x * 92837111) ^ (y * 689287499) ^ (salt * 283923481)) % 1000003

static func is_open(pos: Vector2) -> bool:
	return hash_cell(floori(pos.x/16),floori(pos.y/16),91)%1000 < 8

func ground_z_scale() -> float:
	return 1.0/cos(deg_to_rad(camera_tilt_degrees))

func ground_point(pos: Vector2) -> Vector3:
	return Vector3(pos.x,0,pos.y*ground_z_scale())

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Original short multi-blade cluster mask: many fine leaves per instanced card.
	for blade in 7:
		var root_x := 3.0+blade*4.2
		var leaf_height := 21+(blade*7)%10
		var bend := float((blade*11)%9-4)
		for y in range(32-leaf_height,32):
			var t := float(31-y)/leaf_height
			var center := root_x+bend*t*t
			var half_width := 1.35*(1.0-t)+0.2
			for x in 32:
				if absf(x-center)<=half_width:
					image.set_pixel(x,y,Color("567c48").lerp(Color("88a65c"),t))
	texture = ImageTexture.create_from_image(image)
	card_mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	# Short upright cards with mild lean; the oblique camera supplies visible height.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5,0,0),Vector3(0.5,0,0),Vector3(-0.5,1,-CARD_LEAN),Vector3(0.5,1,-CARD_LEAN)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,1,2,3])
	card_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	grass_material = ShaderMaterial.new()
	grass_material.shader = load("res://scripts/grass_cards.gdshader")
	grass_material.set_shader_parameter("blade_texture", texture)
	patch_noise = FastNoiseLite.new()
	var noise := patch_noise
	noise.seed = 3801
	noise.frequency = 0.065
	var noise_image := noise.get_image(64,64)
	grass_material.set_shader_parameter("wind_noise", ImageTexture.create_from_image(noise_image))
	card_mesh.surface_set_material(0, grass_material)
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(960,540)
	viewport_3d.transparent_bg = true
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport_3d)
	world_root = Node3D.new()
	viewport_3d.add_child(world_root)
	camera_3d = Camera3D.new()
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT
	camera_3d.size = 540
	camera_3d.near = 1
	camera_3d.far = 1000
	world_root.add_child(camera_3d)
	camera_3d.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.88,0.93,0.81)
	environment.environment.ambient_light_energy = 0.85
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-25,0)
	sun.light_color = Color(1.0,0.98,0.9)
	sun.light_energy = 0.35
	sun.shadow_enabled = false
	world_root.add_child(sun)

func set_quality(value: int) -> void:
	quality = clampi(value,0,2)
	for chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()
	order.clear()
	last_keys.clear()
	visible_instances = 0
	if viewport_3d:
		# Low renders grass alone at 5/6 resolution; labels/actors stay native 960x540.
		viewport_3d.size = Vector2i(800,450) if quality == 1 else Vector2i(960,540)
		viewport_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED if quality == 0 else SubViewport.UPDATE_ALWAYS
	queue_redraw()

func chunk_for(key: Vector2i) -> MultiMeshInstance3D:
	if chunks.has(key):
		order.erase(key)
		order.append(key)
		return chunks[key]
	var projection_scale := ground_z_scale()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for y in 16:
		for x in 16:
			var gx := key.x * 16 + x
			var gy := key.y * 16 + y
			var h := hash_cell(gx,gy)
			if h % 100 > (97 if quality == 1 else 99):
				continue
			var pos := Vector2(gx*16+3+h%11,gy*16+3+(h/41)%11)
			if is_open(pos):
				continue
			var broad := patch_noise.get_noise_2d(pos.x*0.025,pos.y*0.025)
			var detail := patch_noise.get_noise_2d(pos.x*0.1,pos.y*0.1)
			var patch := clampf(0.5+0.7*broad+0.3*detail,0,1)
			for blade in (2 if quality == 1 else 4):
				var seed := hash_cell(gx,gy,blade+1)
				var angle := CARD_YAW
				var scale_value := 0.90+(seed%23)/100.0
				var basis := Basis(Vector3.UP,angle).scaled_local(Vector3(CARD_WIDTH*scale_value,CARD_HEIGHT*scale_value,CARD_HEIGHT*scale_value))
				var origin := Vector3(pos.x-key.x*CELL+(seed%13)-6,0,(pos.y-key.y*CELL+((seed/13)%13)-6)*projection_scale)
				transforms.append(Transform3D(basis,origin))
				var tint := Color(0.78,0.91,0.80).lerp(Color(1.10,1.12,0.90),patch)
				tint *= 0.96+(seed%9)/100.0
				colors.append(tint)
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = card_mesh
	mesh.instance_count = transforms.size()
	# Bounds are local to this chunk, including maximum lean and shader displacement.
	mesh.custom_aabb = AABB(Vector3(-72,-1,-72),Vector3(CELL+144,72,CELL*projection_scale+144))
	for i in transforms.size():
		mesh.set_instance_transform(i,transforms[i])
		mesh.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mesh
	instance.position = Vector3(key.x*CELL,0,key.y*CELL*projection_scale)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(instance)
	if order.size() >= MAX_CHUNKS:
		var old: Vector2i = order.pop_front()
		chunks[old].queue_free()
		chunks.erase(old)
	chunks[key] = instance
	order.append(key)
	return instance

func _process(_dt: float) -> void:
	var started := Time.get_ticks_usec()
	visible_instances = 0
	if quality == 0 or game == null:
		last_cpu_us = 0
		return
	var center: Vector2 = game.camera.position
	var target := ground_point(center)
	var angle := deg_to_rad(camera_tilt_degrees)
	camera_3d.position = target+Vector3(0,600,600*tan(angle))
	camera_3d.look_at(target,Vector3(0,sin(angle),-cos(angle)))
	var view := Rect2(center-Vector2(480,270),Vector2(960,540)).grow(64)
	var keys: Array[Vector2i] = []
	for y in range(floori(view.position.y/CELL),ceili(view.end.y/CELL)):
		for x in range(floori(view.position.x/CELL),ceili(view.end.x/CELL)):
			keys.append(Vector2i(x,y))
	for key in chunks:
		chunks[key].visible = keys.has(key)
	for key in keys:
		var chunk := chunk_for(key)
		chunk.visible = true
		visible_instances += chunk.multimesh.instance_count
	last_keys = keys
	queue_redraw()
	last_cpu_us = Time.get_ticks_usec()-started

func _draw() -> void:
	if quality > 0 and viewport_3d and game:
		draw_texture_rect(viewport_3d.get_texture(),Rect2(game.camera.position-Vector2(480,270),Vector2(960,540)),false)
