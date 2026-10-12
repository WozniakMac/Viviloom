class_name GrimReaper
extends Node
## Death: the Grim Reaper rises beside a Sim who has died, the Sim fades away, a
## tombstone is left where they fell, and the household mourns. If the last Sim
## in the household dies, the game is over.

signal finished(sim: Sim, cause: String)

const CAUSES := {
	"old_age": "passed away peacefully after a long and full life",
	"hunger": "starved to death",
	"fire": "perished in a fire",
}


## Plays the death scene for `sim` (who stops whatever they were doing).
static func reap(parent: Node, sim: Sim, cause: String) -> GrimReaper:
	var r := GrimReaper.new()
	parent.add_child(r)
	r._run(sim, cause)
	return r


func _run(sim: Sim, cause: String) -> void:
	sim.clear_queue()
	sim.dying = true
	sim._set_pose("lie" if cause != "old_age" else "stand")
	Sfx.play("fail", -2.0)
	# The Reaper: a tall figure in a black robe and hood, rising out of the ground.
	var reaper := Sim.new()
	reaper.sim_name = "Grim Reaper"
	reaper.shirt_color = Color(0.06, 0.05, 0.08)
	reaper.pants_color = Color(0.06, 0.05, 0.08)
	reaper.skin_color = Color(0.82, 0.82, 0.86)
	reaper.hair_color = Color(0.06, 0.05, 0.08)
	reaper.hair_style = "long"
	reaper.long_sleeves = true
	reaper.body_heavy = 0.3
	reaper.lot = null
	reaper.away = true  # not an active Sim: no needs, no autonomy
	sim.get_parent().add_child(reaper)
	reaper.set_selected(false)
	var at := sim.global_position + Vector3(1.1, -2.0, 0.6)
	reaper.global_position = at
	reaper.rotation.y = atan2(-(sim.global_position.x - at.x), -(sim.global_position.z - at.z))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.45, 0.85, 0.55)
	glow.light_energy = 2.0
	glow.omni_range = 4.0
	glow.position.y = 1.5
	reaper.add_child(glow)
	var tw := create_tween()
	tw.tween_property(reaper, "global_position:y", sim.global_position.y, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.6)
	# The Sim fades away.
	tw.tween_method(func(a: float): _fade(sim, a), 0.0, 1.0, 1.4)
	tw.tween_interval(0.4)
	tw.tween_property(reaper, "global_position:y", sim.global_position.y - 2.2, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		reaper.queue_free()
		finished.emit(sim, cause)
		queue_free())


static func _fade(sim: Sim, a: float) -> void:
	for c in sim.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).transparency = a
