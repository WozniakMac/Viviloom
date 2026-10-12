class_name Daylight
extends Node
## Moves the sun with the game clock: warm sunrise and sunset, a dim blue moonlit
## night, and the sky and ambient light to match. Lamps (group "lamps") switch on
## when it gets dark.

const DAY_TOP := Color(0.36, 0.56, 0.86)
const DAY_HORIZON := Color(0.72, 0.8, 0.9)
const DUSK_HORIZON := Color(0.98, 0.62, 0.42)
const DUSK_TOP := Color(0.32, 0.38, 0.62)
const NIGHT_TOP := Color(0.03, 0.05, 0.13)
const NIGHT_HORIZON := Color(0.1, 0.13, 0.24)
const SUN_DAY := Color(1.0, 0.97, 0.9)
const SUN_LOW := Color(1.0, 0.68, 0.42)
const MOON := Color(0.55, 0.65, 1.0)

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var lamps_on := false
## Whether lamps should be on right now (read by lamps placed later).
static var lit_now := false
## Set by Bills when the power is cut for unpaid bills.
static var power_off := false


const SUNRISE := 6.0
const SUNSET := 20.0


## -1..1 height of the sun over the horizon (negative at night) for a time of day.
## Days run from 6 AM to 8 PM, so evenings stay light.
static func sun_height(hour: float) -> float:
	if hour >= SUNRISE and hour <= SUNSET:
		return sin((hour - SUNRISE) / (SUNSET - SUNRISE) * PI)
	var into_night := fmod(hour - SUNSET + 24.0, 24.0)
	return -sin(into_night / (24.0 - SUNSET + SUNRISE) * PI)


static func is_dark(hour: float) -> bool:
	return sun_height(hour) < 0.12


func _process(_delta: float) -> void:
	if sun == null:
		return
	apply(fmod(Clock.total_minutes, 1440.0) / 60.0)


func apply(hour: float) -> void:
	var hgt := sun_height(hour)
	var day := smoothstep(-0.12, 0.3, hgt)
	var low := 1.0 - smoothstep(0.0, 0.45, absf(hgt))
	if hgt > -0.05:
		# The sun crosses the sky from east to west.
		var elev := maxf(hgt, 0.04) * 68.0 + 4.0
		sun.rotation_degrees = Vector3(-elev, 35.0 + (hour - 13.0) * 11.0, 0.0)
		sun.light_color = SUN_DAY.lerp(SUN_LOW, low)
		sun.light_energy = lerpf(0.15, 1.15, day)
	else:
		# The moon: a fixed, soft blue light from high up.
		sun.rotation_degrees = Vector3(-50.0, -20.0, 0.0)
		sun.light_color = MOON
		sun.light_energy = 0.22
	var top := NIGHT_TOP.lerp(DUSK_TOP, smoothstep(-0.15, 0.1, hgt)).lerp(DAY_TOP, smoothstep(0.1, 0.4, hgt))
	var horizon := NIGHT_HORIZON.lerp(DUSK_HORIZON, smoothstep(-0.15, 0.05, hgt)).lerp(DAY_HORIZON, smoothstep(0.1, 0.4, hgt))
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.3)
	env.ambient_light_energy = lerpf(0.28, 0.9, day)
	var dark := is_dark(hour)
	if dark != lamps_on:
		lamps_on = dark
		lit_now = dark
		get_tree().call_group("lamps", "set_lit", dark and not power_off)
