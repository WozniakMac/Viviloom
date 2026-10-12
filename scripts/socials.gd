class_name Socials
extends RefCounted
## Social interactions between two Sims and the relationship levels they lead to.
## Each social is an Interaction whose `social` dictionary holds:
##   friendship / romance: change on success
##   min_friendship / min_romance: below this the other Sim turns it down
##   risky: may fall flat (more likely to land when playful or cheerful)
##   target_moodlet / actor_moodlet: [id, emotion, weight, label, description, minutes]
##   category: "Friendly", "Romance" or "Mean" (pie menu grouping)

const FRIEND_LEVELS := [[80.0, "Best Friend"], [60.0, "Good Friend"], [30.0, "Friend"], [10.0, "Acquaintance"], [-20.0, "Stranger"], [-60.0, "Disliked"], [-101.0, "Enemy"]]


static func all() -> Array[Interaction]:
	var out: Array[Interaction] = []
	out.append(_make("Chat", 25.0, {"social": 90.0, "fun": 10.0}, {"category": "Friendly", "friendship": 6.0}))
	out.append(_make("Tell a Joke", 20.0, {"social": 80.0, "fun": 35.0}, {"category": "Friendly", "friendship": 9.0, "risky": true,
		"target_moodlet": ["amused", "playful", 1, "Amused", "That was a good one.", 120.0]}))
	out.append(_make("Compliment", 15.0, {"social": 85.0}, {"category": "Friendly", "friendship": 7.0,
		"target_moodlet": ["flattered", "happy", 1, "Flattered", "Someone noticed!", 120.0]}))
	out.append(_make("Deep Conversation", 40.0, {"social": 100.0, "fun": 5.0}, {"category": "Friendly", "friendship": 12.0, "min_friendship": 30.0,
		"actor_moodlet": ["meaningful", "happy", 1, "Meaningful Talk", "Really connected with someone.", 180.0],
		"target_moodlet": ["meaningful", "happy", 1, "Meaningful Talk", "Really connected with someone.", 180.0]}))
	out.append(_make("Hug", 10.0, {"social": 90.0}, {"category": "Friendly", "friendship": 5.0, "romance": 2.0, "min_friendship": 40.0,
		"target_moodlet": ["hugged", "happy", 1, "Warm Hug", "Feels good to be appreciated.", 120.0]}))
	out.append(_make("Flirt", 20.0, {"social": 85.0, "fun": 10.0}, {"category": "Romance", "romance": 10.0, "min_friendship": 20.0,
		"actor_moodlet": ["flirty", "flirty", 1, "Flirty", "Something's in the air.", 120.0],
		"target_moodlet": ["flirty", "flirty", 1, "Flirty", "Something's in the air.", 120.0]}))
	out.append(_make("Kiss", 15.0, {"social": 90.0}, {"category": "Romance", "romance": 12.0, "friendship": 3.0, "min_romance": 30.0,
		"actor_moodlet": ["kissed", "flirty", 2, "First Kiss Glow", "Wow.", 240.0],
		"target_moodlet": ["kissed", "flirty", 2, "First Kiss Glow", "Wow.", 240.0]}))
	out.append(_make("Try for Baby", 60.0, {"social": 100.0, "fun": 30.0}, {"category": "Romance", "romance": 5.0, "min_romance": 60.0, "baby": true,
		"actor_moodlet": ["in_love", "flirty", 2, "In Love", "Life together is wonderful.", 360.0],
		"target_moodlet": ["in_love", "flirty", 2, "In Love", "Life together is wonderful.", 360.0]}))
	out.append(_make("Cheer Up", 30.0, {"social": 90.0}, {"category": "Friendly", "friendship": 10.0, "target_mood": "sad", "cheer": true,
		"target_moodlet": ["cheered_up", "happy", 2, "Cheered Up", "A friend made everything better.", 240.0]}))
	out.append(_make("Share Ideas", 30.0, {"social": 90.0, "fun": 15.0}, {"category": "Friendly", "friendship": 8.0, "actor_mood": "inspired",
		"actor_moodlet": ["brainstorm", "inspired", 1, "Brainstorm", "Ideas bouncing back and forth.", 180.0],
		"target_moodlet": ["brainstorm", "inspired", 1, "Brainstorm", "Ideas bouncing back and forth.", 180.0]}))
	out.append(_make("Brag", 15.0, {"social": 70.0}, {"category": "Friendly", "friendship": 3.0, "actor_mood": "confident", "risky": true,
		"actor_moodlet": ["bragged", "confident", 1, "Showed Off", "They were clearly impressed.", 120.0]}))
	out.append(_make("Argue", 20.0, {"social": 60.0}, {"category": "Mean", "friendship": -12.0, "actor_mood": "angry",
		"actor_moodlet": ["vented", "fine", 0, "Vented", "Feels good to get that out.", 60.0],
		"target_moodlet": ["argued", "angry", 1, "Had an Argument", "Who do they think they are?", 180.0]}))
	out.append(_make("Ask to Move In", 20.0, {"social": 60.0}, {"category": "Friendly", "friendship": 5.0, "min_friendship": 60.0, "move_in": true,
		"target_moodlet": ["new_home", "happy", 2, "New Home", "Moving in together!", 480.0]}))
	out.append(_make("Propose", 20.0, {"social": 80.0}, {"category": "Romance", "romance": 10.0, "min_romance": 75.0, "marry": true}))
	out.append(_make("Insult", 10.0, {"social": 30.0}, {"category": "Mean", "friendship": -15.0,
		"actor_moodlet": ["mean", "confident", 1, "Got That Off My Chest", "They had it coming.", 90.0],
		"target_moodlet": ["insulted", "angry", 2, "Insulted", "How rude!", 180.0]}))
	return out


static func _make(p_name: String, minutes: float, rates: Dictionary, social: Dictionary) -> Interaction:
	var i := Interaction.new(p_name, rates, minutes, "", "stand", true)
	i.social = social
	return i


static func find(p_name: String) -> Interaction:
	for i in all():
		if i.name == p_name:
			return i
	return null


static func friendship_label(friendship: float, romance: float) -> String:
	if romance >= 60.0:
		return "Sweetheart"
	if romance >= 30.0:
		return "Romantic Interest"
	for lvl in FRIEND_LEVELS:
		if friendship >= lvl[0]:
			return lvl[1]
	return "Enemy"


## Socials worth offering right now; ones that would surely be rejected are still
## shown (that's part of the fun) except kissing before any romance at all.
static func available(friendship: float, romance: float, actor_stage := "young_adult", target_stage := "young_adult", actor_mood := "fine", target_mood := "fine") -> Array[Interaction]:
	var out: Array[Interaction] = []
	for i in all():
		if i.social.get("category", "") == "Romance" and not Ages.romance_ok(actor_stage, target_stage):
			continue
		if not Ages.allows(actor_stage, i):
			continue
		if i.social.has("actor_mood") and actor_mood != i.social["actor_mood"]:
			continue
		if i.social.has("target_mood") and target_mood != i.social["target_mood"]:
			continue
		if i.name == "Try for Baby" and (romance < 50.0 or actor_stage == "elder" or actor_stage == "teen"):
			continue
		if i.name == "Kiss" and romance < 15.0:
			continue
		if i.name == "Propose" and (romance < 50.0 or actor_stage == "teen"):
			continue
		if i.name == "Ask to Move In" and (friendship < 40.0 or not Ages.is_adult(actor_stage)):
			continue
		if i.name == "Hug" and friendship < 20.0:
			continue
		out.append(i)
	return out


## Chance (0..1) that a social lands well, given the relationship and the actor.
static func success_chance(i: Interaction, friendship: float, romance: float, actor_mood: String, actor_traits: Array[String]) -> float:
	var s: Dictionary = i.social
	if friendship < s.get("min_friendship", -1000.0) or romance < s.get("min_romance", -1000.0):
		return 0.0
	if not s.get("risky", false):
		return 1.0
	var c := 0.6
	if actor_mood == "playful":
		c += 0.25
	if actor_traits.has("cheerful"):
		c += 0.1
	if actor_traits.has("gloomy"):
		c -= 0.15
	return clampf(c, 0.05, 0.95)
