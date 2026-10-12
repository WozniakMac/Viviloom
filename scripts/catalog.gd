class_name Catalog
extends RefCounted
## Builds the furniture the game knows about. All shapes are simple original placeholders.

const KINDS: Array[String] = ["fridge", "bed", "toilet", "shower", "tv", "desk", "bookshelf", "easel", "chess", "lamp", "sofa", "dining_table", "chair", "counter", "stove", "sink", "plant", "mailbox", "bench", "tree", "bush", "grill", "picnic_table", "fountain", "treadmill", "mirror", "guitar", "stairs", "bar", "stereo", "toybox"]

## Messes made by Sims: not sold in the catalogue, cleaned up by Sims.
const MESSES: Array[String] = ["dishes", "puddle", "fire"]
## Recipes: [name, Cooking level needed, servings, minutes to cook, plate colour].
const RECIPES := [
	["Grilled Cheese", 0, 4, 30.0, Color(0.95, 0.78, 0.35)],
	["Pancakes", 0, 4, 30.0, Color(0.9, 0.7, 0.45)],
	["Mac and Cheese", 1, 6, 45.0, Color(0.98, 0.8, 0.3)],
	["Garden Salad", 2, 6, 30.0, Color(0.45, 0.75, 0.35)],
	["Spaghetti", 3, 6, 60.0, Color(0.85, 0.35, 0.25)],
	["Roast Chicken", 5, 6, 75.0, Color(0.8, 0.55, 0.3)],
	["Grilled Salmon", 7, 6, 60.0, Color(0.95, 0.55, 0.45)],
	["Baked Alaska", 9, 8, 90.0, Color(0.98, 0.92, 0.85)],
]
const MEAL_QUALITY: Array[String] = ["Poor", "Normal", "Good", "Excellent"]
## Objects that wear out and sometimes break when used.
const BREAKABLE: Array[String] = ["tv", "desk", "stove", "fridge", "shower", "toilet", "treadmill", "sink"]
const BREAK_CHANCE := 0.04
## Cooks below this skill level can set the kitchen on fire.
const FIRE_SKILL := 3
const FIRE_CHANCE := 0.12

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
	"lamp": ["Floor Lamp", 120],
	"sofa": ["Three-Seat Sofa", 750],
	"dining_table": ["Dining Table", 380],
	"chair": ["Dining Chair", 90],
	"counter": ["Kitchen Counter", 210],
	"stove": ["Stove", 600],
	"sink": ["Kitchen Sink", 260],
	"plant": ["Potted Plant", 60],
	"mailbox": ["Mailbox", 50],
	"bench": ["Park Bench", 180],
	"tree": ["Shade Tree", 120],
	"bush": ["Round Bush", 40],
	"grill": ["Charcoal Grill", 280],
	"picnic_table": ["Picnic Table", 320],
	"fountain": ["Wishing Fountain", 900],
	"treadmill": ["Treadmill", 650],
	"mirror": ["Standing Mirror", 150],
	"guitar": ["Acoustic Guitar", 300],
	"stairs": ["Staircase", 800],
	"bar": ["Bar Counter", 1400],
	"stereo": ["Stereo", 350],
	"toybox": ["Toy Box", 120],
	"car": ["Car", 0],
	"pizza": ["Pizza", 0],
	"dishes": ["Dirty Dishes", 0],
	"puddle": ["Puddle", 0],
	"fire": ["Fire!", 0],
	"pool": ["Swimming Pool", 0],
	"tombstone": ["Tombstone", 0],
	"painting": ["Painting", 0],
	"meal": ["Meal", 0],
}
## Build-mode catalogue sections: [id, label]; "all" lists everything.
const CATEGORIES := [["all", "All"], ["bedroom", "Bedroom"], ["kitchen", "Kitchen"], ["bathroom", "Bathroom"], ["fun", "Fun"], ["hobby", "Hobbies"], ["living", "Living"], ["outdoor", "Outdoor"]]
const CATEGORY_OF := {
	"bed": "bedroom", "fridge": "kitchen", "toilet": "bathroom", "shower": "bathroom",
	"tv": "fun", "desk": "fun", "chess": "hobby", "easel": "hobby", "bookshelf": "hobby", "lamp": "bedroom",
	"sofa": "living", "dining_table": "living", "chair": "living", "counter": "kitchen", "stove": "kitchen",
	"sink": "kitchen", "plant": "living", "mailbox": "outdoor",
	"bench": "outdoor", "tree": "outdoor", "bush": "outdoor", "grill": "outdoor", "picnic_table": "outdoor", "fountain": "outdoor",
	"treadmill": "hobby", "mirror": "bedroom", "guitar": "hobby", "stairs": "living", "bar": "fun", "stereo": "fun", "toybox": "bedroom",
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
	"lamp": "A warm glow for the evenings. Switches on by itself at dusk.",
	"sofa": "Room for three, or one very relaxed Sim.",
	"dining_table": "Proper meals taste better at a proper table.",
	"chair": "A simple chair. Sit, think, eat.",
	"counter": "Prep space for salads and sandwiches.",
	"stove": "Where real cooking happens. Mind the smoke alarm.",
	"sink": "Wash up, freshen up.",
	"plant": "A bit of green. Needs the occasional drink.",
	"mailbox": "Bills arrive here. Pay them before the power goes out.",
	"bench": "Sit a while and watch the world go by.",
	"tree": "Leafy, shady, and very good at standing still.",
	"bush": "A tidy little bush.",
	"grill": "Burgers taste better outdoors.",
	"picnic_table": "Room for a whole family's lunch.",
	"fountain": "Toss in a coin and make a wish.",
	"treadmill": "Run for miles without leaving the room.",
	"mirror": "Practise speeches until you believe them.",
	"guitar": "Strum, practise, maybe even get good.",
	"toybox": "Blocks, dolls and a squeaky duck. Little ones love it.",
	"stereo": "Turn it up and dance the night away.",
	"bar": "A bar with stools. Drinks cost a few Simoleons each.",
	"stairs": "Leads up to the next floor. The top step needs floor upstairs to land on.",
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
			]
			f.interactions.append_array(_recipes(3))
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
			f.extra_positions = [Vector3(0.45, 0.62, 0.92)]
			f.use_facing = Vector3(0, 0, 1)
			var sleep_rates := {"energy": 13.0, "hunger": -3.0, "bladder": -4.0, "hygiene": -2.0, "fun": 0.0, "social": -2.0}
			f.interactions = [
				_cry(),
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
				Interaction.new("Take a Thinking Shower", {"hygiene": 180.0}, 50.0, "hygiene", "stand", true).when_feeling("inspired").grants("shower_thoughts", "inspired", 2, "Shower Thoughts", "Had a brilliant idea in the shower!", 240.0),
				Interaction.new("Take a Steamy Shower", {"hygiene": 180.0, "fun": 10.0}, 40.0, "hygiene", "stand", true).when_feeling("flirty").grants("steamy", "flirty", 1, "Steamy", "Feeling irresistible.", 180.0),
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
				_find_job(),
				_homework(),
				Interaction.new("Chat Online", {"social": 25.0, "fun": 8.0}, 180.0, "social", "sit", true),
				Interaction.new("Write a Book", {"fun": 10.0}, 240.0, "", "sit", true).practices("writing", 55.0).pays(40, 35).grants("author", "confident", 1, "Published Author", "Their words are out in the world.", 240.0),
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
				Interaction.new("Paint", {"fun": 25.0}, 180.0, "", "stand", true).practices("painting", 65.0).grants("proud_painter", "confident", 1, "Proud Painter", "Finished a painting worth showing off.", 180.0).makes("painting"),
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
		"lamp":
			f.display_name = "Floor Lamp"
			f.height = 1.7
			f.add_box(Vector3(0.35, 0.04, 0.35), Vector3(0, 0.02, 0), DARK)
			f.add_box(Vector3(0.04, 1.45, 0.04), Vector3(0, 0.74, 0), DARK)
			var shade_mesh := CylinderMesh.new()
			shade_mesh.top_radius = 0.14
			shade_mesh.bottom_radius = 0.24
			shade_mesh.height = 0.3
			var shade := MeshInstance3D.new()
			shade.name = "Shade"
			shade.mesh = shade_mesh
			shade.position = Vector3(0, 1.5, 0)
			var shade_mat := StandardMaterial3D.new()
			shade_mat.albedo_color = Color(0.96, 0.9, 0.78)
			shade.material_override = shade_mat
			f.add_child(shade)
			var glow := OmniLight3D.new()
			glow.name = "Glow"
			glow.position = Vector3(0, 1.4, 0)
			glow.light_color = Color(1.0, 0.82, 0.6)
			glow.light_energy = 1.6
			glow.omni_range = 6.5
			glow.shadow_enabled = false
			glow.visible = false
			f.add_child(glow)
			f.add_to_group("lamps")
		"sofa":
			f.display_name = "Sofa"
			f.footprint = Vector2i(3, 1)
			f.height = 0.9
			f.spots = [Vector3(0, 0, 1.0), Vector3(-1.0, 0, 1.0), Vector3(1.0, 0, 1.0)]
			f.use_position = Vector3(0, 0.05, 0.05)
			f.use_facing = Vector3(0, 0, 1)
			f.interactions = [
				Interaction.new("Sit", {"fun": 6.0, "energy": 3.0}, 60.0, "", "sit"),
				Interaction.new("Sulk", {"fun": 4.0}, 45.0, "", "sit").when_feeling("angry").clearing("angry").grants("calmed", "fine", 0, "Calmed Down", "Got it out of their system.", 60.0),
				Interaction.new("Nap", {"energy": 9.0, "hunger": -3.0, "bladder": -4.0}, 90.0, "energy", "lie"),
			]
		"dining_table":
			f.display_name = "Dining Table"
			f.footprint = Vector2i(2, 1)
			f.height = 0.8
			f.spots = [Vector3(0, 0, 1.0), Vector3(0, 0, -1.0)]
			f.use_position = Vector3(0, 0, 0.55)
			f.use_facing = Vector3(0, 0, -1)
			f.interactions = [
				_homework(),
				_dishes(Interaction.new("Have a Proper Meal", {"hunger": 80.0, "social": 4.0}, 45.0, "hunger", "sit", true).grants("good_meal", "happy", 1, "Nice Dinner", "Eating at the table makes all the difference.", 180.0)),
			]
		"chair":
			f.display_name = "Dining Chair"
			f.height = 1.0
			f.spots = [Vector3(0, 0, 0.9)]
			f.use_position = Vector3(0, 0, 0.05)
			f.use_facing = Vector3(0, 0, 1)
			f.interactions = [Interaction.new("Sit", {"fun": 3.0}, 30.0, "", "sit")]
		"counter":
			f.display_name = "Kitchen Counter"
			f.height = 0.95
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				_dishes(Interaction.new("Make a Salad", {"hunger": 70.0}, 30.0, "hunger", "stand", true).practices("cooking", 50.0)),
			]
		"stove":
			f.display_name = "Stove"
			f.height = 0.95
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = _recipes(10)
		"sink":
			f.display_name = "Kitchen Sink"
			f.height = 1.2
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				Interaction.new("Wash Up", {"hygiene": 120.0}, 15.0, "hygiene", "stand", true),
			]
		"plant":
			f.display_name = "Potted Plant"
			f.height = 0.8
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				Interaction.new("Water", {"fun": 15.0}, 10.0, "", "stand", true).practices("gardening", 40.0).grants("green_thumb", "happy", 1, "Green Thumb", "The plant looks grateful.", 90.0),
			]
		"mailbox":
			f.display_name = "Mailbox"
			f.height = 1.4
			f.spots = [Vector3(0, 0, 0.8), Vector3(0, 0, -0.8)]
			var pay := Interaction.new("Pay Bills", {}, 10.0, "", "stand", true)
			pay.opens_panel = "pay_bills"
			f.interactions = [pay]
		"bench":
			f.display_name = "Park Bench"
			f.footprint = Vector2i(2, 1)
			f.height = 0.9
			f.spots = [Vector3(0, 0, 0.9), Vector3(-0.6, 0, 0.9), Vector3(0.6, 0, 0.9)]
			f.use_position = Vector3(0, 0.0, 0.0)
			f.use_facing = Vector3(0, 0, 1)
			f.interactions = [Interaction.new("Sit", {"fun": 6.0, "energy": 2.0}, 60.0, "", "sit")]
		"tree", "bush":
			f.display_name = INFO[kind][0]
			f.height = 3.0 if kind == "tree" else 0.8
		"grill":
			f.display_name = "Charcoal Grill"
			f.height = 1.0
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				_dishes(Interaction.new("Grill Burgers", {"hunger": 75.0, "fun": 8.0}, 50.0, "hunger", "stand", true).practices("cooking", 60.0).grants("bbq", "happy", 1, "Backyard Barbecue", "Nothing beats a grilled burger.", 180.0)),
			]
		"picnic_table":
			f.display_name = "Picnic Table"
			f.footprint = Vector2i(2, 2)
			f.height = 0.8
			f.spots = [Vector3(0, 0, 1.3), Vector3(0, 0, -1.3)]
			f.use_position = Vector3(0, 0, 0.6)
			f.use_facing = Vector3(0, 0, -1)
			f.interactions = [
				_dishes(Interaction.new("Have a Picnic", {"hunger": 60.0, "social": 10.0, "fun": 10.0}, 45.0, "hunger", "sit", true).grants("picnic", "happy", 1, "Lovely Picnic", "Fresh air and good food.", 180.0)),
			]
		"fountain":
			f.display_name = "Wishing Fountain"
			f.footprint = Vector2i(2, 2)
			f.height = 1.3
			f.spots = [Vector3(0, 0, 1.4), Vector3(1.4, 0, 0), Vector3(-1.4, 0, 0)]
			f.interactions = [
				Interaction.new("Make a Wish", {"fun": 20.0}, 10.0, "", "stand", true).grants("wished", "inspired", 1, "Made a Wish", "Maybe it'll come true...", 240.0),
			]
		"treadmill":
			f.display_name = "Treadmill"
			f.footprint = Vector2i(1, 2)
			f.height = 1.4
			f.spots = [Vector3(0, 0, 1.4), Vector3(0.9, 0, 0)]
			f.use_position = Vector3(0, 0.16, 0.1)
			f.use_facing = Vector3(0, 0, -1)
			f.interactions = [
				Interaction.new("Jog", {"fun": 12.0, "energy": -14.0, "hygiene": -18.0}, 60.0, "", "run").practices("fitness", 65.0).grants("pumped", "energized", 1, "Pumped", "Great workout!", 180.0),
			]
		"mirror":
			f.display_name = "Standing Mirror"
			f.height = 1.8
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				Interaction.new("Practise Speech", {"fun": 8.0, "social": 6.0}, 45.0, "", "stand", true).practices("charisma", 60.0).grants("confident_talk", "confident", 1, "Feeling Charming", "Ready to win anyone over.", 180.0),
				Interaction.new("Admire Self", {"fun": 10.0}, 10.0, "", "stand").grants("looking_good", "confident", 1, "Looking Good", "Not bad at all.", 90.0),
				Interaction.new("Give Self a Pep Talk", {"fun": 5.0}, 15.0, "", "stand").when_feeling("tense").clearing("tense").grants("pep_talk", "confident", 1, "Pep Talk", "You've got this.", 180.0),
			]
		"guitar":
			f.display_name = "Acoustic Guitar"
			f.height = 1.5
			f.spots = [Vector3(0, 0, 0.8)]
			f.interactions = [
				Interaction.new("Practise Guitar", {"fun": 30.0}, 90.0, "fun", "stand", true).practices("guitar", 60.0).grants("jammed", "playful", 1, "Jammed Out", "That riff is stuck in their head.", 180.0),
				Interaction.new("Play for Tips", {"fun": 20.0}, 90.0, "", "stand", true).practices("guitar", 40.0).pays(10, 15),
			]
		"dishes":
			f.display_name = "Dirty Dishes"
			f.blocks = false
			f.height = 0.15
			for k in 3:
				var plate := f.add_box(Vector3(0.26 - k * 0.02, 0.025, 0.26 - k * 0.02), Vector3(0.05 * k, 0.015 + k * 0.026, -0.03 * k), WHITE)
				plate.rotation.y = k * 0.5
			f.add_box(Vector3(0.1, 0.02, 0.08), Vector3(-0.02, 0.09, 0.0), Color(0.55, 0.35, 0.2))
			f.spots = [Vector3.ZERO]
			var clean := Interaction.new("Clean Up", {"fun": 2.0}, 10.0, "", "stand", true)
			clean.consumes = true
			f.interactions = [clean]
		"bar":
			f.display_name = "Bar Counter"
			f.footprint = Vector2i(2, 1)
			f.height = 1.3
			f.spots = [Vector3(0, 0, 1.3), Vector3(-0.7, 0, 1.3), Vector3(0.7, 0, 1.3)]
			var drink := Interaction.new("Order a Drink", {"fun": 30.0, "social": 15.0}, 30.0, "", "stand", true).grants("bubbly", "playful", 1, "Bubbly", "That drink hit the spot.", 120.0)
			drink.cost = 12
			f.interactions = [drink, Interaction.new("Chat with the Bartender", {"social": 70.0}, 30.0, "social", "stand", true)]
		"toybox":
			f.display_name = "Toy Box"
			f.height = 0.55
			f.add_box(Vector3(0.8, 0.45, 0.5), Vector3(0, 0.23, -0.1), Color(0.95, 0.75, 0.3))
			f.add_box(Vector3(0.84, 0.05, 0.54), Vector3(0, 0.48, -0.1), Color(0.3, 0.55, 0.85))
			for k in 4:
				f.add_box(Vector3(0.12, 0.12, 0.12), Vector3(-0.25 + k * 0.17, 0.06, 0.32), [Color(0.9, 0.3, 0.3), Color(0.3, 0.7, 0.4), Color(0.3, 0.5, 0.9), Color(0.95, 0.8, 0.2)][k])
			f.spots = [Vector3(0, 0, 0.9)]
			f.interactions = [
				Interaction.new("Play with Toys", {"fun": 60.0, "social": 5.0}, 60.0, "fun", "stand", true).grants("playtime", "playful", 1, "Playtime!", "Toys are the best.", 120.0),
			]
		"stereo":
			f.display_name = "Stereo"
			f.height = 0.7
			f.spots = [Vector3(0, 0, 1.0), Vector3(0.9, 0, 0.8), Vector3(-0.9, 0, 0.8)]
			var on := Interaction.new("Turn On", {}, 5.0, "", "stand", true)
			on.effect = "stereo_on"
			on.needs_off = true
			var off := Interaction.new("Turn Off", {}, 5.0, "", "stand", true)
			off.effect = "stereo_off"
			off.needs_on = true
			var dance := Interaction.new("Dance", {"fun": 45.0, "energy": -8.0, "social": 5.0}, 60.0, "fun", "dance").grants("dancing", "playful", 1, "Danced It Out", "Couldn't stop moving!", 180.0)
			dance.needs_on = true
			var listen := Interaction.new("Listen to Music", {"fun": 25.0}, 45.0, "fun", "stand").grants("tunes", "happy", 1, "Good Tunes", "That song is stuck in their head.", 120.0)
			listen.needs_on = true
			f.interactions = [on, off, dance, listen]
		"pizza":
			f.display_name = "Pizza"
			f.blocks = false
			f.height = 0.1
			f.spots = [Vector3(0, 0, 0.0)]
			f.set_meta("servings", 4)
			f.interactions = [_dishes(Interaction.new("Have a Slice", {"hunger": 90.0, "fun": 5.0}, 15.0, "hunger", "stand", true).grants("pizza", "happy", 1, "Pizza Night", "Nothing like a hot slice.", 120.0))]
		"stairs":
			f.display_name = "Staircase"
			f.footprint = Vector2i(1, 3)
			f.height = Lot.WALL_HEIGHT
			# Twelve solid steps rising from the front (+Z) to the back, with rails.
			var steps := 12
			var rise := Lot.WALL_HEIGHT / steps
			var run := 3.0 / steps
			for k in steps:
				var h := rise * (k + 1)
				f.add_box(Vector3(0.94, h, run), Vector3(0, h * 0.5, 1.5 - run * (k + 0.5)), WOOD if k % 2 == 0 else WOOD.darkened(0.08))
			for x in [-0.47, 0.47]:
				var rail := f.add_box(Vector3(0.04, 0.04, 3.4), Vector3(x, Lot.WALL_HEIGHT * 0.5 + 0.9, 0), DARK)
				rail.rotation.x = atan2(Lot.WALL_HEIGHT, 3.0)
		"meal":
			# A serving platter; make_meal() sets the food, servings and quality.
			f.display_name = "Meal"
			f.blocks = false
			f.height = 0.15
			f.add_box(Vector3(0.5, 0.03, 0.36), Vector3(0, 0.015, 0), WHITE)
			f.spots = [Vector3(0, 0, 0.9)]
			f.interactions = [_dishes(Interaction.new("Grab a Serving", {"hunger": 160.0}, 20.0, "hunger", "stand", true))]
		"painting":
			# Its picture and value come from make_painting().
			f.display_name = "Painting"
			f.wall_mounted = true
			f.blocks = false
			f.height = 0.6
			f.spots = [Vector3(0, -1.45, 1.1)]
			f.interactions = [Interaction.new("View", {"fun": 20.0}, 15.0, "", "stand").grants("art", "inspired", 1, "Inspired by Art", "What a lovely painting.", 120.0)]
		"tombstone":
			f.display_name = "Tombstone"
			f.height = 1.0
			var stone := Color(0.62, 0.63, 0.66)
			f.add_box(Vector3(0.7, 0.08, 0.45), Vector3(0, 0.04, 0), stone.darkened(0.2))
			f.add_box(Vector3(0.55, 0.85, 0.14), Vector3(0, 0.5, -0.08), stone)
			f.add_box(Vector3(0.4, 0.05, 0.02), Vector3(0, 0.75, 0.0), stone.darkened(0.35))
			f.add_box(Vector3(0.05, 0.3, 0.02), Vector3(0, 0.62, 0.0), stone.darkened(0.35))
			f.spots = [Vector3(0, 0, 1.0)]
			f.interactions = [
				Interaction.new("Mourn", {"social": 20.0}, 30.0, "", "stand").grants("mourned", "sad", 1, "Paid Respects", "They're gone, but not forgotten.", 240.0),
			]
		"pool":
			# Its footprint, spots and visuals come from Lot.add_pool.
			f.display_name = "Swimming Pool"
			f.height = 0.2
			f.use_position = Vector3(0, Lot.WATER_LEVEL - 0.05, 0)
			# Several swimmers share a pool.
			f.extra_positions = [f.use_position, f.use_position, f.use_position]
			f.interactions = [
				Interaction.new("Swim", {"fun": 35.0, "hygiene": 20.0, "energy": -10.0}, 60.0, "", "swim").practices("fitness", 45.0).grants("swim", "happy", 1, "Refreshing Swim", "The water was perfect.", 180.0),
			]
		"fire":
			f.display_name = "Fire!"
			f.blocks = false
			f.height = 1.0
			var flames := CPUParticles3D.new()
			flames.amount = 40
			flames.lifetime = 0.9
			flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			flames.emission_sphere_radius = 0.3
			flames.direction = Vector3.UP
			flames.spread = 15.0
			flames.initial_velocity_min = 0.8
			flames.initial_velocity_max = 1.6
			flames.gravity = Vector3(0, 1.0, 0)
			flames.scale_amount_min = 0.2
			flames.scale_amount_max = 0.5
			var grad := Gradient.new()
			grad.set_color(0, Color(1.0, 0.85, 0.3))
			grad.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
			flames.color_ramp = grad
			var puff := SphereMesh.new()
			puff.radius = 0.5
			puff.height = 1.0
			flames.mesh = puff
			var fm := StandardMaterial3D.new()
			fm.vertex_color_use_as_albedo = true
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			flames.material_override = fm
			f.add_child(flames)
			var glow := OmniLight3D.new()
			glow.position.y = 0.6
			glow.light_color = Color(1.0, 0.55, 0.2)
			glow.light_energy = 2.5
			glow.omni_range = 5.0
			f.add_child(glow)
			f.spots = [Vector3(0, 0, 1.0), Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0)]
			var douse := Interaction.new("Put Out Fire", {}, 20.0, "", "stand", true)
			douse.consumes = true
			douse.grants("hero", "confident", 2, "Fire Fighter", "Saved the house!", 240.0)
			f.interactions = [douse]
		"puddle":
			f.display_name = "Puddle"
			f.blocks = false
			f.height = 0.05
			var p := f.add_box(Vector3(0.8, 0.01, 0.6), Vector3(0, 0.025, 0), Color(0.75, 0.85, 0.3, 0.55))
			p.rotation.y = 0.4
			f.spots = [Vector3.ZERO]
			var mop := Interaction.new("Mop Up", {"hygiene": -2.0}, 15.0, "", "stand", true)
			mop.consumes = true
			f.interactions = [mop]
		_:
			push_error("Unknown furniture kind: %s" % kind)
	f.price = INFO[kind][1]
	_use_model(f, kind)
	if kind == "bed":
		# A duvet that covers whoever is sleeping (hidden while the bed is empty).
		var covers := f.add_box(Vector3(1.88, 0.26, 1.4), Vector3(0, 0.84, 0.28), Color(0.32, 0.48, 0.78))
		covers.name = "Covers"
		covers.visible = false
	if kind != "pool":
		f.build_collider()
	return f


static func _find_job() -> Interaction:
	var i := Interaction.new("Find a Job", {}, 20.0, "", "sit", true)
	i.opens_panel = "career"
	return i


## Swaps the placeholder boxes for the Blender model (tools/make_objects.py) when one
## exists. Lamps keep their light; the model's shade becomes the glowing "Shade".
static func _use_model(f: Furniture, kind: String) -> void:
	var path := "res://assets/objects/%s.glb" % kind
	if not ResourceLoader.exists(path):
		return
	for c in f.get_children():
		if c is MeshInstance3D:
			f.remove_child(c)
			c.free()
	var model := (load(path) as PackedScene).instantiate()
	f.add_child(model)
	var shade := model.find_child("Shade", true, false) as MeshInstance3D
	if shade != null:
		shade.get_parent().remove_child(shade)
		shade.name = "Shade"
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.9, 0.76)
		shade.material_override = m
		f.add_child(shade)


## Meals leave a stack of dirty dishes behind.
static func _dishes(i: Interaction) -> Interaction:
	i.leaves_mess = "dishes"
	return i


## Crying on the bed while sad makes the sadness go away.
static func _cry() -> Interaction:
	return Interaction.new("Cry It Out", {"energy": -4.0}, 40.0, "", "lie").when_feeling("sad").clearing("sad") \
		.grants("cried", "fine", 0, "Feeling Better", "A good cry really helps.", 120.0)


const PAINTING_QUALITY: Array[String] = ["Poor", "Decent", "Good", "Masterpiece"]


## A finished painting from inventory data: an abstract picture drawn from its
## seed in a wooden frame, worth `value`.
static func make_painting(item: Dictionary) -> Furniture:
	var f := create("painting")
	var seed: int = item.get("seed", 1)
	var q: int = item.get("quality", 0)
	f.price = item.get("value", 20)
	f.display_name = "%s Painting" % PAINTING_QUALITY[q]
	f.set_meta("item", item.duplicate())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var frame := WOOD.darkened(0.3) if q < 3 else Color(0.85, 0.68, 0.25)
	f.add_box(Vector3(0.82, 0.62, 0.04), Vector3(0, 0, 0), frame)
	f.add_box(Vector3(0.72, 0.52, 0.01), Vector3(0, 0, 0.022), Color.from_hsv(rng.randf(), 0.15, 0.95))
	# Better painters use more, bolder shapes.
	for k in 2 + q * 2:
		var w := rng.randf_range(0.08, 0.32)
		var h := rng.randf_range(0.06, 0.26)
		var col := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.85), rng.randf_range(0.5, 0.95))
		f.add_box(Vector3(w, h, 0.004), Vector3(rng.randf_range(-0.3 + w * 0.5, 0.3 - w * 0.5), rng.randf_range(-0.2 + h * 0.5, 0.2 - h * 0.5), 0.03 + k * 0.001), col)
	if q >= 2:
		f.interactions[0].moodlet = ["art", "inspired", q, "Inspired by Art", "What a wonderful painting.", 180.0]
	return f


## "Cook..." interactions for recipes up to `max_level` Cooking (the stove has them
## all, the fridge only the simple ones). Cooks skilled enough get each recipe.
static func _recipes(max_level: int) -> Array[Interaction]:
	var out: Array[Interaction] = []
	for r in RECIPES:
		if r[1] > max_level:
			continue
		var i := Interaction.new("Cook %s" % r[0], {"fun": 5.0}, r[3], "", "stand", true).practices("cooking", 80.0)
		i.menu = "Cook..."
		i.recipe = r[0]
		i.min_skill = r[1]
		out.append(i)
	return out


static func recipe(name: String) -> Array:
	for r in RECIPES:
		if r[0] == name:
			return r
	return RECIPES[0]


## A platter of `recipe_name` with its servings, cooked to `quality` (0..3).
static func make_meal(recipe_name: String, quality: int) -> Furniture:
	var f := create("meal")
	var r := recipe(recipe_name)
	f.display_name = "%s (%s)" % [r[0], MEAL_QUALITY[quality]]
	f.set_meta("servings", r[2])
	f.set_meta("quality", quality)
	f.set_meta("recipe", r[0])
	var food: Color = r[4]
	if quality == 0:
		food = food.darkened(0.45)
	for k in 3:
		f.add_box(Vector3(0.12, 0.05, 0.1), Vector3(-0.13 + k * 0.13, 0.055, 0.0), food.lightened(0.08 * k))
	var serve: Interaction = f.interactions[0]
	match quality:
		0:
			serve.moodlet = ["bad_food", "uncomfortable", 1, "Ate Something Gross", "That was... not good.", 120.0]
		2:
			serve.moodlet = ["good_food", "happy", 1, "Tasty Meal", "That really hit the spot.", 180.0]
		3:
			serve.moodlet = ["great_food", "happy", 2, "Delicious Meal", "Best meal in ages!", 240.0]
	return f


## Doing homework raises the school grade; it needs homework in the inventory.
static func _homework() -> Interaction:
	var i := Interaction.new("Do Homework", {"fun": -10.0}, 60.0, "", "sit", true).practices("logic", 30.0) \
		.grants("homework_done", "confident", 1, "Homework Done", "Free at last!", 180.0)
	i.needs_item = "homework"
	return i
