extends Node3D
## Game root: builds the world, the lot, the Sim and the camera, and routes clicks.
##
## Dev flags (after `--`): `--screenshot=<path>` saves a frame after a short scripted
## scenario and quits; `--scenario=<menu|sleep|walk>` picks the scenario.

var lot: Lot
var sim: Sim
var rig: CameraRig
var hud: Hud
var build: BuildMode
var _marker: MeshInstance3D
var _marker_time := 0.0


func _ready() -> void:
	_setup_environment()

	lot = Lot.new()
	lot.name = "Lot"
	add_child(lot)
	_place_house()

	sim = Sim.new()
	sim.name = "Sim"
	sim.lot = lot
	add_child(sim)
	sim.global_position = lot.cell_to_world(Vector2i(10, 14))
	sim.set_selected(true)
	var start_needs := {"hunger": 70.0, "energy": 85.0, "bladder": 55.0, "hygiene": 80.0, "fun": 45.0, "social": 60.0}
	for n in start_needs:
		sim.needs.set_value(n, start_needs[n])
	var start_traits: Array[String] = ["cheerful", "creative", "bookworm"]
	sim.set_traits(start_traits)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.position = lot.center()

	_build_marker()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_sim(sim)

	build = BuildMode.new()
	build.name = "BuildMode"
	build.lot = lot
	build.sim = sim
	build.camera = rig.camera
	add_child(build)
	hud.set_build(build, lot)
	sim.earned.connect(build.earn)
	_check_dev_args()


func _unhandled_input(event: InputEvent) -> void:
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
			var f := _furniture_at(mb.position)
			if f != null:
				open_menu(f, mb.position)
				return
			var hit: Variant = _ground_point(mb.position)
			if hit != null and lot.contains_point(hit):
				if lot.is_walkable(lot.world_to_cell(hit)) and sim.queue_go(hit):
					_show_marker(hit)


## Opens the interaction pie menu for `f` at a screen position.
func open_menu(f: Furniture, screen_pos: Vector2) -> void:
	var names: Array[String] = []
	for i in f.interactions:
		names.append(i.name)
	for c in hud.pie_menu.chosen.get_connections():
		hud.pie_menu.chosen.disconnect(c.callable)
	hud.pie_menu.chosen.connect(func(idx: int): sim.queue_interaction(f, f.interactions[idx]), CONNECT_ONE_SHOT)
	hud.pie_menu.open(screen_pos, f.display_name, names)


func _furniture_at(screen_pos: Vector2) -> Furniture:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen_pos) * 500.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider as Object).has_meta("furniture"):
		return null
	return (hit.collider as Object).get_meta("furniture") as Furniture


func _process(delta: float) -> void:
	lot.update_walls(rig.camera.global_position, rig.global_position, delta)
	var people: Array[Vector3] = [sim.global_position]
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


func _place_house() -> void:
	# A small starter house: floor, walls with two doors, and basic furniture.
	lot.add_floor(Rect2i(3, 2, 15, 10), Color(0.62, 0.48, 0.34))
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
	var hedge := Color(0.18, 0.38, 0.16)
	lot.add_block(Rect2i(1, 16, 6, 1), 0.9, hedge, "HedgeFrontWest")
	lot.add_block(Rect2i(15, 16, 7, 1), 0.9, hedge, "HedgeFrontEast")


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
