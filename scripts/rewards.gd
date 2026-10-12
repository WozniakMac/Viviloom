class_name Rewards
extends RefCounted
## The Rewards Store: satisfaction points from wants and milestones buy potions
## and lasting perks.

## id -> [name, price, description]
const INFO := {
	"happy_potion": ["Potion of Joy", 400, "A big, warm, happy moodlet for most of a day."],
	"focus_potion": ["Potion of Focus", 400, "Sharp, focused thinking for most of a day."],
	"energy_potion": ["Energizing Draught", 300, "Fills Energy right up."],
	"fast_learner": ["Fast Learner", 1500, "A lasting perk: every skill is learned 25% faster."],
	"youth_potion": ["Potion of Youth", 2000, "Turns back the clock to the start of the current life stage."],
	"steel_bladder": ["Steel Bladder", 1200, "A lasting perk: Bladder drains half as fast."],
}
const ORDER: Array[String] = ["happy_potion", "focus_potion", "energy_potion", "fast_learner", "steel_bladder", "youth_potion"]
const PERKS: Array[String] = ["fast_learner", "steel_bladder"]


static func name_of(id: String) -> String:
	return INFO[id][0]


static func price(id: String) -> int:
	return INFO[id][1]


## Buys `id` for `sim` with `tracker`'s satisfaction points. Returns a message.
static func buy(id: String, sim: Sim, tracker: AspirationTracker) -> String:
	if PERKS.has(id) and sim.perks.has(id):
		return "%s already has %s." % [sim.sim_name, name_of(id)]
	if tracker.satisfaction < price(id):
		return "Not enough satisfaction points for %s." % name_of(id)
	tracker.satisfaction -= price(id)
	match id:
		"happy_potion":
			sim.emotions.add("potion_joy", "happy", 3, "Potion of Joy", "Everything is wonderful.", 720.0)
		"focus_potion":
			sim.emotions.add("potion_focus", "focused", 3, "Potion of Focus", "Crystal-clear thinking.", 720.0)
		"energy_potion":
			sim.needs.set_value("energy", 100.0)
		"youth_potion":
			sim.age_days = 0
			sim.emotions.add("youthful", "happy", 2, "Young Again", "Feeling years younger.", 480.0)
		_:
			sim.perks.append(id)
	tracker.changed.emit()
	return "%s used %s." % [sim.sim_name, name_of(id)]
