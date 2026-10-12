class_name Interaction
extends RefCounted
## Something a Sim can do with an object, e.g. "Sleep" on a bed.

var name: String
## need -> points per game hour while performing (replaces normal decay for that need).
var rates: Dictionary
## Ends early once this need is full ("" = only the time limit applies).
var until_full: String
var max_minutes: float
## "stand", "sit" or "lie".
var pose: String
## Whether the Sim moves its arms while doing this (eating, typing...).
var busy_hands: bool
## Skill practised while performing, and experience per game hour.
var skill := ""
var skill_rate := 0.0
## Moodlet granted once the Sim has done this for a while:
## [id, emotion, weight, label, description, minutes]. Skilled Sims get a stronger one.
var moodlet: Array = []
## Money earned on completion, plus this much more per skill level.
var earns := 0
var earns_per_level := 0
## A HUD panel to open when finished (e.g. "career" after looking for a job).
var opens_panel := ""
## A mess this leaves behind when finished ("dishes"), and whether doing it
## removes the object (cleaning a mess up).
var leaves_mess := ""
var consumes := false
## Repairing: finishing fixes the object.
var fixes := false
## Something the object does when this finishes ("stereo_on", "stereo_off").
var effect := ""
## Only offered while the object is switched on (or off).
var needs_on := false
var needs_off := false
## Simoleons it costs the household each time (a drink at the bar).
var cost := 0
## Only offered while the Sim feels this emotion ("" = any time).
var requires_mood := ""
## Finishing removes every moodlet of this emotion (e.g. crying away sadness).
var clears_emotion := ""


func when_feeling(emotion: String) -> Interaction:
	requires_mood = emotion
	return self


func clearing(emotion: String) -> Interaction:
	clears_emotion = emotion
	return self
## Set for social interactions between two Sims (see Socials).
var social := {}


func _init(p_name: String, p_rates: Dictionary, p_max_minutes: float, p_until_full := "", p_pose := "stand", p_busy_hands := false) -> void:
	name = p_name
	rates = p_rates
	max_minutes = p_max_minutes
	until_full = p_until_full
	pose = p_pose
	busy_hands = p_busy_hands


func practices(p_skill: String, xp_per_hour: float) -> Interaction:
	skill = p_skill
	skill_rate = xp_per_hour
	return self


func grants(id: String, emotion: String, weight: int, label: String, description: String, minutes: float) -> Interaction:
	moodlet = [id, emotion, weight, label, description, minutes]
	return self


func pays(base: int, per_level: int) -> Interaction:
	earns = base
	earns_per_level = per_level
	return self


## An item put in the Sim's inventory when this finishes ("painting").
var creates := ""
## Needs this item in the Sim's inventory (and uses it up): "homework".
var needs_item := ""
## Done together with a partner (WooHoo): only offered when one is around, never autonomous.
var with_partner := false
## Pie menu group this sits in ("Cook..."); "" for the top level.
var menu := ""
## For cooking: the recipe made (see Catalog.RECIPES) and the Cooking level needed.
var recipe := ""
var min_skill := 0


func makes(item: String) -> Interaction:
	creates = item
	return self


func is_social() -> bool:
	return not social.is_empty()


## Game minutes of doing this before its moodlet is earned.
func reward_after() -> float:
	return minf(30.0, max_minutes * 0.5)
