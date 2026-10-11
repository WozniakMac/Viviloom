class_name Catalog
extends RefCounted
## Builds the furniture the game knows about. All shapes are simple original placeholders.

const KINDS: Array[String] = ["fridge", "bed", "toilet", "shower", "tv", "desk"]

const WHITE := Color(0.93, 0.93, 0.9)
const WOOD := Color(0.55, 0.38, 0.24)
const DARK := Color(0.12, 0.12, 0.14)


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
				Interaction.new("Have a Meal", {"hunger": 75.0, "fun": 2.0}, 80.0, "hunger", "stand", true),
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
				Interaction.new("Sleep", sleep_rates, 600.0, "energy", "lie"),
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
				Interaction.new("Take a Shower", {"hygiene": 220.0}, 40.0, "hygiene", "stand", true),
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
				Interaction.new("Play Games", {"fun": 45.0, "energy": -6.0}, 180.0, "fun", "sit", true),
			]
		_:
			push_error("Unknown furniture kind: %s" % kind)
	f.build_collider()
	return f
