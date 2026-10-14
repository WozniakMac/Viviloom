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
## Blew out a birthday cake's candles: main ages the Sim up.
signal grow_up_requested
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
@export var pants_color := Color(0.3, 0.4, 0.62)
@export var skin_color := Color(0.87, 0.69, 0.55)
@export var hair_color := Color(0.25, 0.16, 0.1)
@export var eye_color := Color(0.25, 0.17, 0.1)
## "short", "long" or "bun".
@export var hair_style := "short"
## How this Sim walks (chosen in Create a Sim): see WALK_STYLES.
var walk_style := "default"
## id -> [label, speed multiplier, bounce height, hip sway, forward lean]
const WALK_STYLES := {
	"default": ["Default", 1.0, 0.0, 0.0, 0.0],
	"swagger": ["Swagger", 0.9, 0.015, 0.11, -0.06],
	"bouncy": ["Bouncy", 1.05, 0.06, 0.0, 0.03],
	"energetic": ["Energetic", 1.2, 0.03, 0.03, 0.09],
	"lazy": ["Lazy", 0.8, 0.0, 0.05, 0.12],
	"snooty": ["Snooty", 0.95, 0.0, 0.02, -0.1],
	"graceful": ["Graceful", 1.0, 0.015, 0.09, 0.0],
}
const WALK_STYLE_ORDER: Array[String] = ["default", "swagger", "bouncy", "energetic", "lazy", "snooty", "graceful"]
## Long trips are jogged, like the reference game.
const JOG_DISTANCE := 9.0
const JOG_MULT := 1.7
var _jogging := false
var _walk_phase := 0.0
## Seconds left of a walk-on-the-spot preview (Create a Sim).
var _preview_walk := 0.0
var creator_preview := false
## Body shape sliders (0..1) and outfit cut.
const BODY_FRAMES: Array[String] = ["masculine", "feminine"]
const BODY_FRAME_LABELS := {"masculine": "Male", "feminine": "Female"}
@export var body_frame := "masculine"
@export var body_heavy := 0.0
@export var body_fit := 0.0
var face_features := {"NoseWidth": 0.0, "JawWidth": 0.0, "EyeSpacing": 0.0, "LipFullness": 0.0}
var _character_age: CharacterAge
var frame_hair_styles := {}
var _head_mesh: MeshInstance3D
@export var long_sleeves := false
@export var shorts := false
@export var skirt := false

const MODEL := preload("res://assets/sim/sim.glb")
const PORTRAIT_LAYER := 4
## Emotion -> the suffix of its body-language idle and walk animations.
const MOOD_ANIMS := {"sad": "sad", "angry": "angry", "happy": "happy", "playful": "happy", "energized": "happy",
	"tense": "tense", "uncomfortable": "tense", "embarrassed": "tense", "flirty": "flirty", "confident": "happy"}
const HAIR_STYLES: Array[String] = ["short", "long", "bun", "ponytail", "buzz", "curly", "bob"]
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
## Boyfriend or girlfriend (going steady, before marriage).
var partner: Sim
## Things the Sim carries: paintings and the like (dictionaries with a "kind").
var inventory: Array = []
signal inventory_changed
## Raises the school grade (main tells Work).
signal homework_done
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
var _model: Node3D
var _anim: AnimationPlayer
## The right hand, for holding props (fishing rods, books, drinks).
var _hand: BoneAttachment3D
var _hand_pose: HandPose
var _prop_kind := ""
var _prop: Node3D
## Hair style name -> its mesh in the model.
var _hair_meshes := {}
var _body_mesh: MeshInstance3D
var _skirt_mesh: MeshInstance3D
var _clothing_meshes := {}
## Mouth and brow shapes by name ("Mouth_Smile", "Brows_Angry"...).
var _face_meshes := {}
var _expression := ""
var _face_time := 0.0
var _action_indices := {}
var _selection_ring: MeshInstance3D
var _plumbob: MeshInstance3D
## Materials by part ("shirt", "pants", "skin", "hair") so the look can change later.
var _materials := {}


func _ready() -> void:
	if likes.is_empty() and dislikes.is_empty():
		roll_likes(_rng)
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


## Face for the current emotion: which mouth and brows show.
const EXPRESSIONS := {
	"happy": ["Smile", "Neutral"], "playful": ["Smile", "Neutral"], "flirty": ["Smile", "Neutral"],
	"confident": ["Smile", "Neutral"], "energized": ["Smile", "Neutral"], "inspired": ["Smile", "Neutral"],
	"sad": ["Frown", "Sad"], "angry": ["Frown", "Angry"], "tense": ["Neutral", "Sad"],
	"uncomfortable": ["Frown", "Sad"], "embarrassed": ["Frown", "Sad"], "bored": ["Frown", "Neutral"],
}


func _update_expression() -> void:
	if _face_meshes.is_empty():
		return
	var e: Array = EXPRESSIONS.get(emotions.mood(), ["Neutral", "Neutral"])
	if dying or _passed_out > 0.0:
		e = ["Frown", "Sad"]
	var key := "%s/%s" % e
	if key == _expression:
		return
	_expression = key
	_set_face_action("Smile", 0.65 if e[0] == "Smile" else 0.0)
	_set_face_action("Frown", 0.7 if e[0] == "Frown" else 0.0)
	_set_face_action("BrowAngry", 0.8 if e[1] == "Angry" else 0.0)
	_set_face_action("BrowSad", 0.8 if e[1] == "Sad" else 0.0)
	for name in _face_meshes:
		var mi: MeshInstance3D = _face_meshes[name]
		mi.visible = name == "Mouth_" + e[0] or name == "Brows_" + e[1]


func _set_face_action(action: String, value: float) -> void:
	if _head_mesh == null:
		return
	if not _action_indices.has(action):
		_action_indices[action] = _head_mesh.find_blend_shape_by_name("Action" + action)
	var index: int = _action_indices[action]
	if index >= 0:
		_head_mesh.set_blend_shape_value(index, value)


func _animate_face(real_delta: float) -> void:
	_face_time += real_delta
	var phase := fmod(_face_time + float(absi(hash(sim_name)) % 37) * 0.1, 4.7)
	var blink := sin(PI * phase / 0.16) if phase < 0.16 else 0.0
	_set_face_action("Blink", blink)


## Recolours one part of the Sim: "shirt", "pants", "skin" or "hair".
func set_part_color(part: String, c: Color) -> void:
	match part:
		"shirt": shirt_color = c
		"pants": pants_color = c
		"skin": skin_color = c
		"hair": hair_color = c
		"eyes": eye_color = c
	var display_color := hair_display_color() if part == "hair" else c
	var key := "iris" if part == "eyes" else part
	if _materials.has(key):
		(_materials[key] as BaseMaterial3D).albedo_color = _skin_tint() if part == "skin" else display_color
	var fabric_key := part + "fabric"
	_set_fabric_color(fabric_key, c)
	if part == "shirt":_set_fabric_color("sleevefabric", c)
	if part == "eyes" and _materials.has("nativeeyes"):
		(_materials["nativeeyes"] as ShaderMaterial).set_shader_parameter("eye_color", c)
	if part == "hair":
		for material_key in _materials:
			if material_key.begins_with("nativehair_"):
				(_materials[material_key] as ShaderMaterial).set_shader_parameter("hair_color", display_color)
	_apply_outfit()
	_store_outfit()


func hair_display_color() -> Color:
	return hair_color.lerp(Color(.82,.82,.84),.75) if age_stage == "elder" else hair_color


## Palette colors describe the intended skin tone; the source texture already has color.
func _skin_tint() -> Color:
	return Color(skin_color.r / .87, skin_color.g / .69, skin_color.b / .55, skin_color.a)


func _set_fabric_color(key: String, color: Color) -> void:
	if _materials.get(key) is ShaderMaterial:
		(_materials[key] as ShaderMaterial).set_shader_parameter("fabric_color", color)


## Outfit categories, each with its own top, bottom and cut. The Sim wears one
## at a time and changes (with a spin) to suit what they're doing.
const OUTFITS: Array[String] = ["everyday", "sleep", "athletic", "swim"]
const OUTFIT_LABELS := {"everyday": "Everyday", "sleep": "Sleepwear", "athletic": "Athletic", "swim": "Swimwear"}
var outfits := {}
var outfit := "everyday"


## The outfit the Sim is wearing, saved into its category.
func _store_outfit() -> void:
	outfits[outfit] = {"shirt": shirt_color, "pants": pants_color, "long_sleeves": long_sleeves, "shorts": shorts, "skirt": skirt}


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


## Puts on the career's uniform (a "career" outfit, as in the reference).
func wear_uniform(career: String) -> void:
	if outfits.is_empty():
		_default_outfits()
	var u: Array = Careers.UNIFORMS.get(career, [])
	if u.is_empty():
		change_outfit("everyday", false)
		return
	outfits["career"] = {"shirt": u[0], "pants": u[1], "long_sleeves": u[2], "shorts": false, "skirt": false}
	outfit = ""
	change_outfit("career")


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
	skirt = o.get("skirt", false)
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
		(_materials["sleeve"] as BaseMaterial3D).albedo_color = shirt_color if long_sleeves else _skin_tint()
	if _materials.has("shin"):
		(_materials["shin"] as BaseMaterial3D).albedo_color = _skin_tint() if shorts or skirt else pants_color
	if _skirt_mesh != null:
		_skirt_mesh.visible = skirt
		if _materials.has("skirt"):
			(_materials["skirt"] as BaseMaterial3D).albedo_color = pants_color
	for part in _clothing_meshes:
		var mesh: MeshInstance3D = _clothing_meshes[part]
		mesh.visible = not ((part == "OutfitSleeve" and not long_sleeves) or (part == "OutfitShin" and (shorts or skirt)) or (part == "OutfitPants" and skirt))
	if not _clothing_meshes.is_empty():
		for part in ["shirt", "pants", "sleeve", "shin", "shoes"]:
			if not _materials.has(part):
				continue
			var material: BaseMaterial3D = _materials[part]
			var hidden: bool = part in ["shirt", "shoes"] or part == "pants" or (part == "sleeve" and long_sleeves) or (part == "shin" and not shorts and not skirt)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if hidden else BaseMaterial3D.TRANSPARENCY_DISABLED
			var tint := _skin_tint()
			tint.a = 0.0 if hidden else 1.0
			material.albedo_color = tint
		for part in ["shirt", "pants"]:
			_set_fabric_color(part + "fabric", shirt_color if part == "shirt" else pants_color)


## Trousers, shorts or a skirt.
func set_legs(style: String) -> void:
	shorts = style == "shorts"
	skirt = style == "skirt"
	_apply_outfit()
	_store_outfit()


func set_outfit(p_long_sleeves: bool, p_shorts: bool) -> void:
	long_sleeves = p_long_sleeves
	shorts = p_shorts
	_apply_outfit()
	_store_outfit()


## Persistent facial proportions. Negative values make the feature narrower/smaller.
func set_face_feature(feature: String, value: float) -> void:
	if not face_features.has(feature):
		return
	face_features[feature] = clampf(value, -1.0, 1.0)
	var meshes: Array = [_head_mesh]
	for key in _face_meshes:
		if key.begins_with("Brows_"):
			meshes.append(_face_meshes[key])
	for mesh in meshes:
		if mesh == null:
			continue
		var index: int = mesh.find_blend_shape_by_name(feature)
		if index >= 0:
			mesh.set_blend_shape_value(index, face_features[feature])


## Both frames use native Anny anatomy fitted to the same animation rig.
func set_body_frame(frame: String) -> void:
	if frame not in BODY_FRAMES or frame == body_frame:
		return
	frame_hair_styles[body_frame] = hair_style
	body_frame = frame
	hair_style = frame_hair_styles.get(frame, "bob" if frame == "feminine" and hair_style == "short" else hair_style)
	if _body != null:
		_build_model()


## Body sliders: 0..1 heavier and 0..1 more muscular.
func set_body(heavy: float, fit: float) -> void:
	body_heavy = clampf(heavy, 0.0, 1.0)
	body_fit = clampf(fit, 0.0, 1.0)
	if _body_mesh == null:
		return
	var meshes: Array = [_body_mesh, _head_mesh]
	meshes.append_array(_clothing_meshes.values())
	meshes.append_array(_hair_meshes.values())
	for mesh in meshes:
		for pair in [["Heavy", body_heavy], ["Fit", body_fit], ["HeavyFit", body_heavy * body_fit]]:
			var idx: int = mesh.find_blend_shape_by_name(pair[0])
			if idx >= 0:
				mesh.set_blend_shape_value(idx, pair[1])


func set_hair_style(style: String) -> void:
	hair_style = style
	for k in _hair_meshes:
		(_hair_meshes[k] as Node3D).visible = k == style


## Native life-stage anatomy plus physical height and walking speed.
func set_age(stage: String) -> void:
	if not Ages.INFO.has(stage):return
	age_stage = stage
	var info: Dictionary = Ages.INFO[stage]
	if _body != null:
		_body.scale = Vector3.ONE * float(info["scale"])
	if _character_age != null:
		_character_age.apply(stage)
		if _anim != null:_anim.advance(0.0)
	walk_speed = 2.0 * info["speed"]
	set_part_color("hair",hair_color)
	if _prop != null:_set_prop(_prop_kind)


func age_point(local: Vector3) -> Vector3:
	return _character_age.point(local,age_stage) if _character_age != null else local


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
		"colors": {"shirt": shirt_color.to_html(), "pants": pants_color.to_html(), "skin": skin_color.to_html(), "hair": hair_color.to_html(), "eyes": eye_color.to_html()},
		"hair_style": hair_style,
		"body_frame": body_frame, "frame_hair_styles": frame_hair_styles.duplicate(),
		"walk_style": walk_style,
		"body": [body_heavy, body_fit, long_sleeves, shorts, skirt],
		"face": face_features.duplicate(),
		"outfit": outfit,
		"outfits": _outfits_dict(),
		"age": [age_stage, age_days, pregnant_days],
		"perks": perks.duplicate(),
		"inventory": inventory.duplicate(true),
		"spouse": spouse.sim_name if spouse != null and is_instance_valid(spouse) else "",
		"partner": partner.sim_name if partner != null and is_instance_valid(partner) else "",
		"parents": parents,
		"traits": traits,
		"likes": likes,
		"dislikes": dislikes,
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
	set_body_frame(d.get("body_frame", "masculine"))
	frame_hair_styles = d.get("frame_hair_styles", {}).duplicate()
	for part in d.get("colors", {}):
		set_part_color(part, Color.html(d["colors"][part]))
	set_hair_style(d.get("hair_style", hair_style))
	walk_style = d.get("walk_style", "default")
	var bd: Array = d.get("body", [0.0, 0.0, false, false])
	set_body(bd[0], bd[1])
	var saved_face: Dictionary = d.get("face", {})
	for feature in face_features:
		set_face_feature(feature, float(saved_face.get(feature, 0.0)))
	set_outfit(bd[2], bd[3])
	if bd.size() > 4 and bd[4]:
		set_legs("skirt")
	outfits.clear()
	for k in d.get("outfits", {}):
		var o: Dictionary = d["outfits"][k]
		outfits[k] = {"shirt": Color.html(o["shirt"]), "pants": Color.html(o["pants"]), "long_sleeves": o["long_sleeves"], "shorts": o["shorts"], "skirt": o.get("skirt", false)}
	_default_outfits()
	var wearing: String = d.get("outfit", "everyday")
	outfit = ""
	change_outfit(wearing, false)
	perks = d.get("perks", []).duplicate()
	inventory = d.get("inventory", []).duplicate(true)
	var ag: Array = d.get("age", ["young_adult", 0, -1])
	age_days = int(ag[1])
	pregnant_days = int(ag[2])
	set_age(ag[0])
	var t: Array[String] = []
	for x in d.get("traits", []):
		t.append(x)
	set_traits(t)
	likes = d.get("likes", likes).duplicate()
	dislikes = d.get("dislikes", dislikes).duplicate()
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
	partner = null
	for o in others:
		if o != self and o.sim_name == d.get("spouse", "") and d.get("spouse", "") != "":
			spouse = o
		if o != self and o.sim_name == d.get("partner", "") and d.get("partner", "") != "":
			partner = o
		if o != self and d.get("relationships", {}).has(o.sim_name):
			var r: Array = d["relationships"][o.sim_name]
			relationships[o] = Vector2(r[0], r[1])
	parents = d.get("parents", []).duplicate()
	relationships_changed.emit()


func _outfits_dict() -> Dictionary:
	_store_outfit()
	var out := {}
	for k in outfits:
		var o: Dictionary = outfits[k]
		out[k] = {"shirt": (o["shirt"] as Color).to_html(), "pants": (o["pants"] as Color).to_html(), "long_sleeves": o["long_sleeves"], "shorts": o["shorts"], "skirt": o.get("skirt", false)}
	return out


var _last_cook_spot: Furniture


## Puts the cooked meal on (or beside) the counter: better cooks make better food.
func _serve_meal(i: Interaction, lvl: int) -> void:
	var q := 1
	var roll := _rng.randf() + lvl * 0.1 + (0.2 if emotions.mood() == "inspired" else 0.0)
	if roll < 0.35:
		q = 0
	elif roll > 1.5:
		q = 3
	elif roll > 0.9:
		q = 2
	var meal := Catalog.make_meal(i.recipe, q)
	# Served on the nearest worktop or table (cooking "at the fridge" still uses one).
	var src: Furniture = null
	var best := 6.0
	for f in lot.furniture:
		if f.kind in ["counter", "stove", "dining_table", "bar", "picnic_table"]:
			var d := f.global_position.distance_to(global_position)
			if d < best:
				best = d
				src = f
	if src == null:
		src = _last_cook_spot
	lot.place_furniture(meal, lot.nearest_walkable(lot.world_to_cell(src.global_position + src.global_basis * Vector3(0, 0, 1.0))) if src != null else lot.world_to_cell(global_position), 0)
	if src != null and src.height > 0.5:
		# On top of the counter it was cooked at.
		meal.global_position = src.global_position + Vector3(0, src.height, 0)
		meal.rotation.y = src.rotation.y
		meal.spots = [Vector3(0, -src.height, 1.0)]
	announced.emit("%s cooked %s (%s). Dinner is served!" % [sim_name, i.recipe, Catalog.MEAL_QUALITY[q].to_lower()])


## Sells an inventory item for its value.
func sell_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var item: Dictionary = inventory[index]
	inventory.remove_at(index)
	if item.get("kind") == "painting":
		count_stat("paintings_sold")
	earned.emit(item.get("value", 0))
	var what: String = item.get("name", "fish").to_lower() if item.get("kind") in ["fish", "produce"] else "painting"
	announced.emit("%s sold a %s for §%d." % [sim_name, what, item.get("value", 0)])
	inventory_changed.emit()


var _last_garden: Furniture

## Picks the ripe crop: better gardeners get more and better produce.
func _harvest(planter: Furniture, lvl: int) -> void:
	var g: Dictionary = planter.get_meta("item", {})
	var crop: String = g.get("crop", "")
	if crop == "":
		return
	var info: Array = Catalog.CROPS[crop]
	var count := 2 + lvl / 3 + _rng.randi_range(0, 1)
	var q := Catalog.produce_quality(lvl, int(g.get("care", 0)), int(g.get("fertilized", 0)))
	var value := roundi((int(info[2]) + lvl) * Catalog.PRODUCE_VALUE_MULT[q])
	for k in count:
		inventory.append({"kind": "produce", "name": info[4], "quality": q, "value": value})
	inventory_changed.emit()
	count_stat("harvests")
	planter.set_meta("item", {})
	planter.refresh_garden()
	announced.emit("%s harvested %d %s %s!" % [sim_name, count, Catalog.PRODUCE_QUALITY[q].to_lower(), info[0].to_lower()])


func _add_part(text: String) -> void:
	inventory.append({"kind": "upgrade_part", "name": "Upgrade Part", "value": 15})
	inventory_changed.emit()
	announced.emit(text)


## A fishing trip may land something: better anglers catch rarer, pricier fish.
func _catch_fish(lvl: int) -> void:
	if _rng.randf() > 0.55 + lvl * 0.04:
		announced.emit("%s didn't catch anything this time." % sim_name)
		return
	var best := mini(Catalog.FISH.size() - 1, 1 + lvl / 2)
	var pick: Array = Catalog.FISH[_rng.randi_range(0, best)]
	var value: int = pick[1] + _rng.randi_range(0, 4) + lvl * 2
	inventory.append({"kind": "fish", "name": pick[0], "value": value})
	inventory_changed.emit()
	count_stat("fish")
	announced.emit("%s caught a %s worth §%d!" % [sim_name, pick[0], value])


func count_stat(stat: String, amount := 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount


func friendship_with(o: Sim) -> float:
	return (relationships.get(o, Vector2.ZERO) as Vector2).x


func romance_with(o: Sim) -> float:
	return (relationships.get(o, Vector2.ZERO) as Vector2).y


func relationship_label(o: Sim) -> String:
	var fam := family_label(o)
	if fam != "":
		return fam
	if spouse == o:
		return "Husband" if o.body_frame == "masculine" else "Wife"
	if partner == o:
		return "Boyfriend" if o.body_frame == "masculine" else "Girlfriend"
	return Socials.friendship_label(friendship_with(o), romance_with(o))


## Names of this Sim's parents (set at birth), for family ties like the reference's.
var parents: Array = []:
	set(v):
		parents = v
		if sim_name != "":
			FAMILY[sim_name] = v.duplicate()
## Everyone's known parents (name -> [names]), so wider family can be traced.
static var FAMILY := {}


static func _parents_of(n: String) -> Array:
	return FAMILY.get(n, [])


## "Mother", "Son", "Sister"... what `o` is to this Sim, or "".
func family_label(o: Sim) -> String:
	var male := o.body_frame == "masculine"
	if parents.has(o.sim_name):
		return "Father" if male else "Mother"
	if o.parents.has(sim_name):
		return "Son" if male else "Daughter"
	for p in parents:
		if o.parents.has(p):
			return "Brother" if male else "Sister"
	var grand: Array = []
	for p in parents:
		grand.append_array(_parents_of(p))
	if grand.has(o.sim_name):
		return "Grandfather" if male else "Grandmother"
	var o_grand: Array = []
	for p in o.parents:
		o_grand.append_array(_parents_of(p))
	if o_grand.has(sim_name):
		return "Grandson" if male else "Granddaughter"
	# Aunts/uncles share a parent with one of my parents; cousins share a grandparent.
	for p in parents:
		for gp in _parents_of(p):
			if p != o.sim_name and _parents_of(o.sim_name).has(gp):
				return "Uncle" if male else "Aunt"
	for p in o.parents:
		for gp in _parents_of(p):
			if p != sim_name and parents.has(gp):
				return "Nephew" if male else "Niece"
	for g in grand:
		if o_grand.has(g):
			return "Cousin"
	return ""


## Changes the relationship on both sides.
func change_relationship(o: Sim, d_friend: float, d_romance: float) -> void:
	for pair in [[self, o], [o, self]]:
		var a: Sim = pair[0]
		var b: Sim = pair[1]
		var r: Vector2 = a.relationships.get(b, Vector2.ZERO)
		a.relationships[b] = Vector2(clampf(r.x + d_friend, -100.0, 100.0), clampf(r.y + d_romance, 0.0, 100.0))
		a.relationships_changed.emit()


## How committed this Sim is to `o`: "spouse", "partner" or "".
func status_with(o: Sim) -> String:
	if spouse == o:
		return "spouse"
	if partner == o:
		return "partner"
	return ""


## Whom this Sim would WooHoo with on the lot right now, or null.
func woohoo_partner() -> Sim:
	if lot == null or not Ages.is_adult(age_stage):
		return null
	var best: Sim = null
	for o in lot.sims:
		var other := o as Sim
		if other == self or not is_instance_valid(other) or not other.visible or other.away or not Ages.is_adult(other.age_stage):
			continue
		if spouse == other or partner == other or romance_with(other) >= 50.0:
			if best == null or romance_with(other) > romance_with(best):
				best = other
	return best


## The category ("Friendly", "Funny", "Romance", "Mischief", "Mean") of the social this Sim is in, or "".
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


func pose_name() -> String:
	return _pose


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
	if a.performing and a.interaction != null and a.interaction.pose == "swim" and a.furniture != null and not a.furniture.has_ladders():
		announced.emit("%s can't get out of the pool: there are no ladders!" % sim_name)
		return
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
	_animate_face(real_delta)
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
	_drop_vanished()
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


## Puts `kind` in the Sim's right hand ("" to empty it).
func _set_prop(kind: String) -> void:
	_prop_kind = kind
	if is_instance_valid(_hand_pose):
		_hand_pose.held_kind = kind
	if _prop != null:
		_prop.queue_free()
		_prop = null
	if kind == "" or _hand == null:
		return
	_prop = Node3D.new()
	_prop.name = "Prop"
	# Locate the grip from the native knuckle, rather than guessing from the wrist.
	_hand.add_child(_prop)
	var skeleton := _hand.get_parent() as Skeleton3D
	var wrist := skeleton.find_bone(_hand.bone_name)
	var middle := skeleton.find_bone("finger3-1.R")
	if wrist >= 0 and middle >= 0:
		var knuckle := skeleton.get_bone_global_rest(middle)
		var palm_depth := 0.009 if kind == "book" else 0.040 if kind == "drink" else 0.022
		var grip := knuckle.origin + knuckle.basis.y * 0.010 + knuckle.basis.z * palm_depth
		_prop.position = skeleton.get_bone_global_rest(wrist).affine_inverse() * grip
	var add := func(sz: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = sz
		m.mesh = b
		m.position = pos
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		m.material_override = mat
		m.layers = 1 | PORTRAIT_LAYER
		if creator_preview:
			m.set_meta("cas_original_layers", m.layers)
			m.layers = 8 | PORTRAIT_LAYER
		_prop.add_child(m)
		return m
	match kind:
		"rod":
			# Gripped in the fist, reaching forward and up over the water.
			var pole: MeshInstance3D = add.call(Vector3(0.025, 0.025, 1.6), Vector3(0, 0, -0.70), Color(0.35, 0.22, 0.12))
			add.call(Vector3(0.035, 0.040, 0.050), Vector3(0, 0, -0.140), Color(0.2, 0.2, 0.22))
			var line: MeshInstance3D = add.call(Vector3(0.008, 1.0, 0.008), Vector3.ZERO, Color(0.95, 0.95, 0.95))
			line.name = "Line"
		"book":
			add.call(Vector3(0.12, 0.18, 0.026), Vector3(0, 0.075, 0), Color(0.7, 0.2, 0.2))
			add.call(Vector3(0.108, 0.166, 0.028), Vector3(0.007, 0.075, 0), Color(0.96, 0.94, 0.88))
		"drink":
			var cup: MeshInstance3D = add.call(Vector3.ONE, Vector3(0, 0, 0), Color(0.85, 0.5, 0.65))
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.028
			cylinder.bottom_radius = 0.022
			cylinder.height = 0.105
			cylinder.radial_segments = 32
			cup.mesh = cylinder
			var liquid: MeshInstance3D = add.call(Vector3.ONE, Vector3(0, 0.050, 0), Color(0.18, 0.07, 0.025))
			var surface := CylinderMesh.new()
			surface.top_radius = 0.025
			surface.bottom_radius = 0.025
			surface.height = 0.002
			liquid.mesh = surface
			var rim: MeshInstance3D = add.call(Vector3.ONE, Vector3(0, 0.052, 0), Color(0.92, 0.72, 0.80))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.025
			ring.outer_radius = 0.029
			rim.mesh = ring
	_orient_prop()


## Carry the object with the wrist, including arm motion and lying poses.
func _orient_prop() -> void:
	if _prop == null or _hand == null:
		return
	var skeleton := _hand.get_parent() as Skeleton3D
	var wrist := skeleton.find_bone(_hand.bone_name)
	if wrist < 0:
		return
	var direction := (Vector3.FORWARD * 0.85 + Vector3.UP * 0.45).normalized() if _prop_kind == "rod" else Vector3.FORWARD
	var rest_basis := skeleton.get_bone_global_rest(wrist).basis
	_prop.basis = rest_basis.inverse() * Basis.looking_at(direction, Vector3.UP)


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


## Drops queued actions whose object is gone (the last serving was eaten, a mess
## was cleaned up, something was sold).
func _drop_vanished() -> void:
	for i in range(queue.size() - 1, -1, -1):
		var a := queue[i]
		var gone := a.furniture != null and not is_instance_valid(a.furniture)
		gone = gone or (a.target_sim != null and not is_instance_valid(a.target_sim))
		if gone:
			if a.performing:
				a.performing = false
				_set_pose("stand")
			queue.remove_at(i)
			queue_changed.emit()


## What happens when a need runs out completely: an accident, or passing out.
func _check_limits() -> void:
	if lot == null or is_visitor:
		return
	# Dangerous extreme feelings, as in the reference: a warning, then a growing
	# risk the longer they last (calm them down, or sleep it off).
	var em := emotions.mood()
	if emotions.intensity() >= 3 and Emotions.DEADLY.has(em):
		if _extreme_minutes == 0.0:
			announced.emit("%s is %s! Calm them down before it's too late." % [sim_name, Emotions.EXTREMES[em]])
		_extreme_minutes += Clock.game_delta
		if _extreme_minutes > 60.0 and _rng.randf() < Clock.game_delta * 0.002:
			died.emit(Emotions.DEADLY[em])
			return
	else:
		_extreme_minutes = 0.0
	# A swimmer with no ladder to climb out keeps swimming until exhausted, then drowns.
	var swim := current_action()
	if swim != null and swim.performing and swim.interaction != null and swim.interaction.pose == "swim" and swim.furniture != null and not swim.furniture.has_ladders():
		if swim.elapsed > swim.interaction.max_minutes * 0.9:
			swim.elapsed = 0.0
		needs.add("energy", -Clock.game_delta * 0.5)
		if needs.get_value("energy") <= 1.0:
			announced.emit("%s couldn't get out of the pool!" % sim_name)
			died.emit("drowning")
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
	# Toddlers who aren't potty trained have little accidents before it gets urgent.
	if age_stage == "toddler" and skills.level("potty") < 2 and needs.get_value("bladder") < 12.0:
		needs.set_value("bladder", 0.0)
		emotions.add("accident", "embarrassed", 1, "Little Accident", "Oops. Needs potty training!", 90.0)
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
	var free_will: int = Settings.get_value("free_will")
	if free_will == 0 or (_selected and Settings.get_value("disable_selected_autonomy")):
		return
	var wait := IDLE_BEFORE_AUTONOMY * (3.0 if free_will == 1 else 1.0)
	if not autonomy_enabled or _idle_minutes < wait:
		return
	_idle_minutes = 0.0
	# Up and about in sleepwear, swimwear or gym clothes: change back sometimes.
	var h := Clock.hour()
	if outfit != "everyday" and _pose == "stand" and h >= 7 and h < 21 and _rng.randf() < 0.35:
		change_outfit("everyday")
		return
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
	if not f.has_room_for(self):
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
	if a.outcome and s.get("partner", false):
		partner = t
		t.partner = self
		announced.emit("%s and %s are now going steady!" % [sim_name, t.sim_name])
	if a.outcome and s.get("break_up", false):
		if spouse == t:
			spouse = null
			t.spouse = null
		if partner == t:
			partner = null
			t.partner = null
		announced.emit("%s broke up with %s." % [sim_name, t.sim_name])
	if a.outcome and s.get("marry", false):
		partner = null
		t.partner = null
		spouse = t
		t.spouse = self
		emotions.add("married", "happy", 3, "Just Married!", "Happily ever after starts now.", 1440.0)
		t.emotions.add("married", "happy", 3, "Just Married!", "Happily ever after starts now.", 1440.0)
		announced.emit("%s and %s are now married!" % [sim_name, t.sim_name])
	if a.outcome and (s.get("move_in", false) or s.get("marry", false)):
		moving_in.emit(t)
	count_stat("socials")
	var stat: String = {"Tell a Joke": "jokes", "Flirt": "flirts", "Kiss": "kisses", "Make Out": "kisses", "Prank": "pranks"}.get(a.interaction.name, "")
	if stat != "" and a.outcome:
		count_stat(stat)
	activity_done.emit(a.interaction.name)
	if a.interaction.skill != "":
		learn(a.interaction.skill, skill_gain(a.interaction, a.interaction.max_minutes) * (1.0 if a.outcome else 0.5))
	# As in the reference: a Hysterical Sim (very playful) can laugh themselves to death at a joke.
	if a.outcome and s.get("category", "") == "Funny":
		for who in [self, t]:
			var w := who as Sim
			if w.emotions.mood() == "playful" and w.emotions.intensity() >= 3 and _rng.randf() < 0.08:
				w.announced.emit("%s is laughing uncontrollably..." % w.sim_name)
				w.died.emit("laughter")
				break
	if age_stage == "child":
		learn("child_social", 25.0 if a.outcome else 10.0)
	if a.outcome and s.has("target_skill"):
		var before := t.skills.level(s["target_skill"])
		t.learn(s["target_skill"], 70.0 * a.interaction.max_minutes / 30.0)
		if t.skills.level(s["target_skill"]) > before:
			announced.emit("%s's %s skill went up thanks to %s!" % [t.sim_name, Skills.label(s["target_skill"]), sim_name])
	if a.outcome:
		# Flirting in front of someone's partner or spouse makes them jealous.
		if s.get("category", "") == "Romance" and lot != null:
			for o in lot.sims:
				var other := o as Sim
				if other == self or other == t or not is_instance_valid(other):
					continue
				if (other.spouse == self or other.partner == self) and other.global_position.distance_to(global_position) < 8.0:
					var w := 2 if other.traits.has("jealous") else 1
					other.emotions.add("jealous", "angry", w, "Jealous", "%s was flirting with %s!" % [sim_name, t.sim_name], 240.0)
					other.change_relationship(self, -4.0 * w, -3.0 * w)
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
	if a.furniture != null:
		_last_cook_spot = a.furniture
		if a.furniture.kind == "planter":
			_last_garden = a.furniture
	if a.target_sim != null:
		_begin_social(a)
		return
	# Like the reference, outfits stick: only sleeping, swimming and working out
	# change clothes by themselves (and the dresser, on request).
	if a.interaction.outfit != "":
		change_outfit(a.interaction.outfit)
	elif not a.furniture.kind in ["bed", "single_bed"] or a.interaction.pose == "lie":
		var want := outfit_for(a.interaction)
		if want != "everyday":
			change_outfit(want)
	if a.interaction.effect.begins_with("upgrade:"):
		var u: Array = a.interaction.get_meta("upgrade")
		if skills.level("handiness") < int(u[2]):
			_fail(a, "%s needs Handiness level %d for %s." % [sim_name, u[2], u[1]])
			return
		if not inventory.any(func(it): return it.get("kind") == "upgrade_part"):
			_fail(a, "%s needs an upgrade part. Search a trash can, or repair broken things to find one." % sim_name)
			return
	if a.interaction.cost > 0 and wallet != null:
		if wallet.funds < a.interaction.cost:
			_fail(a, "%s can't afford that (§%d)." % [sim_name, a.interaction.cost])
			return
		wallet.earn(-a.interaction.cost)
		Sfx.play("cash", -8.0)
	# Inexperienced cooks sometimes set the kitchen on fire.
	if a.interaction.skill == "cooking" and (a.interaction.leaves_mess != "" or a.interaction.recipe != "") and lot != null \
			and skills.level("cooking") < Catalog.FIRE_SKILL and not a.furniture.has_upgrade_effect("fireproof") and _rng.randf() < Catalog.FIRE_CHANCE:
		var fire := lot.add_mess("fire", a.furniture.global_position + (a.furniture.global_basis * Vector3(0, 0, 1.2)))
		fire.set_meta("source", a.furniture)
		a.furniture.set_broken(true)
		Sfx.play("alarm", -2.0)
		announced.emit("FIRE! %s set the %s on fire!" % [sim_name, a.furniture.display_name])
		_complete(a)
		return
	a.performing = true
	var f := a.furniture
	var place: Variant = f.claim(self)
	var facing: Vector3
	if a.interaction.pose == "swim":
		_swim_center = f.to_global(f.use_position)
		_swim_half = Vector2(f.footprint) * 0.5
		_swim_phase = randf() * TAU
	if place != null:
		global_position = f.to_global(place)
		facing = f.global_basis * f.use_facing
	# Sharing a bed with someone special is lovely.
	if f.kind in ["bed", "single_bed"] and a.interaction.pose == "lie":
		for other in f.users:
			if other != self and is_instance_valid(other) and (spouse == other or romance_with(other) >= 30.0):
				emotions.add("cozy", "happy", 1, "Cozy Together", "Nothing beats falling asleep next to them.", 480.0)
				other.emotions.add("cozy", "happy", 1, "Cozy Together", "Nothing beats falling asleep next to them.", 480.0)
	else:
		facing = f.global_position - global_position
	facing.y = 0.0
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)
	_set_pose(a.interaction.pose)
	if a.interaction.with_partner and f.users.size() >= 2:
		f.set_romp(true)
		Sfx.play("select", -6.0)


## Experience gained for `minutes` of an activity, sped up by traits and by feeling
## the emotion that suits the skill.
func skill_gain(interaction: Interaction, minutes: float) -> float:
	if interaction.skill == "":
		return 0.0
	var gain := interaction.skill_rate * minutes / 60.0 * Traits.skill_mult(traits, interaction.skill)
	if perks.has("fast_learner"):
		gain *= 1.25
	if perks.has("top_notch_toddler") and age_stage == "child":
		gain *= 1.2
	if lot != null:
		gain *= LotTraits.skill_mult(lot.lot_traits, interaction.skill)
	if emotions.mood() == Skills.boosting_emotion(interaction.skill):
		gain *= Skills.EMOTION_BONUS
	return gain


func _practise(interaction: Interaction, minutes: float) -> void:
	if interaction.skill != "":
		learn(interaction.skill, skill_gain(interaction, minutes))


## Adds experience, translated for the Sim's life stage (a child at the chess table
## builds Mental, not Logic).
func learn(skill: String, amount: float) -> void:
	var s := Skills.for_stage(skill, age_stage)
	if s != "":
		skills.add_xp(s, amount)


## Likes & Dislikes, as in the reference: activities (by skill) this Sim enjoys
## or can't stand. Rolled once, saved, shown in Simology.
var likes: Array = []
var dislikes: Array = []
const LIKEABLE := ["cooking", "logic", "painting", "gaming", "fitness", "charisma", "guitar", "gardening", "writing", "handiness", "comedy", "mixology", "programming", "piano", "fishing"]


func roll_likes(rng: RandomNumberGenerator) -> void:
	var pool := LIKEABLE.duplicate()
	pool.shuffle()
	var n := rng.randi_range(2, 3)
	likes = pool.slice(0, n)
	dislikes = pool.slice(n, n + 1)


func like_mult(skill: String) -> float:
	if likes.has(skill):
		return 1.5
	if dislikes.has(skill):
		return 0.4
	return 1.0


var _extreme_minutes := 0.0
const ELECTRONICS := ["tv", "desk", "stereo", "stove", "fridge", "treadmill", "microwave", "coffee_maker"]


## Moodlet and pay for an activity done long enough. Skill makes both better.
## Pay only comes when the activity is finished, not cancelled.
func _reward(i: Interaction, minutes_done: float, finished: bool) -> void:
	if minutes_done < i.reward_after():
		return
	activity_done.emit(i.name)
	if likes.has(i.skill):
		emotions.add("like_" + i.skill, "happy", 1, "Doing Something I Like", "%s is one of my favourite things!" % Skills.label(i.skill), 180.0)
	elif dislikes.has(i.skill):
		emotions.add("dislike_" + i.skill, "tense", 1, "Doing Something I Dislike", "Ugh, %s again." % Skills.label(i.skill).to_lower(), 180.0)
	var lvl := skills.level(i.skill) if i.skill != "" else 0
	if not i.moodlet.is_empty():
		var m := i.moodlet
		emotions.add(m[0], m[1], m[2] + lvl / 4, m[3], m[4], m[5])
	if finished and i.needs_item != "":
		# Uses up the item the activity needed (homework, produce for fertilizer...).
		for k in inventory.size():
			if inventory[k].get("kind") == i.needs_item:
				inventory.remove_at(k)
				break
		inventory_changed.emit()
		if i.needs_item == "homework":
			homework_done.emit()
	if finished and i.recipe != "" and lot != null:
		_serve_meal(i, lvl)
	if finished and i.creates == "cake" and lot != null:
		var cake := Catalog.create("cake")
		lot.place_furniture(cake, lot.nearest_walkable(lot.world_to_cell(global_position + global_basis * Vector3(0, 0, -1.0))), 0)
		announced.emit("%s baked a birthday cake! Click it to blow out the candles." % sim_name)
	if finished and i.creates == "fish":
		_catch_fish(lvl)
	if finished and i.creates == "produce" and _last_garden != null and is_instance_valid(_last_garden):
		_harvest(_last_garden, lvl)
	if finished and i.creates == "painting":
		var bonus := 0
		for t in traits:
			bonus += int(Traits.INFO[t].get("quality_bonus", 0))
		var q := clampi(lvl / 3 + bonus, 0, 3)
		var value := 20 + lvl * 22 + q * 15 + _rng.randi_range(0, 20)
		inventory.append({"kind": "painting", "seed": _rng.randi(), "quality": q, "value": value})
		inventory_changed.emit()
		announced.emit("%s finished a %s painting worth §%d. It's in their inventory." % [sim_name, Catalog.PAINTING_QUALITY[q].to_lower(), value])
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
	a.furniture.release(self)
	if finished and a.interaction.effect != "clean" and Catalog.DIRTIES.has(a.furniture.kind):
		if a.furniture.is_dirty():
			emotions.add("grossed_out", "uncomfortable", 2 if traits.has("squeamish") else 1, "Grossed Out", "That %s is filthy!" % a.furniture.display_name.to_lower(), 180.0)
		a.furniture.add_dirt()
	if finished and a.interaction.effect == "clean":
		emotions.add("sparkling", "happy" if traits.has("neat") else "fine", 1 if traits.has("neat") else 0, "Sparkling Clean", "Now that's how it should look.", 120.0)
	if finished and a.interaction.leaves_mess != "" and lot != null:
		lot.add_mess(a.interaction.leaves_mess, a.spot if a.spot != Vector3.ZERO else global_position)
	elif finished and traits.has("slob") and lot != null and a.furniture.blocks and _rng.randf() < 0.25:
		# Slobs leave a little mess wherever they go.
		lot.add_mess("dishes", a.spot if a.spot != Vector3.ZERO else global_position)
	if finished and a.interaction.effect.begins_with("upgrade:"):
		for k in inventory.size():
			if inventory[k].get("kind") == "upgrade_part":
				inventory.remove_at(k)
				break
		inventory_changed.emit()
		announced.emit("%s installed %s on the %s." % [sim_name, (a.interaction.get_meta("upgrade") as Array)[1], a.furniture.display_name])
	if finished and a.interaction.creates == "upgrade_part":
		if _rng.randf() < 0.45 + skills.level("handiness") * 0.05:
			_add_part("%s dug an upgrade part out of the trash!" % sim_name)
		else:
			announced.emit("%s rummaged through the trash but found nothing useful." % sim_name)
	if finished and a.interaction.effect == "age_up":
		if Ages.next(age_stage) == "":
			announced.emit("%s blew out the candles. Happy birthday!" % sim_name)
		else:
			grow_up_requested.emit()
	if finished and a.interaction.effect == "assign":
		# This side of the bed is now theirs.
		var item: Dictionary = a.furniture.get_meta("item", {}).duplicate()
		item["owner"] = sim_name
		a.furniture.set_meta("item", item)
		announced.emit("The %s is now %s's." % [a.furniture.display_name, sim_name])
	elif finished and a.interaction.effect != "":
		a.furniture.apply_effect(a.interaction.effect)
	if finished and a.interaction.clears_emotion != "":
		emotions.clear_emotion(a.interaction.clears_emotion)
	# As in the reference: fixing electronics with little Handiness can give a shock,
	# and a second shock while still shocked is fatal.
	if finished and a.interaction.fixes and a.furniture.kind in ELECTRONICS and _rng.randf() < maxf(0.0, 0.25 - skills.level("handiness") * 0.05):
		if emotions.has("shocked"):
			announced.emit("%s was electrocuted!" % sim_name)
			died.emit("electrocution")
			return
		emotions.add("shocked", "uncomfortable", 2, "Shocked", "Zapped! Hair standing on end.", 240.0)
		needs.add("energy", -15.0)
		Sfx.play("fail", -4.0)
		announced.emit("%s got an electric shock fixing the %s! Be careful..." % [sim_name, a.furniture.display_name])
		return
	if finished and a.interaction.fixes:
		a.furniture.set_broken(false)
		announced.emit("%s repaired the %s." % [sim_name, a.furniture.display_name])
		if _rng.randf() < Catalog.PART_FROM_REPAIR:
			_add_part("%s found a spare upgrade part while fixing the %s." % [sim_name, a.furniture.display_name])
	elif finished and lot != null and Catalog.BREAKABLE.has(a.furniture.kind) and not a.furniture.is_upgraded() and _rng.randf() < Catalog.BREAK_CHANCE * LotTraits.break_mult(lot.lot_traits):
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
	if _path_index == 0 or Engine.get_process_frames() % 15 == 0:
		_jogging = _remaining_path() > JOG_DISTANCE
	var step := move_speed() * delta
	if to.length() <= step:
		global_position = target
		_path_index += 1
		if _path_index >= path.size():
			stop()
			# Clumsy Sims sometimes trip on arrival.
			if traits.has("clumsy") and _rng.randf() < 0.08:
				emotions.add("tripped", "embarrassed", 1, "Tripped!", "Whoops! Graceful as ever.", 90.0)
				announced.emit("%s tripped over their own feet!" % sim_name)
			return false
		return true
	var dir := to.normalized()
	global_position += dir * step
	_face(dir, delta)
	return true


## Walking speed with the walk style and jogging taken into account.
func move_speed() -> float:
	return walk_speed * WALK_STYLES.get(walk_style, WALK_STYLES["default"])[1] * (JOG_MULT if _jogging else 1.0)


func _remaining_path() -> float:
	var total := 0.0
	var prev := global_position
	for k in range(_path_index, path.size()):
		total += prev.distance_to(path[k])
		prev = path[k]
	return total


## Bounce, sway and lean on top of the walk cycle; jogging leans forward more.
func _apply_walk_style(walking: bool, delta: float) -> void:
	if _pose != "stand":
		return
	var st: Array = WALK_STYLES.get(walk_style, WALK_STYLES["default"])
	if not walking:
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, 0.2)
		return
	var real := get_process_delta_time()
	var rate := 1.0 if _preview_walk > 0.0 else minf(Clock.SPEED_FACTORS[Clock.speed], 3.0)
	_walk_phase += real * rate * move_speed() * 2.2
	_body.position.y = absf(sin(_walk_phase * PI)) * st[2]
	_body.rotation.z = sin(_walk_phase * PI) * st[3] * 0.5
	_body.rotation.x = -(st[4] + (0.12 if _jogging else 0.0))


## Shows off the walk style on the spot for a couple of seconds.
func preview_walk() -> void:
	_preview_walk = 2.5


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
	if _preview_walk > 0.0 and _pose == "stand":
		_preview_walk -= get_process_delta_time()
		anim = "walk"
	_apply_walk_style(anim == "walk", delta)
	# Step up onto (and down off) foundations smoothly.
	if lot != null and _pose == "stand" and (cur == null or cur.stairs == null):
		var fy := lot.floor_y_at(global_position)
		if absf(global_position.y - fy) > 0.001:
			global_position.y = move_toward(global_position.y, fy, maxf(get_process_delta_time(), 0.0) * 3.0 * maxf(Clock.SPEED_FACTORS[Clock.speed], 1.0))
	_update_expression()
	var want_prop := ""
	if cur != null and cur.performing and cur.interaction != null:
		want_prop = cur.interaction.prop
	if want_prop != _prop_kind:
		_set_prop(want_prop)
	if _prop != null:
		var line := _prop.get_node_or_null("Line") as MeshInstance3D
		if line != null:
			# The line hangs straight down from the rod tip into the water.
			var tip := _prop.to_global(Vector3(0, 0, -1.50))
			var drop := maxf(tip.y - 0.12 - global_position.y, 0.05)
			line.global_basis = Basis.IDENTITY
			line.scale = Vector3(1, drop, 1)
			line.global_position = tip - Vector3(0, drop * 0.5, 0)
	if _anim != null:
		# Standing around and walking show the Sim's mood (strong feelings only).
		if not creator_preview and (anim == "idle" or anim == "walk") and emotions.intensity() >= 1:
			var mood_anim := "%s_%s" % [anim, MOOD_ANIMS.get(emotions.mood(), "")]
			if _anim.has_animation(mood_anim):
				anim = mood_anim
		if _anim.current_animation != anim:
			_anim.play(anim, 0.3)
		# Animations follow game speed (capped so ultra speed isn't frantic), and the
		# walk cycle matches the walking speed (about 1.4 m per stride).
		var rate := minf(Clock.SPEED_FACTORS[Clock.speed], 3.0)
		if creator_preview or _preview_walk > 0.0:
			rate = 1.0
		if anim.begins_with("walk"):
			rate *= move_speed() / 1.4
		_anim.speed_scale = rate
	# The plumbob floats over the head, spinning and bobbing even while paused.
	_plumbob.rotation.y += get_process_delta_time() * 1.8
	var head := _body.to_global(Vector3(0, 1.7, 0))
	_plumbob.scale = Vector3.ONE * size_scale()
	_plumbob.global_position = head + Vector3(0, 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.04, 0)


## Reloads only the character meshes; gameplay, selection and collision nodes survive.
func _build_model() -> void:
	var held := _prop_kind
	if is_instance_valid(_model):
		_model.free()
	_hand = null
	_hand_pose = null
	_prop = null
	_prop_kind = ""
	_head_mesh = null
	_body_mesh = null
	_skirt_mesh = null
	_hair_meshes.clear()
	_face_meshes.clear()
	_clothing_meshes.clear()
	_action_indices.clear()
	_expression = ""
	# The character model (tools/make_sim.py) with its own copy of each material so
	# every Sim can have their own colours.
	var model := MODEL.instantiate() as Node3D
	_model = model
	_body.add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		_hand_pose = HandPose.new()
		_hand_pose.name = "HandPose"
		_hand_pose.influence = 0.0
		skel.add_child(_hand_pose)
		for bone_name in ["hand.R", "hand_R"]:
			if skel.find_bone(bone_name) >= 0:
				_hand = BoneAttachment3D.new()
				_hand.bone_name = bone_name
				skel.add_child(_hand)
				break
	if _anim != null:
		for a in _anim.get_animation_list():
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	_materials = {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var prefix := body_frame.capitalize() + "_"
		if mi.name.begins_with("Masculine_") or mi.name.begins_with("Feminine_"):
			if not mi.name.begins_with(prefix):
				mi.free()
				continue
			mi.name = mi.name.trim_prefix(prefix)
		# Layer 3 as well, so the portrait camera can see Sims and nothing else.
		mi.layers = 1 | PORTRAIT_LAYER
		if creator_preview:
			mi.set_meta("cas_original_layers", mi.layers)
			mi.layers = 8 | PORTRAIT_LAYER
		if mi.name.begins_with("Outfit"):
			_clothing_meshes[mi.name] = mi
		if mi.name == "Head":
			_head_mesh = mi
		if mi.name == "Body":
			_body_mesh = mi
		if mi.name == "Skirt":
			_skirt_mesh = mi
		if mi.name.begins_with("Mouth_") or mi.name.begins_with("Brows_"):
			_face_meshes[mi.name] = mi
		if mi.name.begins_with("Hair_"):
			_hair_meshes[mi.name.trim_prefix("Hair_").to_lower()] = mi
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var key := "skirt" if mi.name == "Skirt" else src.resource_name.to_lower().get_slice(".", 0)
			if not _materials.has(key):
				if key in ["shirtfabric", "pantsfabric", "sleevefabric"] and src is BaseMaterial3D:
					var fabric := ShaderMaterial.new()
					fabric.shader = preload("res://shaders/fabric.gdshader")
					fabric.set_shader_parameter("fabric_texture", src.albedo_texture)
					fabric.set_shader_parameter("fabric_normal", src.normal_texture)
					fabric.set_shader_parameter("has_normal", src.normal_texture != null)
					_materials[key] = fabric
				elif key == "nativeeyes" and src is BaseMaterial3D:
					var eye_material := ShaderMaterial.new()
					eye_material.shader = preload("res://shaders/eyes.gdshader")
					eye_material.set_shader_parameter("eye_texture", src.albedo_texture)
					_materials[key] = eye_material
				elif key.begins_with("nativehair_") and src is BaseMaterial3D:
					var hair_material := ShaderMaterial.new()
					hair_material.shader = preload("res://shaders/facial_hair.gdshader") if key in ["nativehair_brows", "nativehair_lashes"] else preload("res://shaders/hair.gdshader")
					hair_material.set_shader_parameter("hair_texture", src.albedo_texture)
					if key not in ["nativehair_brows", "nativehair_lashes"]:
						hair_material.set_shader_parameter("hair_normal", src.normal_texture)
						hair_material.set_shader_parameter("has_normal", src.normal_texture != null)
						if key == "nativehair_long":
							hair_material.set_shader_parameter("hair_detail_texture", preload("res://assets/sim/hair-detail-ai-v1.png"))
							hair_material.set_shader_parameter("has_detail", true)
					_materials[key] = hair_material
				else:
					_materials[key] = src.duplicate()
					if key in ["skin", "sleeve", "shin"] and src is BaseMaterial3D:
						var skin: BaseMaterial3D = _materials[key]
						skin.subsurf_scatter_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
						skin.subsurf_scatter_skin_mode = true
						skin.subsurf_scatter_strength = 0.15
						skin.roughness = 0.55
						skin.metallic_specular = 0.35
			mi.set_surface_override_material(i, _materials[key])
	_character_age = CharacterAge.new(model,body_frame)
	set_age(age_stage)
	set_part_color("shirt", shirt_color)
	set_part_color("pants", pants_color)
	set_part_color("skin", skin_color)
	set_part_color("hair", hair_color)
	set_part_color("eyes", eye_color)
	set_hair_style(hair_style)
	set_body(body_heavy, body_fit)
	for feature in face_features:
		set_face_feature(feature, face_features[feature])
	_apply_outfit()
	_default_outfits()

	_update_expression()
	_set_prop(held)


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	_build_model()

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
