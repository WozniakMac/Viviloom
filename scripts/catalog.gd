class_name Catalog
extends RefCounted
## Builds the furniture the game knows about. All shapes are simple original placeholders.

const KINDS: Array[String] = ["fridge", "bed", "toilet", "shower", "tv", "desk", "bookshelf", "easel", "chess"]

## Display name and price for the build-mode catalogue.
const INFO := {
	"bed": ["Double Bed", 1100],
	"fridge": ["Fridge", 800],
	"toilet": ["Toilet", 300],
	"shower": ["Shower", 650],
	"tv": ["Television", 500],
	"desk": ["Computer Desk", 450],
	"bookshelf": ["Bookshelf", 250],
	"easel": ["Easel", 350],
	"chess": ["Chess Table", 400],
}
## Build-mode catalogue sections: [id, label]; "all" lists everything.
const CATEGORIES := [["all", "All"], ["bedroom", "Bedroom"], ["kitchen", "Kitchen"], ["bathroom", "Bathroom"], ["fun", "Fun"], ["hobby", "Hobbies"]]
const CATEGORY_OF := {
	"bed": "bedroom", "fridge": "kitchen", "toilet": "bathroom", "shower": "bathroom",
	"tv": "fun", "desk": "fun", "chess": "hobby", "easel": "hobby", "bookshelf": "hobby",
}
const DESCRIPTIONS := {
	"bed": "A sturdy double bed. Restful nights, fewer grumpy mornings.",
	"fridge": "Keeps food cold and ideas fresh. Snacks or a proper home-cooked meal.",
	"toilet": "Does exactly what you'd hope.",
	"shower": "A quick rinse or a long think, your choice.",
	"tv": "Hours of fun, and cooking shows for the ambitious.",
	"desk": "A desk with a computer for chatting and gaming.",
	"bookshelf": "Browse for inspiration or study for the brain.",
	"easel": "Paint, improve, sell. Repeat.",
	"chess": "Practise chess and sharpen your logic.",
}
const WALL_PRICE := 14
const DOOR_PRICE := 150

const WHITE := Color(0.93, 0.93, 0.9)
const WOOD := Color(0.55, 0.38, 0.24)
const DARK := Color(0.12, 0.12, 0.14)


## Tooltip text for the catalogue: name, price, description and what it's good for.
static func describe(kind: String) -> String:
	var f := create(kind)
	var helps := {}
	var skills := {}
	for i in f.interactions:
		for n in i.rates:
			if i.rates[n] > 0.0:
				helps[Needs.LABELS[n]] = true
		if i.skill != "":
			skills[Skills.label(i.skill)] = true
	f.free()
	var text: String = "%s\n§ %d\n%s" % [INFO[kind][0], INFO[kind][1], DESCRIPTIONS[kind]]
	if not helps.is_empty():
		text += "\nNeeds: " + ", ".join(PackedStringArray(helps.keys()))
	if not skills.is_empty():
		text += "\nSkills: " + ", ".join(PackedStringArray(skills.keys()))
	return text


static func create(kind: String) -> Furniture:
	var f := Furniture.new()
	f.kind = kind
	f.name = kind.capitalize()
	match kind:
		"fridge":
			f.display_name = "Fridge"
			f.height = 1.9
			f.add_box(Vector3(0.85, 1.9, 0.75), Vector3(0, 0.95, -0.05), WHITE)
			f.add_box(Vector3(0.86, 0.02, 0.02), Vector3(0, 1.25, 0.33), Color(0.6, 0.6, 0.6))
			f.add_box(Vector3(0.04, 0.5, 0.04), Vector3(0.33, 1.55, 0.35), Color(0.5, 0.5, 0.55))
			f.add_box(Vector3(0.04, 0.4, 0.04), Vector3(0.33, 0.9, 0.35), Color(0.5, 0.5, 0.55))
			f.spots = [Vector3(0, 0, 1.0)]
			f.interactions = [
				Interaction.new("Grab a Snack", {"hunger": 90.0}, 15.0, "hunger", "stand", true),
				Interaction.new("Cook a Meal", {"hunger": 75.0, "fun": 4.0}, 80.0, "hunger", "stand", true).practices("cooking", 70.0).grants("tasty_meal", "happy", 1, "Tasty Meal", "That really hit the spot.", 180.0),
			]
		"bed":
			f.display_name = "Double Bed"
			f.footprint = Vector2i(2, 2)
			f.height = 0.9
			f.add_box(Vector3(1.9, 0.35, 1.95), Vector3(0, 0.18, 0), WOOD)
			f.add_box(Vector3(1.8, 0.2, 1.85), Vector3(0, 0.45, 0.02), WHITE)
			f.add_box(Vector3(1.82, 0.06, 1.25), Vector3(0, 0.57, 0.33), Color(0.3, 0.45, 0.7))
			f.add_box(Vector3(0.6, 0.12, 0.35), Vector3(-0.45, 0.6, -0.7), WHITE)
			f.add_box(Vector3(0.6, 0.12, 0.35), Vector3(0.45, 0.6, -0.7), WHITE)
			f.add_box(Vector3(1.95, 0.9, 0.1), Vector3(0, 0.45, -0.95), WOOD)
			f.spots = [Vector3(-1.5, 0, 0.2), Vector3(1.5, 0, 0.2)]
			f.use_position = Vector3(-0.45, 0.62, 0.92)
			f.use_facing = Vector3(0, 0, 1)
			var sleep_rates := {"energy": 13.0, "hunger": -3.0, "bladder": -4.0, "hygiene": -2.0, "fun": 0.0, "social": -2.0}
			f.interactions = [
				Interaction.new("Sleep", sleep_rates, 600.0, "energy", "lie").grants("well_rested", "energized", 1, "Well Rested", "Ready to take on the day!", 240.0),
				Interaction.new("Nap", sleep_rates, 90.0, "energy", "lie"),
			]
		"toilet":
			f.display_name = "Toilet"
			f.height = 0.9
			f.add_box(Vector3(0.4, 0.42, 0.55), Vector3(0, 0.21, 0.05), WHITE)
			f.add_box(Vector3(0.45, 0.45, 0.2), Vector3(0, 0.62, -0.32), WHITE)
			f.add_box(Vector3(0.42, 0.04, 0.5), Vector3(0, 0.44, 0.07), Color(0.85, 0.85, 0.82))
			f.spots = [Vector3(0, 0, 1.0)]
			f.use_position = Vector3(0, 0, 0.12)
			f.use_facing = Vector3(0, 0, 1)
			f.interactions = [
				Interaction.new("Use Toilet", {"bladder": 350.0, "hygiene": -4.0}, 20.0, "bladder", "sit"),
			]
		"shower":
			f.display_name = "Shower"
			f.height = 2.1
			f.add_box(Vector3(0.95, 0.08, 0.95), Vector3(0, 0.04, 0), WHITE)
			f.add_box(Vector3(0.95, 2.1, 0.05), Vector3(0, 1.05, -0.46), Color(0.75, 0.82, 0.86))
			f.add_box(Vector3(0.05, 2.1, 0.95), Vector3(-0.46, 1.05, 0), Color(0.75, 0.82, 0.86))
			f.add_box(Vector3(0.05, 2.1, 0.95), Vector3(0.46, 1.05, 0), Color(0.7, 0.85, 0.95, 0.35))
			f.add_box(Vector3(0.15, 0.04, 0.15), Vector3(0, 2.0, -0.33), Color(0.6, 0.6, 0.65))
			f.spots = [Vector3(0, 0, 1.0)]
			f.use_position = Vector3(0, 0.08, 0)
			f.use_facing = Vector3(0, 0, 1)
			f.interactions = [
				Interaction.new("Take a Shower", {"hygiene": 220.0}, 40.0, "hygiene", "stand", true).grants("fresh", "happy", 1, "Freshly Showered", "Clean and refreshed.", 120.0),
			]
		"tv":
			f.display_name = "Television"
			f.footprint = Vector2i(2, 1)
			f.height = 1.4
			f.add_box(Vector3(1.6, 0.5, 0.5), Vector3(0, 0.25, 0), WOOD)
			f.add_box(Vector3(1.5, 0.85, 0.06), Vector3(0, 0.95, -0.05), DARK)
			f.add_box(Vector3(1.4, 0.75, 0.01), Vector3(0, 0.95, -0.015), Color(0.15, 0.25, 0.4))
			f.spots = [Vector3(0, 0, 2.5), Vector3(-1.0, 0, 2.5), Vector3(1.0, 0, 2.5)]
			f.interactions = [
				Interaction.new("Watch TV", {"fun": 35.0}, 240.0, "fun"),
				Interaction.new("Watch Cooking Show", {"fun": 20.0}, 120.0, "fun").practices("cooking", 25.0).grants("tv_inspired", "inspired", 1, "Inspired by TV", "So many recipes to try!", 120.0),
			]
		"desk":
			f.display_name = "Computer Desk"
			f.footprint = Vector2i(2, 2)
			f.height = 1.3
			f.add_box(Vector3(1.8, 0.06, 0.8), Vector3(0, 0.74, -0.5), WOOD)
			for x in [-0.85, 0.85]:
				f.add_box(Vector3(0.06, 0.72, 0.75), Vector3(x, 0.36, -0.5), WOOD)
			f.add_box(Vector3(0.65, 0.42, 0.05), Vector3(0, 1.05, -0.72), DARK)
			f.add_box(Vector3(0.6, 0.37, 0.01), Vector3(0, 1.05, -0.695), Color(0.3, 0.55, 0.75))
			f.add_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.45, 0.35), Color(0.2, 0.2, 0.22))
			f.add_box(Vector3(0.5, 0.5, 0.06), Vector3(0, 0.72, 0.6), Color(0.2, 0.2, 0.22))
			f.spots = [Vector3(0, 0, 1.5), Vector3(-1.5, 0, 0.4), Vector3(1.5, 0, 0.4)]
			f.use_position = Vector3(0, 0, 0.35)
			f.use_facing = Vector3(0, 0, -1)
			f.interactions = [
				Interaction.new("Chat Online", {"social": 25.0, "fun": 8.0}, 180.0, "social", "sit", true),
				Interaction.new("Play Games", {"fun": 45.0, "energy": -6.0}, 180.0, "fun", "sit", true).practices("gaming", 60.0).grants("gamer_high", "playful", 1, "Game On", "That was a great match.", 120.0),
			]
		"bookshelf":
			f.display_name = "Bookshelf"
			f.height = 2.0
			f.add_box(Vector3(0.9, 2.0, 0.4), Vector3(0, 1.0, -0.28), WOOD)
			var book_colors := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.7, 0.25), Color(0.25, 0.55, 0.3)]
			for shelf in 4:
				f.add_box(Vector3(0.82, 0.03, 0.34), Vector3(0, 0.15 + shelf * 0.47, -0.24), WOOD.darkened(0.25))
				for b in 5:
					var h := 0.28 + 0.06 * ((b + shelf) % 3)
					f.add_box(Vector3(0.12, h, 0.26), Vector3(-0.3 + b * 0.15, 0.17 + shelf * 0.47 + h * 0.5, -0.24), book_colors[(b + shelf) % 4])
			f.spots = [Vector3(0, 0, 0.9)]
			f.interactions = [
				Interaction.new("Browse Books", {"fun": 30.0}, 60.0, "fun", "stand", true).grants("lit_inspired", "inspired", 1, "Inspired by Literature", "Browsing books sparked some new ideas.", 120.0),
				Interaction.new("Study", {"fun": 8.0}, 120.0, "", "stand", true).practices("logic", 55.0).grants("studied", "focused", 1, "Studious", "Facts are sticking today.", 120.0),
			]
		"easel":
			f.display_name = "Easel"
			f.height = 1.8
			for x in [-0.25, 0.25]:
				var leg := f.add_box(Vector3(0.05, 1.7, 0.05), Vector3(x, 0.85, -0.1), WOOD)
				leg.rotation.z = -x * 0.25
			var back_leg := f.add_box(Vector3(0.05, 1.6, 0.05), Vector3(0, 0.8, -0.35), WOOD)
			back_leg.rotation.x = -0.3
			f.add_box(Vector3(0.7, 0.05, 0.12), Vector3(0, 0.75, -0.05), WOOD)
			f.add_box(Vector3(0.62, 0.72, 0.03), Vector3(0, 1.15, -0.06), WHITE)
			f.add_box(Vector3(0.3, 0.25, 0.01), Vector3(-0.08, 1.2, -0.04), Color(0.3, 0.6, 0.85))
			f.add_box(Vector3(0.18, 0.3, 0.01), Vector3(0.15, 1.05, -0.04), Color(0.9, 0.55, 0.2))
			f.spots = [Vector3(0, 0, 0.9)]
			f.interactions = [
				Interaction.new("Paint", {"fun": 25.0}, 180.0, "", "stand", true).practices("painting", 65.0).grants("proud_painter", "confident", 1, "Proud Painter", "Finished a painting worth showing off.", 180.0).pays(25, 30),
			]
		"chess":
			f.display_name = "Chess Table"
			f.height = 0.9
			f.add_box(Vector3(0.08, 0.7, 0.08), Vector3(0, 0.35, -0.15), DARK)
			f.add_box(Vector3(0.6, 0.05, 0.6), Vector3(0, 0.72, -0.15), WOOD)
			for i in 16:
				var light := (i + i / 4) % 2 == 0
				f.add_box(Vector3(0.12, 0.012, 0.12), Vector3(-0.18 + (i % 4) * 0.12, 0.75, -0.33 + (i / 4) * 0.12), WHITE if light else DARK)
			f.add_box(Vector3(0.4, 0.05, 0.35), Vector3(0, 0.45, 0.3), WOOD.darkened(0.2))
			f.spots = [Vector3(0, 0, 0.9)]
			f.use_position = Vector3(0, 0, 0.3)
			f.use_facing = Vector3(0, 0, -1)
			f.interactions = [
				Interaction.new("Practise Chess", {"fun": 30.0}, 120.0, "fun", "sit", true).practices("logic", 70.0).grants("chess_focus", "focused", 1, "Sharp Thinking", "Thinking several moves ahead.", 120.0),
			]
		_:
			push_error("Unknown furniture kind: %s" % kind)
	f.price = INFO[kind][1]
	f.build_collider()
	return f
