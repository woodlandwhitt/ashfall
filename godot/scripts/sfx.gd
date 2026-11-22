# Sound effects: the same CC0 recordings the WebView build uses. play() is flat (UI, the player's own gun),
# play_at() is positional.
extends Node

var cache: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var pool3: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)

func stream(name: String) -> AudioStream:
	if cache.has(name):
		return cache[name]
	var s: AudioStream = null
	for ext in [".mp3", ".ogg", ".wav"]:
		var path: String = "res://sfx/" + name + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	cache[name] = s
	return s

func play(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

func play_at(name: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null or not is_inside_tree():
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var p: AudioStreamPlayer3D = null
	# players parented to a scene that's since been swapped out (travel, the K-hole) are gone: drop them
	pool3 = pool3.filter(func(q): return is_instance_valid(q))
	for q in pool3:
		if not q.playing:
			p = q
			break
	if p == null:
		if pool3.size() >= 16:
			return
		p = AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 120.0
		root.add_child(p)
		pool3.append(p)
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

func loop(name: String, vol_db: float) -> AudioStreamPlayer:
	var s := stream(name)
	if s == null:
		return null
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / 2
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	return p

func has(name: String) -> bool:
	return stream(name) != null
