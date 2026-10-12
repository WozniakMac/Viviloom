class_name Story
extends RefCounted
## Story progression: the households you aren't playing live on in the background.
## Each day they age, work and get paid, get promoted, find jobs, have babies and
## eventually pass away, and the notable moments come back as neighbourhood news.
## Households are the saved snapshots kept in Main.other_households.

const BABY_CHANCE := 0.08
const JOB_CHANCE := 0.35
const MAX_SIZE := 4
const BABY_NAMES: Array[String] = ["Ada", "Bo", "Cleo", "Dax", "Esme", "Felix", "Gus", "Hazel", "Iris", "Jonah", "Kit", "Luna"]


## Advances every household by one day (`day` is the new day number) and returns
## the news worth telling the player. Households that die out are removed.
static func advance_day(households: Array, day: int, rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	for h in households.duplicate():
		var members: Array = h.get("household", [])
		var family := _family_name(h)
		for m in members.duplicate():
			var sim: Dictionary = m["sim"]
			var age: Array = sim.get("age", ["young_adult", 0, -1])
			age[1] = int(age[1]) + 1
			if int(age[1]) >= Ages.INFO[age[0]]["days"]:
				if age[0] == "elder":
					members.erase(m)
					for other in members:
						if other["sim"].get("spouse", "") == sim.get("name", ""):
							other["sim"]["spouse"] = ""
					news.append("%s %s passed away peacefully at a ripe old age." % [sim.get("name", "?"), family])
					continue
				age[0] = Ages.next(age[0])
				age[1] = 0
				_enrol(m)
			sim["age"] = age
			_work_day(h, m, day, rng)
		if members.is_empty():
			households.erase(h)
			news.append("The %s household has no one left. Their home is up for sale." % family)
			continue
		var baby := _maybe_baby(members, rng)
		if not baby.is_empty():
			members.append(baby)
			news.append("The %s family welcomed a baby, %s!" % [family, baby["sim"]["name"]])
	return news


static func _family_name(h: Dictionary) -> String:
	var members: Array = h.get("household", [])
	return members[0]["sim"].get("name", "?") if not members.is_empty() else "?"


## Children and teens go to school; grown-ups leave it.
static func _enrol(m: Dictionary) -> void:
	var stage: String = m["sim"]["age"][0]
	var w: Dictionary = m.get("work", {})
	match stage:
		"child":
			w["career"] = "school"
		"teen":
			w["career"] = "high_school"
		_:
			if Careers.is_school(w.get("career", "")):
				w["career"] = ""
	w["level"] = 0
	w["performance"] = 0.0
	m["work"] = w


## A working day: pay into the household's funds, performance and promotions; the
## jobless sometimes find work.
static func _work_day(h: Dictionary, m: Dictionary, day: int, rng: RandomNumberGenerator) -> void:
	var stage: String = m["sim"]["age"][0]
	var w: Dictionary = m.get("work", {})
	var career: String = w.get("career", "")
	if career == "" and Ages.is_adult(stage) and stage != "elder" and rng.randf() < JOB_CHANCE:
		w["career"] = Careers.ORDER[rng.randi() % Careers.ORDER.size()]
		w["level"] = 0
		w["performance"] = 0.0
		m["work"] = w
		return
	if career == "" or Careers.is_school(career) or not Careers.is_work_day(day):
		return
	var level := int(w.get("level", 0))
	h["funds"] = int(h.get("funds", 0)) + Careers.hourly(career, level) * Careers.shift_hours(career)
	var perf: float = w.get("performance", 0.0) + rng.randf_range(10.0, 25.0)
	if perf >= 100.0 and level < Careers.max_level(career):
		level += 1
		perf = 30.0
	w["level"] = level
	w["performance"] = minf(perf, 100.0)
	m["work"] = w


## Married couples with room in the house sometimes have a baby.
static func _maybe_baby(members: Array, rng: RandomNumberGenerator) -> Dictionary:
	if members.size() >= MAX_SIZE or rng.randf() > BABY_CHANCE:
		return {}
	for m in members:
		var s: Dictionary = m["sim"]
		var stage: String = s["age"][0]
		if s.get("spouse", "") == "" or not stage in ["young_adult", "adult"]:
			continue
		var baby: Dictionary = m.duplicate(true)
		var b: Dictionary = baby["sim"]
		b["name"] = BABY_NAMES[rng.randi() % BABY_NAMES.size()]
		b["age"] = ["toddler", 0, -1]
		b["spouse"] = ""
		b["partner"] = ""
		b["relationships"] = {}
		b["inventory"] = []
		b["skills"] = {}
		b["stats"] = {}
		b["moodlets"] = []
		b["perks"] = []
		b["traits"] = []
		baby["work"] = {"career": "", "level": 0, "performance": 0.0}
		baby.erase("aspiration")
		return baby
	return {}
