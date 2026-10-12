class_name CharacterSculpt
extends Control
## Direct manipulation of the native facial and body shapes in the creator.
signal changed
signal gesture_started
signal zoom_requested(close_up: bool)
signal history_changed(can_undo: bool, can_redo: bool)

const LABELS := {"NoseWidth":"Nose", "JawWidth":"Jaw", "EyeSpacing":"Eyes", "LipFullness":"Lips", "Weight":"Waist", "Fitness":"Chest", "Face":"Face", "Turn":"Turn"}
const FACE_REGIONS := [
    ["NoseWidth",Vector3(0,1.673,-.130),Vector2(.025,.021)],
    ["LipFullness",Vector3(0,1.650,-.115),Vector2(.036,.013)],
    ["EyeSpacing",Vector3(-.045,1.719,-.100),Vector2(.029,.019)],
    ["EyeSpacing",Vector3(.045,1.719,-.100),Vector2(.029,.019)],
    ["JawWidth",Vector3(-.074,1.620,-.060),Vector2(.036,.025)],
    ["JawWidth",Vector3(.074,1.620,-.060),Vector2(.036,.025)],
    ["JawWidth",Vector3(0,1.609,-.080),Vector2(.045,.016)]
]
var subject: Sim
var close_up := false
var _hover := {}
var _active := ""
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _before := {}
var _side := 1.0
var _moved := false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _hint: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var hint_panel:=PanelContainer.new()
    hint_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    hint_panel.position=Vector2(-300,-172)
    hint_panel.custom_minimum_size=Vector2(600,30)
    hint_panel.add_theme_stylebox_override("panel",UiTheme.panel_style(16,7))
    add_child(hint_panel)
    _hint=Label.new()
    _hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _hint.add_theme_font_size_override("font_size",14)
    _hint.add_theme_color_override("font_color",UiTheme.TEXT)
    hint_panel.add_child(_hint)

func select(person: Sim) -> void:
    cancel_drag()
    subject=person
    clear_history()

func set_view(face: bool) -> void:
    cancel_drag()
    close_up=face

func clear_history() -> void:
    _undo.clear()
    _redo.clear()
    history_changed.emit(false,false)

func _camera() -> Camera3D:
    return get_viewport().get_camera_3d()

func _region(screen: Vector2, feature: String, local: Vector3, radius: Vector2) -> Dictionary:
    var camera := _camera()
    var head := subject._head_mesh
    local=subject.age_point(local)
    var world := head.to_global(local)
    if camera.is_position_behind(world):return {}
    var center := camera.unproject_position(world)
    var rx := maxf(9.0,center.distance_to(camera.unproject_position(head.to_global(local+Vector3(radius.x,0,0)))))
    var ry := maxf(9.0,center.distance_to(camera.unproject_position(head.to_global(local+Vector3(0,radius.y,0)))))
    var distance := ((screen-center)/Vector2(rx,ry)).length_squared()
    if distance>1.0:return {}
    return {"feature":feature,"point":center,"distance":distance}

func region_at(screen: Vector2) -> Dictionary:
    if not is_instance_valid(subject) or not is_instance_valid(subject._head_mesh) or _camera()==null:return {}
    var head := subject._head_mesh
    var camera := _camera()
    if close_up:
        # Width gestures are useful from the front; the back/profile remains rotatable.
        var toward_camera := (camera.global_position-head.to_global(subject.age_point(Vector3(0,1.7,0)))).normalized()
        var forward := (head.global_basis*Vector3(0,0,-1)).normalized()
        if forward.dot(toward_camera)<.50:return {}
        var best := {}
        for region in FACE_REGIONS:
            var hit := _region(screen,region[0],region[1],region[2])
            if not hit.is_empty() and (best.is_empty() or hit.distance<best.distance):best=hit
        return best
    var face := _region(screen,"Face",Vector3(0,1.720,-.06),Vector2(.125,.145))
    if not face.is_empty():return face
    var chest := _region(screen,"Fitness",Vector3(0,1.37,0),Vector2(.19,.11))
    if not chest.is_empty():return chest
    return _region(screen,"Weight",Vector3(0,1.08,0),Vector2(.24,.18))

func _process(_delta: float) -> void:
    if not is_instance_valid(subject):return
    if _active.is_empty():
        _hover={} if get_viewport().gui_get_hovered_control()!=null else region_at(get_global_mouse_position())
    var feature: String=_active if not _active.is_empty() else str(_hover.get("feature",""))
    match feature:
        "NoseWidth","JawWidth","EyeSpacing":_hint.text=LABELS[feature]+" · Drag away from the centre to widen"
        "LipFullness":_hint.text="Lips · Drag up for fuller lips"
        "Weight":_hint.text="Waist · Drag outward to add weight"
        "Fitness":_hint.text="Chest · Drag up to add muscle"
        "Face":_hint.text="Click the face to edit details"
        "Turn":_hint.text="Drag to turn · Escape cancels"
        _:_hint.text="Drag facial features to reshape · Drag the background to turn" if close_up else "Click the face · Drag the waist or chest to reshape"
    queue_redraw()

func _draw() -> void:
    if _hover.is_empty():return
    var point: Vector2=_hover.point
    draw_circle(point,8,Color(1,1,1,.75),false,2.0,true)
    draw_circle(point,3,UiTheme.ACCENT,true,-1.0,true)

func _unhandled_input(event: InputEvent) -> void:
    if not is_instance_valid(subject):return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_ESCAPE and not _active.is_empty():
            cancel_drag()
            get_viewport().set_input_as_handled()
        elif event.keycode==KEY_Z and event.ctrl_pressed:
            if event.shift_pressed:redo()
            else:undo()
            get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
        if _active.is_empty():zoom_requested.emit(event.button_index==MOUSE_BUTTON_WHEEL_UP)
        get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and _active.is_empty():
        # GUI controls consume their own presses before this stage.
        get_viewport().gui_release_focus()
        _hover=region_at(event.position)
        _active=str(_hover.get("feature","Turn"))
        _start=event.position
        _last=_start
        gesture_started.emit()
        _before=_snapshot()
        _moved=false
        var center := _camera().unproject_position(subject._head_mesh.to_global(Vector3(0,1.68,0)))
        _side=-1.0 if _start.x<center.x-3 else 1.0
        get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
    # Capture an active gesture even when the cursor leaves the model or crosses UI.
    if _active.is_empty():return
    if event is InputEventMouseMotion:
        _last=event.position
        _moved=_moved or _last.distance_to(_start)>5.0
        if _moved:_apply_drag(_last-_start)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        var zoom := _active=="Face" and not _moved
        if _moved and _snapshot()!=_before:
            _undo.append({"before":_before,"after":_snapshot()})
            if _undo.size()>40:_undo.pop_front()
            _redo.clear()
        _active=""
        _before={}
        history_changed.emit(not _undo.is_empty(),not _redo.is_empty())
        if zoom:zoom_requested.emit(true)
        get_viewport().set_input_as_handled()

func _apply_drag(delta: Vector2) -> void:
    var amount := delta/get_viewport_rect().size.y*5.0
    if _active in ["Turn","Face"]:
        subject.rotation.y=float(_before.rotation)+delta.x/get_viewport_rect().size.x*TAU*1.5
    elif _active=="Weight":subject.set_body(float(_before.heavy)+amount.x*_side,subject.body_fit)
    elif _active=="Fitness":subject.set_body(subject.body_heavy,float(_before.fit)-amount.y)
    elif _active=="LipFullness":subject.set_face_feature(_active,float(_before.face[_active])-amount.y)
    else:subject.set_face_feature(_active,float(_before.face[_active])+amount.x*_side)
    changed.emit()

func _snapshot() -> Dictionary:
    return {"face":subject.face_features.duplicate(),"heavy":subject.body_heavy,"fit":subject.body_fit,"rotation":subject.rotation.y}

func _restore(state: Dictionary) -> void:
    subject.set_body(state.heavy,state.fit)
    for feature in state.face:subject.set_face_feature(feature,state.face[feature])
    subject.rotation.y=state.rotation
    changed.emit()

func cancel_drag() -> void:
    if not _active.is_empty() and is_instance_valid(subject) and not _before.is_empty():_restore(_before)
    _active=""
    _before={}
    _hover={}

func undo() -> void:
    cancel_drag()
    if _undo.is_empty():return
    var entry: Dictionary=_undo.pop_back()
    _restore(entry.before)
    _redo.append(entry)
    history_changed.emit(not _undo.is_empty(),true)

func redo() -> void:
    cancel_drag()
    if _redo.is_empty():return
    var entry: Dictionary=_redo.pop_back()
    _restore(entry.after)
    _undo.append(entry)
    history_changed.emit(true,not _redo.is_empty())

func _notification(what: int) -> void:
    if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:cancel_drag()
