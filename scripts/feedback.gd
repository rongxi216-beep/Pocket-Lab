extends Node
var sound := false
var haptics := true
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_sound := 0
var last_vibration := 0
var rng := RandomNumberGenerator.new()
var airflow: AudioStreamPlayer

func _ready() -> void:
	rng.seed = 71
	for kind in ["impact", "impact_metal", "impact_wood", "impact_plastic", "place", "spring", "magnet", "fan", "delete"]:
		streams[kind] = synthesize(kind)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	airflow = AudioStreamPlayer.new()
	add_child(airflow)
	airflow.stream = make_airflow()
	airflow.volume_db = -45

func synthesize(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.16 if kind != "spring" else 0.28
	var frequencies := {"impact": 710, "impact_metal": 870, "impact_wood": 290, "impact_plastic": 430, "place": 530, "spring": 350, "magnet": 220, "fan": 160, "delete": 410}
	var bytes := PackedByteArray()
	bytes.resize(int(duration * 22050) * 2)
	for i in bytes.size() / 2:
		var t := float(i) / 22050
		var frequency: float = frequencies[kind]
		var envelope := exp(-t * 30) * minf(t * 900, 1)
		var sample := (sin(TAU * frequency * t) + sin(TAU * frequency * 2.73 * t) * 0.25) * envelope * 0.35
		if kind == "impact_wood": sample = (sin(TAU * frequency * t) * 0.7 + rng.randf_range(-1, 1) * 0.15) * exp(-t * 48) * minf(t * 1000, 1) * 0.45
		if kind == "impact_plastic": sample = (sin(TAU * frequency * t) + sin(TAU * frequency * 1.6 * t) * 0.32) * exp(-t * 34) * minf(t * 1000, 1) * 0.3
		if kind == "impact_metal": sample = (sin(TAU * frequency * t) + sin(TAU * frequency * 2.76 * t) * 0.18) * exp(-t * 23) * minf(t * 1000, 1) * 0.32
		if kind == "spring": sample = sin(TAU * (420 * t - 410 * t * t)) * exp(-t * 16) * 0.25
		if kind == "fan": sample = rng.randf_range(-1, 1) * envelope * 0.15
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
	stream.data = bytes
	return stream

func play(kind: String = "place", intensity: float = 0.5) -> void:
	var now := Time.get_ticks_msec()
	if sound and kind.begins_with("impact_") and intensity > 0.18 and now - last_sound > 140:
		for voice in voices:
			if not voice.playing:
				voice.stream = streams.get(kind, streams.place)
				voice.volume_db = lerpf(-38, -24, clampf(intensity, 0, 1))
				voice.pitch_scale = rng.randf_range(0.92, 1.09)
				voice.play()
				last_sound = now
				break
	var is_impact := kind.begins_with("impact")
	if haptics and now - last_vibration > (700 if is_impact else 220) and (not is_impact or intensity > 0.7):
		if OS.has_feature("android") or OS.has_feature("ios"):
			Input.vibrate_handheld(18 if is_impact else 12, 0.25)
		last_vibration = now

func stop_audio() -> void:
	for voice in voices: voice.stop()
	if is_instance_valid(airflow): airflow.stop()

func make_airflow() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 22050
	var bytes := PackedByteArray()
	bytes.resize(44100)
	for i in 22050:
		var t := float(i) / 22050
		var sample := 0.0
		for frequency in [83, 137, 193, 251, 317, 389, 457, 541]:
			sample += sin(TAU * frequency * t + frequency * 0.37) / 20.0
		bytes.encode_s16(i * 2, int(sample * 32767))
	stream.data = bytes
	return stream

func update_airflow(_power: float, _delta: float) -> void:
	# Fans are visual and physical; no continuous loop in the quiet default design.
	airflow.stop()
