class_name CameraRig
extends Node3D
## Orbiting overhead camera: WASD/arrows pan, Q/E or middle-drag rotate, wheel or Z/X zoom.

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
			MOUSE_BUTTON_MIDDLE:
				_rotating = mb.pressed
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.008
		pitch = clampf(pitch - mm.relative.y * 0.006, deg_to_rad(-85.0), deg_to_rad(-15.0))


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
	if Input.is_key_pressed(KEY_Q):
		yaw += rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		yaw -= rotate_speed * delta
	# Z / X zoom in and out, as well as the wheel.
	if Input.is_key_pressed(KEY_Z):
		_target_distance = maxf(min_distance, _target_distance * (1.0 - 1.5 * delta))
	if Input.is_key_pressed(KEY_X):
		_target_distance = minf(max_distance, _target_distance * (1.0 + 1.5 * delta))

	if fwd_in != 0.0 or right_in != 0.0:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var move := (fwd * fwd_in + right * right_in).normalized()
		position += move * pan_speed * (distance / 22.0) * delta
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.z = clampf(position.z, bounds.position.y, bounds.end.y)

	distance = lerpf(distance, _target_distance, 1.0 - exp(-10.0 * delta))
	_apply()


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
