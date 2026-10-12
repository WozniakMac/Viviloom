extends Node
## Native anatomical hands rendered through the real Sim materials and skeleton.
func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    var output := args[0] if not args.is_empty() else "user://hands.png"
    var camera_side := float(args[1]) if args.size()>1 else 1.0
    var heavy := float(args[2]) if args.size()>2 else 0.0
    var fit := float(args[3]) if args.size()>3 else 0.0
    var body_frame := args[4] if args.size()>4 else "masculine"
    var grid := GridContainer.new()
    grid.columns = 3
    grid.position = Vector2(20,20)
    grid.add_theme_constant_override("h_separation",16)
    grid.add_theme_constant_override("v_separation",16)
    add_child(grid)
    var names := ["Open", "Relaxed", "Female relaxed", "Book", "Drink", "Rod"]
    for index in names.size():
        var card := VBoxContainer.new()
        card.custom_minimum_size = Vector2(510,416)
        grid.add_child(card)
        var label := Label.new()
        label.text = names[index]
        label.add_theme_font_size_override("font_size",26)
        card.add_child(label)
        var container := SubViewportContainer.new()
        container.custom_minimum_size = Vector2(510,372)
        container.stretch = true
        card.add_child(container)
        var viewport := SubViewport.new()
        viewport.size = Vector2i(510,372)
        viewport.own_world_3d = true
        viewport.msaa_3d = Viewport.MSAA_4X
        container.add_child(viewport)
        var env := WorldEnvironment.new()
        env.environment = Environment.new()
        env.environment.background_mode = Environment.BG_COLOR
        env.environment.background_color = Color(.78,.86,.90)
        env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.environment.ambient_light_energy = .55
        env.environment.ambient_light_color = Color(.8,.85,.9)
        viewport.add_child(env)
        var light := OmniLight3D.new()
        light.position = Vector3(0,2,3*camera_side)
        light.omni_range = 10
        light.light_energy = .75
        viewport.add_child(light)
        var sim := Sim.new()
        sim.creator_preview = true
        sim.autonomy_enabled = false
        sim.body_frame="feminine" if index==2 else body_frame
        sim.body_heavy=heavy
        sim.body_fit=fit
        viewport.add_child(sim)
        sim.set_part_color("skin",Color(.87,.69,.55))
        sim.set_process(false)
        sim.set_physics_process(false)
        sim.rotation.y = PI
        sim._selection_ring.visible = false
        sim._anim.play("idle")
        sim._anim.seek(.4,true)
        sim._anim.pause()
        if index==0:
            sim._hand_pose.active=false
            var skeleton: Skeleton3D = sim._hand.get_parent()
            for bone in skeleton.get_bone_count():
                if skeleton.get_bone_name(bone).begins_with("finger"):
                    skeleton.set_bone_pose_rotation(bone,Quaternion.IDENTITY)
        if index>=3:
            sim._set_prop(names[index].to_lower())
            sim._hand_pose.influence=1.0
            sim._orient_prop()
        var camera := Camera3D.new()
        viewport.add_child(camera)
        var center := sim._hand.global_position+Vector3(0,-.090,0)
        camera.look_at_from_position(center+Vector3(.060,.015,.40*camera_side),center)
        camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        camera.size = .25
        camera.current = true
    for frame in 12:await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(output)
    print("NATIVE HAND PREVIEW ",output)
    get_tree().quit()
