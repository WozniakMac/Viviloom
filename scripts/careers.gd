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
		"skill": "programming",
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
	"business": {
		"label": "Business",
		"skill": "charisma",
		"start": 9, "end": 17,
		"levels": [["Mailroom Clerk", 15], ["Office Assistant", 22], ["Account Manager", 34], ["Regional Director", 52], ["CEO", 85]],
		"description": "Climb the corporate ladder. Charisma helps you rise.",
	},
	"athlete": {
		"label": "Athlete",
		"skill": "fitness",
		"start": 7, "end": 13,
		"levels": [["Waterboy", 13], ["Minor Leaguer", 20], ["Rookie", 32], ["Pro Athlete", 50], ["Hall of Famer", 75]],
		"description": "Train hard, play harder. Fitness helps you rise.",
	},
	"entertainer": {
		"label": "Entertainer",
		"skill": "guitar",
		"start": 14, "end": 22,
		"levels": [["Street Performer", 11], ["Opening Act", 19], ["Headliner", 30], ["Star", 48], ["Legend", 72]],
		"description": "From busking to sold-out shows. Guitar helps you rise.",
	},
	"writer": {
		"label": "Writer",
		"skill": "writing",
		"start": 10, "end": 16,
		"levels": [["Copy Editor", 14], ["Blogger", 21], ["Author", 31], ["Bestselling Author", 47], ["Literary Legend", 68]],
		"description": "Words on paper, money in the bank. Writing helps you rise.",
	},
	"astronaut": {
		"label": "Astronaut",
		"skill": "logic",
		"start": 8, "end": 16,
		"levels": [["Space Cadet", 16], ["Flight Engineer", 25], ["Mission Specialist", 38], ["Commander", 58], ["Space Ranger", 90]],
		"description": "Reach for the stars. Logic helps you rise.",
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
const ORDER: Array[String] = ["culinary", "tech", "painter", "business", "athlete", "entertainer", "writer", "astronaut"]
## How hard the Sim works: [label, performance multiplier, moodlet on return].
const WORK_STYLES := {
	"hard": ["Work Hard", 1.6, ["work_hard", "tense", 1, "Worked Hard", "Tiring, but it'll pay off.", 240.0]],
	"normal": ["Normal", 1.0, []],
	"easy": ["Take It Easy", 0.4, ["work_easy", "happy", 1, "Easy Day", "Barely broke a sweat today.", 180.0]],
}
## A daily task per career: done before the shift, it gives a performance boost.
## {text, skill, xp} (practise that skill) or {text, mood} (arrive in that mood).
const DAILY_TASKS := {
	"culinary": {"text": "Practise Cooking", "skill": "cooking", "xp": 40.0},
	"tech": {"text": "Practise Programming", "skill": "programming", "xp": 40.0},
	"painter": {"text": "Paint something", "skill": "painting", "xp": 40.0},
	"business": {"text": "Go to work Confident", "mood": "confident"},
	"athlete": {"text": "Work out", "skill": "fitness", "xp": 40.0},
	"entertainer": {"text": "Practise Comedy", "skill": "comedy", "xp": 30.0},
	"writer": {"text": "Practise Writing", "skill": "writing", "xp": 40.0},
	"astronaut": {"text": "Practise Logic", "skill": "logic", "xp": 40.0},
}
const TASK_BONUS := 12.0

## Things that come up during a shift: [title, text, [[choice, perf, moodlet or [], needs {skill: level}]...]].
## A choice with a skill requirement succeeds only if the Sim has it; otherwise the
## second (failure) performance and moodlet apply.
const EVENTS := [
	["Extra Project", "The boss is asking for a volunteer to take on an extra project.", [
		["Volunteer", 15.0, ["overworked", "tense", 1, "Extra Work", "That project is a lot.", 240.0]],
		["Keep your head down", 0.0, []],
	]],
	["Stolen Credit", "A coworker just presented %s's idea as their own!", [
		["Speak up", 12.0, ["stood_up", "confident", 1, "Stood My Ground", "Credit where it's due.", 180.0], {"charisma": 3}, -6.0, ["credit_stolen", "angry", 1, "Credit Stolen", "That was MY idea.", 180.0]],
		["Let it go", 0.0, ["credit_stolen", "sad", 1, "Overlooked", "Nobody noticed.", 120.0]],
	]],
	["Pizza Party", "Someone brought pizza to the break room.", [
		["Grab a slice", 0.0, ["pizza_party", "happy", 1, "Office Pizza", "Free food is the best food.", 120.0]],
		["Keep working", 8.0, []],
	]],
	["Jammed Printer", "The printer jammed right before a big meeting.", [
		["Fix it yourself", 10.0, ["fixed_it", "confident", 1, "Handy at Work", "Who needs IT?", 120.0], {"handiness": 3}, -5.0, ["ink_mess", "embarrassed", 1, "Covered in Toner", "That did not go well.", 120.0]],
		["Call IT", 0.0, []],
	]],
	["Team Lunch", "The team is heading out for lunch together.", [
		["Join them", 5.0, ["team_lunch", "happy", 1, "Team Spirit", "Good people to work with.", 180.0]],
		["Eat at your desk", 6.0, ["lonely_lunch", "sad", 1, "Desk Lunch", "Bit lonely.", 90.0]],
	]],
]


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
