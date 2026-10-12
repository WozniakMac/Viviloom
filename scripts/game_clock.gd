extends Node
## Autoload "Clock": game time. At normal speed one real second is one game minute.

signal speed_changed(speed: int)
signal hour_changed(hour: int)

const SPEED_FACTORS: Array[float] = [0.0, 1.0, 3.0, 12.0]
const DAY_NAMES: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const MINUTES_PER_SECOND := 1.0

var speed := 1
## Minutes since the start of day 1 (midnight).
var total_minutes := 8.0 * 60.0
## Game minutes that passed during the current frame.
var game_delta := 0.0


func _process(delta: float) -> void:
	game_delta = delta * MINUTES_PER_SECOND * SPEED_FACTORS[speed]
	var prev_hour := hour()
	total_minutes += game_delta
	if hour() != prev_hour:
		hour_changed.emit(hour())


## Real-time delta scaled by game speed, for animation and movement.
func scaled(delta: float) -> float:
	return delta * SPEED_FACTORS[speed]


func set_speed(s: int) -> void:
	s = clampi(s, 0, SPEED_FACTORS.size() - 1)
	if s != speed:
		speed = s
		speed_changed.emit(speed)


func is_paused() -> bool:
	return speed == 0


func day() -> int:
	return int(total_minutes / 1440.0) + 1


func weekday_name() -> String:
	return DAY_NAMES[(day() - 1) % 7]


func hour() -> int:
	return int(fmod(total_minutes, 1440.0) / 60.0)


func minute() -> int:
	return int(fmod(total_minutes, 60.0))


func time_string() -> String:
	if Settings.get_value("clock_24h"):
		return "%02d:%02d" % [hour(), minute()]
	var h := hour() % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, minute(), "AM" if hour() < 12 else "PM"]
