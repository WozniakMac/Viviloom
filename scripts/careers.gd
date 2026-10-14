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
	"criminal": {
		"label": "Criminal",
		"skill": "mischief",
		"start": 20, "end": 3,
		"levels": [["Lookout", 15], ["Getaway Driver", 24], ["Safecracker", 36], ["Cat Burglar", 54], ["Criminal Mastermind", 85]],
		"description": "Work the night shift on the wrong side of the law. Mischief helps you rise.",
	},
	"secret_agent": {
		"label": "Secret Agent",
		"skill": "charisma",
		"start": 9, "end": 17,
		"levels": [["Training Agent", 17], ["Field Analyst", 26], ["Field Agent", 39], ["Double Agent", 58], ["Super Agent", 88]],
		"description": "License to charm. Charisma and Logic help you rise.",
	},
	"style_influencer": {
		"label": "Style Influencer",
		"skill": "writing",
		"start": 10, "end": 17,
		"levels": [["Style Novice", 14], ["Fashion Blogger", 22], ["Trendsetter", 34], ["Style Icon", 52], ["Fashion Mogul", 82]],
		"description": "Set the trends everyone follows. Writing and Charisma help you rise.",
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
const ORDER: Array[String] = ["culinary", "tech", "painter", "business", "athlete", "entertainer", "writer", "astronaut", "criminal", "secret_agent", "style_influencer"]
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
	"criminal": {"text": "Pull a prank", "skill": "mischief", "xp": 30.0},
	"secret_agent": {"text": "Practise Charisma", "skill": "charisma", "xp": 40.0},
	"style_influencer": {"text": "Write a style post", "skill": "writing", "xp": 40.0},
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


## Career branches, as in the reference: from level BRANCH_AT the Sim follows one
## of two paths, each with its own titles and pay for the top two levels.
## career -> [[branch label, [[title, pay], [title, pay]]], [...]]
const BRANCH_AT := 3
const BRANCHES := {
	"culinary": [["Chef", [["Chef de Cuisine", 50], ["Celebrity Chef", 72]]], ["Mixologist", [["Head Bartender", 46], ["Master Mixologist", 66]]]],
	"tech": [["Start-up Entrepreneur", [["Start-up Founder", 60], ["Tech Mogul", 90]]], ["eSport Gamer", [["Pro Gamer", 52], ["eSport Legend", 80]]]],
	"painter": [["Master of the Real", [["Gallery Painter", 48], ["Master Painter", 72]]], ["Patron of the Arts", [["Art Dealer", 52], ["Patron of the Arts", 78]]]],
	"business": [["Management", [["Executive", 58], ["Business Tycoon", 92]]], ["Investor", [["Investor", 55], ["Angel Investor", 88]]]],
	"athlete": [["Bodybuilder", [["Fitness Champion", 54], ["Mr. or Ms. Galaxy", 78]]], ["Professional Athlete", [["All-Star", 60], ["Hall of Famer", 92]]]],
	"entertainer": [["Comedian", [["Headliner", 50], ["Comedy Legend", 78]]], ["Musician", [["Virtuoso", 52], ["Musical Superstar", 82]]]],
	"writer": [["Author", [["Bestselling Author", 54], ["Literary Legend", 85]]], ["Journalist", [["Columnist", 48], ["Editor-in-Chief", 76]]]],
	"astronaut": [["Space Ranger", [["Commander", 58], ["Space Ranger", 90]]], ["Interstellar Smuggler", [["Space Pirate", 56], ["Interstellar Smuggler", 88]]]],
	"criminal": [["Boss", [["Underboss", 56], ["Criminal Mastermind", 85]]], ["Oracle", [["Hacker", 58], ["Oracle", 90]]]],
	"secret_agent": [["Diamond Agent", [["Double-O Agent", 60], ["Diamond Agent", 92]]], ["Villain", [["Henchman", 50], ["Supervillain", 86]]]],
	"style_influencer": [["Stylist", [["Celebrity Stylist", 52], ["Style Icon", 80]]], ["Trend Setter", [["Trendsetter", 54], ["Fashion Mogul", 82]]]],
}


static func has_branches(c: String) -> bool:
	return BRANCHES.has(c)


static func branch_labels(c: String) -> Array:
	return BRANCHES.get(c, []).map(func(b): return b[0])


static func _level_entry(c: String, level: int, branch: int) -> Array:
	if level >= BRANCH_AT and BRANCHES.has(c):
		var b: Array = BRANCHES[c][clampi(branch, 0, 1)]
		return b[1][mini(level - BRANCH_AT, b[1].size() - 1)]
	return INFO[c]["levels"][level]


static func title(c: String, level: int, branch := 0) -> String:
	return _level_entry(c, level, branch)[0]


static func hourly(c: String, level: int, branch := 0) -> int:
	return _level_entry(c, level, branch)[1]


static func max_level(c: String) -> int:
	return INFO[c]["levels"].size() - 1


static func shift_hours(c: String) -> int:
	return posmod(INFO[c]["end"] - INFO[c]["start"], 24)


## Whether hour `h` is inside the shift (night shifts wrap past midnight).
static func on_shift(c: String, h: int) -> bool:
	var s: int = INFO[c]["start"]
	var e: int = INFO[c]["end"]
	return (h >= s and h < e) if s < e else (h >= s or h < e)


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
