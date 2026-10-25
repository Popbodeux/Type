extends SceneTree
const Model = preload("res://scripts/survival_state.gd")
const Grass = preload("res://scripts/grass_layer.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)
func fixture():
	var s = Model.new(1764)
	s.maintenance_enabled = false
	s.enemy_updates_enabled = false
	s.reset_run()
	s.orbs.clear()
	s.enemies.clear()
	s.camera_pos = s.player
	s.orbs.append({"id": 1,"word": "ash","pos": s.player+Vector2(180,0),"reward": 1.0,"tier": 0})
	s.orbs.append({"id": 2,"word": "amber","pos": s.player+Vector2(-180,0),"reward": 1.0,"tier": 0})
	return s
func play(sound, names: Array[String], now: float) -> void:
	sound.consume(names,now)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.grass.set_process(false)
	game.settings_path = "res://artifacts/v04-settings-test.ini"
	var s = fixture()
	game.state = s
	var origin: Vector2 = game.word_origin(s.orbs[0])
	check(game.WORD_SIZE == 18,"fixed 18px word size in all typing states")
	check(game.matching_plate.bg_color.a > game.neutral_plate.bg_color.a,"matching backplate raises contrast")
	for c in "asz":
		s.queue_character(c)
		s.tick()
		check(game.word_origin(s.orbs[0]) == origin,"glyph origin never shifts while typing or rejecting typo")
	check(s.buffer == "as","invalid letter preserves accepted prefix")
	s.queue_backspace()
	s.tick()
	check(game.word_origin(s.orbs[0]) == origin and s.buffer == "a","Backspace keeps fixed glyph origin")
	check(s.orb_feedback(s.orbs[0],s.typing_feedback()).body_alpha == 0.98,"active orb nearly opaque")
	s.buffer = ""
	s.active_id = -1
	check(s.orb_feedback(s.orbs[0],s.typing_feedback()).body_alpha == 0.5,"idle orb clearly visible at 50 percent")
	for seed_value in 20:
		var spawn = Model.new(seed_value+1)
		spawn.reset_run()
		for enemy in spawn.enemies:
			check(enemy.pos.distance_to(spawn.player) > Model.AGGRO_ENTER and not enemy.aggro,"initial enemies spawn outside acquisition range")
	for kind in 3:
		s = fixture()
		var enemy: Dictionary = s.make_enemy(kind,s.player+Vector2(141,0))
		enemy.heading = 0.0
		s.enemies.append(enemy)
		s.update_enemies()
		check(not enemy.aggro,"all kinds remain calm beyond 140")
		s.player = enemy.pos+Vector2(139,0)
		var before: Vector2 = enemy.pos
		s.update_enemies()
		check(enemy.aggro and enemy.pos.distance_to(before) < 0.6,"nearby acquisition uses slower pursuit")
		s.player = enemy.pos+Vector2(191,0)
		s.update_enemies()
		check(not enemy.aggro,"all kinds disengage beyond 190")
	s = fixture()
	s.queue_character("a")
	s.tick()
	check(s.drain_audio_events() == ["typing"],"accepted prefix emits typing")
	s.queue_character("z")
	s.tick()
	check(s.drain_audio_events() == ["mistake"],"rejected typo emits mistake only")
	s.queue_character("s")
	s.queue_character("h")
	s.tick()
	var events: Array[String] = s.drain_audio_events()
	check(events.has("typing") and events.has("ready") and events.count("typing") == 1,"batched accepted characters coalesce and completion emits ready")
	s.enemies.append(s.make_enemy(0,s.player+Vector2(80,0)))
	s.confirm_word()
	events = s.drain_audio_events()
	check(events.has("dash") and events.has("hit"),"real dash combat emits dash and hit")
	for tick in 30:
		s.tick()
	check(s.drain_audio_events().has("collect"),"arrival emits collection")
	s = fixture()
	s.buffer = "ash"
	s.active_id = 1
	var shield: Dictionary = s.make_enemy(1,s.player+Vector2(80,0))
	shield.facing = 0.0
	s.enemies.append(shield)
	s.confirm_word()
	check(s.drain_audio_events().has("block"),"directional blocked hit emits block")
	s.end_run()
	check(s.drain_audio_events().has("gameover"),"timer gameover emits gameover")
	var sound = game.sound
	sound.set_muted(false)
	sound.set_volume(0.6)
	for name in sound.NAMES:
		check(sound.streams[name] is AudioStreamWAV and sound.streams[name].data.size()>0 and sound.streams[name].get_length()>0.02,"original PCM stream loaded: "+name)
	play(sound,["typing"],10.0)
	var count: int = sound.played_count
	play(sound,["typing","typing"],10.01)
	check(sound.played_count == count,"rapid typing rate limited and deduplicated")
	play(sound,["typing","ready"],11.0)
	check(sound.played_count == count+1 and sound.played_log[-1].name == "ready","ready suppresses overlapping typing sound")
	play(sound,["dash","hit","block","mistake","collect"],12.0)
	check(sound.players.size() == 4,"voice pool bounded to four under simultaneous events")
	sound.set_muted(true)
	for player in sound.players:
		check(not player.playing,"mute immediately stops active voices")
	count = sound.played_count
	play(sound,["dash","typing","mistake"],13.0)
	check(sound.played_count == count,"muted events dropped")
	sound.set_muted(false)
	play(sound,[],14.0)
	check(sound.played_count == count,"unmute never plays a queued burst")
	sound.set_volume(1.5)
	check(sound.master_volume == 1.0,"master volume clamps high")
	sound.set_volume(-1)
	check(sound.master_volume == 0.0,"master volume clamps low")
	game.set_grass_quality(2,false)
	game.set_audio_volume(0.35,false)
	game.set_audio_muted(true,false)
	game.save_settings()
	game.set_grass_quality(0,false)
	game.set_audio_volume(1,false)
	game.set_audio_muted(false,false)
	game.load_settings()
	check(game.grass_quality==2 and sound.muted and is_equal_approx(sound.master_volume,0.35),"quality/mute/volume settings round trip")
	DirAccess.remove_absolute(game.settings_path)
	var grass = game.grass
	check(grass.camera_3d.projection == Camera3D.PROJECTION_ORTHOGONAL,"real orthographic 3D camera")
	check(grass.viewport_3d.transparent_bg and grass.viewport_3d.own_world_3d,"separate transparent 3D background")
	var chunk = grass.chunk_for(Vector2i(16,10))
	check(chunk is MultiMeshInstance3D and chunk.multimesh.transform_format == MultiMesh.TRANSFORM_3D,"actual chunked MultiMeshInstance3D cards")
	check(chunk.multimesh.custom_aabb.position.x < 0 and chunk.multimesh.custom_aabb.size.x > 512,"local chunk bounds include wind and lean")
	for angle in [-0.4,0.0,0.4]:
		var basis := Basis(Vector3.UP,angle).scaled(Vector3(12,27,27))
		var local_up := (basis.transposed()*Vector3.UP).normalized()
		var world_up := (basis.inverse().transposed()*local_up).normalized()
		check(world_up.is_equal_approx(Vector3.UP),"upward normal survives inverse-transpose under nonuniform transform")
	var shader: String = grass.grass_material.shader.code
	check(shader.contains("tip * tip") and shader.contains("clamp(VERTEX.y, 0.0, 1.0)"),"root weight zero anchors wind to blade roots")
	check(shader.contains("ALPHA_SCISSOR_THRESHOLD = 0.5"),"binary alpha cutout rather than soft overlapping transparency")
	for x in range(28):
		grass.chunk_for(Vector2i(x,10))
	check(grass.chunks.size() <= 24,"3D chunk cache bounded across world travel")
	game.set_grass_quality(0,false)
	check(grass.chunks.is_empty() and grass.viewport_3d.render_target_update_mode == SubViewport.UPDATE_DISABLED,"grass Off frees chunks and stops 3D rendering")
	sound.set_muted(true)
	# Headless process frames can elapse faster than one audio mix block.
	# Let the audio thread acknowledge stopped/replaced voices before teardown.
	await create_timer(1.0).timeout
	chunk = null
	grass = null
	sound = null
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	var file := FileAccess.open("res://artifacts/visual-audio-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks-failures.size(),"failures":failures},"  "))
	print("VISUAL AUDIO CHECKS: %d PASSED: %d FAILED: %d" % [checks,checks-failures.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
