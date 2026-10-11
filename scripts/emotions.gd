class_name Emotions
extends RefCounted
## Moodlets and the emotion they add up to. Every moodlet pushes one emotion by a
## weight for a while; the emotion with the largest total becomes the Sim's mood,
## and the size of that total sets how strongly they feel it.

signal changed

const FINE := "fine"
## emotion -> [label, colour]
const INFO := {
	"fine": ["Fine", Color(0.36, 0.72, 0.36)],
	"happy": ["Happy", Color(0.95, 0.78, 0.2)],
	"inspired": ["Inspired", Color(0.2, 0.7, 0.72)],
	"focused": ["Focused", Color(0.55, 0.42, 0.85)],
	"energized": ["Energized", Color(0.98, 0.55, 0.16)],
	"playful": ["Playful", Color(0.2, 0.62, 0.95)],
	"confident": ["Confident", Color(0.9, 0.4, 0.62)],
	"sad": ["Sad", Color(0.3, 0.42, 0.8)],
	"tense": ["Tense", Color(0.55, 0.62, 0.3)],
	"angry": ["Angry", Color(0.86, 0.22, 0.18)],
	"embarrassed": ["Embarrassed", Color(0.82, 0.45, 0.4)],
	"bored": ["Bored", Color(0.55, 0.55, 0.55)],
	"uncomfortable": ["Uncomfortable", Color(0.6, 0.45, 0.3)],
}
## need -> [[below, id, emotion, weight, label, description], ...] strongest first.
const NEED_MOODLETS := {
	"hunger": [[15.0, "starving", "uncomfortable", 3, "Starving", "If I don't eat something soon..."], [30.0, "hungry", "uncomfortable", 1, "Hungry", "A meal would be nice."]],
	"energy": [[15.0, "exhausted", "uncomfortable", 3, "Exhausted", "Can barely keep their eyes open."], [30.0, "tired", "uncomfortable", 1, "Tired", "Could do with some sleep."]],
	"bladder": [[15.0, "bursting", "uncomfortable", 3, "About to Burst", "Toilet. Now."], [30.0, "full_bladder", "uncomfortable", 1, "Needs the Toilet", "Nature is calling."]],
	"hygiene": [[15.0, "stinky", "embarrassed", 2, "Stinky", "Others can smell it too."], [30.0, "grimy", "uncomfortable", 1, "Feeling Grimy", "A shower would help."]],
	"fun": [[15.0, "very_bored", "bored", 3, "Bored Out of Their Mind", "Anything would be better than this."], [30.0, "bored", "bored", 1, "Bored", "Something fun to do, please."]],
	"social": [[15.0, "very_lonely", "sad", 3, "Very Lonely", "Really needs to talk to someone."], [30.0, "lonely", "sad", 1, "Lonely", "Misses having someone to talk to."]],
}


class Moodlet:
	extends RefCounted
	var id: String
	var emotion: String
	var weight: int
	var label: String
	var description: String
	## Game minutes left; INF lasts until removed.
	var remaining := INF


var moodlets: Array[Moodlet] = []


## Adds a moodlet, replacing one with the same id (which refreshes its timer).
func add(id: String, emotion: String, weight: int, label: String, description := "", minutes := INF) -> Moodlet:
	remove(id, false)
	var m := Moodlet.new()
	m.id = id
	m.emotion = emotion
	m.weight = weight
	m.label = label
	m.description = description
	m.remaining = minutes
	moodlets.append(m)
	changed.emit()
	return m


func remove(id: String, notify := true) -> void:
	for i in range(moodlets.size() - 1, -1, -1):
		if moodlets[i].id == id:
			moodlets.remove_at(i)
			if notify:
				changed.emit()


func has(id: String) -> bool:
	return get_moodlet(id) != null


func get_moodlet(id: String) -> Moodlet:
	for m in moodlets:
		if m.id == id:
			return m
	return null


## Counts down timed moodlets and drops the ones that ran out.
func tick(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var expired := false
	for i in range(moodlets.size() - 1, -1, -1):
		var m := moodlets[i]
		if m.remaining == INF:
			continue
		m.remaining -= minutes
		if m.remaining <= 0.0:
			moodlets.remove_at(i)
			expired = true
	if expired:
		changed.emit()


## Keeps the "Hungry", "Tired"... moodlets in step with the needs.
func sync_needs(needs: Needs) -> void:
	for need in NEED_MOODLETS:
		var v := needs.get_value(need)
		var active := ""
		for rule in NEED_MOODLETS[need]:
			if v < rule[0]:
				active = "need_" + rule[1]
				if not has(active):
					add(active, rule[2], rule[3], rule[4], rule[5])
				break
		for rule in NEED_MOODLETS[need]:
			var id: String = "need_" + rule[1]
			if id != active and has(id):
				remove(id)


## emotion -> summed weight of its moodlets.
func totals() -> Dictionary:
	var t := {}
	for m in moodlets:
		t[m.emotion] = t.get(m.emotion, 0) + m.weight
	return t


## The current emotion: the one with the largest total, or "fine" if none.
func mood() -> String:
	var t := totals()
	var best := FINE
	var best_total := 0
	for e in t:
		if t[e] > best_total:
			best = e
			best_total = t[e]
	return best


## 0 for fine, then 1 (mild), 2 (very), 3 (extremely).
func intensity() -> int:
	var e := mood()
	if e == FINE:
		return 0
	var total: int = totals()[e]
	if total >= 5:
		return 3
	if total >= 3:
		return 2
	return 1


func mood_label() -> String:
	var prefix: String = ["", "", "Very ", "Extremely "][intensity()]
	return prefix + label(mood())


static func label(emotion: String) -> String:
	return INFO[emotion][0]


static func color(emotion: String) -> Color:
	return INFO[emotion][1]


static func describe_time(minutes: float) -> String:
	if minutes == INF:
		return ""
	var m := int(ceil(minutes))
	if m >= 60:
		return "%dh %02dm left" % [m / 60, m % 60]
	return "%dm left" % m
