class_name Visitors
extends Node
## A neighbour who drops by during the day: walks onto the lot in the morning, looks
## after themselves (and chats) on their own, and heads home in the evening.

signal arrived(visitor: Sim)
signal left(visitor: Sim)

const ARRIVE_HOUR := 9
const LEAVE_HOUR := 19

var lot: Lot
var neighbour: Sim
var _leaving := false
var _last_visit_day := 0


func setup(p_lot: Lot) -> void:
	lot = p_lot
	neighbour = Sim.new()
	neighbour.name = "Neighbour"
	neighbour.sim_name = "Jules"
	neighbour.is_visitor = true
	neighbour.shirt_color = Color(0.85, 0.35, 0.3)
	neighbour.pants_color = Color(0.3, 0.32, 0.4)
	neighbour.skin_color = Color(0.6, 0.42, 0.3)
	neighbour.hair_color = Color(0.08, 0.07, 0.07)
	neighbour.hair_style = "bun"
	neighbour.lot = lot
	add_child(neighbour)
	neighbour.set_selected(false)
	var t: Array[String] = ["cheerful", "bookworm"]
	neighbour.set_traits(t)
	neighbour.needs.set_value("social", 35.0)
	_send_home(true)


func _process(_delta: float) -> void:
	var h := Clock.hour()
	if neighbour.away:
		if h >= ARRIVE_HOUR and h < LEAVE_HOUR - 2 and Clock.day() != _last_visit_day:
			_arrive()
	elif not _leaving and (h >= LEAVE_HOUR or h < ARRIVE_HOUR):
		_leave()
	elif _leaving and neighbour.queue.is_empty() and not neighbour.is_moving():
		_send_home(false)


func entry_point() -> Vector3:
	return lot.cell_to_world(Vector2i(lot.size.x / 2 - 1, lot.size.y - 1))


func _arrive() -> void:
	_last_visit_day = Clock.day()
	_leaving = false
	neighbour.away = false
	neighbour.visible = true
	neighbour.global_position = entry_point()
	# A fresh day: rested and ready to chat.
	for n in Needs.ORDER:
		neighbour.needs.set_value(n, 75.0)
	neighbour.needs.set_value("social", 35.0)
	if not lot.sims.has(neighbour):
		lot.sims.append(neighbour)
	arrived.emit(neighbour)


func _leave() -> void:
	_leaving = true
	neighbour.clear_queue()
	neighbour.queue_go(entry_point())


func _send_home(quiet: bool) -> void:
	_leaving = false
	neighbour.clear_queue()
	neighbour.away = true
	neighbour.visible = false
	lot.sims.erase(neighbour)
	if not quiet:
		left.emit(neighbour)
