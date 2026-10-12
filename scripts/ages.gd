class_name Ages
extends RefCounted
## Life stages: how long each lasts (in game days), how big a Sim is, and what
## they're allowed to do.

const ORDER: Array[String] = ["toddler", "child", "teen", "young_adult", "adult", "elder"]
const INFO := {
	"toddler": {"label": "Toddler", "days": 4, "scale": 0.5, "speed": 0.6},
	"child": {"label": "Child", "days": 8, "scale": 0.66, "speed": 0.85},
	"teen": {"label": "Teen", "days": 8, "scale": 0.93, "speed": 1.0},
	"young_adult": {"label": "Young Adult", "days": 14, "scale": 1.0, "speed": 1.0},
	"adult": {"label": "Adult", "days": 14, "scale": 1.0, "speed": 1.0},
	"elder": {"label": "Elder", "days": 10, "scale": 0.97, "speed": 0.8},
}
## What a toddler can do on their own (everything else is too grown-up).
const TODDLER_CAN: Array[String] = ["Nap", "Sleep", "Sit", "Grab a Snack", "Use Toilet", "Take a Shower", "Watch TV", "Chat", "Hug", "Tell a Joke", "Have a Proper Meal", "Play with Toys", "Grab a Serving"]
## School for children and teens: [label, start hour, end hour].
const SCHOOL := {"child": ["Grade School", 8, 15], "teen": ["High School", 8, 15]}


static func label(stage: String) -> String:
	return INFO[stage]["label"]


static func next(stage: String) -> String:
	var i := ORDER.find(stage)
	return ORDER[i + 1] if i >= 0 and i < ORDER.size() - 1 else ""


static func is_adult(stage: String) -> bool:
	return stage in ["young_adult", "adult", "elder"]


## Age rules plus mood: some interactions only appear in a certain emotion.
static func allows_for(sim: Sim, interaction: Interaction) -> bool:
	if interaction.requires_mood != "" and sim.emotions.mood() != interaction.requires_mood:
		return false
	if interaction.min_skill > 0 and sim.skills.level(interaction.skill) < interaction.min_skill:
		return false
	if interaction.needs_item != "" and not sim.inventory.any(func(it): return it.get("kind") == interaction.needs_item):
		return false
	if interaction.with_partner and sim.woohoo_partner() == null:
		return false
	return allows(sim.age_stage, interaction)


## Whether a Sim at `stage` can do `interaction` (romance and jobs are for grown-ups).
static func allows(stage: String, interaction: Interaction) -> bool:
	if stage == "toddler":
		return TODDLER_CAN.has(interaction.name)
	if interaction.opens_panel == "career" and not is_adult(stage):
		return false
	if interaction.is_social() and interaction.social.get("category", "") == "Romance" and not is_adult(stage):
		return false
	return true


## Romance needs two grown-ups, or two teens.
static func romance_ok(a: String, b: String) -> bool:
	return (is_adult(a) and is_adult(b)) or (a == "teen" and b == "teen")
