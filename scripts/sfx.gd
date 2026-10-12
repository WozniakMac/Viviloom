extends Node
## Autoload "Sfx": sound effects, music and ambience (sounds from tools/make_audio.py).
## Every button in the game clicks automatically.

const DIR := "res://assets/audio/"
const POOL := 8

var music_enabled := true
var _sfx: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var _music_name := ""
var _ambience: AudioStreamPlayer
var _ambience_name := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -14.0
	add_child(_ambience)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(play.bind("click", -6.0))


func stream(sound: String, loop := false) -> AudioStream:
	var key := sound + ("_loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := DIR + sound + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStreamWAV
	if loop:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[key] = s
	return s


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _sfx[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Crossfades to a music loop ("" for silence).
func music(sound: String) -> void:
	if sound == _music_name:
		return
	_music_name = sound
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var cur := _music[_music_on]
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "volume_db", -80.0, 1.2)
	if sound != "" and music_enabled:
		cur.stream = stream(sound, true)
		cur.volume_db = -40.0
		cur.play()
		tw.tween_property(cur, "volume_db", -11.0, 1.2)
	tw.chain().tween_callback(old.stop)


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	var name := _music_name
	_music_name = "-"
	music(name if on else "")
	_music_name = name


func ambience(sound: String) -> void:
	if sound == _ambience_name:
		return
	_ambience_name = sound
	if sound == "":
		_ambience.stop()
		return
	_ambience.stream = stream(sound, true)
	_ambience.play()


## A babbling voice from a Sim: higher or lower by `pitch`, from a 3D player.
func voice(player: AudioStreamPlayer3D, high: bool, pitch: float) -> void:
	var s := stream("voice_%s_%d" % ["high" if high else "low", randi() % 4])
	if s == null or player.playing:
		return
	player.stream = s
	player.pitch_scale = pitch * randf_range(0.95, 1.06)
	player.play()
