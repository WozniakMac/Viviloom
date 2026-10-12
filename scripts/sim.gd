class_name Sim
extends Node3D
## A simple stylised person. Walks along paths from its Lot and works through a queue
## of actions (walk somewhere, or use an object).

signal arrived
signal queue_changed
signal action_failed(message: String)
## Something worth telling the player (skill level, money earned...).
signal announced(message: String)
signal earned(amount: int)
signal relationships_changed
## A "Try for Baby" went well with `partner`.
signal baby_tried(partner: Sim)
## A Move In or Propose went well; main brings `other` into the household.
signal moving_in(other: Sim)
## The Sim has died; main calls the Grim Reaper.
signal died(cause: String)
## Asks the HUD to show a panel ("career"...).
signal panel_requested(panel: String)
## An activity or social was done long enough to count (for wants and goals).
signal activity_done(activity: String)

const MAX_QUEUE := 8
## Game minutes a Sim stands around before deciding something on their own.
const IDLE_BEFORE_AUTONOMY := 4.0


class SimAction:
	extends RefCounted
	var label: String
	var target := Vector3.ZERO
	var furniture: Furniture
	var interaction: Interaction
	var autonomous := false
	var started := false
	var performing := false
	var elapsed := 0.0
	var spot := Vector3.ZERO
	## For socials: who they're talking to, whether it will land, re-path attempts.
	var target_sim: Sim
	var outcome := true
	var retries := 0
	## Which level a "Go Here" leads to (null = the Sim's current level).
	var target_lot: Lot
	## Taking the stairs: the staircase, and where the climb starts and ends.
	var stairs: Furniture
	var climb_from := Vector3.ZERO
	var climb_to := Vector3.ZERO
	var climb_lot: Lot

	func progress() -> float:
		if not performing or interaction == null:
			return 0.0
		return clampf(elapsed / interaction.max_minutes, 0.0, 1.0)


@export var sim_name := "Alex"
@export var shirt_color := Color(0.22, 0.47, 0.82)
@export var pants_color := Color(0.18, 0.2, 0.28)
@export var skin_color := Color(0.87, 0.69, 0.55)
@export var hair_color := Color(0.25, 0.16, 0.1)
## "short", "long" or "bun".
@export var hair_style := "short"
## Body shape sliders (0..1) and outfit cut.
@export var body_heavy := 0.0
@export var body_fit := 0.0
@export var long_sleeves := false
@export var shorts := false

const MODEL := preload("res://assets/sim/sim.glb")
const PORTRAIT_LAYER := 4
const HAIR_STYLES: Array[String] = ["short", "long", "bun"]
@export var walk_speed := 2.0

var lot: Lot
var needs := Needs.new()
var emotions := Emotions.new()
var skills := Skills.new()
var traits: Array[String] = []
## trait -> game minutes until its periodic moodlet comes back.
var _trait_timers := {}
var autonomy_enabled := true
## Other Sim -> Vector2(friendship -100..100, romance 0..100).
var relationships := {}
## Visitors aren't controlled by the player and come and go on their own.
var is_visitor := false
## Lifelong goal (see Aspirations) and counters it can check, e.g. "paintings_sold".
var aspiration := "renaissance"
## Lasting perks bought in the Rewards Store.
var perks: Array = []
## The household's funds pay for things that cost money (null for townies).
var wallet: BuildMode
## Married partner, if any.
var spouse: Sim
## Life stage (see Ages) and days lived in it; days of pregnancy (-1 = not expecting).
var age_stage := "young_adult"
var age_days := 0
var pregnant_days := -1
var stats := {}
## Off the lot (at work, or a visitor who went home).
var away := false
var _social_with: Sim = null
var _social_interaction: Interaction
var _idle_minutes := 0.0
var _rng := RandomNumberGenerator.new()
var queue: Array[SimAction] = []
var path := PackedVector3Array()
var _path_index := 0
var _pose := "stand"
var _selected := false
var _voice: AudioStreamPlayer3D
## Game minutes left lying on the floor after collapsing from exhaustion.
var _passed_out := 0.0
## Set while the Grim Reaper is collecting this Sim.
var dying := false
## Game minutes spent starving, and too close to a fire.
var _starving := 0.0
var _burning := 0.0
const STARVE_MINUTES := 1440.0
const BURN_MINUTES := 40.0
## While swimming: the pool's centre and half size, and the lap phase.
var _swim_center := Vector3.ZERO
var _swim_half := Vector2.ONE
var _swim_phase := 0.0
var _voice_timer := 0.0
## Voice pitch, picked once per Sim.
var _voice_pitch := 1.0
var _voice_high := false

var _body: Node3D
var _anim: AnimationPlayer
## Hair style name -> its mesh in the model.
var _hair_meshes := {}
var _body_mesh: MeshInstance3D
var _selection_ring: MeshInstance3D
var _plumbob: MeshInstance3D
## Materials by part ("shirt", "pants", "skin", "hair") so the look can change later.
var _materials := {}


func _ready() -> void:
	_build_visual()
	set_age(age_stage)
	skills.leveled_up.connect(func(s: String, l: int):
		Sfx.play("level_up", -4.0)
		announced.emit("%s reached %s level %d!" % [sim_name, Skills.label(s), l]))
	earned.connect(func(_a: int): Sfx.play("cash", -4.0))
	_voice = AudioStreamPlayer3D.new()
	_voice.position = Vector3(0, 1.6, 0)
	_voice.unit_size = 6.0
	_voice.max_db = -2.0
	add_child(_voice)
	var h := hash(sim_name) if sim_name != "" else randi()
	_voice_high = h % 2 == 0
	_voice_pitch = 0.92 + float(h % 17) / 100.0


## Recolours one part of the Sim: "shirt", "pants", "skin" or "hair".
func set_part_color(part: String, c: Color) -> void:
	match part:
		"shirt": shirt_color = c
		"pants": pants_color = c
		"skin": skin_color = c
		"hair": hair_color = c
	if _materials.has(part):
		(_materials[part] as BaseMaterial3D).albedo_color = c
	_apply_outfit()
	_store_outfit()


## Outfit categories, each with its own top, bottom and cut. The Sim wears one
## at a time and changes (with a spin) to suit what they're doing.
const OUTFITS: Array[String] = ["everyday", "sleep", "athletic", "swim"]
const OUTFIT_LABELS := {"everyday": "Everyday", "sleep": "Sleepwear", "athletic": "Athletic", "swim": "Swimwear"}
var outfits := {}
var outfit := "everyday"


## The outfit the Sim is wearing, saved into its category.
func _store_outfit() -> void:
	outfits[outfit] = {"shirt": shirt_color, "pants": pants_color, "long_sleeves": long_sleeves, "shorts": shorts}


## Fills in missing categories from the everyday outfit.
func _default_outfits() -> void:
	var every: Dictionary = outfits.get("everyday", {"shirt": shirt_color, "pants": pants_color, "long_sleeves": long_sleeves, "shorts": shorts})
	outfits["everyday"] = every
	if not outfits.has("sleep"):
		outfits["sleep"] = {"shirt": Color(0.72, 0.8, 0.95), "pants": Color(0.72, 0.8, 0.95), "long_sleeves": true, "shorts": false}
	if not outfits.has("athletic"):
		outfits["athletic"] = {"shirt": (every["shirt"] as Color).lightened(0.2), "pants": Color(0.15, 0.15, 0.18), "long_sleeves": false, "shorts": true}
	if not outfits.has("swim"):
		outfits["swim"] = {"shirt": Color(0.95, 0.4, 0.35), "pants": Color(0.2, 0.45, 0.85), "long_sleeves": false, "shorts": true}


## Changes into another outfit category; `spin` plays the quick twirl.
func change_outfit(category: String, spin := true) -> void:
	if outfits.is_empty():
		_default_outfits()
	if category == outfit or not outfits.has(category):
		return
	outfit = category
	var o: Dictionary = outfits[category]
	shirt_color = o["shirt"]
	pants_color = o["pants"]
	long_sleeves = o["long_sleeves"]
	shorts = o["shorts"]
	for part in ["shirt", "pants"]:
		if _materials.has(part):
			(_materials[part] as BaseMaterial3D).albedo_color = shirt_color if part == "shirt" else pants_color
	_apply_outfit()
	if spin and is_inside_tree() and visible:
		_spin()


## The outfit change twirl: a quick spin with a burst of sparkles.
func _spin() -> void:
	Sfx.play("select", -10.0)
	var tw := create_tween()
	tw.tween_property(_body, "rotation:y", _body.rotation.y + TAU, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _body.rotation.y = 0.0)
	var sparkle := CPUParticles3D.new()
	sparkle.one_shot = true
	sparkle.amount = 30
	sparkle.lifetime = 0.8
	sparkle.explosiveness = 0.8
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.5
	sparkle.position = Vector3(0, 1.0 * size_scale(), 0)
	sparkle.direction = Vector3.UP
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 0.4
	sparkle.initial_velocity_max = 1.2
	sparkle.gravity = Vector3.ZERO
	sparkle.scale_amount_min = 0.03
	sparkle.scale_amount_max = 0.07
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	sparkle.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle.material_override = m
	add_child(sparkle)
	sparkle.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparkle.queue_free)


## Which outfit suits an interaction.
static func outfit_for(i: Interaction) -> String:
	if i == null:
		return "everyday"
	if i.name in ["Sleep", "Nap"] and i.pose == "lie":
		return "sleep"
	if i.pose == "swim":
		return "swim"
	if i.skill == "fitness":
		return "athletic"
	return "everyday"


## Sleeves and lower legs show cloth or skin depending on the outfit's cut.
func _apply_outfit() -> void:
	if _materials.has("sleeve"):
		(_materials["sleeve"] as BaseMaterial3D).albedo_color = shirt_color if long_sleeves else skin_color
	if _materials.has("shin"):
		(_materials["shin"] as BaseMaterial3D).albedo_color = skin_color if shorts else pants_color


func set_outfit(p_long_sleeves: bool, p_shorts: bool) -> void:
	long_sleeves = p_long_sleeves
	shorts = p_shorts
	_apply_outfit()
	_store_outfit()


## Body sliders: 0..1 heavier and 0..1 more muscular.
func set_body(heavy: float, fit: float) -> void:
	body_heavy = clampf(heavy, 0.0, 1.0)
	body_fit = clampf(fit, 0.0, 1.0)
	if _body_mesh == null:
		return
	for pair in [["Heavy", body_heavy], ["Fit", body_fit]]:
		var idx := _body_mesh.find_blend_shape_by_name(pair[0])
		if idx >= 0:
			_body_mesh.set_blend_shape_value(idx, pair[1])


func set_hair_style(style: String) -> void:
	hair_style = style
	for k in _hair_meshes:
		(_hair_meshes[k] as Node3D).visible = k == style


## Changes life stage: size, walking speed, and grey hair for elders.
func set_age(stage: String) -> void:
	age_stage = stage
	var info: Dictionary = Ages.INFO[stage]
	if _body != null:
		var k: float = info["scale"]
		_body.scale = Vector3.ONE * k
	walk_speed = 2.0 * info["speed"]
	if stage == "elder":
		set_part_color("hair", hair_color.lerp(Color(0.82, 0.82, 0.84), 0.75))


func size_scale() -> float:
	return Ages.INFO[age_stage]["scale"]


## Replaces the Sim's traits and their lasting moodlets.
func set_traits(list: Array[String]) -> void:
	for t in traits:
		emotions.remove("trait_" + t)
	traits = list.duplicate()
	_trait_timers.clear()
	for t in traits:
		var info: Dictionary = Traits.INFO[t]
		if info.has("lasting"):
			var l: Array = info["lasting"]
			emotions.add("trait_" + t, l[0], l[1], l[2], l[3])
		if info.has("periodic"):
			# First occurrence comes partway through the cycle.
			_trait_timers[t] = info["periodic"][4] * 0.25


func _update_traits(minutes: float) -> void:
	for t in _trait_timers:
		_trait_timers[t] -= minutes
		if _trait_timers[t] <= 0.0:
			var p: Array = Traits.INFO[t]["periodic"]
			_trait_timers[t] += p[4]
			emotions.add("trait_" + t, p[0], p[1], p[2], p[3], p[5])


func is_moving() -> bool:
	return _path_index < path.size()


func is_idle() -> bool:
	return queue.is_empty()


func current_action() -> SimAction:
	return queue[0] if not queue.is_empty() else null


## Starts walking to `target`. Returns false if there is no route.
func move_to(target: Vector3) -> bool:
	var p := lot.find_path(global_position, target)
	if p.is_empty():
		return false
	path = p
	_path_index = 0
	return true


## Drops every queued action (used when entering build mode).
func clear_queue() -> void:
	while not queue.is_empty():
		cancel(queue.size() - 1)
	stop()


func stop() -> void:
	path = PackedVector3Array()
	_path_index = 0


func set_selected(selected: bool) -> void:
	_selected = selected
	_selection_ring.visible = selected and _pose == "stand"
	_plumbob.visible = selected


func queue_go(target: Vector3, on_lot: Lot = null) -> bool:
	var a := SimAction.new()
	a.label = "Go Here"
	a.target = target
	a.target_lot = on_lot
	return _enqueue(a)


## Every level of the lot (set by main); the ground floor first.
var levels: Array = []


## Furniture on every level, for autonomy.
func all_furniture() -> Array:
	if levels.is_empty():
		return lot.furniture
	var out: Array = []
	for l in levels:
		out.append_array(l.furniture)
	return out


## The level an action takes place on.
func _action_lot(a: SimAction) -> Lot:
	if a.furniture != null and a.furniture.get_parent() is Lot:
		return a.furniture.get_parent()
	if a.target_lot != null:
		return a.target_lot
	return lot


## Puts a "Take Stairs" step before `a` when it's on another level. Returns false
## (and fails `a`) when there is no way up or down.
func _route_levels(a: SimAction) -> bool:
	var dest := _action_lot(a)
	if dest == lot or levels.is_empty():
		return true
	var stairs: Furniture = null
	for f in (levels[0] as Lot).furniture:
		if f.kind == "stairs":
			stairs = f
	if stairs == null:
		_fail(a, "%s can't get to the other floor without stairs." % sim_name)
		return false
	var up := dest.level > lot.level
	var bottom := stairs.to_global(Vector3(0, 0, 2.0))
	var top := stairs.to_global(Vector3(0, Lot.WALL_HEIGHT, -2.0))
	var climb := SimAction.new()
	climb.label = "Take Stairs"
	climb.stairs = stairs
	climb.climb_from = bottom if up else top
	climb.climb_to = top if up else bottom
	climb.climb_lot = dest
	climb.autonomous = a.autonomous
	a.started = false
	queue.insert(0, climb)
	queue_changed.emit()
	return true


## Everything about this Sim that a save game needs. Relationships are stored by
## the other Sim's name.
func to_dict() -> Dictionary:
	var moods: Array = []
	for m in emotions.moodlets:
		# Trait and need moodlets are rebuilt from traits and needs on load.
		if m.id.begins_with("trait_") or m.id.begins_with("need_"):
			continue
		moods.append([m.id, m.emotion, m.weight, m.label, m.description, m.remaining if m.remaining != INF else -1.0])
	var rels := {}
	for o in relationships:
		if is_instance_valid(o):
			rels[o.sim_name] = [relationships[o].x, relationships[o].y]
	return {
		"name": sim_name,
		"colors": {"shirt": shirt_color.to_html(), "pants": pants_color.to_html(), "skin": skin_color.to_html(), "hair": hair_color.to_html()},
		"hair_style": hair_style,
		"body": [body_heavy, body_fit, long_sleeves, shorts],
		"outfit": outfit,
		"outfits": _outfits_dict(),
		"age": [age_stage, age_days, pregnant_days],
		"perks": perks.duplicate(),
		"spouse": spouse.sim_name if spouse != null and is_instance_valid(spouse) else "",
		"traits": traits,
		"aspiration": aspiration,
		"needs": needs.values.duplicate(),
		"skills": skills.xp.duplicate(),
		"moodlets": moods,
		"stats": stats.duplicate(),
		"position": [global_position.x, global_position.z],
		"relationships": rels,
	}


func from_dict(d: Dictionary, others: Array) -> void:
	sim_name = d.get("name", sim_name)
	for part in d.get("colors", {}):
		set_part_color(part, Color.html(d["colors"][part]))
	set_hair_style(d.get("hair_style", hair_style))
	var bd: Array = d.get("body", [0.0, 0.0, false, false])
	set_body(bd[0], bd[1])
	set_outfit(bd[2], bd[3])
	outfits.clear()
	for k in d.get("outfits", {}):
		var o: Dictionary = d["outfits"][k]
		outfits[k] = {"shirt": Color.html(o["shirt"]), "pants": Color.html(o["pants"]), "long_sleeves": o["long_sleeves"], "shorts": o["shorts"]}
	_default_outfits()
	var wearing: String = d.get("outfit", "everyday")
	outfit = ""
	change_outfit(wearing, false)
	perks = d.get("perks", []).duplicate()
	var ag: Array = d.get("age", ["young_adult", 0, -1])
	age_days = int(ag[1])
	pregnant_days = int(ag[2])
	set_age(ag[0])
	var t: Array[String] = []
	for x in d.get("traits", []):
		t.append(x)
	set_traits(t)
	aspiration = d.get("aspiration", aspiration)
	for n in d.get("needs", {}):
		needs.set_value(n, d["needs"][n])
	for s in d.get("skills", {}):
		skills.xp[s] = d["skills"][s]
	for m in d.get("moodlets", []):
		emotions.add(m[0], m[1], int(m[2]), m[3], m[4], INF if m[5] < 0.0 else m[5])
	stats = d.get("stats", {}).duplicate()
	var pos: Array = d.get("position", [global_position.x, global_position.z])
	global_position = Vector3(pos[0], 0.0, pos[1])
	relationships.clear()
	spouse = null
	for o in others:
		if o != self and o.sim_name == d.get("spouse", "") and d.get("spouse", "") != "":
			spouse = o
		if o != self and d.get("relationships", {}).has(o.sim_name):
			var r: Array = d["relationships"][o.sim_name]
			relationships[o] = Vector2(r[0], r[1])
	relationships_changed.emit()


func _outfits_dict() -> Dictionary:
	_store_outfit()
	var out := {}
	for k in outfits:
		var o: Dictionary = outfits[k]
		out[k] = {"shirt": (o["shirt"] as Color).to_html(), "pants": (o["pants"] as Color).to_html(), "long_sleeves": o["long_sleeves"], "shorts": o["shorts"]}
	return out


func count_stat(stat: String, amount := 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount


func friendship_with(o: Sim) -> float:
	return (relationships.get(o, Vector2.ZERO) as Vector2).x


func romance_with(o: Sim) -> float:
	return (relationships.get(o, Vector2.ZERO) as Vector2).y


func relationship_label(o: Sim) -> String:
	if spouse == o:
		return "Spouse"
	return Socials.friendship_label(friendship_with(o), romance_with(o))


## Changes the relationship on both sides.
func change_relationship(o: Sim, d_friend: float, d_romance: float) -> void:
	for pair in [[self, o], [o, self]]:
		var a: Sim = pair[0]
		var b: Sim = pair[1]
		var r: Vector2 = a.relationships.get(b, Vector2.ZERO)
		a.relationships[b] = Vector2(clampf(r.x + d_friend, -100.0, 100.0), clampf(r.y + d_romance, 0.0, 100.0))
		a.relationships_changed.emit()


## The category ("Friendly", "Romance", "Mean") of the social this Sim is in, or "".
func social_bubble() -> String:
	if _social_with != null and _social_interaction != null:
		return _social_interaction.social.get("category", "Friendly")
	var cur := current_action()
	if cur != null and cur.performing and cur.target_sim != null:
		return cur.interaction.social.get("category", "Friendly")
	return ""


## The lowest need if it's desperately low, for a thought bubble.
func desperate_need() -> String:
	var n := needs.lowest()
	return n if needs.get_value(n) < Needs.CRITICAL else ""


## Whether another Sim can start talking to this one right now.
func can_socialize() -> bool:
	return visible and not away and _pose != "lie" and _social_with == null


func is_socializing() -> bool:
	return _social_with != null


func queue_social(target: Sim, interaction: Interaction, autonomous := false) -> bool:
	var a := SimAction.new()
	a.label = "%s with %s" % [interaction.name, target.sim_name]
	a.target_sim = target
	a.interaction = interaction
	a.autonomous = autonomous
	return _enqueue(a)


## Called on the Sim being talked to: they stop and face the speaker.
func join_social(partner: Sim, interaction: Interaction) -> void:
	_social_with = partner
	_social_interaction = interaction
	stop()
	var cur := current_action()
	if cur != null and cur.started and not cur.performing:
		cur.started = false
	elif cur != null and cur.performing and cur.autonomous:
		cancel(0)


func leave_social(partner: Sim) -> void:
	if _social_with == partner:
		_social_with = null
		_social_interaction = null


func _face_toward(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func queue_interaction(f: Furniture, interaction: Interaction, autonomous := false) -> bool:
	var a := SimAction.new()
	a.label = interaction.name
	a.furniture = f
	a.interaction = interaction
	a.autonomous = autonomous
	return _enqueue(a)


## Cancels the action at `index`; a running one stops right away.
func cancel(index: int) -> void:
	if index < 0 or index >= queue.size():
		return
	var a := queue[index]
	if a.stairs != null and a.performing:
		# Never leave a Sim halfway up the stairs: finish the climb.
		lot = a.climb_lot
		global_position = a.climb_to
	elif a.started:
		if a.performing:
			_end_perform(a)
		else:
			stop()
	queue.erase(a)
	queue_changed.emit()


func _enqueue(a: SimAction) -> bool:
	if not a.autonomous:
		# A direct order replaces whatever the Sim chose on their own.
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].autonomous:
				cancel(i)
	if queue.size() >= MAX_QUEUE:
		action_failed.emit("%s's queue is full." % sim_name)
		return false
	queue.append(a)
	queue_changed.emit()
	return true


func _process(real_delta: float) -> void:
	if away:
		return
	if dying:
		_animate(Clock.scaled(real_delta), false, null)
		return
	var delta := Clock.scaled(real_delta)
	if _passed_out > 0.0:
		_sleep_it_off(delta)
		return
	if _social_with != null:
		_listen(delta)
		return
	_check_limits()
	var cur := current_action()
	if cur != null and not cur.started:
		_start(cur)
		cur = current_action()

	var rates := {}
	if cur != null and cur.performing and cur.interaction != null:
		rates = cur.interaction.rates
		_practise(cur.interaction, Clock.game_delta)
	needs.tick(Clock.game_delta, rates, _decay_mult())
	emotions.tick(Clock.game_delta)
	emotions.sync_needs(needs)
	_update_traits(Clock.game_delta)

	_update_autonomy()
	var moving := _follow_path(delta)
	if cur != null and cur.stairs != null and cur.started:
		moving = _climb(cur, delta) or moving
	elif cur != null and cur.started and not cur.performing and not is_moving():
		if cur.interaction == null:
			_complete(cur)
		elif cur.target_sim != null and global_position.distance_to(cur.target_sim.global_position) > 1.8 and cur.retries < 3:
			# They moved while we walked over; catch up.
			cur.retries += 1
			_path_to_partner(cur)
		else:
			_begin_perform(cur)
	elif cur != null and cur.performing:
		if cur.target_sim != null:
			_chatter(delta)
		cur.elapsed += Clock.game_delta
		var full := cur.interaction.until_full != "" and needs.get_value(cur.interaction.until_full) >= 99.9
		var lost := cur.target_sim != null and cur.target_sim._social_with != self
		if cur.elapsed >= cur.interaction.max_minutes or full or lost or _should_abandon(cur):
			_end_perform(cur, true)
			_complete(cur)
	_animate(delta, moving, cur)


## Walks up or down the staircase, then carries on from the other level.
func _climb(a: SimAction, delta: float) -> bool:
	if not a.performing:
		if is_moving():
			return false
		a.performing = true
		a.elapsed = 0.0
		global_position = a.climb_from
	a.elapsed += delta
	var t := clampf(a.elapsed / 2.2, 0.0, 1.0)
	global_position = a.climb_from.lerp(a.climb_to, t)
	var dir := a.climb_to - a.climb_from
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)
	if t >= 1.0:
		lot = a.climb_lot
		a.performing = false
		_complete(a)
		return false
	return true


## What happens when a need runs out completely: an accident, or passing out.
func _check_limits() -> void:
	if lot == null or is_visitor:
		return
	# Starving for a whole day, or standing in a fire too long, is fatal.
	var was_starving := _starving > 0.0
	_starving = _starving + Clock.game_delta if needs.get_value("hunger") <= 0.0 else 0.0
	if _starving > 0.0 and not was_starving:
		announced.emit("%s is starving! Get them something to eat, fast." % sim_name)
	if _starving >= STARVE_MINUTES:
		died.emit("hunger")
		return
	var near_fire := false
	var cur := current_action()
	var fighting := cur != null and cur.furniture != null and cur.furniture.kind == "fire"
	for f in lot.furniture:
		if f.kind == "fire" and f.global_position.distance_to(global_position) < 1.3:
			near_fire = true
	_burning = _burning + Clock.game_delta if near_fire and not fighting else maxf(0.0, _burning - Clock.game_delta)
	if _burning >= BURN_MINUTES:
		died.emit("fire")
		return
	if needs.get_value("bladder") <= 0.0:
		clear_queue()
		lot.add_mess("puddle", global_position)
		needs.set_value("bladder", 100.0)
		needs.add("hygiene", -40.0)
		emotions.add("accident", "embarrassed", 2, "Had an Accident", "That was mortifying.", 240.0)
		Sfx.play("fail", -4.0)
		announced.emit("%s couldn't hold it any longer..." % sim_name)
	elif needs.get_value("energy") <= 0.0:
		clear_queue()
		_passed_out = 180.0
		_set_pose("lie")
		emotions.add("passed_out", "tense", 1, "Passed Out", "Fell asleep on the floor. Ouch.", 300.0)
		announced.emit("%s was so exhausted they passed out on the floor!" % sim_name)


func _sleep_it_off(delta: float) -> void:
	_passed_out -= Clock.game_delta
	needs.tick(Clock.game_delta, {"energy": 25.0}, _decay_mult())
	emotions.tick(Clock.game_delta)
	if _passed_out <= 0.0 or needs.get_value("energy") >= 70.0:
		_passed_out = 0.0
		_set_pose("stand")
	_animate(delta, false, null)


## Sims drop something they chose themselves when another need becomes critical.
func _should_abandon(a: SimAction) -> bool:
	if not a.autonomous:
		return false
	for n in Needs.ORDER:
		if needs.get_value(n) < Needs.CRITICAL and a.interaction.rates.get(n, 0.0) <= 0.0:
			return true
	return false


## Being talked to: stand facing the speaker, gesturing, while Social fills up.
## Babbles now and then while talking.
func _chatter(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		_voice_timer = randf_range(1.6, 3.2)
		Sfx.voice(_voice, _voice_high, _voice_pitch)


func _listen(delta: float) -> void:
	var partner := _social_with
	if not is_instance_valid(partner) or partner.away:
		_social_with = null
		return
	_face_toward(partner.global_position)
	_chatter(delta)
	var rates: Dictionary = _social_interaction.rates if _social_interaction != null else {}
	needs.tick(Clock.game_delta, rates, _decay_mult())
	emotions.tick(Clock.game_delta)
	emotions.sync_needs(needs)
	_update_traits(Clock.game_delta)
	_animate(delta, false, null)


## Need decay multipliers from traits and perks.
func _decay_mult() -> Dictionary:
	var m := Traits.decay_mult(traits)
	if perks.has("steel_bladder"):
		m["bladder"] = m.get("bladder", 1.0) * 0.5
	return m


## Makes the Sim decide what to do on their next update instead of waiting.
func think_now() -> void:
	_idle_minutes = IDLE_BEFORE_AUTONOMY


func _update_autonomy() -> void:
	if not queue.is_empty() or is_moving():
		_idle_minutes = 0.0
		return
	_idle_minutes += Clock.game_delta
	if not autonomy_enabled or _idle_minutes < IDLE_BEFORE_AUTONOMY:
		return
	_idle_minutes = 0.0
	var pick := Autonomy.choose(self, lot, _rng)
	if pick.is_empty():
		return
	if pick[0] is Sim:
		queue_social(pick[0], pick[1], true)
	else:
		queue_interaction(pick[0], pick[1], true)


func _start(a: SimAction) -> void:
	if a.stairs == null and not _route_levels(a):
		return
	if a != current_action():
		# A climb was queued first; it starts on the next update.
		return
	a.started = true
	if a.stairs != null:
		if not move_to(a.climb_from):
			_fail(a, "%s can't reach the stairs." % sim_name)
		return
	if a.target_sim != null:
		_path_to_partner(a)
		return
	if a.interaction == null:
		if not move_to(a.target):
			_fail(a, "%s can't get there." % sim_name)
		return
	var f := a.furniture
	if f.user != null and f.user != self:
		_fail(a, "The %s is in use." % f.display_name)
		return
	if f.broken and not a.interaction.fixes:
		_fail(a, "The %s is broken. Repair it first." % f.display_name)
		return
	if Daylight.power_off and Bills.ELECTRIC.has(f.kind):
		_fail(a, "The %s doesn't work: the power is off. Pay the bills!" % f.display_name)
		return
	var best := PackedVector3Array()
	var best_len := INF
	for s in f.world_spots():
		if not lot.is_walkable(lot.world_to_cell(s)) or lot.crosses_wall(s, f.global_position):
			continue
		var p := lot.find_path(global_position, s)
		if p.is_empty():
			continue
		var length := 0.0
		var prev := global_position
		for q in p:
			length += prev.distance_to(q)
			prev = q
		if length < best_len:
			best_len = length
			best = p
			a.spot = s
	if best.is_empty():
		_fail(a, "%s can't reach the %s." % [sim_name, f.display_name])
		return
	path = best
	_path_index = 0


## Walks up to the Sim we want to talk to, stopping about a metre away.
func _path_to_partner(a: SimAction) -> void:
	var t := a.target_sim
	if not is_instance_valid(t) or (not t.can_socialize() and t._social_with != self):
		_fail(a, "%s is busy right now." % (t.sim_name if is_instance_valid(t) else "They"))
		return
	var away_dir := global_position - t.global_position
	away_dir.y = 0.0
	if away_dir.length() < 0.01:
		away_dir = Vector3.FORWARD
	away_dir = away_dir.normalized()
	for k in 8:
		var dir := away_dir.rotated(Vector3.UP, (k + 1) / 2 * (PI / 4.0) * (1.0 if k % 2 == 0 else -1.0))
		var spot := t.global_position + dir * 1.0
		var cell := lot.world_to_cell(spot)
		if not lot.in_bounds(cell) or not lot.is_walkable(cell) or lot.crosses_wall(spot, t.global_position):
			continue
		var p := lot.find_path(global_position, spot)
		if p.is_empty() and global_position.distance_to(spot) > 0.3:
			continue
		path = p
		_path_index = 0
		a.spot = spot
		return
	_fail(a, "%s can't reach %s." % [sim_name, t.sim_name])


func _begin_social(a: SimAction) -> void:
	var t := a.target_sim
	if not t.can_socialize() and t._social_with != self:
		_fail(a, "%s is busy right now." % t.sim_name)
		return
	a.performing = true
	t.join_social(self, a.interaction)
	_face_toward(t.global_position)
	_set_pose("stand")
	a.outcome = _rng.randf() < Socials.success_chance(a.interaction, friendship_with(t), romance_with(t), emotions.mood(), traits)


## Relationship and moodlets once a social has gone on long enough.
func _social_result(a: SimAction) -> void:
	var t := a.target_sim
	if not is_instance_valid(t) or a.elapsed < a.interaction.reward_after():
		return
	var s: Dictionary = a.interaction.social
	if a.outcome and s.get("baby", false):
		baby_tried.emit(t)
	if a.outcome and s.get("marry", false):
		spouse = t
		t.spouse = self
		emotions.add("married", "happy", 3, "Just Married!", "Happily ever after starts now.", 1440.0)
		t.emotions.add("married", "happy", 3, "Just Married!", "Happily ever after starts now.", 1440.0)
		announced.emit("%s and %s are now married!" % [sim_name, t.sim_name])
	if a.outcome and (s.get("move_in", false) or s.get("marry", false)):
		moving_in.emit(t)
	count_stat("socials")
	var stat: String = {"Tell a Joke": "jokes", "Flirt": "flirts", "Kiss": "kisses"}.get(a.interaction.name, "")
	if stat != "" and a.outcome:
		count_stat(stat)
	activity_done.emit(a.interaction.name)
	if a.outcome:
		if s.get("cheer", false):
			t.emotions.clear_emotion("sad")
		change_relationship(t, s.get("friendship", 0.0), s.get("romance", 0.0))
		var am: Array = s.get("actor_moodlet", [])
		if not am.is_empty():
			emotions.add(am[0], am[1], am[2], am[3], am[4], am[5])
		var tm: Array = s.get("target_moodlet", [])
		if not tm.is_empty():
			t.emotions.add(tm[0], tm[1], tm[2], tm[3], tm[4], tm[5])
		return
	if s.get("risky", false) and friendship_with(t) >= s.get("min_friendship", -1000.0):
		change_relationship(t, -3.0, 0.0)
		emotions.add("fell_flat", "embarrassed", 1, "Fell Flat", "Nobody laughed.", 120.0)
		announced.emit("%s's %s fell flat with %s." % [sim_name, a.interaction.name.to_lower(), t.sim_name])
	else:
		change_relationship(t, -5.0, -3.0 if s.get("category", "") == "Romance" else 0.0)
		emotions.add("rejected", "embarrassed", 2, "Turned Down", "Well, that was awkward.", 180.0)
		t.emotions.add("uncomfortable_advance", "tense", 1, "Awkward Moment", "That came out of nowhere.", 120.0)
		announced.emit("%s wasn't ready for that from %s. Get to know them better first." % [t.sim_name, sim_name])


func _begin_perform(a: SimAction) -> void:
	if a.target_sim != null:
		change_outfit("everyday")
		_begin_social(a)
		return
	if a.furniture.kind != "bed" or a.interaction.pose == "lie":
		change_outfit(outfit_for(a.interaction))
	if a.interaction.cost > 0 and wallet != null:
		if wallet.funds < a.interaction.cost:
			_fail(a, "%s can't afford that (§%d)." % [sim_name, a.interaction.cost])
			return
		wallet.earn(-a.interaction.cost)
		Sfx.play("cash", -8.0)
	# Inexperienced cooks sometimes set the kitchen on fire.
	if a.interaction.skill == "cooking" and a.interaction.leaves_mess != "" and lot != null \
			and skills.level("cooking") < Catalog.FIRE_SKILL and _rng.randf() < Catalog.FIRE_CHANCE:
		var fire := lot.add_mess("fire", a.furniture.global_position + (a.furniture.global_basis * Vector3(0, 0, 1.2)))
		fire.set_meta("source", a.furniture)
		a.furniture.set_broken(true)
		Sfx.play("alarm", -2.0)
		announced.emit("FIRE! %s set the %s on fire!" % [sim_name, a.furniture.display_name])
		_complete(a)
		return
	a.performing = true
	var f := a.furniture
	f.user = self
	var facing: Vector3
	if a.interaction.pose == "swim":
		_swim_center = f.to_global(f.use_position)
		_swim_half = Vector2(f.footprint) * 0.5
		_swim_phase = randf() * TAU
	if f.use_position != null:
		global_position = f.to_global(f.use_position)
		facing = f.global_basis * f.use_facing
	else:
		facing = f.global_position - global_position
	facing.y = 0.0
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)
	_set_pose(a.interaction.pose)


## Experience gained for `minutes` of an activity, sped up by traits and by feeling
## the emotion that suits the skill.
func skill_gain(interaction: Interaction, minutes: float) -> float:
	if interaction.skill == "":
		return 0.0
	var gain := interaction.skill_rate * minutes / 60.0 * Traits.skill_mult(traits, interaction.skill)
	if perks.has("fast_learner"):
		gain *= 1.25
	if emotions.mood() == Skills.boosting_emotion(interaction.skill):
		gain *= Skills.EMOTION_BONUS
	return gain


func _practise(interaction: Interaction, minutes: float) -> void:
	if interaction.skill != "":
		skills.add_xp(interaction.skill, skill_gain(interaction, minutes))


## Moodlet and pay for an activity done long enough. Skill makes both better.
## Pay only comes when the activity is finished, not cancelled.
func _reward(i: Interaction, minutes_done: float, finished: bool) -> void:
	if minutes_done < i.reward_after():
		return
	activity_done.emit(i.name)
	var lvl := skills.level(i.skill) if i.skill != "" else 0
	if not i.moodlet.is_empty():
		var m := i.moodlet
		emotions.add(m[0], m[1], m[2] + lvl / 4, m[3], m[4], m[5])
	if finished and i.opens_panel != "":
		panel_requested.emit(i.opens_panel)
	if i.earns > 0 and finished:
		var amount := i.earns + i.earns_per_level * lvl
		count_stat("paintings_sold")
		earned.emit(amount)
		var what: String = {"Write a Book": "earned §%d in royalties", "Play for Tips": "made §%d in tips"}.get(i.name, "sold their painting for §%d")
		announced.emit(("%s " + what + ".") % [sim_name, amount])


func _end_perform(a: SimAction, finished := false) -> void:
	if not a.performing:
		return
	if a.target_sim != null:
		_social_result(a)
		a.performing = false
		if is_instance_valid(a.target_sim):
			a.target_sim.leave_social(self)
		return
	_reward(a.interaction, a.elapsed, finished)
	a.performing = false
	a.furniture.user = null
	if finished and a.interaction.leaves_mess != "" and lot != null:
		lot.add_mess(a.interaction.leaves_mess, a.spot if a.spot != Vector3.ZERO else global_position)
	elif finished and traits.has("slob") and lot != null and a.furniture.blocks and _rng.randf() < 0.25:
		# Slobs leave a little mess wherever they go.
		lot.add_mess("dishes", a.spot if a.spot != Vector3.ZERO else global_position)
	if finished and a.interaction.effect != "":
		a.furniture.apply_effect(a.interaction.effect)
	if finished and a.interaction.clears_emotion != "":
		emotions.clear_emotion(a.interaction.clears_emotion)
	if finished and a.interaction.fixes:
		a.furniture.set_broken(false)
		announced.emit("%s repaired the %s." % [sim_name, a.furniture.display_name])
	elif finished and lot != null and Catalog.BREAKABLE.has(a.furniture.kind) and _rng.randf() < Catalog.BREAK_CHANCE:
		a.furniture.set_broken(true)
		Sfx.play("demolish", -6.0)
		announced.emit("Oh no, the %s broke! Click it to repair it." % a.furniture.display_name)
	if finished and a.furniture.has_meta("servings") and lot != null:
		var left: int = a.furniture.get_meta("servings") - 1
		a.furniture.set_meta("servings", left)
		if left <= 0:
			lot.remove_furniture(a.furniture)
			a.furniture.queue_free()
			return
	if finished and a.interaction.consumes and lot != null:
		lot.remove_furniture(a.furniture)
		a.furniture.queue_free()
	if a.furniture.use_position != null:
		global_position = a.spot
	_set_pose("stand")


func _complete(a: SimAction) -> void:
	queue.erase(a)
	queue_changed.emit()
	if a.interaction == null:
		arrived.emit()


func _fail(a: SimAction, message: String) -> void:
	queue.erase(a)
	queue_changed.emit()
	if not a.autonomous:
		action_failed.emit(message)


func _follow_path(delta: float) -> bool:
	if _path_index >= path.size():
		return false
	var target := path[_path_index]
	var to := target - global_position
	to.y = 0.0
	var step := walk_speed * delta
	if to.length() <= step:
		global_position = target
		_path_index += 1
		if _path_index >= path.size():
			stop()
			return false
		return true
	var dir := to.normalized()
	global_position += dir * step
	_face(dir, delta)
	return true


func _face(dir: Vector3, delta: float) -> void:
	var desired := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired, 1.0 - exp(-14.0 * delta))


func _set_pose(p: String) -> void:
	_pose = p
	_selection_ring.visible = _selected and _pose == "stand"


## Picks the body animation for what the Sim is doing and lays the body down or
## sits it on furniture.
func _animate(delta: float, moving: bool, cur: SimAction) -> void:
	var busy := cur != null and cur.performing and cur.interaction != null and cur.interaction.busy_hands
	var talking := _social_with != null or (cur != null and cur.performing and cur.target_sim != null)
	var anim := "idle"
	match _pose:
		"sit":
			anim = "sit_use" if busy else "sit"
			_body.rotation.x = 0.0
			_body.position.y = -0.45 * size_scale()
		"lie":
			anim = "lie"
			_body.rotation.x = PI * 0.5
			_body.position.y = 0.15
		"swim":
			# Face down in the water, doing laps round the pool.
			anim = "walk"
			_body.rotation.x = -PI * 0.5
			_body.position.y = 0.0
			_swim_phase += delta * 0.35
			var hx := maxf(_swim_half.x - 0.6, 0.1)
			var hz := maxf(_swim_half.y - 0.6, 0.1)
			var p := _swim_center + Vector3(cos(_swim_phase) * hx, 0, sin(_swim_phase) * hz)
			var tangent := Vector3(-sin(_swim_phase) * hx, 0, cos(_swim_phase) * hz)
			global_position = p
			if tangent.length() > 0.01:
				rotation.y = atan2(-tangent.x, -tangent.z)
		_:
			_body.rotation.x = 0.0
			_body.position.y = 0.0
			if moving or (cur != null and cur.performing and cur.interaction != null and cur.interaction.pose == "run"):
				anim = "walk"
			elif cur != null and cur.performing and cur.interaction != null and cur.interaction.pose == "dance":
				anim = "dance"
			elif talking:
				anim = "talk"
			elif busy:
				anim = "use"
	if _anim != null:
		if _anim.current_animation != anim:
			_anim.play(anim, 0.25)
		# Animations follow game speed (capped so ultra speed isn't frantic), and the
		# walk cycle matches the walking speed (about 1.4 m per stride).
		var rate := minf(Clock.SPEED_FACTORS[Clock.speed], 3.0)
		if anim == "walk":
			rate *= walk_speed / 1.4
		_anim.speed_scale = rate
	# The plumbob floats over the head, spinning and bobbing even while paused.
	_plumbob.rotation.y += get_process_delta_time() * 1.8
	var head := _body.to_global(Vector3(0, 1.7, 0))
	_plumbob.scale = Vector3.ONE * size_scale()
	_plumbob.global_position = head + Vector3(0, 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.04, 0)


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	# The character model (tools/make_sim.py) with its own copy of each material so
	# every Sim can have their own colours.
	var model := MODEL.instantiate() as Node3D
	_body.add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for a in _anim.get_animation_list():
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	_materials = {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		# Layer 3 as well, so the portrait camera can see Sims and nothing else.
		mi.layers = 1 | PORTRAIT_LAYER
		if mi.name == "Body":
			_body_mesh = mi
		if mi.name.begins_with("Hair_"):
			_hair_meshes[mi.name.trim_prefix("Hair_").to_lower()] = mi
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var key := src.resource_name.to_lower()
			if not _materials.has(key):
				_materials[key] = src.duplicate()
			mi.set_surface_override_material(i, _materials[key])
	set_part_color("shirt", shirt_color)
	set_part_color("pants", pants_color)
	set_part_color("skin", skin_color)
	set_part_color("hair", hair_color)
	set_hair_style(hair_style)
	set_body(body_heavy, body_fit)
	_apply_outfit()
	_default_outfits()

	_selection_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.42
	_selection_ring.mesh = ring
	_selection_ring.position.y = 0.02
	_selection_ring.scale.y = 0.15
	var ring_mat := _mat(Color(0.35, 0.95, 0.45))
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.8, 0.3)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.material_override = ring_mat
	_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_selection_ring)

	# Click target so the Sim can be picked for social interactions.
	var body := StaticBody3D.new()
	body.set_meta("sim", self)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	body.add_child(shape)
	add_child(body)

	# The green diamond over the controlled Sim.
	_plumbob = MeshInstance3D.new()
	_plumbob.name = "Plumbob"
	var gem_mat := _mat(Color(0.3, 0.95, 0.35))
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.15, 0.7, 0.2)
	gem_mat.roughness = 0.2
	for half in [1.0, -1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0 if half > 0.0 else 0.11
		cone.bottom_radius = 0.11 if half > 0.0 else 0.0
		cone.height = 0.2 if half > 0.0 else 0.13
		cone.radial_segments = 6
		cone.rings = 1
		var piece := MeshInstance3D.new()
		piece.mesh = cone
		piece.position.y = 0.1 * half if half > 0.0 else -0.065
		piece.material_override = gem_mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Layer 2 keeps the plumbob out of the portrait camera.
		piece.layers = 2
		_plumbob.add_child(piece)
	_plumbob.top_level = true
	_plumbob.visible = false
	add_child(_plumbob)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
