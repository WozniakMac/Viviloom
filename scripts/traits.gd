class_name Traits
extends RefCounted
## Personality traits. Each one can give a lasting moodlet, a moodlet that comes back
## every so often, faster skill practice, different need decay, and favourite
## activities that the Sim picks more often on their own.

const MAX_TRAITS := 3
## Keys per trait (all optional except label/description):
##   lasting:   [emotion, weight, moodlet label, moodlet description]
##   periodic:  [emotion, weight, moodlet label, description, every N game minutes, lasting minutes]
##   skill_mult: {skill: multiplier}
##   decay_mult: {need: multiplier}
##   likes:     {skill or object kind: autonomy multiplier}
const INFO := {
	"cheerful": {
		"label": "Cheerful",
		"description": "Tends to be happier than other Sims.",
		"lasting": ["happy", 1, "Naturally Cheerful", "Life is good."],
	},
	"gloomy": {
		"label": "Gloomy",
		"description": "Grows sad now and then, and enjoys things a little less.",
		"periodic": ["sad", 1, "Feeling Gloomy", "Nothing in particular, just... gloomy.", 360.0, 180.0],
		"decay_mult": {"fun": 1.25},
	},
	"creative": {
		"label": "Creative",
		"description": "Often inspired, and learns painting faster.",
		"periodic": ["inspired", 1, "Creative Spark", "An idea is forming!", 480.0, 240.0],
		"skill_mult": {"painting": 1.5},
		"likes": {"painting": 2.0},
	},
	"genius": {
		"label": "Genius",
		"description": "Often focused, and picks up logic faster.",
		"periodic": ["focused", 1, "Sharp Mind", "Thoughts are crystal clear.", 480.0, 240.0],
		"skill_mult": {"logic": 1.5},
		"likes": {"logic": 2.0},
	},
	"lazy": {
		"label": "Lazy",
		"description": "Tires quickly and loves lounging in front of the TV.",
		"decay_mult": {"energy": 1.3},
		"likes": {"tv": 2.0, "bed": 1.3},
	},
	"bookworm": {
		"label": "Bookworm",
		"description": "Finds books more fun than anything else.",
		"likes": {"bookshelf": 2.5},
		"skill_mult": {"logic": 1.2},
	},
	"neat": {
		"label": "Neat",
		"description": "Loves a tidy home: cleans up eagerly and hates mess.",
		"likes": {"dishes": 2.5, "puddle": 2.5, "clean": 2.5},
	},
	"slob": {
		"label": "Slob",
		"description": "Leaves a trail of mess and doesn't mind it one bit.",
	},
	"active": {
		"label": "Active",
		"description": "Full of energy and loves working out. Learns Fitness faster.",
		"periodic": ["energized", 1, "Restless Energy", "Needs to move!", 480.0, 180.0],
		"skill_mult": {"fitness": 1.5},
		"likes": {"fitness": 2.5, "pool": 2.0},
	},
	"romantic": {
		"label": "Romantic",
		"description": "Dreams of love; flirts often and loves romantic moments.",
		"periodic": ["flirty", 1, "Love Is in the Air", "Thinking about romance...", 600.0, 180.0],
		"likes": {"romance": 2.5},
	},
	"loner": {
		"label": "Loner",
		"description": "Needs less company and gets tense in crowds.",
		"decay_mult": {"social": 0.5},
		"likes": {"social": 0.5},
	},
	"hot_headed": {
		"label": "Hot-Headed",
		"description": "Quick to anger, slow to cool down.",
		"periodic": ["angry", 1, "Easily Annoyed", "Everything is irritating today.", 420.0, 150.0],
	},
	"foodie": {
		"label": "Foodie",
		"description": "Lives for good food. Learns Cooking faster.",
		"skill_mult": {"cooking": 1.5},
		"likes": {"cooking": 2.5},
	},
	"ambitious": {
		"label": "Ambitious",
		"description": "Driven to climb the career ladder. Works harder and gets tense when stuck.",
		"periodic": ["confident", 1, "Driven", "Big plans, big dreams.", 480.0, 180.0],
		"likes": {"charisma": 1.5, "logic": 1.3, "programming": 1.3},
		"work_bonus": 5.0,
	},
	"childish": {
		"label": "Childish",
		"description": "Never really grew up. Loves toys and silly games.",
		"periodic": ["playful", 1, "Young at Heart", "Wheee!", 420.0, 180.0],
		"likes": {"toybox": 3.0, "dollhouse": 3.0, "monkey_bars": 3.0, "activity_table": 2.5},
	},
	"goofball": {
		"label": "Goofball",
		"description": "Always joking around. Learns Comedy faster.",
		"periodic": ["playful", 1, "Goofing Around", "Everything is funny!", 360.0, 180.0],
		"skill_mult": {"comedy": 1.5},
		"likes": {"comedy": 2.5},
	},
	"self_assured": {
		"label": "Self-Assured",
		"description": "Confident, and it shows.",
		"lasting": ["confident", 1, "Self-Assured", "Feeling pretty great about themselves."],
	},
	"glutton": {
		"label": "Glutton",
		"description": "Always hungry, always snacking.",
		"decay_mult": {"hunger": 1.35},
		"likes": {"fridge": 2.0, "fruit_bowl": 2.5, "microwave": 2.0},
	},
	"good": {
		"label": "Good",
		"description": "Kind to everyone; happiest when being nice.",
		"periodic": ["happy", 1, "Do-Gooder", "Doing the right thing feels good.", 600.0, 180.0],
		"likes": {"social": 1.3, "mean": 0.1},
	},
	"mean": {
		"label": "Mean",
		"description": "Enjoys a good insult and a nasty prank.",
		"periodic": ["angry", 1, "Grumpy", "Everyone's so annoying.", 480.0, 150.0],
		"likes": {"mean": 3.0, "mischief": 2.0},
	},
	"outgoing": {
		"label": "Outgoing",
		"description": "A people person: needs company and loves a crowd.",
		"decay_mult": {"social": 1.4},
		"likes": {"social": 2.0},
	},
	"perfectionist": {
		"label": "Perfectionist",
		"description": "Takes longer to paint and write, but the results are better.",
		"skill_mult": {"painting": 0.85, "writing": 0.85},
		"quality_bonus": 1,
	},
	"geek": {
		"label": "Geek",
		"description": "Loves games, computers and sci-fi. Learns Video Gaming and Programming faster.",
		"skill_mult": {"gaming": 1.5, "programming": 1.5},
		"likes": {"gaming": 2.5, "programming": 1.5, "telescope": 2.0},
	},
	"music_lover": {
		"label": "Music Lover",
		"description": "Happiest with music playing. Learns Guitar faster.",
		"skill_mult": {"guitar": 1.5},
		"likes": {"guitar": 2.5, "stereo": 2.5},
	},
}
const ORDER: Array[String] = ["cheerful", "gloomy", "creative", "genius", "lazy", "bookworm", "neat", "slob", "active", "romantic", "loner", "hot_headed", "foodie", "music_lover",
	"ambitious", "childish", "goofball", "self_assured", "glutton", "good", "mean", "outgoing", "perfectionist", "geek"]
const CONFLICTS := [["cheerful", "gloomy"], ["neat", "slob"], ["active", "lazy"], ["loner", "romantic"], ["cheerful", "hot_headed"],
	["good", "mean"], ["outgoing", "loner"], ["ambitious", "lazy"], ["self_assured", "gloomy"], ["goofball", "hot_headed"]]


static func label(t: String) -> String:
	return INFO[t]["label"]


static func description(t: String) -> String:
	return INFO[t]["description"]


static func conflicts(a: String, b: String) -> bool:
	for pair in CONFLICTS:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


## Whether `t` can join `current` (not full, not a duplicate, no conflict).
static func can_add(current: Array[String], t: String) -> bool:
	if current.size() >= MAX_TRAITS or current.has(t):
		return false
	for c in current:
		if conflicts(c, t):
			return false
	return true


static func skill_mult(traits: Array[String], skill: String) -> float:
	var m := 1.0
	for t in traits:
		m *= INFO[t].get("skill_mult", {}).get(skill, 1.0)
	return m


static func decay_mult(traits: Array[String]) -> Dictionary:
	var out := {}
	for t in traits:
		var d: Dictionary = INFO[t].get("decay_mult", {})
		for need in d:
			out[need] = out.get(need, 1.0) * d[need]
	return out


## How much more the Sim wants to do `interaction` on `kind` of object.
static func liking(traits: Array[String], kind: String, interaction: Interaction) -> float:
	var m := 1.0
	for t in traits:
		var likes: Dictionary = INFO[t].get("likes", {})
		m *= likes.get(kind, 1.0)
		if interaction.effect != "":
			m *= likes.get(interaction.effect, 1.0)
		if interaction.skill != "":
			m *= likes.get(interaction.skill, 1.0)
		if interaction.is_social():
			m *= likes.get("social", 1.0)
			if interaction.social.get("category", "") == "Romance":
				m *= likes.get("romance", 1.0)
			if interaction.social.get("category", "") == "Mean":
				m *= likes.get("mean", 1.0)
			if interaction.social.get("category", "") == "Mischief":
				m *= likes.get("mischief", 1.0)
	return m
