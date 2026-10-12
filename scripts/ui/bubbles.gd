class_name Bubbles
extends Control
## Speech bubbles over Sims who are talking (an icon for the kind of social) and
## thought bubbles over Sims with a desperate need, drawn in screen space above
## their heads.

const NEED_ICONS := {"hunger": "food", "energy": "zzz", "bladder": "drop", "hygiene": "soap", "fun": "smile", "social": "relationships"}
const CATEGORY_ICONS := {"Friendly": "smile", "Funny": "laugh", "Romance": "heart", "Mischief": "horns", "Mean": "bolt"}

var lot: Lot
var camera: Camera3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if lot == null or camera == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for s in lot.sims:
		var sim := s as Sim
		if not sim.visible or sim.away or camera.is_position_behind(sim.global_position):
			continue
		var head := camera.unproject_position(sim.global_position + Vector3(0, 2.25, 0))
		var phase := t * 0.9 + float(sim.get_instance_id() % 97) * 0.37
		var social := sim.social_bubble()
		if social != "":
			# Speakers take turns: each bubble shows for part of a cycle.
			if fmod(phase, 2.4) < 1.3:
				_speech(head, CATEGORY_ICONS.get(social, "smile"), social)
			continue
		var need := sim.desperate_need()
		if need != "":
			_thought(head + Vector2(0, sin(t * 2.0) * 3.0), NEED_ICONS[need], Hud.NEED_COLORS[need])


func _bubble_shape(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, 3), r, Color(0.05, 0.12, 0.3, 0.2))
	draw_circle(c, r, Color.WHITE)
	draw_arc(c, r, 0, TAU, 32, UiTheme.PANEL_EDGE, 2.0, true)


func _speech(at: Vector2, icon: String, category: String) -> void:
	var c := at + Vector2(0, -22)
	var r := 20.0
	var tail := PackedVector2Array([c + Vector2(-6, r - 3), c + Vector2(6, r - 3), c + Vector2(-2, r + 10)])
	draw_colored_polygon(tail, Color.WHITE)
	_bubble_shape(c, r)
	var col := Color(0.92, 0.35, 0.55) if category == "Romance" else (UiTheme.RED if category == "Mean" else UiTheme.ACCENT)
	IconButton.draw_icon(self, icon, c, 9.0, col)


func _thought(at: Vector2, icon: String, col: Color) -> void:
	var c := at + Vector2(0, -30)
	draw_circle(at + Vector2(-4, -4), 4.0, Color.WHITE)
	draw_circle(at + Vector2(-9, 3), 2.5, Color.WHITE)
	_bubble_shape(c, 21.0)
	IconButton.draw_icon(self, icon, c, 10.0, col.darkened(0.15))
