extends Node
## Real viewport mouse/keyboard events exercise CAS gestures and GUI routing.
var game: Node3D
var failures := 0
var checks := 0

func _ready() -> void:
    game=load("res://scenes/main.tscn").instantiate()
    add_child(game)
    game.dialogs_enabled=false
    await get_tree().create_timer(.6).timeout
    game.open_create_a_sim()
    await get_tree().process_frame
    var cas: CreateASim=game._cas
    var person: Sim=game.sim
    var camera: Camera3D=game.rig.camera
    for frame in Sim.BODY_FRAMES:
        cas._pick_frame(frame)
        person.set_body(.2,.35)
        cas._sync_body()
        cas.view_requested.emit(false)
        await get_tree().process_frame
        var face := point(Vector3(0,1.71,-.08))
        await click(face)
        expect(cas._sculpt.close_up,frame+" clicking head opens face view")
        await scroll(MOUSE_BUTTON_WHEEL_DOWN,Vector2(1080,650))
        expect(not cas._sculpt.close_up,"wheel down returns to body view")
        await scroll(MOUSE_BUTTON_WHEEL_UP,Vector2(1080,650))
        expect(cas._sculpt.close_up,"wheel up opens face view")
        for entry in [["NoseWidth",Vector3(.010,1.673,-.130)],["EyeSpacing",Vector3(.045,1.719,-.100)],["LipFullness",Vector3(0,1.650,-.115)],["JawWidth",Vector3(.074,1.620,-.060)]]:
            var feature: String=entry[0]
            person.set_face_feature(feature,0)
            cas._sync_body()
            var start := point(entry[1])
            var center := point(Vector3(0,1.68,0))
            var side := -1.0 if start.x<center.x-3 else 1.0
            var delta := Vector2(0,-60) if feature=="LipFullness" else Vector2(60*side,0)
            var before := person.face_features.duplicate()
            await drag(start,start+delta)
            expect(person.face_features[feature]>.05,frame+" direct "+feature+" changes shape")
            for other in before:
                if other!=feature:expect(is_equal_approx(before[other],person.face_features[other]),frame+" "+feature+" preserves "+other)
            expect(absf(cas._face_sliders[feature].value-person.face_features[feature])<=.0051,"drag synchronizes slider")
            var amount: float=person.face_features[feature]
            var index:=person._head_mesh.find_blend_shape_by_name(feature)
            expect(is_equal_approx(person._head_mesh.get_blend_shape_value(index),amount),"drag reaches native face mesh")
            await key(KEY_Z,true)
            expect(is_zero_approx(person.face_features[feature]),"Ctrl+Z restores "+feature)
            await key(KEY_Z,true,true)
            expect(is_equal_approx(person.face_features[feature],amount),"Ctrl+Shift+Z reapplies "+feature)
        var nose := point(Vector3(.010,1.673,-.130))
        var baseline: float=person.face_features.NoseWidth
        await move(nose)
        await press(nose,true)
        await move(nose+Vector2(80,0),MOUSE_BUTTON_MASK_LEFT)
        await key(KEY_ESCAPE)
        await press(nose,false)
        expect(is_equal_approx(person.face_features.NoseWidth,baseline),"Escape cancels gesture")
        expect(cas._sculpt._active.is_empty(),"cancel releases capture")
        # Releasing a shape drag over a GUI field cannot trigger or strand the field.
        var name_before:=person.sim_name
        var lip := point(Vector3(0,1.650,-.115))
        await drag(lip,cas._name_edit.get_global_rect().get_center())
        expect(cas._sculpt._active.is_empty(),"release over UI ends sculpt")
        expect(person.sim_name==name_before,"crossing name field preserves name")
        cas.view_requested.emit(false)
        await get_tree().process_frame
        var waist := point(Vector3(.10,1.08,0))
        var center := point(Vector3(0,1.08,0))
        var side := -1.0 if waist.x<center.x-3 else 1.0
        await drag(waist,waist+Vector2(70*side,0))
        expect(person.body_heavy>.3,frame+" waist drag changes native weight")
        expect(is_equal_approx(person.body_fit,.35),"waist preserves muscle")
        expect(absf(cas._heavy_slider.value-person.body_heavy)<=.0051,"waist synchronizes slider")
        var chest:=point(Vector3(0,1.37,0))
        var weight:=person.body_heavy
        await drag(chest,chest+Vector2(0,-60))
        expect(person.body_fit>.4,frame+" chest drag changes muscle")
        expect(is_equal_approx(person.body_heavy,weight),"chest preserves weight")
        var saved:=person.to_dict()
        person.set_body(0,0)
        person.from_dict(saved,[])
        cas._sync_swatches()
        for part in cas._swatches:
            var selected:=0
            for swatch in cas._swatches[part]:
                if swatch[0].button_pressed:selected+=1
            expect(selected==1,part+" saved palette retains its selected swatch")
        expect(is_equal_approx(person.body_heavy,saved.body[0]) and is_equal_approx(person.body_fit,saved.body[1]),"dragged body saves and loads")
        for feature in person.face_features:
            expect(is_equal_approx(person.face_features[feature],saved.face[feature]),"dragged face saves and loads")
        var yaw:=person.rotation.y
        await drag(Vector2(1080,670),Vector2(1170,670))
        expect(absf(person.rotation.y-yaw)>.1,"background drag rotates character")
        await key(KEY_Z,true)
        expect(is_equal_approx(person.rotation.y,yaw),"undo restores rotation")
        await click(cas._frame_buttons[frame].get_global_rect().get_center())
        expect(person.body_frame==frame and cas._sculpt._active.is_empty(),"frame GUI consumes click")
        expect(cas._sculpt._undo.is_empty(),"frame action clears stale drag history")
        # GUI slider input must still work and cannot rotate the model.
        var slider: HSlider=cas._heavy_slider
        var yaw_before:=person.rotation.y
        var rect:=slider.get_global_rect()
        await click(Vector2(rect.position.x+rect.size.x*.8,rect.get_center().y))
        expect(person.body_heavy>.6,"GUI weight slider remains usable")
        expect(is_equal_approx(person.rotation.y,yaw_before),"GUI click cannot start rotation")
        print("DIRECT SCULPT FRAME ",frame," checked")
    # History belongs to one household member and cannot affect another Sim.
    cas.view_requested.emit(true)
    await get_tree().process_frame
    await drag(point(Vector3(.010,1.673,-.130)),point(Vector3(.010,1.673,-.130))+Vector2(40,0))
    var original_face:=person.face_features.duplicate()
    var other: Sim=game._new_sim("Other")
    game.add_to_household(other)
    cas.set_household(game.household,game.MAX_HOUSEHOLD)
    await get_tree().process_frame
    cas._turn(.6)
    await click(cas._household_row.get_child(1).get_global_rect().get_center())
    expect(not cas._turn_tween.is_valid(),"member switch stops the previous member turn tween")
    expect(cas.sim==other and cas._sculpt.subject==other,"household icon selects sculpt subject")
    expect(cas._sculpt._undo.is_empty(),"member switch clears previous member history")
    await key(KEY_Z,true)
    expect(other.face_features.NoseWidth==0,"undo cannot change a different member")
    expect(person.face_features==original_face,"member switch preserves previous face")
    await click(cas._household_row.get_child(0).get_global_rect().get_center())
    expect(cas.sim==person and cas._sculpt.subject==person,"original member can be edited again")
    # Text-field undo must not reach sculpt history.
    await drag(point(Vector3(.010,1.673,-.130)),point(Vector3(.010,1.673,-.130))+Vector2(40,0))
    var shape_before: float=person.face_features.NoseWidth
    var name_before:=person.sim_name
    await click(cas._name_edit.get_global_rect().get_center())
    var typed:=InputEventKey.new()
    typed.keycode=KEY_Q;typed.physical_keycode=KEY_Q;typed.unicode=81;typed.pressed=true
    Input.parse_input_event(typed)
    await get_tree().process_frame
    expect(person.sim_name!=name_before,"name field still accepts text")
    await key(KEY_Z,true)
    expect(person.sim_name==name_before,"text-field undo restores the name")
    expect(is_equal_approx(person.face_features.NoseWidth,shape_before),"text-field undo preserves sculpt history")
    # Face editing remains reachable after changes in character scale.
    for stage in ["child","teen","elder"]:
        cas._pick_age(stage)
        cas.view_requested.emit(false)
        await get_tree().process_frame
        await click(point(Vector3(0,1.71,-.08)))
        expect(cas._sculpt.close_up,stage+" head click opens details")
        var on_screen:=point(Vector3(0,1.71,-.08))
        expect(on_screen.x>500 and on_screen.x<1150 and on_screen.y>150 and on_screen.y<650,stage+" face camera remains centred")
        var nose:=point(Vector3(.01,1.673,-.13))
        var before: float=person.face_features.NoseWidth
        await drag(nose,nose+Vector2(60,0))
        expect(not is_equal_approx(before,person.face_features.NoseWidth),stage+" scaled face remains editable")
    cas._pick_age("young_adult")
    cas._pick_frame("feminine")
    person.set_body(.15,.35)
    for feature in person.face_features:person.set_face_feature(feature,0)
    cas._sync_body()
    cas._pick_hair("bob")
    cas.view_requested.emit(true)
    await get_tree().process_frame
    person.set_part_color("hair",Color(.25,.16,.1))
    cas._sync_swatches()
    var capture_point:=point(Vector3(.010,1.673,-.130))
    await move(capture_point)
    await press(capture_point,true)
    await move(capture_point+Vector2(20,0),MOUSE_BUTTON_MASK_LEFT)
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var args:=OS.get_cmdline_user_args()
    for arg in args:
        if arg.begins_with("--capture="):get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
    await key(KEY_ESCAPE)
    await press(capture_point,false)
    print("DIRECT SCULPT INPUT / UNDO / CANCEL / GUI / SAVE CHECK: ",checks," checks, ",failures," failures")
    get_tree().quit(0 if failures==0 else 1)

func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error("SCULPT CHECK: "+label)

func point(local: Vector3) -> Vector2:
    return game.rig.camera.unproject_position(game.sim._head_mesh.to_global(local))

func move(at: Vector2,mask: int=0) -> void:
    var event:=InputEventMouseMotion.new()
    event.position=at;event.global_position=at;event.button_mask=mask
    Input.parse_input_event(event)
    await get_tree().process_frame
    await get_tree().process_frame

func press(at: Vector2,down: bool) -> void:
    var event:=InputEventMouseButton.new()
    event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
    event.position=at;event.global_position=at
    Input.parse_input_event(event)
    await get_tree().process_frame
    await get_tree().process_frame

func click(at: Vector2) -> void:
    await move(at)
    await press(at,true)
    await press(at,false)

func drag(start: Vector2,end: Vector2) -> void:
    await move(start)
    await press(start,true)
    await move(end,MOUSE_BUTTON_MASK_LEFT)
    await press(end,false)

func key(code: Key,ctrl: bool=false,shift: bool=false) -> void:
    for down in [true,false]:
        var event:=InputEventKey.new()
        event.keycode=code;event.physical_keycode=code;event.pressed=down
        event.ctrl_pressed=ctrl;event.shift_pressed=shift
        Input.parse_input_event(event)
        await get_tree().process_frame

func scroll(button: MouseButton,at: Vector2) -> void:
    await move(at)
    var event:=InputEventMouseButton.new()
    event.button_index=button;event.pressed=true;event.position=at;event.global_position=at
    Input.parse_input_event(event)
    await get_tree().process_frame
    await get_tree().process_frame
