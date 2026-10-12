class_name Burglar
extends Node
## A late-night burglar, as in the reference (Game Options > Gameplay > Allow burglar
## visits): someone in black sneaks in from the street towards the most valuable
## object. A burglar alarm calls the police straight away; a Sim who is awake may
## spot them and call the police; otherwise the object is gone by morning.

signal finished(text: String, stolen: Furniture)

const CHANCE := 0.12
const SPEED := 1.6


## The priciest object a burglar could carry off, or null.
static func pick_target(lot: Lot) -> Furniture:
	var best: Furniture = null
	for f in lot.furniture:
		# Only things one person can carry off: no beds, sofas or big fixtures.
		var tiles := f.footprint.x * f.footprint.y
		if f.wall_mounted or tiles > 2 or f.kind.contains("bed") or f.kind in ["pool", "stairs", "fire", "dishes", "puddle", "meal", "pizza", "tombstone", "burglar_alarm", "fridge", "stove", "toilet", "shower", "sink", "counter", "bathtub", "treadmill", "bar", "fountain"] or f.price <= 0:
			continue
		if best == null or f.price > best.price:
			best = f
	return best


static func has_alarm(lot: Lot) -> bool:
	return lot.furniture.any(func(f): return f.kind == "burglar_alarm")


static func start(parent: Node, lot: Lot, household: Array, rng: RandomNumberGenerator) -> Burglar:
	var target := pick_target(lot)
	if target == null:
		return null
	var b := Burglar.new()
	parent.add_child(b)
	b._run(lot, household, target, rng)
	return b


func _run(lot: Lot, household: Array, target: Furniture, rng: RandomNumberGenerator) -> void:
	var thief := Sim.new()
	thief.sim_name = "Burglar"
	thief.shirt_color = Color(0.08, 0.08, 0.1)
	thief.pants_color = Color(0.08, 0.08, 0.1)
	thief.hair_color = Color(0.08, 0.08, 0.1)
	thief.long_sleeves = true
	thief.away = true
	thief.lot = null
	lot.add_child(thief)
	thief.set_selected(false)
	var start_at := lot.cell_to_world(Vector2i(lot.size.x / 2 - 1, lot.size.y - 1))
	thief.global_position = start_at
	var path := lot.find_path(start_at, target.global_position)
	if path.is_empty():
		path = PackedVector3Array([start_at])
	var awake: Array = household.filter(func(m): return m.visible and not m.away and m.pose_name() != "lie")
	var alarm := has_alarm(lot)
	var spotted: bool = not alarm and not awake.is_empty() and rng.randf() < 0.6
	# How far the burglar gets: alarms go off at the door, a Sim awake spots them halfway.
	var steps := path.size()
	if alarm:
		steps = mini(2, path.size())
	elif spotted:
		steps = maxi(1, path.size() / 2)
	var tw := create_tween()
	var prev := start_at
	for k in range(steps):
		var p := path[k]
		var dir := p - prev
		if dir.length() > 0.01:
			tw.tween_callback(func(): thief.rotation.y = atan2(-dir.x, -dir.z))
		tw.tween_property(thief, "global_position", p, maxf(prev.distance_to(p) / SPEED, 0.05))
		prev = p
	tw.tween_callback(func():
		var text := ""
		var stolen: Furniture = null
		if alarm:
			Sfx.play("alarm", -2.0)
			text = "The burglar alarm went off and the police caught the burglar red-handed!"
			for m in household:
				(m as Sim).emotions.add("burglar_caught", "confident", 1, "Burglar Caught", "That'll teach them.", 360.0)
		elif spotted:
			var hero: Sim = awake[0]
			text = "%s spotted a burglar and called the police. The burglar ran off empty-handed!" % hero.sim_name
			hero.emotions.add("scared_burglar", "tense", 1, "Startled by a Burglar", "Someone was in the house!", 240.0)
		else:
			stolen = target
			text = "A burglar crept in during the night and stole the %s!" % target.display_name
			for m in household:
				(m as Sim).emotions.add("robbed", "angry", 2, "Robbed!", "Someone took our %s!" % target.display_name, 720.0)
		finished.emit(text, stolen))
	# Running off the way they came.
	tw.tween_property(thief, "global_position", start_at + Vector3(0, 0, 6.0), maxf(prev.distance_to(start_at) / (SPEED * 1.8), 0.3))
	tw.tween_callback(func():
		thief.queue_free()
		queue_free())
