class_name Settings
extends RefCounted
## Game Options, kept in user://settings.cfg and laid out like the reference game's
## options dialog (Graphics, Sound, Music, Gameplay, Save Settings, Camera,
## Tutorial & Tips, Other, Accessibility).

const PATH := "user://settings.cfg"

## key -> default value
const DEFAULTS := {
	"fullscreen": false,
	"vsync": true,
	"quality": 3,
	"master": 80,
	"music": 70,
	"sfx": 90,
	"ambience": 70,
	"music_on": true,
	"free_will": 2,
	"disable_selected_autonomy": false,
	"aging_played": true,
	"aging_unplayed": true,
	"lifespan": 1,
	"show_wants": true,
	"autosave": 0,
	"edge_scrolling": true,
	"sims3_camera": false,
	"invert_horizontal": false,
	"invert_vertical": false,
	"show_tips": true,
	"clock_24h": false,
	"ui_scale": 1,
	"capture_ui": false,
	"capture_size": 1,
	"capture_notice": true,
	"lunar_cycle": 1,
	"lunar_fixed": 0,
	"lunar_effects_off": false,
}
const CAPTURE_SCALES: Array[float] = [0.5, 1.0, 2.0]
const LIFESPAN_MULT: Array[float] = [0.5, 1.0, 2.0]
const UI_SCALES: Array[float] = [0.9, 1.0, 1.15]
## Autosave interval in real minutes for each option (0 = off).
const AUTOSAVE_MINUTES: Array[int] = [0, 10, 30, 60]

static var values := {}


static func get_value(key: String) -> Variant:
	if values.is_empty():
		load_file()
	return values.get(key, DEFAULTS[key])


static func load_file() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("options", k, DEFAULTS[k])


static func save_file() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("options", k, values[k])
	cfg.save(PATH)


## Puts every option into effect.
static func apply(tree: SceneTree) -> void:
	if values.is_empty():
		load_file()
	var win := tree.root.get_window()
	if not DisplayServer.get_name() == "headless":
		var want_full: bool = get_value("fullscreen")
		var is_full := win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		if want_full != is_full:
			win.mode = Window.MODE_FULLSCREEN if want_full else Window.MODE_WINDOWED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)
	var q: int = get_value("quality")
	tree.root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	tree.root.scaling_3d_scale = [0.7, 0.85, 1.0, 1.0][q]
	tree.root.content_scale_factor = UI_SCALES[get_value("ui_scale")]
	_set_bus("Master", get_value("master"))
	_set_bus("Music", get_value("music"))
	_set_bus("SFX", get_value("sfx"))
	_set_bus("Ambience", get_value("ambience"))
	Sfx.set_music_enabled(get_value("music_on"))
	CameraRig.edge_scrolling = get_value("edge_scrolling")
	CameraRig.sims3_camera = get_value("sims3_camera")
	CameraRig.invert_horizontal = get_value("invert_horizontal")
	CameraRig.invert_vertical = get_value("invert_vertical")
	Ages.lifespan_mult = LIFESPAN_MULT[get_value("lifespan")]


static func _set_bus(bus: String, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(percent / 100.0, 0.0001)))
	AudioServer.set_bus_mute(i, percent <= 0)
