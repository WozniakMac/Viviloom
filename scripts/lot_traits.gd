class_name LotTraits
## Lot traits: up to three per home, each nudging life there a little (faster
## skills, a mood, more breakdowns...).

const MAX := 3

## id -> {label, description, skill_mult: {skill: x}, moodlet: [id, emotion, weight, label, text], daytime, break_mult}
const INFO := {
	"homey": {"label": "Homey", "description": "Sims feel happy to be at home.",
		"moodlet": ["homey", "happy", 1, "Homey", "There's no place like home."]},
	"chefs_kitchen": {"label": "Chef's Kitchen", "description": "Cooking skill builds faster here.",
		"skill_mult": {"cooking": 1.5}},
	"home_studio": {"label": "Home Studio", "description": "Guitar and Piano skills build faster.",
		"skill_mult": {"guitar": 1.5, "piano": 1.5}},
	"gym": {"label": "Gym", "description": "Fitness skill builds faster.",
		"skill_mult": {"fitness": 1.5}},
	"science_lair": {"label": "Science Lair", "description": "Logic and Programming build faster.",
		"skill_mult": {"logic": 1.5, "programming": 1.5}},
	"natural_light": {"label": "Natural Light", "description": "Sunny days lift everyone's spirits.",
		"moodlet": ["sunlit", "happy", 1, "Sunlit Home", "The light pours in."], "daytime": true},
	"romantic_aura": {"label": "Romantic Aura", "description": "Love is in the air. Sims feel flirty.",
		"moodlet": ["romantic_aura", "flirty", 1, "Romantic Aura", "Something about this place..."]},
	"creative_vibes": {"label": "Creative Vibes", "description": "Sims often feel inspired here.",
		"moodlet": ["creative_vibes", "inspired", 1, "Creative Vibes", "Ideas everywhere!"],
		"skill_mult": {"painting": 1.2, "writing": 1.2}},
	"gremlins": {"label": "Gremlins", "description": "Things break more often. Great for handy Sims.",
		"break_mult": 2.5, "skill_mult": {"handiness": 1.5}},
}
const ORDER: Array[String] = ["homey", "chefs_kitchen", "home_studio", "gym", "science_lair", "natural_light", "romantic_aura", "creative_vibes", "gremlins"]


static func skill_mult(traits: Array, skill: String) -> float:
	var m := 1.0
	for t in traits:
		m *= INFO.get(t, {}).get("skill_mult", {}).get(skill, 1.0)
	return m


static func break_mult(traits: Array) -> float:
	var m := 1.0
	for t in traits:
		m *= INFO.get(t, {}).get("break_mult", 1.0)
	return m


## Moodlets the lot gives right now: [[id, emotion, weight, label, text], ...].
static func moodlets(traits: Array, hour: float) -> Array:
	var out: Array = []
	for t in traits:
		var info: Dictionary = INFO.get(t, {})
		if not info.has("moodlet"):
			continue
		if info.get("daytime", false) and (hour < 8.0 or hour >= 18.0):
			continue
		out.append(info["moodlet"])
	return out
