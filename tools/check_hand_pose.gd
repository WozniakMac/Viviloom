extends Node
## Exercise real AnimationMixer/modifier ordering, releases and rebuilt skeletons.
var failures := 0
var captured := {}
var capture_count := 0

func _ready() -> void:
    Engine.max_fps = 120
    call_deferred("check")

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        print("HAND POSE FAILURE: ",message)

func capture(modifier: HandPose) -> void:
    var skeleton := modifier.get_skeleton()
    captured.clear()
    for side in ["L","R"]:
        for finger in range(1,6):
            for segment in range(1,4):
                var name := "finger%d-%d.%s" % [finger,segment,side]
                captured[name] = skeleton.get_bone_pose_rotation(skeleton.find_bone(name))
    capture_count += 1

func settle() -> void:
    await get_tree().create_timer(0.40).timeout

func profile_matches(kind: String) -> void:
    for finger in range(1,6):
        for segment in range(1,4):
            var name := "finger%d-%d.R" % [finger,segment]
            expect(captured.has(name),"Modifier never captured "+name)
            if not captured.has(name):continue
            var expected := Quaternion(Vector3.RIGHT,deg_to_rad(HandPose.PROFILES[kind][finger-1][segment-1]))
            expect((captured[name] as Quaternion).angle_to(expected)<0.015,"Animation overwrote grip "+name)

func check() -> void:
    var sim := Sim.new()
    sim.creator_preview = true
    sim.autonomy_enabled = false
    add_child(sim)
    sim.set_process(false)
    sim.set_physics_process(false)
    sim._anim.play("idle")
    sim._hand_pose.modification_processed.connect(capture.bind(sim._hand_pose))
    await settle()
    var skeleton := sim._hand.get_parent() as Skeleton3D
    expect(skeleton.get_bone_count()==47,"Missing anatomical finger bones")
    var relaxed := {}
    var left_relaxed := {}
    for finger in range(1,6):
        for segment in range(1,4):
            var name := "finger%d-%d.R" % [finger,segment]
            relaxed[name]=skeleton.get_bone_pose_rotation(skeleton.find_bone(name))
            var left_name := name.trim_suffix(".R")+".L"
            left_relaxed[left_name]=skeleton.get_bone_pose_rotation(skeleton.find_bone(left_name))
    sim._set_prop("drink")
    await settle()
    expect(sim._hand_pose.influence>0.99,"Grip did not start from zero influence")
    profile_matches("drink")
    for name in left_relaxed:
        expect(skeleton.get_bone_pose_rotation(skeleton.find_bone(name)).angle_to(left_relaxed[name])<0.015,"Right-hand grip changed the left hand")
    expect(sim._prop.position.length()>0.10 and sim._prop.position.length()<0.18,"Prop is anchored at the wrist")
    var local_basis := sim._prop.basis
    sim._anim.play("walk")
    await settle()
    profile_matches("drink")
    expect(sim._prop.basis.is_equal_approx(local_basis),"Prop stopped following the animated wrist")
    expect(sim._prop.global_basis.is_equal_approx(sim._hand.global_basis*local_basis),"Prop orientation disconnected from wrist")
    sim._set_prop("book")
    await settle()
    profile_matches("book")
    var before: Quaternion = captured["finger3-2.R"]
    sim._set_prop("rod")
    await get_tree().process_frame
    await get_tree().process_frame
    var transitioning: Quaternion = captured["finger3-2.R"]
    expect(before.angle_to(transitioning)<deg_to_rad(12),"Grip switched abruptly")
    await settle()
    profile_matches("rod")
    sim.set_body_frame("feminine")
    sim._hand_pose.modification_processed.connect(capture.bind(sim._hand_pose))
    await settle()
    expect(sim._prop_kind=="rod" and sim._hand_pose.held_kind=="rod","Frame switch lost the held object")
    expect(sim._hand_pose.get_skeleton()==sim._hand.get_parent(),"Frame switch retained stale bones")
    profile_matches("rod")
    sim._anim.play("idle")
    sim._set_prop("")
    await get_tree().process_frame
    await get_tree().process_frame
    expect(sim._hand_pose.influence>0 and sim._hand_pose.influence<1,"Grip release skipped its blend")
    await settle()
    expect(is_zero_approx(sim._hand_pose.influence),"Grip release never finished")
    skeleton=sim._hand.get_parent()
    for name in relaxed:
        expect(skeleton.get_bone_pose_rotation(skeleton.find_bone(name)).angle_to(relaxed[name])<0.015,"Release did not restore animated resting fingers")
    expect(capture_count>30,"Modifier did not run with AnimationMixer")
    sim.queue_free()
    await get_tree().process_frame
    print("ANIMATED HAND GRIPS / TRANSITIONS / RELEASE / FRAME SWITCH: ",failures," failures")
    get_tree().quit(0 if failures==0 else 1)
