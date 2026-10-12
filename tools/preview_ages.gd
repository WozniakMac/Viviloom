extends Node
func _ready() -> void:
    var grid := GridContainer.new()
    grid.columns=6
    grid.position=Vector2(16,16)
    grid.add_theme_constant_override("h_separation",12)
    grid.add_theme_constant_override("v_separation",12)
    add_child(grid)
    for index in 12:
        var card := VBoxContainer.new()
        grid.add_child(card)
        var label := Label.new()
        label.text=("Male" if index<6 else "Female")+" — "+Ages.label(Ages.ORDER[index%6])
        label.add_theme_font_size_override("font_size",22)
        card.add_child(label)
        var container := SubViewportContainer.new()
        container.custom_minimum_size=Vector2(360,600)
        card.add_child(container)
        var viewport := SubViewport.new()
        viewport.size=Vector2i(360,600)
        viewport.own_world_3d=true
        viewport.msaa_3d=Viewport.MSAA_4X
        container.add_child(viewport)
        var world := WorldEnvironment.new()
        world.environment=Environment.new()
        world.environment.background_mode=Environment.BG_COLOR
        world.environment.background_color=Color(.40,.65,.72)
        world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
        world.environment.ambient_light_color=Color(.78,.84,.95)
        world.environment.ambient_light_energy=.25
        world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
        viewport.add_child(world)
        for light_index in 3:
            var light := OmniLight3D.new()
            light.position=[Vector3(1.2,2.4,3.2),Vector3(-2,1.7,2),Vector3(.5,2.1,-1.5)][light_index]
            light.omni_range=9
            light.light_cull_mask=8
            light.shadow_caster_mask=8
            light.light_energy=[.85,.28,.28][light_index]
            light.light_color=[Color(1,.97,.92),Color(.84,.9,1),Color.WHITE][light_index]
            light.shadow_enabled=light_index==0
            viewport.add_child(light)
        var sim := Sim.new()
        sim.body_frame="masculine" if index<6 else "feminine"
        sim.creator_preview=true
        sim.autonomy_enabled=false
        viewport.add_child(sim)
        sim.set_process(false)
        sim.set_physics_process(false)
        sim.set_hair_style("short" if index<6 else "bob")
        sim.set_age(Ages.ORDER[index%6])
        sim.set_part_color("hair",Color(.25,.16,.1))
        sim.set_part_color("shirt",Color(.62,.3,.47))
        sim.rotation.y=PI
        sim._selection_ring.visible=false
        sim._anim.play("idle")
        sim._anim.seek(.4,true)
        sim._anim.pause()
        var camera := Camera3D.new()
        viewport.add_child(camera)
        var face_mode: bool="faces" in OS.get_cmdline_user_args()
        if face_mode:
            var center:=sim.age_point(Vector3(0,1.70,0))*sim.size_scale()
            camera.look_at_from_position(center+Vector3(.06,.02,.65)*sim.size_scale(),center)
            camera.fov=40
        else:
            camera.look_at_from_position(Vector3(.15,1.08,3.15),Vector3(0,1.0,0))
            camera.fov=40
        camera.current=true
    for frame in 15:await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var args:=OS.get_cmdline_user_args()
    var output:=args[0] if args.size()>0 else "user://portraits.png"
    get_viewport().get_texture().get_image().save_png(output)
    print("NATIVE AGE COMPARISON ",output)
    get_tree().quit()
