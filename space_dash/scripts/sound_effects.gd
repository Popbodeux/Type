extends Node
## Original offline-synthesized PCM assets. Four voices, cooldowns, no microphone.
const NAMES := ["typing", "ready", "dash", "hit", "block", "mistake", "collect", "gameover"]
const COOLDOWN := {"typing": 0.045, "ready": 0.15, "dash": 0.12, "hit": 0.08, "block": 0.12, "mistake": 0.14, "collect": 0.10, "gameover": 0.5}
const PRIORITY := {"typing": 0, "ready": 1, "collect": 2, "dash": 3, "hit": 4, "block": 5, "mistake": 6, "gameover": 9}
const LEVEL_DB := {"typing": -18.0, "ready": -12.0, "dash": -11.0, "hit": -10.0, "block": -12.0, "mistake": -14.0, "collect": -12.0, "gameover": -11.0}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var voice_priority: Array[int] = []
var last_played: Dictionary = {}
var muted := false
var master_volume := 0.6
var played_count := 0
var dropped_count := 0
var played_log: Array[Dictionary] = []
var capture: AudioEffectRecord
var capture_index := -1
var bus_index := -1

func _ready() -> void:
	bus_index = AudioServer.get_bus_index("TypeSFX")
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "TypeSFX")
	for name in NAMES:
		streams[name] = load("res://assets/audio/" + name + ".wav")
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "TypeSFX"
		player.max_polyphony = 1
		add_child(player)
		players.append(player)
		voice_priority.append(-1)

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in players:
			player.stop()

func set_volume(value: float) -> void:
	master_volume = clampf(value, 0, 1)
	# Apply master gain immediately even to already-playing voices.
	for i in players.size():
		if players[i].playing:
			players[i].volume_db = float(players[i].get_meta("base_db", -12.0)) + linear_to_db(maxf(0.00001, master_volume))

func consume(events: Array[String], now: float = -1.0) -> void:
	if now < 0:
		now = Time.get_ticks_msec() / 1000.0
	if muted or master_volume <= 0:
		return # Drop rather than queue a burst for unmute.
	var unique := {}
	for name in events:
		if streams.has(name):
			unique[name] = true
	if unique.has("ready"):
		unique.erase("typing")
	var ordered: Array = unique.keys()
	ordered.sort_custom(func(a, b) -> bool: return PRIORITY[a] > PRIORITY[b])
	for name in ordered:
		if now - float(last_played.get(name, -100.0)) < float(COOLDOWN[name]):
			dropped_count += 1
			continue
		if name == "gameover":
			for player in players:
				player.stop()
		var slot := -1
		for i in players.size():
			if not players[i].playing:
				slot = i
				break
		if slot < 0:
			var lowest := 999
			for i in players.size():
				if voice_priority[i] < lowest:
					lowest = voice_priority[i]
					slot = i
			if PRIORITY[name] <= lowest:
				dropped_count += 1
				continue
		players[slot].stop()
		players[slot].stream = streams[name]
		players[slot].set_meta("base_db", LEVEL_DB[name])
		players[slot].volume_db = LEVEL_DB[name] + linear_to_db(master_volume)
		voice_priority[slot] = PRIORITY[name]
		players[slot].play()
		last_played[name] = now
		played_count += 1
		if played_log.size() < 4096:
			played_log.append({"name": name, "time": now, "master": master_volume})

func start_capture() -> void:
	capture = AudioEffectRecord.new()
	capture.format = AudioStreamWAV.FORMAT_16_BITS
	capture_index = AudioServer.get_bus_effect_count(bus_index)
	AudioServer.add_bus_effect(bus_index, capture)
	capture.set_recording_active(true)

func finish_capture(path: String) -> int:
	if capture == null:
		return 0
	capture.set_recording_active(false)
	var recording := capture.get_recording()
	var count := recording.data.size()
	if count > 0:
		recording.save_to_wav(path)
	AudioServer.remove_bus_effect(bus_index, capture_index)
	capture = null
	return count
