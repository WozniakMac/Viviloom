class_name Visitors
extends Node
## The townies: Sims who live elsewhere in the neighbourhood. One neighbour drops
## by most days; any of them can be invited over by phone; and some of them are
## out and about at community lots. They look after themselves while present.

signal arrived(visitor: Sim)
signal left(visitor: Sim)

const ARRIVE_HOUR := 9
const LEAVE_HOUR := 19
## How long an invited guest stays, in game minutes.
const VISIT_MINUTES := 300.0
## name, shirt, pants, skin, hair colour, hair style, traits, age
const PEOPLE := [
	["Jules", Color(0.85, 0.35, 0.3), Color(0.3, 0.32, 0.4), Color(0.6, 0.42, 0.3), Color(0.08, 0.07, 0.07), "bun", ["cheerful", "bookworm"], "young_adult"],
	["Marco", Color(0.25, 0.55, 0.4), Color(0.2, 0.2, 0.25), Color(0.8, 0.62, 0.48), Color(0.2, 0.13, 0.08), "short", ["genius", "lazy"], "adult"],
	["Priya", Color(0.95, 0.75, 0.25), Color(0.35, 0.3, 0.45), Color(0.55, 0.38, 0.27), Color(0.06, 0.05, 0.05), "long", ["creative", "cheerful"], "young_adult"],
	["Hank", Color(0.45, 0.45, 0.5), Color(0.4, 0.3, 0.22), Color(0.9, 0.75, 0.62), Color(0.7, 0.7, 0.72), "short", ["gloomy", "bookworm"], "elder"],
	["Sofia", Color(0.6, 0.35, 0.75), Color(0.15, 0.15, 0.2), Color(0.95, 0.8, 0.68), Color(0.75, 0.3, 0.12), "long", ["creative"], "teen"],
	["Dev", Color(0.2, 0.45, 0.8), Color(0.5, 0.48, 0.4), Color(0.42, 0.28, 0.2), Color(0.1, 0.08, 0.07), "short", ["cheerful", "genius"], "adult"],
]

var lot: Lot
var townies: Array[Sim] = []
## The neighbour who drops by (townies[0]).
var neighbour: Sim
## Whether the household is at home; the daily drop-in only happens there.
var at_home := true
## Townie -> game minute they'll leave (INF = when the household leaves).
var _leave_at := {}
var _last_visit_day := 0
var _rng := RandomNumberGenerator.new()


## New faces who move to town when someone passes away.
const NEWCOMER_NAMES: Array[String] = ["Rosa", "Kofi", "Mei", "Lars", "Amara", "Tomas", "Yuki", "Bram", "Nadia", "Oscar"]
const MARRY_CHANCE := 0.06


func setup(p_lot: Lot) -> void:
	lot = p_lot
	for p in PEOPLE:
		var s := _make_townie(p[0])
		s.shirt_color = p[1]
		s.pants_color = p[2]
		s.skin_color = p[3]
		s.hair_color = p[4]
		s.hair_style = p[5]
		s.age_stage = p[7]
		var t: Array[String] = []
		t.assign(p[6])
		s.set_traits(t)
	neighbour = townies[0]


func _make_townie(n: String) -> Sim:
	var s := Sim.new()
	s.name = "Townie_" + n
	s.sim_name = n
	s.is_visitor = true
	s.lot = lot
	add_child(s)
	s.set_selected(false)
	townies.append(s)
	_hide(s)
	return s


## A day passes for the townies: birthdays, old age (and a newcomer moving in),
## and now and then two of them tie the knot. Returns neighbourhood news.
func new_day(rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	for t in townies.duplicate():
		if t.visible:
			continue
		t.age_days += 1
		if t.age_days < Ages.INFO[t.age_stage]["days"]:
			continue
		t.age_days = 0
		if t.age_stage == "elder":
			news.append("%s, a familiar face around town, passed away." % t.sim_name)
			if t.spouse != null and is_instance_valid(t.spouse):
				t.spouse.spouse = null
			remove_townie(t)
			t.queue_free()
			var n := newcomer(rng)
			news.append("%s just moved to town." % n.sim_name)
		else:
			t.set_age(Ages.next(t.age_stage))
	var singles := townies.filter(func(t: Sim): return t.spouse == null and Ages.is_adult(t.age_stage) and not t.visible)
	if singles.size() >= 2 and rng.randf() < MARRY_CHANCE:
		var a: Sim = singles[rng.randi() % singles.size()]
		singles.erase(a)
		var b: Sim = singles[rng.randi() % singles.size()]
		a.spouse = b
		b.spouse = a
		a.change_relationship(b, 60.0, 80.0)
		news.append("%s and %s got married!" % [a.sim_name, b.sim_name])
	return news


## A young adult with a fresh name and look joins the townies.
func newcomer(rng: RandomNumberGenerator) -> Sim:
	var taken := townies.map(func(t: Sim): return t.sim_name)
	var free := NEWCOMER_NAMES.filter(func(n): return not taken.has(n))
	var n: String = free[rng.randi() % free.size()] if not free.is_empty() else "Newcomer %d" % townies.size()
	var s := _make_townie(n)
	s.shirt_color = Color.from_hsv(rng.randf(), 0.5, 0.85)
	s.pants_color = Color.from_hsv(rng.randf(), 0.3, 0.35)
	s.skin_color = Color(0.95, 0.8, 0.68).lerp(Color(0.4, 0.27, 0.2), rng.randf())
	s.hair_color = Color.from_hsv(0.08, 0.6, rng.randf_range(0.08, 0.6))
	s.hair_style = Sim.HAIR_STYLES[rng.randi() % Sim.HAIR_STYLES.size()]
	s.age_stage = "young_adult"
	if neighbour == null:
		neighbour = s
	return s


## Takes a townie out of the pool (they moved in with the household); someone
## else becomes the neighbour who drops by.
func remove_townie(t: Sim) -> void:
	townies.erase(t)
	_leave_at.erase(t)
	if neighbour == t:
		neighbour = townies[0] if not townies.is_empty() else null


func present() -> Array[Sim]:
	var out: Array[Sim] = []
	for t in townies:
		if not t.away:
			out.append(t)
	return out


func _process(_delta: float) -> void:
	if lot == null:
		return
	var h := Clock.hour()
	# The neighbour drops by most mornings while the household is home.
	if at_home and neighbour != null and neighbour.away and h >= ARRIVE_HOUR and h < LEAVE_HOUR - 2 and Clock.day() != _last_visit_day:
		_last_visit_day = Clock.day()
		bring(neighbour, LEAVE_HOUR * 60.0 + floorf(Clock.total_minutes / 1440.0) * 1440.0)
		arrived.emit(neighbour)
	for t in townies:
		if t.away or not _leave_at.has(t):
			continue
		var leaving: bool = t.get_meta("leaving", false)
		if not leaving and Clock.total_minutes >= _leave_at[t]:
			t.set_meta("leaving", true)
			t.clear_queue()
			t.queue_go(entry_point())
		elif leaving and t.queue.is_empty() and not t.is_moving():
			_hide(t)
			left.emit(t)


func entry_point() -> Vector3:
	return lot.cell_to_world(Vector2i(lot.size.x / 2 - 1, lot.size.y - 1))


## Brings a townie onto the lot until `leave_minute` (INF: until sent home).
func bring(t: Sim, leave_minute := INF, at: Variant = null) -> void:
	t.away = false
	t.visible = true
	t.lot = lot
	t.set_meta("leaving", false)
	t.global_position = at if at != null else entry_point()
	for n in Needs.ORDER:
		t.needs.set_value(n, _rng.randf_range(60.0, 90.0))
	t.needs.set_value("social", 35.0)
	_leave_at[t] = leave_minute
	if not lot.sims.has(t):
		lot.sims.append(t)


## A guest invited by phone: arrives soon and stays a few hours.
func invite(t: Sim) -> void:
	if not t.away:
		return
	bring(t, Clock.total_minutes + VISIT_MINUTES)
	arrived.emit(t)


## A few townies are around when the household arrives at a community lot.
func populate(count: int, spots: Array) -> void:
	var pool := townies.duplicate()
	pool.shuffle()
	for i in mini(count, pool.size()):
		bring(pool[i], INF, spots[i % spots.size()])


## Sends one townie away straight away.
func send_home(t: Sim) -> void:
	if not t.away:
		_hide(t)


func send_all_home() -> void:
	for t in townies:
		if not t.away:
			_hide(t)


func _hide(t: Sim) -> void:
	t.clear_queue()
	t.away = true
	t.visible = false
	_leave_at.erase(t)
	lot.sims.erase(t)


func to_dict() -> Array:
	return townies.map(func(t: Sim): return t.to_dict())


## `full`: `data` is every townie (older saves only stored the neighbour).
func from_dict(data: Array, everyone: Array, full := true) -> void:
	if data.is_empty():
		return
	var names := data.map(func(d): return d.get("name", ""))
	# Townies who passed away (or moved in) since the game began are gone; newcomers
	# who arrived since are recreated.
	if full:
		for t in townies.duplicate():
			if not names.has(t.sim_name):
				remove_townie(t)
				t.queue_free()
	for d in data:
		var found: Sim = null
		for t in townies:
			if t.sim_name == d.get("name", ""):
				found = t
		if found == null:
			found = _make_townie(d.get("name", "Newcomer"))
		found.from_dict(d, everyone)
		_hide(found)
	# Couples where one of them is a newcomer.
	for d in data:
		var sp: String = d.get("spouse", "")
		if sp == "":
			continue
		for t in townies:
			if t.sim_name == d.get("name", "") and t.spouse == null:
				for o in townies:
					if o.sim_name == sp:
						t.spouse = o
