class_name Aspirations
extends RefCounted
## Lifelong goals made of milestones, and the small day-to-day wants a Sim has.
##
## A goal is a dictionary with "text" and one of these checks:
##   skill: name, level           any_skills: level, count
##   stat: name, count            friendship / romance: at least this with anyone
##   funds: amount                career_level: level (1-based)

const INFO := {
	"renaissance": {
		"label": "Renaissance Sim",
		"category": "Knowledge",
		"description": "Wants to be good at a bit of everything.",
		"milestones": [
			[{"text": "Reach level 2 in two skills", "any_skills": 2, "count": 2}],
			[{"text": "Reach level 4 in two skills", "any_skills": 4, "count": 2}, {"text": "Reach level 2 in three skills", "any_skills": 2, "count": 3}],
			[{"text": "Reach level 6 in two skills", "any_skills": 6, "count": 2}],
			[{"text": "Reach level 8 in three skills", "any_skills": 8, "count": 3}],
		],
	},
	"painter": {
		"label": "Painter Extraordinaire",
		"category": "Creativity",
		"description": "Dreams of filling galleries with their work.",
		"milestones": [
			[{"text": "Reach Painting level 2", "skill": "painting", "level": 2}],
			[{"text": "Sell 3 paintings", "stat": "paintings_sold", "count": 3}, {"text": "Reach Painting level 4", "skill": "painting", "level": 4}],
			[{"text": "Sell 8 paintings", "stat": "paintings_sold", "count": 8}],
			[{"text": "Reach Painting level 8", "skill": "painting", "level": 8}],
		],
	},
	"friend_of_world": {
		"label": "Friend of the World",
		"category": "Popularity",
		"description": "Wants to be on good terms with everyone.",
		"milestones": [
			[{"text": "Have 10 social interactions", "stat": "socials", "count": 10}],
			[{"text": "Become Friends with someone", "friendship": 30.0}],
			[{"text": "Become Good Friends with someone", "friendship": 60.0}, {"text": "Tell 5 jokes", "stat": "jokes", "count": 5}],
			[{"text": "Have a Best Friend", "friendship": 80.0}],
		],
	},
	"wealthy": {
		"label": "Fabulously Wealthy",
		"category": "Fortune",
		"description": "Wants a fortune, and wants it soon.",
		"milestones": [
			[{"text": "Get a job", "career_level": 1}],
			[{"text": "Have §25,000", "funds": 25000}],
			[{"text": "Reach career level 3", "career_level": 3}, {"text": "Have §40,000", "funds": 40000}],
			[{"text": "Have §75,000", "funds": 75000}],
		],
	},
	"bodybuilder": {
		"label": "Bodybuilder",
		"category": "Athletic",
		"description": "Wants the perfect physique.",
		"milestones": [
			[{"text": "Reach Fitness level 2", "skill": "fitness", "level": 2}],
			[{"text": "Reach Fitness level 4", "skill": "fitness", "level": 4}],
			[{"text": "Reach Fitness level 7", "skill": "fitness", "level": 7}],
			[{"text": "Reach Fitness level 10", "skill": "fitness", "level": 10}],
		],
	},
	"musical_genius": {
		"label": "Musical Genius",
		"category": "Creativity",
		"description": "Hears music everywhere and wants to master it.",
		"milestones": [
			[{"text": "Reach Guitar or Piano level 2", "any_of": ["guitar", "piano"], "level": 2}],
			[{"text": "Reach Guitar or Piano level 5", "any_of": ["guitar", "piano"], "level": 5}],
			[{"text": "Reach level 4 in both Guitar and Piano", "all_of": ["guitar", "piano"], "level": 4}],
			[{"text": "Reach Guitar or Piano level 10", "any_of": ["guitar", "piano"], "level": 10}],
		],
	},
	"bestselling_author": {
		"label": "Bestselling Author",
		"category": "Creativity",
		"description": "Has stories to tell the whole world.",
		"milestones": [
			[{"text": "Reach Writing level 2", "skill": "writing", "level": 2}],
			[{"text": "Reach Writing level 4", "skill": "writing", "level": 4}],
			[{"text": "Reach Writing level 7", "skill": "writing", "level": 7}],
			[{"text": "Reach Writing level 10", "skill": "writing", "level": 10}],
		],
	},
	"chief_of_mischief": {
		"label": "Chief of Mischief",
		"category": "Deviance",
		"description": "Lives for a good prank.",
		"milestones": [
			[{"text": "Pull 3 pranks", "stat": "pranks", "count": 3}],
			[{"text": "Reach Mischief level 4", "skill": "mischief", "level": 4}],
			[{"text": "Pull 15 pranks", "stat": "pranks", "count": 15}],
			[{"text": "Reach Mischief level 10", "skill": "mischief", "level": 10}],
		],
	},
	"big_happy_family": {
		"label": "Big Happy Family",
		"category": "Family",
		"description": "Wants a home full of love and children.",
		"milestones": [
			[{"text": "Become Sweethearts with someone", "romance": 60.0}],
			[{"text": "Have a household of 2", "household": 2}],
			[{"text": "Have a household of 3", "household": 3}],
			[{"text": "Have a household of 4", "household": 4}],
		],
	},
	"master_chef": {
		"label": "Master Chef",
		"category": "Food",
		"description": "Dreams of running the finest kitchen.",
		"milestones": [
			[{"text": "Reach Cooking level 2", "skill": "cooking", "level": 2}],
			[{"text": "Reach Cooking level 5", "skill": "cooking", "level": 5}],
			[{"text": "Reach Cooking level 8", "skill": "cooking", "level": 8}],
			[{"text": "Reach Cooking level 10", "skill": "cooking", "level": 10}],
		],
	},
	"master_mixologist": {
		"label": "Master Mixologist",
		"category": "Food",
		"description": "Shaken, stirred, and perfected.",
		"milestones": [
			[{"text": "Reach Mixology level 2", "skill": "mixology", "level": 2}],
			[{"text": "Reach Mixology level 5", "skill": "mixology", "level": 5}],
			[{"text": "Reach Mixology level 8", "skill": "mixology", "level": 8}],
			[{"text": "Reach Mixology level 10", "skill": "mixology", "level": 10}],
		],
	},
	"computer_whiz": {
		"label": "Computer Whiz",
		"category": "Knowledge",
		"description": "At home behind a keyboard.",
		"milestones": [
			[{"text": "Reach Programming level 2", "skill": "programming", "level": 2}],
			[{"text": "Reach Video Gaming level 4", "skill": "gaming", "level": 4}],
			[{"text": "Reach Programming level 7", "skill": "programming", "level": 7}],
			[{"text": "Reach Programming level 10", "skill": "programming", "level": 10}],
		],
	},
	"nerd_brain": {
		"label": "Nerd Brain",
		"category": "Knowledge",
		"description": "Fascinated by how everything works.",
		"milestones": [
			[{"text": "Reach Logic level 2", "skill": "logic", "level": 2}],
			[{"text": "Reach Handiness level 3", "skill": "handiness", "level": 3}],
			[{"text": "Reach Logic level 6", "skill": "logic", "level": 6}],
			[{"text": "Reach Logic level 10", "skill": "logic", "level": 10}],
		],
	},
	"serial_romantic": {
		"label": "Serial Romantic",
		"category": "Love",
		"description": "In love with being in love.",
		"milestones": [
			[{"text": "Flirt 5 times", "stat": "flirts", "count": 5}],
			[{"text": "Kiss 5 times", "stat": "kisses", "count": 5}],
			[{"text": "Flirt 20 times", "stat": "flirts", "count": 20}],
			[{"text": "Kiss 20 times", "stat": "kisses", "count": 20}],
		],
	},
	"freelance_botanist": {
		"label": "Freelance Botanist",
		"category": "Nature",
		"description": "Has a green thumb and wants to prove it.",
		"milestones": [
			[{"text": "Reach Gardening level 2", "skill": "gardening", "level": 2}],
			[{"text": "Harvest 5 times", "stat": "harvests", "count": 5}],
			[{"text": "Reach Gardening level 6", "skill": "gardening", "level": 6}],
			[{"text": "Harvest 25 times", "stat": "harvests", "count": 25}],
		],
	},
	"angling_ace": {
		"label": "Angling Ace",
		"category": "Nature",
		"description": "Happiest with a rod in hand.",
		"milestones": [
			[{"text": "Catch 3 fish", "stat": "fish", "count": 3}],
			[{"text": "Reach Fishing level 4", "skill": "fishing", "level": 4}],
			[{"text": "Catch 20 fish", "stat": "fish", "count": 20}],
			[{"text": "Reach Fishing level 10", "skill": "fishing", "level": 10}],
		],
	},
	"joke_star": {
		"label": "Joke Star",
		"category": "Popularity",
		"description": "Born to make people laugh.",
		"milestones": [
			[{"text": "Tell 5 jokes", "stat": "jokes", "count": 5}],
			[{"text": "Reach Comedy level 4", "skill": "comedy", "level": 4}],
			[{"text": "Tell 25 jokes", "stat": "jokes", "count": 25}],
			[{"text": "Reach Comedy level 10", "skill": "comedy", "level": 10}],
		],
	},
	"party_animal": {
		"label": "Party Animal",
		"category": "Popularity",
		"description": "Never misses a good party.",
		"milestones": [
			[{"text": "Throw a social event", "stat": "events", "count": 1}],
			[{"text": "Earn a silver or gold event medal", "stat": "event_silver", "count": 1}],
			[{"text": "Earn 3 gold event medals", "stat": "event_gold", "count": 3}],
			[{"text": "Have 200 social interactions", "stat": "socials", "count": 200}],
		],
	},
	"soulmate": {
		"label": "Soulmate",
		"category": "Love",
		"description": "Searching for the one.",
		"milestones": [
			[{"text": "Flirt 3 times", "stat": "flirts", "count": 3}],
			[{"text": "Become a Romantic Interest", "romance": 30.0}],
			[{"text": "Have a first kiss", "stat": "kisses", "count": 1}],
			[{"text": "Become Sweethearts", "romance": 60.0}],
		],
	},
}
const ORDER: Array[String] = ["bodybuilder", "painter", "musical_genius", "bestselling_author", "chief_of_mischief", "big_happy_family",
	"master_chef", "master_mixologist", "wealthy", "renaissance", "computer_whiz", "nerd_brain", "soulmate", "serial_romantic",
	"freelance_botanist", "angling_ace", "friend_of_world", "joke_star", "party_animal"]
const MILESTONE_POINTS := 500
const WANT_POINTS := 100

## Wants: [id, text, activity name that fulfils it (prefix match), base weight].
const WANTS := [
	["paint", "Paint something", "Paint", 1.0],
	["cook", "Cook a meal", "Cook ", 1.0],
	["chess", "Play some chess", "Practise Chess", 1.0],
	["books", "Browse books", "Browse Books", 1.0],
	["study", "Study", "Study", 0.7],
	["chat", "Chat with someone", "Chat", 1.0],
	["joke", "Tell a joke", "Tell a Joke", 0.8],
	["tv", "Watch TV", "Watch", 0.9],
	["games", "Play video games", "Play Games", 0.8],
	["shower", "Take a shower", "Take a Shower", 0.6],
	["flirt", "Flirt with someone", "Flirt", 0.5],
	["compliment", "Compliment someone", "Compliment", 0.6],
	["jog", "Go for a jog", "Jog", 0.7],
	["guitar", "Play the guitar", "Practise Guitar", 0.8],
	["speech", "Practise a speech", "Practise Speech", 0.6],
	["write", "Write a book", "Write a Book", 0.6],
]
## What makes a want more likely: trait or emotion -> {want id: multiplier}.
const WANT_LIKES := {
	"creative": {"paint": 3.0, "guitar": 2.0, "write": 2.0}, "genius": {"chess": 3.0, "study": 2.0}, "bookworm": {"books": 3.0, "study": 1.5},
	"cheerful": {"joke": 2.5, "chat": 1.5}, "lazy": {"tv": 3.0, "games": 1.5}, "gloomy": {"tv": 1.5},
	"inspired": {"paint": 3.0, "cook": 1.5}, "focused": {"chess": 2.0, "study": 2.0}, "playful": {"joke": 3.0, "games": 2.0},
	"flirty": {"flirt": 4.0, "compliment": 2.0}, "bored": {"games": 2.0, "tv": 2.0}, "happy": {"chat": 1.5},
	"energized": {"jog": 3.0}, "confident": {"speech": 2.5},
}


static func label(a: String) -> String:
	return INFO[a]["label"]


## Whether one goal is met. `ctx` has: sim, funds, career_level.
static func goal_met(goal: Dictionary, ctx: Dictionary) -> bool:
	var sim: Sim = ctx["sim"]
	if goal.has("skill"):
		return sim.skills.level(goal["skill"]) >= goal["level"]
	if goal.has("any_skills"):
		var n := 0
		for s in Skills.ORDER:
			if sim.skills.level(s) >= goal["any_skills"]:
				n += 1
		return n >= goal["count"]
	if goal.has("any_of"):
		return (goal["any_of"] as Array).any(func(k): return sim.skills.level(k) >= goal["level"])
	if goal.has("all_of"):
		return (goal["all_of"] as Array).all(func(k): return sim.skills.level(k) >= goal["level"])
	if goal.has("household"):
		return ctx.get("household", 1) >= goal["household"]
	if goal.has("stat"):
		return sim.stats.get(goal["stat"], 0) >= goal["count"]
	if goal.has("friendship"):
		for o in sim.relationships:
			if sim.relationships[o].x >= goal["friendship"]:
				return true
		return false
	if goal.has("romance"):
		for o in sim.relationships:
			if sim.relationships[o].y >= goal["romance"]:
				return true
		return false
	if goal.has("funds"):
		return ctx.get("funds", 0) >= goal["funds"]
	if goal.has("career_level"):
		return ctx.get("career_level", 0) >= goal["career_level"]
	return false


## Picks a new want, favouring ones that suit the Sim's traits and mood and
## skipping any in `exclude`.
static func roll_want(sim: Sim, exclude: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var total := 0.0
	for w in WANTS:
		if exclude.has(w[0]):
			continue
		var weight: float = w[3]
		var keys: Array = sim.traits.duplicate()
		keys.append(sim.emotions.mood())
		for key in keys:
			weight *= WANT_LIKES.get(key, {}).get(w[0], 1.0)
		pool.append([w, weight])
		total += weight
	if pool.is_empty():
		return []
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return pool[-1][0]
