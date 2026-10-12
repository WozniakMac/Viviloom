class_name LifeCycle
extends Node
## Ages the household one day at a time: birthdays move Sims to the next life
## stage, children and teens go to school, couples who "Try for Baby" may have one
## a few days later, and elders eventually pass on.

signal notice(text: String, title: String)
## A baby was born; main adds them to the household.
signal born(baby: Sim, parents: Array)
signal passed_away(sim: Sim)
## Midnight: the rest of the world moves on too (story progression).
signal day_passed(day: int)

const PREGNANCY_DAYS := 3
const BABY_CHANCE := 0.6
const FIRST_NAMES: Array[String] = ["Mia", "Theo", "Lena", "Otto", "Ivy", "Max", "Nora", "Finn", "Zoe", "Eli", "Ruby", "Sam"]

## Set by main: the household list, their jobs, and how many Sims fit.
var household: Array[Sim] = []
var works := {}
var max_size := 4
var aging_enabled := true
var _last_day := 0
var _rng := RandomNumberGenerator.new()


func _process(_delta: float) -> void:
	var day := Clock.day()
	if _last_day == 0:
		_last_day = day
	while _last_day < day:
		_last_day += 1
		new_day()


## Everything that happens at midnight.
func new_day() -> void:
	day_passed.emit(_last_day)
	for s in household.duplicate():
		if s.pregnant_days >= 0:
			s.pregnant_days += 1
			if s.pregnant_days >= PREGNANCY_DAYS:
				_give_birth(s)
		if not aging_enabled:
			continue
		s.age_days += 1
		if s.age_days >= Ages.INFO[s.age_stage]["days"]:
			if s.age_stage == "elder":
				_pass_away(s)
			else:
				birthday(s)


func birthday(s: Sim) -> void:
	var next := Ages.next(s.age_stage)
	if next == "":
		return
	s.age_days = 0
	s.set_age(next)
	s.emotions.add("birthday", "happy", 2, "Happy Birthday!", "Another year older, and wiser.", 480.0)
	Sfx.play("level_up", -4.0)
	notice.emit("Happy birthday, %s! They're now %s." % [s.sim_name, _article(Ages.label(next))], "Birthday")
	enrol(s)


## Puts children and teens in school, and takes them out when they grow up.
func enrol(s: Sim) -> void:
	var w: Work = works.get(s)
	if w == null:
		return
	match s.age_stage:
		"child":
			w.join("school", true)
		"teen":
			w.join("high_school", true)
		_:
			if Careers.is_school(w.career):
				w.career = ""
				w.changed.emit()


## After a successful "Try for Baby": maybe a baby is on the way.
func try_for_baby(a: Sim, b: Sim) -> void:
	if not household.has(a) and not household.has(b):
		return
	var mother := a if household.has(a) else b
	if mother.pregnant_days >= 0 or b.pregnant_days >= 0 or a.pregnant_days >= 0:
		return
	if household.size() >= max_size:
		notice.emit("The household is full, so there's no room for a baby.", "Family")
		return
	if not (a.age_stage in ["young_adult", "adult"] and b.age_stage in ["young_adult", "adult"]):
		return
	if _rng.randf() > BABY_CHANCE:
		return
	mother.pregnant_days = 0
	mother.emotions.add("expecting", "happy", 2, "Expecting!", "A little one is on the way.", INF)
	mother.set_meta("baby_other_parent", b if mother == a else a)
	notice.emit("%s is expecting a baby! They'll arrive in %d days." % [mother.sim_name, PREGNANCY_DAYS], "Family")


func _give_birth(mother: Sim) -> void:
	mother.pregnant_days = -1
	mother.emotions.remove("expecting")
	var other: Sim = mother.get_meta("baby_other_parent", null)
	var baby := Sim.new()
	baby.sim_name = FIRST_NAMES[_rng.randi() % FIRST_NAMES.size()]
	var dad := other if is_instance_valid(other) else mother
	baby.skin_color = mother.skin_color.lerp(dad.skin_color, _rng.randf())
	baby.hair_color = (mother.hair_color if _rng.randf() < 0.5 else dad.hair_color)
	baby.shirt_color = Color.from_hsv(_rng.randf(), 0.45, 0.9)
	baby.pants_color = Color(0.3, 0.35, 0.5)
	baby.hair_style = "short"
	baby.age_stage = "toddler"
	baby.lot = mother.lot
	born.emit(baby, [mother, other])
	for p in [mother, other]:
		if is_instance_valid(p):
			p.emotions.add("new_parent", "happy", 3, "New Parent", "Welcome to the world, %s!" % baby.sim_name, 1440.0)
			p.change_relationship(baby, 60.0, 0.0)
	Sfx.play("level_up", -2.0)
	notice.emit("Welcome to the world, %s! %s has a new baby." % [baby.sim_name, mother.sim_name], "It's a baby!")


func _pass_away(s: Sim) -> void:
	# The last Sim in a household lives on, so the game can continue.
	if household.size() <= 1:
		return
	for o in household:
		if o != s:
			var close := o.friendship_with(s) >= 30.0 or o.romance_with(s) >= 30.0
			o.emotions.add("mourning", "sad", 3 if close else 1, "Mourning", "Missing %s." % s.sim_name, 1440.0)
	passed_away.emit(s)


static func _article(word: String) -> String:
	return ("an " if word[0].to_lower() in "aeiou" else "a ") + word.to_lower()
