extends SceneTree
## Hybrid camera regression. Add -- --render for private front/back normal frames.
## All raw evidence stays in ignored artifacts/projection-qa/.
const OUTPUT := "res://artifacts/projection-qa"
var checks := 0
var failures: Array[String] = []
var maximum_projection_error := 0.0
var render_checks_requested := false
var normal_results: Dictionary = {}
var geometry_results: Dictionary = {}
var projection_by_quality: Dictionary = {}
var camera_comparisons: Dictionary = {}
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	render_checks_requested = OS.get_cmdline_user_args().has("--render")
	if render_checks_requested and DisplayServer.get_name() == "headless":
		printerr("PROJECTION RENDER CHECKS REQUIRE A REAL DISPLAY: remove --headless and run with X11/OpenGL; Dummy cannot supply frame_post_draw or actual MultiMesh transforms.")
		quit(2)
		return
	call_deferred("run")

func anchor_check(point: Vector2, label: String) -> void:
	var grass = game.grass
	var projected: Vector2 = grass.camera_3d.unproject_position(grass.ground_point(point))
	projected *= Vector2(960,540) / Vector2(grass.viewport_3d.size)
	var expected := point - Vector2(game.camera.position) + Vector2(480,270)
	var error := projected.distance_to(expected)
	maximum_projection_error = maxf(maximum_projection_error,error)
	check(error < 0.01, "camera alignment within 0.01px: " + label)

func current_anchors(label: String) -> void:
	anchor_check(game.state.player,label+" player")
	for i in game.state.orbs.size():
		anchor_check(game.state.orbs[i].pos,label+" orb "+str(i))
	for i in game.state.enemies.size():
		anchor_check(game.state.enemies[i].pos,label+" enemy "+str(i))
	for corner in [Vector2(-480,-270),Vector2(480,-270),Vector2(-480,270),Vector2(480,270)]:
		anchor_check(game.camera.position+corner,label+" viewport corner")
	anchor_check(game.state.dash_from,label+" dash line start")
	anchor_check(game.state.dash_to,label+" dash line end")

func inspect_actual_cards() -> void:
	var grass = game.grass
	var max_width_error := 0.0
	var max_height_error := 0.0
	var max_lean_error := 0.0
	var max_axis_error := 0.0
	var max_root_height := 0.0
	var max_bounds_error := 0.0
	var count := 0
	var width_example := {}
	for chunk in grass.chunks.values():
		var box: AABB = chunk.multimesh.custom_aabb
		for i in chunk.multimesh.instance_count:
			var transform: Transform3D = chunk.multimesh.get_instance_transform(i)
			var scale_value := transform.basis.y.length()/float(grass.CARD_HEIGHT)
			var width := transform.basis.x.length()
			var height := (transform.basis*Vector3.UP).y
			var tip := transform.basis*Vector3(0,1,-float(grass.CARD_LEAN))
			if absf(width-float(grass.CARD_WIDTH)*scale_value)>max_width_error:
				width_example = {"width":width,"scale":scale_value,"constant":grass.CARD_WIDTH,"height_constant":grass.CARD_HEIGHT,"basis_x":str(transform.basis.x),"basis_y":str(transform.basis.y)}
			max_width_error = maxf(max_width_error,absf(width-float(grass.CARD_WIDTH)*scale_value))
			max_height_error = maxf(max_height_error,absf(height-float(grass.CARD_HEIGHT)*scale_value))
			max_lean_error = maxf(max_lean_error,absf(Vector2(tip.x,tip.z).length()/tip.y-float(grass.CARD_LEAN)))
			max_axis_error = maxf(max_axis_error,transform.basis.y.normalized().distance_to(Vector3.UP))
			max_root_height = maxf(max_root_height,absf((chunk.global_transform*transform.origin).y))
			for point in [transform.origin,transform.origin+tip]:
				var closest: Vector3 = point.clamp(box.position,box.end)
				max_bounds_error = maxf(max_bounds_error,point.distance_to(closest))
			count += 1
	geometry_results = {"worst_width":width_example,"cards":count,"max_width_error":max_width_error,"max_height_error":max_height_error,"max_lean_ratio_error":max_lean_error,"max_vertical_axis_error":max_axis_error,"max_root_y":max_root_height,"max_bounds_error":max_bounds_error}
	check(count>100,"inspect populated actual instance transforms")
	check(max_width_error<0.001,"yaw preserves blade width under local nonuniform scaling")
	check(max_height_error<0.001,"all local heights remain world-up")
	check(max_lean_error<0.001,"yaw does not shear intended blade lean")
	check(max_axis_error<0.001,"instance height axes remain upright")
	check(max_root_height<0.001,"all actual card roots lie on mapped ground plane")
	check(max_bounds_error<0.001,"chunk-local bounds contain root and baked tip")

func settle() -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw

func render_normal_face(stage: MultiMeshInstance3D, yaw: float, label: String) -> void:
	var grass = game.grass
	stage.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,yaw).scaled_local(Vector3(float(grass.CARD_WIDTH),float(grass.CARD_HEIGHT),float(grass.CARD_HEIGHT))),Vector3.ZERO))
	await settle()
	var image: Image = grass.viewport_3d.get_texture().get_image()
	image.save_png(OUTPUT.path_join(label+"-normals.png"))
	var opaque := 0
	var up := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.a>0.9:
				opaque += 1
				if absf(color.r-0.5)<0.03 and color.g>0.97 and absf(color.b-0.5)<0.03:
					up += 1
	var arrays: Array = grass.card_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var geometric_normal: Vector3 = (vertices[indices[1]]-vertices[indices[0]]).cross(vertices[indices[2]]-vertices[indices[0]]).normalized()
	var basis := Basis(Vector3.UP,yaw)
	var towards_camera: Vector3 = (grass.camera_3d.position-Vector3(0,float(grass.CARD_HEIGHT)*0.5,0)).normalized()
	var facing_dot: float = (basis*geometric_normal).dot(towards_camera)
	normal_results[label] = {"opaque_pixels":opaque,"upward_pixels":up,"geometric_facing_dot":facing_dot,"passed":opaque>20 and up==opaque}
	check(opaque>20,"actual rendered card has visible pixels: "+label)
	check(up==opaque,"all actual shading normals point world-up: "+label)

func render_camera_comparisons() -> void:
	var grass = game.grass
	var original_tilt: float = grass.camera_tilt_degrees
	for tilt in [10.0,15.0,20.0]:
		grass.camera_tilt_degrees = tilt
		game.set_grass_quality(1,false)
		grass._process(0)
		game.queue_redraw()
		game.entities.queue_redraw()
		game.hud.queue_redraw()
		await settle()
		root.get_texture().get_image().save_png(OUTPUT.path_join("camera-%d.png" % int(tilt)))
		current_anchors("camera comparison %d degrees" % int(tilt))
		camera_comparisons[str(int(tilt))] = {"tilt_degrees":tilt,"camera_center":str(game.camera.position),"player":str(game.state.player),"orbs":game.state.orbs.size(),"timer":game.state.timer,"grass_viewport":[grass.viewport_3d.size.x,grass.viewport_3d.size.y],"visible_instances":grass.visible_instances}
	grass.camera_tilt_degrees = original_tilt
	game.set_grass_quality(1,false)
	grass._process(0)

func rendered_normals() -> void:
	var grass = game.grass
	game.set_grass_quality(2,false)
	grass._process(0)
	for chunk in grass.chunks.values():
		chunk.visible = false
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = grass.card_mesh
	multimesh.instance_count = 1
	var stage := MultiMeshInstance3D.new()
	stage.multimesh = multimesh
	grass.world_root.add_child(stage)
	var camera = grass.camera_3d
	var theta := deg_to_rad(float(grass.camera_tilt_degrees))
	camera.size = 70
	camera.position = Vector3(0,600,600*tan(theta))
	camera.look_at(Vector3.ZERO,Vector3(0,sin(theta),-cos(theta)))
	grass.grass_material.set_shader_parameter("debug_normals",true)
	await render_normal_face(stage,0.0,"yaw-zero")
	await render_normal_face(stage,PI,"yaw-half-turn")
	var first: float = normal_results["yaw-zero"].geometric_facing_dot
	var second: float = normal_results["yaw-half-turn"].geometric_facing_dot
	check(first*second<0,"rendered stages cover opposite geometric face directions")
	grass.grass_material.set_shader_parameter("debug_normals",false)
	stage.queue_free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(960,540)
	game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.grass.set_process(false)
	game.set_audio_muted(true,false)
	game.settings_path = OUTPUT.path_join("isolated-settings.ini")
	game.state.save_path = OUTPUT.path_join("isolated-highscore.ini")
	game.state.rng.seed = 1764
	game.state.reset_run()
	game.state.maintenance_enabled = false
	game.state.enemy_updates_enabled = false
	var initial_camera: Vector2 = game.state.camera_pos.round()
	var centers := [initial_camera,initial_camera+Vector2(450,210),initial_camera+Vector2(-330,-170),Vector2(480,270),Vector2(15800,9700)]
	for quality in [1,2]:
		game.set_grass_quality(quality,false)
		check(game.grass.viewport_3d.size.x>0 and game.grass.viewport_3d.size.y>0,"quality has valid viewport")
		for i in centers.size():
			game.camera.position = centers[i]
			game.grass._process(0)
			current_anchors("quality %d camera %d" % [quality,i])
			check(game.grass.chunks.size()<=game.grass.MAX_CHUNKS,"chunk cache remains bounded during camera movement")
		projection_by_quality[str(quality)] = {"viewport":[game.grass.viewport_3d.size.x,game.grass.viewport_3d.size.y],"camera_positions":centers.size(),"maximum_error_pixels":maximum_projection_error}
	# Three real model dash initiations/ticks follow the normal eased camera path.
	game.set_grass_quality(1,false)
	game.state.enemies.clear()
	for dash in 3:
		var target: Vector2 = game.state.player+Vector2(240+dash*60,120 if dash%2==0 else -180)
		var orb := {"id":90000+dash,"word":"ash","pos":target,"reward":1.0,"tier":0}
		game.state.orbs.append(orb)
		game.state.orb_revision += 1
		game.state.active_id = orb.id
		game.state.buffer = orb.word
		game.state.hit_stop = 0
		check(game.state.confirm_word(),"real dash initiation succeeds")
		for tick in 20:
			game._physics_process(1.0/60.0)
			game.grass._process(0)
			anchor_check(game.state.player,"dash %d tick %d player" % [dash,tick])
			anchor_check(game.state.dash_from,"dash start line anchor")
			anchor_check(game.state.dash_to,"dash target line anchor")
		check(not game.state.dash_active,"real dash completes")
	if DisplayServer.get_name() != "headless":
		await settle()
		inspect_actual_cards()
	else:
		geometry_results = {"status":"not run: Dummy RenderingServer does not retain actual MultiMesh transform data"}
	if render_checks_requested:
		await render_camera_comparisons()
		await rendered_normals()
	else:
		normal_results = {"status":"not run; use -- --render on an available display"}
	var report := {"checks":checks,"passed":checks-failures.size(),"failures":failures,"camera_tilt_degrees":game.grass.camera_tilt_degrees,"maximum_projection_error_pixels":maximum_projection_error,"quality_projection":projection_by_quality,"geometry":geometry_results,"rendered_normals":normal_results,"camera_comparisons":camera_comparisons,"render_requested":render_checks_requested}
	var file := FileAccess.open(OUTPUT.path_join("results-render.json" if render_checks_requested else "results-headless.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("PROJECTION CHECKS: %d PASSED: %d FAILED: %d MAX ERROR PX: %.6f" % [checks,checks-failures.size(),failures.size(),maximum_projection_error])
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
