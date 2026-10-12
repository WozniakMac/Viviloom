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
const ORDER: Array[String] = ["renaissance", "painter", "friend_of_world", "wealthy", "soulmate"]
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
