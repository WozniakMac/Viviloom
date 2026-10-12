extends SceneTree
## Renders the character once per animation, side by side, to check the rig.
##   Godot.exe --path . --script res://tools/preview_sim.gd -- <out.png> [time] [yaw]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://preview.png"
	var t := float(args[1]) if args.size() > 1 else 0.4
	var yaw := float(args[2]) if args.size() > 2 else 0.0
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.85, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root3d.add_child(sun)
	var scene: PackedScene = load("res://assets/sim/sim.glb")
	var names := ["idle", "walk", "sit", "sit_use", "lie", "talk", "use"]
	if args.size() > 4 and args[4] == "faces":
		names = ["idle", "idle", "idle", "idle", "idle", "idle", "idle"]
	if args.size() > 4 and args[4] == "moods":
		names = ["idle_sad", "idle_angry", "idle_happy", "idle_tense", "idle_flirty", "walk_sad", "walk_angry"]
	for i in names.size():
		var inst := scene.instantiate() as Node3D
		root3d.add_child(inst)
		inst.position = Vector3((i - 3) * 0.9, 0, 0)
		inst.rotation.y = deg_to_rad(yaw)
		for hair in ["Hair_Long", "Hair_Bun"]:
			var h := inst.find_child(hair, true, false) as Node3D
			if h != null:
				h.visible = i % 3 == ["Hair_Short", "Hair_Long", "Hair_Bun"].find(hair)
		var hs := inst.find_child("Hair_Short", true, false) as Node3D
		if hs != null:
			hs.visible = i % 3 == 0
		if args.size() > 4 and args[4] == "faces":
			var faces := [["Smile", "Neutral"], ["Smile", "Neutral"], ["Frown", "Sad"], ["Frown", "Angry"], ["Neutral", "Sad"], ["Smile", "Neutral"], ["Neutral", "Neutral"]]
			for m in inst.find_children("*", "MeshInstance3D", true, false):
				if m.name.begins_with("Mouth_"):
					m.visible = m.name == "Mouth_" + faces[i][0]
				if m.name.begins_with("Brows_"):
					m.visible = m.name == "Brows_" + faces[i][1]
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null and ap.has_animation(names[i]):
			ap.play(names[i])
			ap.seek(t, true)
			ap.pause()
		var label := Label3D.new()
		label.text = names[i]
		label.position = Vector3((i - 3) * 0.9, 2.05, 0)
		label.font_size = 48
		label.modulate = Color.BLACK
		root3d.add_child(label)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	if args.size() > 3 and args[3] == "head":
		# Close-up of the middle character's head.
		cam.look_at_from_position(Vector3(0.0, 1.72, 0.9), Vector3(0, 1.68, 0))
	else:
		cam.look_at_from_position(Vector3(0, 1.2, 5.2), Vector3(0, 0.95, 0))
	cam.current = true
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("anims: ", (scene.instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_list())
	quit()
