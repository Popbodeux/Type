extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> Image:
	for i in 3:
		await process_frame
	game.queue_redraw()
	game.entities.queue_redraw()
	game.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png("res://artifacts/v0.4.3-scenery/"+name+".png")
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/v0.4.3-scenery")
	root.size = Vector2i(960,540)
	game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.state.rng.seed = 1764
	game.state.reset_run()
	game.camera.position = game.state.camera_pos.round()
	game.set_audio_muted(true,false)
	var proofs := {}
	for mode in 3:
		game.set_grass_quality(mode,false)
		await capture(["off","low","high"][mode])
		proofs[["off","low","high"][mode]] = {"cards":game.grass.visible_instances,"chunks":game.grass.chunks.size(),"camera_size":game.grass.camera_3d.size}
	# Inspect the actual 3D framebuffer without the 2D ground/entities.
	game.grass.grass_material.set_shader_parameter("debug_normals",true)
	await capture("normals-composited")
	var raw: Image = game.grass.viewport_3d.get_texture().get_image()
	raw.save_png("res://artifacts/v0.4.3-scenery/normals-3d.png")
	var up := 0
	var opaque := 0
	for y in raw.get_height():
		for x in raw.get_width():
			var c := raw.get_pixel(x,y)
			if c.a > 0.9:
				opaque += 1
				if absf(c.r-0.5)<0.03 and c.g>0.97 and absf(c.b-0.5)<0.03:
					up += 1
	proofs["normals"] = {"opaque_pixels":opaque,"upward_pixels":up,"passed":opaque>100 and up==opaque}
	var file := FileAccess.open("res://artifacts/v0.4.3-scenery/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(proofs,"  "))
	print("SCENERY CHECK: ",proofs)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if up==opaque and opaque>100 else 1)
