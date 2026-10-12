class_name Careers
extends RefCounted
## Career tracks: five levels each with a title and hourly pay, a work schedule
## (Monday to Friday) and the skill needed for promotions.

const INFO := {
	"culinary": {
		"label": "Culinary",
		"skill": "cooking",
		"start": 12, "end": 20,
		"levels": [["Dishwasher", 14], ["Line Cook", 20], ["Sous Chef", 30], ["Chef", 45], ["Head Chef", 65]],
		"description": "From scrubbing pots to running the kitchen. Cooking helps you rise.",
	},
	"tech": {
		"label": "Tech Guru",
		"skill": "logic",
		"start": 9, "end": 17,
		"levels": [["Tech Support", 16], ["Junior Developer", 24], ["Developer", 36], ["Senior Developer", 55], ["Chief Technologist", 80]],
		"description": "Fix printers today, design systems tomorrow. Logic helps you rise.",
	},
	"painter": {
		"label": "Painter",
		"skill": "painting",
		"start": 10, "end": 16,
		"levels": [["Canvas Stretcher", 12], ["Gallery Assistant", 18], ["Artist", 28], ["Acclaimed Artist", 42], ["Master Painter", 60]],
		"description": "Make a name in the art world. Painting helps you rise.",
	},
	"school": {
		"label": "Grade School", "skill": "logic", "start": 8, "end": 15,
		"levels": [["Student", 0]], "description": "Reading, writing and recess.",
	},
	"high_school": {
		"label": "High School", "skill": "logic", "start": 8, "end": 15,
		"levels": [["Student", 0]], "description": "Homework, friends and a lot of growing up.",
	},
}
const ORDER: Array[String] = ["culinary", "tech", "painter"]
## School counts as a "career" for children and teens: no pay, a grade instead.
const SCHOOLS: Array[String] = ["school", "high_school"]
const WORK_DAYS := 5
## Emotions that make a shift go better or worse.
const GOOD_MOODS: Array[String] = ["happy", "confident", "focused", "energized", "inspired"]
const BAD_MOODS: Array[String] = ["sad", "angry", "tense", "uncomfortable", "embarrassed", "bored"]


static func is_school(c: String) -> bool:
	return SCHOOLS.has(c)


## A school grade for a performance value.
static func grade(performance: float) -> String:
	if performance >= 80.0:
		return "A"
	if performance >= 60.0:
		return "B"
	if performance >= 40.0:
		return "C"
	if performance >= 20.0:
		return "D"
	return "F"


static func label(c: String) -> String:
	return INFO[c]["label"]


static func title(c: String, level: int) -> String:
	return INFO[c]["levels"][level][0]


static func hourly(c: String, level: int) -> int:
	return INFO[c]["levels"][level][1]


static func max_level(c: String) -> int:
	return INFO[c]["levels"].size() - 1


static func shift_hours(c: String) -> int:
	return INFO[c]["end"] - INFO[c]["start"]


## Skill level needed to be promoted from `level` to the next one.
static func skill_for_promotion(level: int) -> int:
	return (level + 1) * 2


static func is_work_day(day: int) -> bool:
	return (day - 1) % 7 < WORK_DAYS


static func schedule_text(c: String) -> String:
	return "Mon–Fri  %s – %s" % [_hour(INFO[c]["start"]), _hour(INFO[c]["end"])]


static func _hour(h: int) -> String:
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d %s" % [h12, "AM" if h < 12 else "PM"]


## Performance gained in one shift (0..100 scale) for a mood and skill level.
static func shift_performance(mood: String, skill_level: int) -> float:
	var base := 18.0
	if GOOD_MOODS.has(mood):
		base = 28.0
	elif BAD_MOODS.has(mood):
		base = 8.0
	return base + skill_level * 1.5
