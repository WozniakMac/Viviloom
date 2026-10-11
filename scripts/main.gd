extends Node3D
## Game root: builds the world, the lot, the Sim and the camera, and routes clicks.
##
## Dev flags (after `--`): `--screenshot=<path>` saves a frame after a short scripted
## scenario and quits; `--scenario=<menu|sleep|walk>` picks the scenario.

## Where the Create a Sim studio is built, well away from the lot.
const CAS_STUDIO := Vector3(400, 0, 400)

var lot: Lot
var sim: Sim
var rig: CameraRig
var hud: Hud
var build: BuildMode
var _marker: MeshInstance3D
var _marker_time := 0.0
var _cas: CreateASim
var _studio: Node3D
var _home_position := Vector3.ZERO
var visitors: Visitors
var work: Work
var daylight: Daylight
var aspirations: AspirationTracker
## Everyone in the player's household; `sim`, `work` and `aspirations` are the
## active member's.
var household: Array[Sim] = []
var works := {}
var trackers := {}
const MAX_HOUSEHOLD := 4
## Which neighbourhood home is on the lot (its floor plan).
var home_id := "cottage"
var _menu: CanvasLayer
var _menu_orbit := false


func _ready() -> void:
	_setup_environment()

	lot = Lot.new()
	lot.name = "Lot"
	add_child(lot)
	_place_house()

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.position = lot.center()

	_build_marker()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	build = BuildMode.new()
	build.name = "BuildMode"
	build.lot = lot
	build.camera = rig.camera
	add_child(build)
	hud.set_build(build, lot)
	hud.sim_selected.connect(select_sim)

	var first := _new_sim("Alex")
	var start_needs := {"hunger": 70.0, "energy": 85.0, "bladder": 55.0, "hygiene": 80.0, "fun": 45.0, "social": 60.0}
	for n in start_needs:
		first.needs.set_value(n, start_needs[n])
	var start_traits: Array[String] = ["cheerful", "creative", "bookworm"]
	first.set_traits(start_traits)
	add_to_household(first)
	select_sim(first)

	visitors = Visitors.new()
	visitors.name = "Visitors"
	add_child(visitors)
	visitors.setup(lot)
	visitors.arrived.connect(func(v: Sim): hud.show_notice("%s from next door has dropped by to say hello. Click them to socialize." % v.sim_name, "Visitor"))
	visitors.left.connect(func(v: Sim): hud.show_notice("%s has gone home for the evening." % v.sim_name, "Visitor"))
	hud.set_others(lot)

	hud.menu_requested.connect(func():
		if _menu == null and _cas == null:
			open_game_menu())
	_check_dev_args()


# --- household ------------------------------------------------------------------

func _new_sim(sim_name: String) -> Sim:
	var s := Sim.new()
	s.name = "Sim_%d" % (household.size() + 1)
	s.sim_name = sim_name
	s.lot = lot
	add_child(s)
	s.set_selected(false)
	s.global_position = lot.cell_to_world(Vector2i(10 + household.size(), 14))
	return s


## Adds a Sim to the household with their own job and aspiration tracker.
func add_to_household(s: Sim) -> void:
	household.append(s)
	if not lot.sims.has(s):
		lot.sims.append(s)
	s.earned.connect(build.earn)
	hud.watch_sim(s)
	var w := Work.new()
	w.name = "Work_" + s.name
	w.sim = s
	w.lot = lot
	add_child(w)
	w.paid.connect(build.earn)
	hud.watch_work(w)
	works[s] = w
	var t := AspirationTracker.new()
	t.name = "Aspirations_" + s.name
	add_child(t)
	t.setup(s, build, w)
	hud.watch_aspirations(t)
	trackers[s] = t
	build.household = household
	hud.set_household(household)


func remove_from_household(s: Sim) -> void:
	if household.size() <= 1 or not household.has(s):
		return
	household.erase(s)
	lot.sims.erase(s)
	(works[s] as Node).queue_free()
	(trackers[s] as Node).queue_free()
	works.erase(s)
	trackers.erase(s)
	for o in household:
		o.relationships.erase(s)
	s.queue_free()
	if sim == s:
		select_sim(household[0])
	hud.set_household(household)


## Takes control of `s`: the HUD, panels and camera follow them.
func select_sim(s: Sim) -> void:
	if sim != null and is_instance_valid(sim):
		sim.set_selected(false)
	sim = s
	work = works[s]
	aspirations = trackers[s]
	build.sim = s
	s.set_selected(_cas == null)
	hud.set_sim(s)
	hud.set_work(work)
	hud.set_aspirations(aspirations)
	# Pan to them unless the camera is held by a menu or Create a Sim.
	if _cas == null and s.visible and rig.is_processing():
		var tw := create_tween()
		tw.tween_property(rig, "position", Vector3(s.global_position.x, 0.0, s.global_position.z), 0.4).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if _cas != null or _menu != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE and not build.active:
		open_game_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F1:
				build.exit()
				return
			KEY_F2, KEY_F3, KEY_B:
				build.enter()
				return
			KEY_V:
				lot.wall_view = ((lot.wall_view + 1) % 3) as Lot.WallView
				hud.refresh_walls_button(lot)
				return
	if build.active:
		build.handle_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_P, KEY_0, KEY_KP_0:
				Clock.set_speed(1 if Clock.is_paused() else 0)
			KEY_1, KEY_KP_1:
				Clock.set_speed(1)
			KEY_2, KEY_KP_2:
				Clock.set_speed(2)
			KEY_3, KEY_KP_3:
				Clock.set_speed(3)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if sim.away:
				return
			var picked: Object = _pick_at(mb.position)
			if picked is Furniture:
				open_menu(picked, mb.position)
				return
			if picked is Sim and picked != sim:
				open_sim_menu(picked, mb.position)
				return
			var hit: Variant = _ground_point(mb.position)
			if hit != null and lot.contains_point(hit):
				if lot.is_walkable(lot.world_to_cell(hit)) and sim.queue_go(hit):
					_show_marker(hit)


## Opens the interaction pie menu for `f` at a screen position.
func open_menu(f: Furniture, screen_pos: Vector2) -> void:
	if f.interactions.is_empty():
		return
	var names: Array[String] = []
	for i in f.interactions:
		names.append(i.name)
	_on_pie_choice(func(idx: int): sim.queue_interaction(f, f.interactions[idx]))
	hud.pie_menu.open(screen_pos, f.display_name, names)


## Social pie menu for another Sim: first a ring of categories, then the socials in
## the chosen one.
func open_sim_menu(other: Sim, screen_pos: Vector2) -> void:
	var options := Socials.available(sim.friendship_with(other), sim.romance_with(other))
	var cats: Array[String] = []
	for i in options:
		var c: String = i.social["category"]
		if not cats.has(c):
			cats.append(c)
	var title := "%s · %s" % [other.sim_name, sim.relationship_label(other)]
	var labels: Array[String] = []
	for c in cats:
		labels.append(c + "...")
	_on_pie_choice(func(ci: int):
		var in_cat: Array[Interaction] = []
		var names: Array[String] = []
		for i in options:
			if i.social["category"] == cats[ci]:
				in_cat.append(i)
				names.append(i.name)
		_on_pie_choice(func(ii: int): sim.queue_social(other, in_cat[ii]))
		hud.pie_menu.open(screen_pos, cats[ci], names))
	hud.pie_menu.open(screen_pos, title, labels)


func _on_pie_choice(callback: Callable) -> void:
	for c in hud.pie_menu.chosen.get_connections():
		hud.pie_menu.chosen.disconnect(c.callable)
	hud.pie_menu.chosen.connect(callback, CONNECT_ONE_SHOT)


## The furniture or Sim under the cursor, if any.
func _pick_at(screen_pos: Vector2) -> Object:
	var cam := rig.camera
	# Other Sims win over the objects they're sitting at: test their on-screen
	# silhouette (feet to head, about a shoulder-width wide) first.
	for other in lot.sims:
		if other == sim or not other.visible or cam.is_position_behind(other.global_position):
			continue
		var feet := cam.unproject_position(other.global_position)
		var head := cam.unproject_position(other.global_position + Vector3(0, 1.8, 0))
		var half := (cam.unproject_position(other.global_position + cam.global_basis.x * 0.35) - feet).length()
		var top := minf(feet.y, head.y)
		var bottom := maxf(feet.y, head.y)
		var t := clampf(inverse_lerp(bottom, top, screen_pos.y), 0.0, 1.0)
		var axis_x := lerpf(feet.x, head.x, t)
		if screen_pos.y >= top and screen_pos.y <= bottom and absf(screen_pos.x - axis_x) <= half:
			return other
	var origin := cam.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen_pos) * 500.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var col := hit.collider as Object
	if col.has_meta("furniture"):
		return col.get_meta("furniture")
	if col.has_meta("sim"):
		return col.get_meta("sim")
	return null


func _furniture_at(screen_pos: Vector2) -> Furniture:
	var picked: Object = _pick_at(screen_pos)
	return picked as Furniture if picked is Furniture else null


func _process(delta: float) -> void:
	if _menu_orbit:
		rig.frame(lot.center(), rig.yaw + delta * 0.08, deg_to_rad(-32.0), 30.0)
	lot.update_walls(rig.camera.global_position, rig.global_position, delta)
	var people: Array[Vector3] = []
	for s in lot.sims:
		people.append(s.global_position)
	lot.update_doors(people, delta)
	if _marker.visible:
		_marker_time += delta
		_marker.scale = Vector3.ONE * (1.0 + 0.15 * sin(_marker_time * 6.0))
		var walking := false
		for a in sim.queue:
			walking = walking or a.interaction == null
		if not walking:
			_marker.visible = false


func _ground_point(screen_pos: Vector2) -> Variant:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)


func _show_marker(at: Vector3) -> void:
	_marker.position = Vector3(at.x, 0.03, at.z)
	_marker_time = 0.0
	_marker.visible = true


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "MoveMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.26
	_marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


## Builds one of the neighbourhood's homes on the lot (see Neighbourhood.LOTS).
func _place_house(layout := "cottage") -> void:
	home_id = layout
	_place_grounds(layout)
	match layout:
		"studio":
			_place_studio()
			return
		"empty":
			return
	# A small starter house: walls with two doors, and basic furniture.
	_place_walls()
	_place("bed", Vector2i(4, 3))
	_place("desk", Vector2i(8, 3))
	_place("tv", Vector2i(12, 3))
	_place("fridge", Vector2i(16, 3))
	_place("bookshelf", Vector2i(17, 6), 3)
	_place("easel", Vector2i(15, 9))
	_place("chess", Vector2i(11, 8))
	_place("toilet", Vector2i(4, 10), 2)
	_place("shower", Vector2i(6, 10), 2)
	_place("lamp", Vector2i(7, 3))
	_place("lamp", Vector2i(14, 7))
	_place("lamp", Vector2i(5, 9))


## Hedges and the floor finish of a home; walls and objects come separately so a
## saved game can put back its own.
func _place_grounds(layout: String) -> void:
	var hedge := Color(0.18, 0.38, 0.16)
	lot.add_block(Rect2i(1, 16, 6, 1), 0.9, hedge, "HedgeFrontWest")
	lot.add_block(Rect2i(15, 16, 7, 1), 0.9, hedge, "HedgeFrontEast")
	match layout:
		"cottage":
			lot.add_floor(Rect2i(3, 2, 15, 10), Color(0.62, 0.48, 0.34))
		"studio":
			lot.add_floor(Rect2i(6, 4, 10, 7), Color(0.7, 0.6, 0.48))


## A compact one-room home with a bathroom corner.
func _place_studio() -> void:
	var runs := [
		[Vector2i(6, 4), Vector2i(16, 4)],
		[Vector2i(6, 11), Vector2i(16, 11)],
		[Vector2i(6, 4), Vector2i(6, 11)],
		[Vector2i(16, 4), Vector2i(16, 11)],
		[Vector2i(6, 8), Vector2i(9, 8)],
		[Vector2i(9, 8), Vector2i(9, 11)],
	]
	for r in runs:
		for e in Lot.wall_run(r[0], r[1]):
			lot.add_wall(e)
	lot.add_door(Vector3i(12, 11, 0))
	lot.add_door(Vector3i(7, 8, 0))
	_place("bed", Vector2i(7, 5))
	_place("tv", Vector2i(11, 5))
	_place("fridge", Vector2i(15, 5))
	_place("desk", Vector2i(13, 8))
	_place("toilet", Vector2i(6, 10), 2)
	_place("shower", Vector2i(8, 10), 2)
	_place("lamp", Vector2i(10, 5))
	_place("lamp", Vector2i(15, 9))


func _place_walls() -> void:
	# Outer walls around the floor, plus a bathroom in the south-west corner.
	var runs := [
		[Vector2i(3, 2), Vector2i(18, 2)],
		[Vector2i(3, 12), Vector2i(18, 12)],
		[Vector2i(3, 2), Vector2i(3, 12)],
		[Vector2i(18, 2), Vector2i(18, 12)],
		[Vector2i(3, 8), Vector2i(8, 8)],
		[Vector2i(8, 8), Vector2i(8, 12)],
	]
	for r in runs:
		for e in Lot.wall_run(r[0], r[1]):
			lot.add_wall(e)
	lot.add_door(Vector3i(10, 12, 0))
	lot.add_door(Vector3i(7, 8, 0))


func _place(kind: String, at: Vector2i, rot := 0) -> Furniture:
	var f := Catalog.create(kind)
	lot.place_furniture(f, at, rot)
	return f


func find_furniture(kind: String) -> Furniture:
	for f in lot.furniture:
		if f.kind == kind:
			return f
	return null


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.56, 0.86)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	daylight = Daylight.new()
	daylight.name = "Daylight"
	daylight.env = env
	daylight.sky_mat = sky_mat
	daylight.sun = sun
	add_child(daylight)


func _check_dev_args() -> void:
	var shot := ""
	var scenario := "menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	if shot != "":
		_run_scenario(scenario, shot)
	elif scenario == "trace":
		_trace()
	elif scenario == "saveload":
		_save_load_check()
	elif scenario == "new":
		open_create_a_sim()
	elif scenario != "skip_cas":
		open_main_menu()


# --- title screen, game menu, saving ---------------------------------------------

## Title screen over a slowly orbiting camera.
func open_main_menu() -> void:
	Clock.set_speed(0)
	hud.visible = false
	sim.set_selected(false)
	rig.set_locked(true)
	_menu_orbit = true
	var menu := MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	menu.setup(SaveGame.exists())
	_menu = menu
	menu.play_pressed.connect(func():
		_close_main_menu(menu)
		load_game())
	menu.new_game_pressed.connect(func():
		_close_main_menu(menu)
		open_create_a_sim())


func _close_main_menu(menu: MainMenu) -> void:
	_menu_orbit = false
	_menu = null
	menu.queue_free()


func open_game_menu() -> void:
	var m := GameMenu.new()
	m.name = "GameMenu"
	add_child(m)
	_menu = m
	m.closed.connect(func(): _menu = null)
	m.save_pressed.connect(save_game)
	m.load_pressed.connect(load_game)
	m.main_menu_pressed.connect(func(): get_tree().reload_current_scene())
	m.setup(SaveGame.exists())


func save_game() -> void:
	var walls: Array = []
	for e in lot.walls:
		walls.append([e.x, e.y, e.z, lot.doors.has(e)])
	var objects: Array = []
	for f in lot.furniture:
		objects.append([f.kind, f.cell.x, f.cell.y, f.rot_steps])
	var data := {
		"version": 1,
		"minutes": Clock.total_minutes,
		"funds": build.funds,
		"home": home_id,
		"walls": walls,
		"objects": objects,
		"household": household.map(func(m: Sim): return {
			"sim": m.to_dict(),
			"work": (works[m] as Work).to_dict(),
			"aspiration": (trackers[m] as AspirationTracker).to_dict(),
		}),
		"active": household.find(sim),
		"neighbour": visitors.neighbour.to_dict(),
	}
	if SaveGame.write(data):
		hud.show_notice("Game saved.", "OpenSims")
	else:
		hud.show_notice("Couldn't save the game.", "OpenSims")


func load_game() -> void:
	var d := SaveGame.read()
	if d.is_empty():
		hud.show_notice("No saved game found.", "OpenSims")
		_enter_live()
		return
	Clock.total_minutes = d.get("minutes", Clock.total_minutes)
	build.funds = int(d.get("funds", build.funds))
	build.funds_changed.emit(build.funds)
	sim.clear_queue()
	lot.clear_build()
	home_id = d.get("home", "cottage")
	_place_grounds(home_id)
	for w in d.get("walls", []):
		var e := Vector3i(int(w[0]), int(w[1]), int(w[2]))
		lot.add_wall(e)
		if w[3]:
			lot.add_door(e)
	for o in d.get("objects", []):
		if Catalog.INFO.has(o[0]):
			_place(o[0], Vector2i(int(o[1]), int(o[2])), int(o[3]))
	var members: Array = d.get("household", [])
	if members.is_empty() and d.has("sim"):
		members = [{"sim": d["sim"], "work": d.get("work", {}), "aspiration": d.get("aspiration", {})}]
	# Match the household size to the save, then fill everyone in.
	while household.size() < members.size():
		add_to_household(_new_sim(""))
	while household.size() > maxi(members.size(), 1):
		remove_from_household(household[household.size() - 1])
	var everyone: Array = household.duplicate()
	everyone.append(visitors.neighbour)
	for i in members.size():
		var m: Dictionary = members[i]
		household[i].from_dict(m.get("sim", {}), everyone)
		(works[household[i]] as Work).from_dict(m.get("work", {}))
		(trackers[household[i]] as AspirationTracker).from_dict(m.get("aspiration", {}))
	visitors.neighbour.from_dict(d.get("neighbour", {}), everyone)
	select_sim(household[clampi(int(d.get("active", 0)), 0, household.size() - 1)])
	_enter_live(false)
	hud.show_notice("Welcome back! Your game was loaded.", "OpenSims")


## Shows Create a Sim over a paused game: the Sim stands in a studio away from
## the lot, centred between the panels.
func open_create_a_sim() -> void:
	Clock.set_speed(0)
	hud.visible = false
	sim.set_selected(false)
	_studio = CreateASim.make_studio(CAS_STUDIO)
	add_child(_studio)
	rig.set_locked(true)
	rig.frame(CAS_STUDIO + Vector3(0, 0.95, 0), 0.0, deg_to_rad(-6.0), 4.6)
	_cas = CreateASim.new()
	_cas.name = "CreateASim"
	add_child(_cas)
	_cas.setup(sim)
	_cas.set_household(household, MAX_HOUSEHOLD)
	_cas.finished.connect(_on_cas_finished)
	_cas.member_selected.connect(_cas_show)
	_cas.add_requested.connect(func():
		var s := _new_sim("")
		add_to_household(s)
		_cas.randomize_sim_for(s)
		_cas_show(s))
	_cas.remove_requested.connect(func(s: Sim):
		remove_from_household(s)
		_cas.set_household(household, MAX_HOUSEHOLD)
		_cas_show(household[0]))
	_cas_show(sim)


## Puts `s` on the studio floor (the others step out of view) and edits them.
func _cas_show(s: Sim) -> void:
	for m in household:
		m.visible = m == s
		m.away = m != s
		m.clear_queue()
	s.global_position = CAS_STUDIO
	# Turned slightly towards the camera, which looks along -Z.
	s.rotation.y = PI - 0.25
	select_sim(s)
	s.set_selected(false)
	_cas.edit(s)
	_cas.set_household(household, MAX_HOUSEHOLD)


func _on_cas_finished() -> void:
	_cas = null
	_studio.queue_free()
	for i in household.size():
		var m := household[i]
		m.visible = true
		m.away = false
		m.global_position = lot.cell_to_world(Vector2i(9 + i, 14))
	# Housemates already know each other.
	for a_sim in household:
		for b_sim in household:
			if a_sim != b_sim and not a_sim.relationships.has(b_sim):
				a_sim.change_relationship(b_sim, 35.0, 0.0)
	select_sim(household[0])
	open_neighbourhood()


## The world map: pick a home, pay for it, and move in.
func open_neighbourhood() -> void:
	var map := Neighbourhood.new()
	map.name = "Neighbourhood"
	add_child(map)
	map.setup(build.funds)
	map.chosen.connect(_on_home_chosen)


func _on_home_chosen(lot_id: String, price: int) -> void:
	lot.clear_build()
	_place_house(lot_id)
	build.funds -= price
	build.funds_changed.emit(build.funds)
	hud.show_notice("Welcome home to %s! %s was spent on the move." % [Neighbourhood.LOTS[lot_id]["name"], Hud.money(price)], "Moved In")
	for i in household.size():
		household[i].global_position = lot.cell_to_world(Vector2i(9 + i, 14))
	_enter_live()


func _enter_live(fresh := true) -> void:
	hud.visible = true
	hud.refresh_identity()
	if fresh:
		for m in household:
			(trackers[m] as AspirationTracker).reset()
	sim.set_selected(true)
	rig.set_locked(false)
	rig.frame(lot.center(), deg_to_rad(35.0), deg_to_rad(-50.0), 22.0)
	Clock.set_speed(1)


## Saves, changes things, loads, and prints whether everything came back.
func _save_load_check() -> void:
	await get_tree().process_frame
	_enter_live()
	work.join("painter")
	sim.sim_name = "Saved Sim"
	sim.skills.add_xp("painting", 500.0)
	build.funds = 12345
	_place("lamp", Vector2i(12, 6))
	var objects_before := lot.furniture.size()
	Clock.total_minutes = 1000.0
	save_game()
	sim.sim_name = "Changed"
	build.funds = 1
	work.quit()
	lot.clear_build()
	Clock.total_minutes = 5.0
	load_game()
	await get_tree().process_frame
	var ok := sim.sim_name == "Saved Sim" and build.funds == 12345 and work.career == "painter" 		and lot.furniture.size() == objects_before and absf(Clock.total_minutes - 1000.0) < 5.0 and not lot.walls.is_empty()
	print("SAVELOAD %s name=%s funds=%d career=%s objects=%d/%d" % ["OK" if ok else "FAIL", sim.sim_name, build.funds, work.career, lot.furniture.size(), objects_before])
	get_tree().quit()


## Headless smoke run: queue a few actions and log what the Sim does.
func _trace() -> void:
	Clock.set_speed(3)
	sim.needs.set_value("bladder", 20.0)
	sim.needs.set_value("fun", 25.0)
	for i in 40:
		await get_tree().create_timer(0.5).timeout
		var cur := sim.current_action()
		print("t=%.1f %s action=%s auto=%s performing=%s needs=%s" % [i * 0.5, Clock.time_string(), cur.label if cur else "-", cur.autonomous if cur else false, cur.performing if cur else false, sim.needs.values])
	get_tree().quit()


func _run_scenario(scenario: String, path: String) -> void:
	await get_tree().create_timer(0.5).timeout
	match scenario:
		"menu":
			var desk := find_furniture("desk")
			sim.queue_interaction(find_furniture("fridge"), find_furniture("fridge").interactions[0])
			sim.queue_interaction(desk, desk.interactions[1])
			sim.queue_go(lot.cell_to_world(Vector2i(10, 14)))
			await get_tree().create_timer(2.5).timeout
			open_menu(find_furniture("bed"), rig.camera.unproject_position(find_furniture("bed").global_position + Vector3.UP))
		"household":
			var bea := _new_sim("Bea")
			bea.set_part_color("shirt", Color(0.85, 0.3, 0.45))
			bea.set_hair_style("long")
			var bt: Array[String] = ["genius", "lazy"]
			bea.set_traits(bt)
			add_to_household(bea)
			select_sim(bea)
			bea.change_relationship(household[0], 55.0, 20.0)
			hud._show_page(3)
			await get_tree().create_timer(2.0).timeout
		"cas2":
			open_create_a_sim()
			_cas.add_requested.emit()
			await get_tree().create_timer(1.0).timeout
		"title":
			open_main_menu()
			await get_tree().create_timer(1.5).timeout
		"gamemenu":
			open_game_menu()
			await get_tree().create_timer(0.8).timeout
		"night", "dusk":
			Clock.total_minutes = (22.0 if scenario == "night" else 19.4) * 60.0
			Clock.set_speed(0)
			await get_tree().create_timer(1.0).timeout
		"sleep":
			Clock.set_speed(3)
			sim.needs.set_value("energy", 30.0)
			sim.queue_interaction(find_furniture("bed"), find_furniture("bed").interactions[0])
			sim.queue_interaction(find_furniture("toilet"), find_furniture("toilet").interactions[0])
			await get_tree().create_timer(2.5).timeout
		"mood":
			var easel := find_furniture("easel")
			var books := find_furniture("bookshelf")
			sim.skills.add_xp("painting", 420.0)
			sim.skills.add_xp("cooking", 120.0)
			sim.needs.set_value("hunger", 25.0)
			sim.emotions.add("lit_inspired", "inspired", 1, "Inspired by Literature", "Browsing books sparked some new ideas.", 120.0)
			sim.emotions.add("trait_creative", "inspired", 1, "Creative Spark", "An idea is forming!", 240.0)
			sim.queue_interaction(easel, easel.interactions[0])
			sim.queue_interaction(books, books.interactions[1])
			hud._show_page(1)
			await get_tree().create_timer(6.0).timeout
		"map":
			hud.visible = false
			open_neighbourhood()
			var map := get_node("Neighbourhood") as Neighbourhood
			map.select("cottage")
			map._view.selected = "cottage"
			map._view.queue_redraw()
			await get_tree().create_timer(1.0).timeout
		"studio":
			open_neighbourhood()
			(get_node("Neighbourhood") as Neighbourhood).choose("studio")
			await get_tree().create_timer(2.0).timeout
		"aspiration":
			sim.skills.add_xp("painting", Skills.xp_for_level(2))
			sim.skills.add_xp("cooking", Skills.xp_for_level(2))
			hud._show_page(5)
			await get_tree().create_timer(1.5).timeout
		"career":
			Clock.total_minutes = 8.0 * 60.0 + 50.0
			work.join("tech")
			hud._show_page(4)
			Clock.set_speed(3)
			await get_tree().create_timer(3.0).timeout
		"social":
			Clock.total_minutes = 9.0 * 60.0 + 1.0
			await get_tree().create_timer(0.3).timeout
			var jules := visitors.neighbour
			jules.global_position = lot.cell_to_world(Vector2i(10, 9))
			jules.clear_queue()
			sim.global_position = lot.cell_to_world(Vector2i(13, 9))
			sim.queue_social(jules, Socials.find("Tell a Joke"))
			hud._show_page(3)
			await get_tree().create_timer(2.5).timeout
		"cas":
			open_create_a_sim()
			_cas.randomize_sim()
			await get_tree().create_timer(1.0).timeout
		"build":
			build.enter()
			build.set_tool(BuildMode.Tool.WALL)
			for e in Lot.wall_run(Vector2i(12, 8), Vector2i(18, 8)):
				lot.add_wall(e)
			build.start_place("tv")
			build._refresh_overlays(Vector3(15.0, 0.0, 10.0))
			await get_tree().create_timer(1.0).timeout
		_:
			sim.queue_go(lot.cell_to_world(Vector2i(20, 8)))
			await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
