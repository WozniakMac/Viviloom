class_name Skills
extends RefCounted
## Skill levels 0..10 earned through practice. A skill appears once it has been
## practised at all; feeling the matching emotion makes practice count for more.

signal leveled_up(skill: String, level: int)
signal changed

const MAX_LEVEL := 10
## skill -> [label, emotion that speeds it up]
const INFO := {
	"cooking": ["Cooking", "inspired"],
	"logic": ["Logic", "focused"],
	"painting": ["Painting", "inspired"],
	"gaming": ["Video Gaming", "focused"],
	"fitness": ["Fitness", "energized"],
	"charisma": ["Charisma", "confident"],
	"guitar": ["Guitar", "focused"],
	"gardening": ["Gardening", "focused"],
	"writing": ["Writing", "focused"],
}
const ORDER: Array[String] = ["cooking", "logic", "painting", "gaming", "fitness", "charisma", "guitar", "gardening", "writing"]
const EMOTION_BONUS := 1.5

var xp := {}


func _init() -> void:
	for s in ORDER:
		xp[s] = 0.0


## Total experience needed to reach `level`.
static func xp_for_level(level: int) -> float:
	# 100, 250, 450, 700... each level costs 50 more than the last.
	var total := 0.0
	for l in range(1, level + 1):
		total += 50.0 + 50.0 * l
	return total


func level(skill: String) -> int:
	var l := 0
	while l < MAX_LEVEL and xp[skill] >= xp_for_level(l + 1):
		l += 1
	return l


## 0..1 progress towards the next level (1.0 at max level).
func progress(skill: String) -> float:
	var l := level(skill)
	if l >= MAX_LEVEL:
		return 1.0
	var lo := xp_for_level(l)
	return (xp[skill] - lo) / (xp_for_level(l + 1) - lo)


func known() -> Array[String]:
	var out: Array[String] = []
	for s in ORDER:
		if xp[s] > 0.0:
			out.append(s)
	return out


func add_xp(skill: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var before := level(skill)
	xp[skill] = minf(xp[skill] + amount, xp_for_level(MAX_LEVEL))
	changed.emit()
	var after := level(skill)
	if after > before:
		leveled_up.emit(skill, after)


static func label(skill: String) -> String:
	return INFO[skill][0]


static func boosting_emotion(skill: String) -> String:
	return INFO[skill][1]
