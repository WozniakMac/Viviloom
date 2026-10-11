extends Node3D
## Game root: builds the world, the lot, the Sim and the camera, and routes clicks.
##
## Dev flag: `-- --screenshot=<path>` sends the Sim on a walk, saves a frame and quits.

var lot: Lot
var sim: Sim
var rig: CameraRig
var _marker: MeshInstance3D
var _marker_time := 0.0


func _ready() -> void:
	_setup_environment()

	lot = Lot.new()
	lot.name = "Lot"
	add_child(lot)
	_place_garden()

	sim = Sim.new()
	sim.name = "Sim"
	sim.lot = lot
	add_child(sim)
	sim.global_position = lot.cell_to_world(Vector2i(3, 14))
	sim.set_selected(true)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.position = lot.center()

	_build_marker()
	_build_hud()
	_check_dev_args()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: Variant = _ground_point(mb.position)
			if hit != null and lot.contains_point(hit):
				if sim.move_to(hit):
					_show_marker(sim.path[sim.path.size() - 1])


func _process(delta: float) -> void:
	if _marker.visible:
		_marker_time += delta
		_marker.scale = Vector3.ONE * (1.0 + 0.15 * sin(_marker_time * 6.0))
		if not sim.is_moving():
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


func _place_garden() -> void:
	# Placeholder hedges so routing around obstacles is visible until real objects exist.
	var hedge := Color(0.18, 0.38, 0.16)
	lot.add_block(Rect2i(8, 3, 1, 10), 1.0, hedge, "HedgeWest")
	lot.add_block(Rect2i(9, 12, 6, 1), 1.0, hedge, "HedgeSouth")
	lot.add_block(Rect2i(14, 5, 1, 7), 1.0, hedge, "HedgeEast")
	lot.add_block(Rect2i(18, 8, 3, 3), 0.5, Color(0.55, 0.5, 0.45), "Planter")


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


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Left-click: walk   WASD: pan   Q/E or middle-drag: rotate   Wheel: zoom"
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(16, 16)
	layer.add_child(label)


func _check_dev_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_take_screenshot(arg.trim_prefix("--screenshot="))


func _take_screenshot(path: String) -> void:
	await get_tree().create_timer(0.5).timeout
	sim.move_to(lot.cell_to_world(Vector2i(11, 7)))
	_show_marker(sim.path[sim.path.size() - 1])
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
