class_name Carpool
extends Node3D
## The car that collects Sims for work or school and brings them home: it drives
## along the road, stops at the curb, and drives off again.

const SPEED := 14.0
const STOP_SECONDS := 1.2

var road_z := 25.0
var _car: Node3D
var _busy := false
var _jobs: Array = []


func _ready() -> void:
	var scene := load("res://assets/objects/car.glb") as PackedScene
	_car = scene.instantiate() if scene != null else Node3D.new()
	add_child(_car)
	_car.visible = false


## Drives up to `curb`, calls `at_curb` while stopped, then leaves.
func visit(curb: Vector3, at_curb: Callable) -> void:
	_jobs.append([curb, at_curb])
	if not _busy:
		_next()


func _next() -> void:
	if _jobs.is_empty():
		_busy = false
		return
	_busy = true
	var job: Array = _jobs.pop_front()
	var curb: Vector3 = job[0]
	var stop := Vector3(curb.x, 0.0, road_z)
	var start := stop + Vector3(-45.0, 0, 0)
	var finish := stop + Vector3(55.0, 0, 0)
	_car.position = start
	_car.rotation.y = 0.0
	_car.visible = true
	var tw := create_tween()
	tw.tween_property(_car, "position", stop, start.distance_to(stop) / SPEED).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): job[1].call())
	tw.tween_interval(STOP_SECONDS)
	tw.tween_property(_car, "position", finish, stop.distance_to(finish) / SPEED).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_car.visible = false
		_next())
