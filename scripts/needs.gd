class_name Needs
extends RefCounted
## The six motives of a Sim, each 0..100. They decay over game time unless an
## activity supplies its own rate for that need.

signal changed

const ORDER: Array[String] = ["hunger", "energy", "bladder", "hygiene", "fun", "social"]
const LABELS := {
	"hunger": "Hunger",
	"energy": "Energy",
	"bladder": "Bladder",
	"hygiene": "Hygiene",
	"fun": "Fun",
	"social": "Social",
}
## Points lost per game hour when nothing is affecting the need.
const DECAY_PER_HOUR := {
	"hunger": 6.0,
	"energy": 4.5,
	"bladder": 10.0,
	"hygiene": 4.0,
	"fun": 6.0,
	"social": 5.0,
}
const LOW := 30.0
const CRITICAL := 15.0

var values := {}


func _init() -> void:
	for n in ORDER:
		values[n] = 80.0


func get_value(need: String) -> float:
	return values[need]


func set_value(need: String, v: float) -> void:
	values[need] = clampf(v, 0.0, 100.0)
	changed.emit()


func add(need: String, amount: float) -> void:
	set_value(need, values[need] + amount)


## Advances needs by `minutes` of game time. `rates` maps need -> points per hour and
## replaces normal decay for those needs (e.g. {"hunger": 40.0} while eating).
func tick(minutes: float, rates: Dictionary = {}) -> void:
	if minutes <= 0.0:
		return
	for n in ORDER:
		var rate: float = rates.get(n, -DECAY_PER_HOUR[n])
		values[n] = clampf(values[n] + rate * minutes / 60.0, 0.0, 100.0)
	changed.emit()


func lowest() -> String:
	var best := ORDER[0]
	for n in ORDER:
		if values[n] < values[best]:
			best = n
	return best


func average() -> float:
	var total := 0.0
	for n in ORDER:
		total += values[n]
	return total / ORDER.size()


## A coarse overall state derived from the needs, shown next to the Sim's name.
func mood() -> String:
	var low: float = values[lowest()]
	if low < CRITICAL:
		return "Miserable"
	if low < LOW:
		return "Uncomfortable"
	if average() > 75.0:
		return "Happy"
	return "Fine"


## Colour for a need bar: green when full, through yellow, to red when empty.
static func bar_color(v: float) -> Color:
	var t := clampf(v / 100.0, 0.0, 1.0)
	var red := Color(0.86, 0.22, 0.18)
	var yellow := Color(0.95, 0.78, 0.2)
	var green := Color(0.35, 0.8, 0.3)
	if t < 0.5:
		return red.lerp(yellow, t / 0.5)
	return yellow.lerp(green, (t - 0.5) / 0.5)
