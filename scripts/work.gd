class_name Work
extends Node
## Runs the household Sim's job: sends them to the curb when the shift starts,
## keeps them off the lot, then brings them home with pay, a moodlet and a
## performance change (and a promotion when earned).

signal notice(text: String, title: String)
signal paid(amount: int)
signal changed

enum State { HOME, LEAVING, AT_WORK }

var sim: Sim
var lot: Lot
var career := ""
var level := 0
var performance := 0.0
var state := State.HOME
var _last_shift_day := 0
var _mood_at_start := "fine"


func join(c: String, quiet := false) -> void:
	career = c
	level = 0
	performance = 0.0
	# Joining after today's shift started means starting tomorrow.
	if Clock.hour() >= Careers.INFO[c]["start"]:
		_last_shift_day = Clock.day()
	if not quiet:
		notice.emit("%s is now a %s in the %s career. Work is %s at §%d an hour." % [sim.sim_name, Careers.title(c, 0), Careers.label(c), Careers.schedule_text(c), Careers.hourly(c, 0)], "New Job")
	changed.emit()


func quit() -> void:
	if career == "":
		return
	notice.emit("%s quit their job as a %s." % [sim.sim_name, Careers.title(career, level)], "Career")
	if state != State.HOME:
		_return_home(false)
	career = ""
	changed.emit()


func to_dict() -> Dictionary:
	return {"career": career, "level": level, "performance": performance, "last_shift_day": _last_shift_day}


## Loading always puts the Sim at home; a shift in progress is simply skipped.
func from_dict(d: Dictionary) -> void:
	career = d.get("career", "")
	level = int(d.get("level", 0))
	performance = d.get("performance", 0.0)
	_last_shift_day = int(d.get("last_shift_day", 0))
	state = State.HOME
	changed.emit()


func has_job() -> bool:
	return career != ""


func _process(_delta: float) -> void:
	if career == "":
		return
	var info: Dictionary = Careers.INFO[career]
	var h := Clock.hour()
	match state:
		State.HOME:
			if Careers.is_work_day(Clock.day()) and h >= info["start"] and h < info["end"] and Clock.day() != _last_shift_day:
				_leave_for_work()
		State.LEAVING:
			# The walk to the curb is done (or was cancelled): off to work.
			if sim.queue.is_empty():
				_arrive_at_work()
		State.AT_WORK:
			if h >= info["end"] or h < info["start"]:
				_return_home(true)


func curb() -> Vector3:
	return lot.cell_to_world(Vector2i(lot.size.x / 2 + 1, lot.size.y - 1))


func _leave_for_work() -> void:
	_last_shift_day = Clock.day()
	_mood_at_start = sim.emotions.mood()
	sim.clear_queue()
	state = State.LEAVING
	if not sim.queue_go(curb()):
		_arrive_at_work()
	notice.emit("%s is heading off to %s." % [sim.sim_name, "school" if Careers.is_school(career) else "work"], "School" if Careers.is_school(career) else "Career")
	changed.emit()


func _arrive_at_work() -> void:
	sim.clear_queue()
	state = State.AT_WORK
	sim.away = true
	sim.visible = false
	lot.sims.erase(sim)
	changed.emit()


func _return_home(worked: bool) -> void:
	state = State.HOME
	sim.away = false
	sim.visible = true
	sim.global_position = curb()
	if not lot.sims.has(sim):
		lot.sims.append(sim)
	if worked:
		_finish_shift()
	changed.emit()


## Pay, needs after a day out, mood and performance.
func _finish_shift() -> void:
	var hours := Careers.shift_hours(career)
	var pay := Careers.hourly(career, level) * hours
	var n := sim.needs
	n.add("hunger", -6.0 * hours * 0.6)
	n.add("energy", -4.5 * hours)
	n.add("fun", -5.0 * hours * 0.7)
	n.add("hygiene", -3.0 * hours)
	n.set_value("bladder", maxf(n.get_value("bladder"), 60.0))
	n.set_value("social", maxf(n.get_value("social"), 65.0))
	var skill: String = Careers.INFO[career]["skill"]
	var gain := Careers.shift_performance(_mood_at_start, sim.skills.level(skill))
	performance = minf(100.0, performance + gain)
	if gain >= 25.0:
		sim.emotions.add("work_day", "confident", 1, "Productive Day", "Got a lot done at work today.", 240.0)
	elif gain < 12.0:
		sim.emotions.add("work_day", "tense", 1, "Rough Day at Work", "Work was hard going in that mood.", 240.0)
	if Careers.is_school(career):
		notice.emit("%s is home from school. Current grade: %s." % [sim.sim_name, Careers.grade(performance)], Careers.label(career))
		return
	paid.emit(pay)
	notice.emit("%s is back from work and earned §%d. Performance %d%%." % [sim.sim_name, pay, int(performance)], Careers.title(career, level))
	_try_promotion()


func _try_promotion() -> void:
	if performance < 100.0 or level >= Careers.max_level(career):
		return
	var skill: String = Careers.INFO[career]["skill"]
	var need := Careers.skill_for_promotion(level)
	if sim.skills.level(skill) < need:
		notice.emit("%s is ready for a promotion but needs %s level %d first." % [sim.sim_name, Skills.label(skill), need], "Career")
		return
	level += 1
	performance = 30.0
	sim.emotions.add("promoted", "happy", 3, "Promoted!", "Hard work paid off.", 480.0)
	notice.emit("%s was promoted to %s! New pay: §%d an hour." % [sim.sim_name, Careers.title(career, level), Careers.hourly(career, level)], "Promotion")
