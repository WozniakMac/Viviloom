class_name Work
extends Node
## Runs the household Sim's job: sends them to the curb when the shift starts,
## keeps them off the lot, then brings them home with pay, a moodlet and a
## performance change (and a promotion when earned).

signal notice(text: String, title: String)
signal paid(amount: int)
signal changed
## A choice came up at work: main shows it; call `resolve_event` with the answer.
signal work_event(title: String, text: String, choices: Array)

enum State { HOME, LEAVING, WAITING, AT_WORK, RETURNING }

var sim: Sim
var lot: Lot
var career := ""
## "hard", "normal" or "easy" (see Careers.WORK_STYLES).
var work_style := "normal"
## Day the Sim is taking off, if any.
var day_off := 0
var level := 0
var performance := 0.0
var state := State.HOME
## Picks the Sim up at the curb and drops them back (null = they just go).
var carpool: Carpool
var _last_shift_day := 0
var _mood_at_start := "fine"
## Skill experience when the daily task window opened (after the last shift).
var task_base_xp := 0.0
var _event_hour := -1
var _event: Array = []
var _rng := RandomNumberGenerator.new()


func join(c: String, quiet := false) -> void:
	career = c
	task_base_xp = _task_xp()
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
	return {"career": career, "level": level, "performance": performance, "last_shift_day": _last_shift_day, "style": work_style, "task_base": task_base_xp}


## Loading always puts the Sim at home; a shift in progress is simply skipped.
func from_dict(d: Dictionary) -> void:
	career = d.get("career", "")
	level = int(d.get("level", 0))
	performance = d.get("performance", 0.0)
	_last_shift_day = int(d.get("last_shift_day", 0))
	work_style = d.get("style", "normal")
	task_base_xp = d.get("task_base", _task_xp())
	state = State.HOME
	changed.emit()


## Skips today's shift (a small hit to performance).
func take_day_off() -> void:
	if career == "" or Careers.is_school(career):
		return
	day_off = Clock.day()
	performance = maxf(0.0, performance - 8.0)
	notice.emit("%s is taking the day off." % sim.sim_name, "Career")
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
			if Careers.is_work_day(Clock.day()) and h >= info["start"] and h < info["end"] and Clock.day() != _last_shift_day and Clock.day() != day_off:
				_leave_for_work()
		State.LEAVING:
			# The walk to the curb is done (or was cancelled): the carpool comes.
			if sim.queue.is_empty():
				state = State.WAITING
				if carpool != null:
					carpool.visit(curb(), _arrive_at_work)
				else:
					_arrive_at_work()
		State.AT_WORK:
			if _event_hour >= 0 and h >= _event_hour and h < info["end"]:
				_event_hour = -1
				_raise_event()
			if h >= info["end"] or h < info["start"]:
				if carpool != null:
					state = State.RETURNING
					carpool.visit(curb(), _return_home.bind(true))
				else:
					_return_home(true)


func curb() -> Vector3:
	return lot.cell_to_world(Vector2i(lot.size.x / 2 + 1, lot.size.y - 1))


func _leave_for_work() -> void:
	sim.change_outfit("everyday")
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
	# Most shifts bring one choice to make, partway through the day.
	var info: Dictionary = Careers.INFO[career]
	_event_hour = -1
	if not Careers.is_school(career) and _rng.randf() < 0.7:
		_event_hour = _rng.randi_range(int(info["start"]) + 1, maxi(int(info["start"]) + 1, int(info["end"]) - 2))
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
	var style: Array = Careers.WORK_STYLES[work_style]
	var gain: float = Careers.shift_performance(_mood_at_start, sim.skills.level(skill)) * style[1]
	for t in sim.traits:
		gain += Traits.INFO[t].get("work_bonus", 0.0)
	var task_done := daily_task_done()
	if task_done:
		gain += Careers.TASK_BONUS
	task_base_xp = _task_xp()
	performance = minf(100.0, performance + gain)
	var m: Array = style[2]
	if not m.is_empty():
		sim.emotions.add(m[0], m[1], m[2], m[3], m[4], m[5])
		if work_style == "hard":
			sim.needs.add("energy", -15.0)
	if gain >= 25.0:
		sim.emotions.add("work_day", "confident", 1, "Productive Day", "Got a lot done at work today.", 240.0)
	elif gain < 12.0:
		sim.emotions.add("work_day", "tense", 1, "Rough Day at Work", "Work was hard going in that mood.", 240.0)
	if Careers.is_school(career):
		if not sim.inventory.any(func(it): return it.get("kind") == "homework"):
			sim.inventory.append({"kind": "homework", "value": 0})
			sim.inventory_changed.emit()
		notice.emit("%s is home from school with homework. Current grade: %s." % [sim.sim_name, Careers.grade(performance)], Careers.label(career))
		return
	paid.emit(pay)
	notice.emit("%s is back from work and earned §%d. Performance %d%%.%s" % [sim.sim_name, pay, int(performance), " Daily task done!" if task_done else ""], Careers.title(career, level))
	_try_promotion()


## Experience in the daily task's skill right now (0 for mood tasks).
func _task_xp() -> float:
	var t: Dictionary = Careers.DAILY_TASKS.get(career, {})
	if sim == null or not t.has("skill"):
		return 0.0
	return sim.skills.xp.get(t["skill"], 0.0)


func daily_task_done() -> bool:
	var t: Dictionary = Careers.DAILY_TASKS.get(career, {})
	if t.is_empty():
		return false
	if t.has("mood"):
		var mood := _mood_at_start if state != State.HOME else sim.emotions.mood()
		return mood == t["mood"]
	return _task_xp() - task_base_xp >= t["xp"]


func _raise_event() -> void:
	_event = Careers.EVENTS[_rng.randi() % Careers.EVENTS.size()]
	var choices: Array = []
	for c in _event[2]:
		var label: String = c[0]
		if c.size() > 3:
			var req: Dictionary = c[3]
			var sk: String = req.keys()[0]
			label += " (%s %d)" % [Skills.label(sk), req[sk]]
		choices.append(label)
	var text: String = _event[1] % sim.sim_name if "%s" in _event[1] else _event[1]
	work_event.emit(_event[0], text, choices)


## Applies the answer to the current work event.
func resolve_event(choice: int) -> void:
	if _event.is_empty():
		return
	var c: Array = _event[2][clampi(choice, 0, _event[2].size() - 1)]
	var perf: float = c[1]
	var m: Array = c[2]
	if c.size() > 3:
		var req: Dictionary = c[3]
		var sk: String = req.keys()[0]
		if sim.skills.level(sk) < req[sk]:
			perf = c[4]
			m = c[5]
	performance = clampf(performance + perf, 0.0, 100.0)
	if not m.is_empty():
		sim.emotions.add(m[0], m[1], m[2], m[3], m[4], m[5])
	_event = []
	changed.emit()


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
