extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var yaw := float(args[1]) if args.size() > 1 else 180.0
	var root3d := Node3D.new()
	root.add_child(root3d)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.16, 0.23, 0.30)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.82, 0.95)
	world.environment.ambient_light_energy = 0.35
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root3d.add_child(world)
	for spec in [[Vector3(-30, -35, 0), 1.0], [Vector3(-15, 140, 0), 0.55]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		root3d.add_child(light)
	var model := load("res://assets/sim/sim.glb").instantiate() as Node3D
	root3d.add_child(model)
	model.rotation_degrees.y = yaw
	var style := args[3] if args.size() > 3 else "Short"
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if part.name.begins_with("Hair_"):
			part.visible = part.name == "Hair_" + style
		elif part.name.begins_with("Mouth_") or part.name.begins_with("Brows_"):
			part.visible = part.name.ends_with("Neutral")
		elif part.name == "Skirt":
			part.visible = false
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if args.size() > 6:
			for i in part.mesh.get_blend_shape_count(): part.set_blend_shape_value(i, float(args[6]))
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play(args[4] if args.size() > 4 else "idle")
	player.seek(float(args[5]) if args.size() > 5 else 0.0, true)
	player.pause()
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var close := args.size() > 2 and args[2] == "head"
	cam.fov = 35
	cam.look_at_from_position(Vector3(0, 1.70, 0.72) if close else Vector3(0, 1.0, 3.2), Vector3(0,1.695,0) if close else Vector3(0,0.95,0))
	cam.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	root3d.queue_free()
	await process_frame
	quit()

