class_name CameraRig
extends Node3D
## Orbiting overhead camera with the reference game's default controls: WASD/arrows
## pan (Shift for faster), Q/E raise and lower the camera, comma/period or
## right-drag rotate, middle-drag pans, wheel or Z/X zoom, and the view scrolls
## when the mouse touches a screen edge.

@export var pan_speed := 12.0
@export var rotate_speed := 1.8
@export var min_distance := 5.0
@export var max_distance := 50.0

var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(-50.0)
var distance := 22.0
var bounds := Rect2(-20, -20, 64, 64)
var camera: Camera3D

var _target_distance := 22.0
var _rotating := false
var _panning := false
## Options (Game Options > Camera).
static var edge_scrolling := true
static var invert_horizontal := false
static var invert_vertical := false
## Build mode uses Q/E/R... as tool keys, and comma/period rotate a held object.
var height_keys_enabled := true
var rotate_keys_enabled := true


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_target_distance = maxf(min_distance, _target_distance * 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_target_distance = minf(max_distance, _target_distance * 1.12)
			MOUSE_BUTTON_RIGHT:
				_rotating = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.008 * (-1.0 if invert_horizontal else 1.0)
		pitch = clampf(pitch - mm.relative.y * 0.006 * (-1.0 if invert_vertical else 1.0), deg_to_rad(-85.0), deg_to_rad(-15.0))
	elif event is InputEventMouseMotion and _panning:
		var mm := event as InputEventMouseMotion
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		position += (-right * mm.relative.x + fwd * mm.relative.y) * 0.02 * (distance / 22.0)
		_clamp_position()


func _process(delta: float) -> void:
	var fwd_in := 0.0
	var right_in := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		fwd_in += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		fwd_in -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		right_in += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		right_in -= 1.0
	# Q raises the camera (a steeper, higher view), E lowers it.
	if height_keys_enabled and Input.is_key_pressed(KEY_Q):
		pitch = clampf(pitch - 0.9 * delta, deg_to_rad(-85.0), deg_to_rad(-15.0))
	if height_keys_enabled and Input.is_key_pressed(KEY_E):
		pitch = clampf(pitch + 0.9 * delta, deg_to_rad(-85.0), deg_to_rad(-15.0))
	if rotate_keys_enabled and Input.is_key_pressed(KEY_COMMA):
		yaw += rotate_speed * delta
	if rotate_keys_enabled and Input.is_key_pressed(KEY_PERIOD):
		yaw -= rotate_speed * delta
	# Edge scrolling, on by default like the reference game.
	if edge_scrolling and get_window().has_focus():
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		var m := 4.0
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < m:
				right_in -= 1.0
			elif mp.x > vs.x - m:
				right_in += 1.0
			if mp.y < m:
				fwd_in += 1.0
			elif mp.y > vs.y - m:
				fwd_in -= 1.0
	# Z / X zoom in and out, as well as the wheel.
	if Input.is_key_pressed(KEY_Z):
		_target_distance = maxf(min_distance, _target_distance * (1.0 - 1.5 * delta))
	if Input.is_key_pressed(KEY_X):
		_target_distance = minf(max_distance, _target_distance * (1.0 + 1.5 * delta))

	if fwd_in != 0.0 or right_in != 0.0:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var move := (fwd * fwd_in + right * right_in).normalized()
		var fast := 2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		position += move * pan_speed * fast * (distance / 22.0) * delta
		_clamp_position()

	distance = lerpf(distance, _target_distance, 1.0 - exp(-10.0 * delta))
	_apply()


func _clamp_position() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func _apply() -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)


## Jumps straight to a view of `focus` (no easing).
func frame(focus: Vector3, p_yaw: float, p_pitch: float, p_distance: float) -> void:
	position = focus
	yaw = p_yaw
	pitch = p_pitch
	distance = p_distance
	_target_distance = p_distance
	_apply()


## Turns player camera controls off or on (e.g. while typing in Create a Sim).
func set_locked(locked: bool) -> void:
	set_process(not locked)
	set_process_unhandled_input(not locked)
