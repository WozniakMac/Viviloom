class_name AspirationTracker
extends Node
## Follows the household Sim's aspiration milestones and their three current wants,
## awarding satisfaction points when either is reached.

signal notice(text: String, title: String)
signal changed

const WANT_COUNT := 3
## Game minutes before an unfulfilled want may be swapped for a fresh one.
const WANT_LIFETIME := 360.0

var sim: Sim
var build: BuildMode
var work: Work
var milestone := 0
var satisfaction := 0
## Each want: [id, text, activity, weight, minutes held].
var wants: Array = []
var _rng := RandomNumberGenerator.new()
var _check_timer := 0.0


func setup(p_sim: Sim, p_build: BuildMode, p_work: Work) -> void:
	sim = p_sim
	build = p_build
	work = p_work
	sim.activity_done.connect(_on_activity)
	reset()


## Starts the aspiration over (after Create a Sim) and rolls fresh wants.
func reset() -> void:
	milestone = 0
	wants.clear()
	while wants.size() < WANT_COUNT:
		_add_want()
	changed.emit()


func milestones() -> Array:
	return Aspirations.INFO[sim.aspiration]["milestones"]


func is_complete() -> bool:
	return milestone >= milestones().size()


func context() -> Dictionary:
	return {
		"sim": sim,
		"funds": build.funds if build != null else 0,
		"career_level": (work.level + 1) if work != null and work.has_job() else 0,
	}


func goal_done(goal: Dictionary) -> bool:
	return Aspirations.goal_met(goal, context())


func _process(delta: float) -> void:
	if sim == null:
		return
	for w in wants:
		w[4] += Clock.game_delta
	# Swap the oldest stale want now and then so wants follow mood changes.
	if not wants.is_empty() and wants[0][4] > WANT_LIFETIME:
		wants.remove_at(0)
		_add_want()
		changed.emit()
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.5
	if is_complete():
		return
	for goal in milestones()[milestone]:
		if not goal_done(goal):
			return
	_complete_milestone()


func _complete_milestone() -> void:
	milestone += 1
	satisfaction += Aspirations.MILESTONE_POINTS
	if is_complete():
		sim.emotions.add("aspiration_done", "happy", 3, "Aspiration Complete!", "A lifelong dream, fulfilled.", 1440.0)
		notice.emit("%s completed the %s aspiration! (+%d satisfaction)" % [sim.sim_name, Aspirations.label(sim.aspiration), Aspirations.MILESTONE_POINTS], "Aspiration")
	else:
		sim.emotions.add("milestone", "confident", 2, "Milestone Reached", "One step closer to the dream.", 360.0)
		notice.emit("%s reached milestone %d of %s. (+%d satisfaction)" % [sim.sim_name, milestone, Aspirations.label(sim.aspiration), Aspirations.MILESTONE_POINTS], "Aspiration")
	changed.emit()


func _on_activity(activity: String) -> void:
	for i in wants.size():
		var w: Array = wants[i]
		if activity.begins_with(w[2]):
			satisfaction += Aspirations.WANT_POINTS
			wants.remove_at(i)
			notice.emit("Want fulfilled: %s (+%d satisfaction)" % [w[1], Aspirations.WANT_POINTS], sim.sim_name)
			sim.emotions.add("want_" + w[0], "happy", 1, "Did What I Wanted", "It's the little things.", 120.0)
			_add_want()
			changed.emit()
			return


func _add_want() -> void:
	var exclude: Array = []
	for w in wants:
		exclude.append(w[0])
	var picked := Aspirations.roll_want(sim, exclude, _rng)
	if not picked.is_empty():
		var w: Array = picked.duplicate()
		w.append(0.0)
		wants.append(w)
