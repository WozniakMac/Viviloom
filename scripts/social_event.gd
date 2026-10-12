class_name SocialEvent
extends Node
## A social event like the reference's (House Party, Dinner Party): guests are
## invited for a few hours, a goal list sits at the top of the screen, and when
## time runs out the event earns a bronze, silver or gold medal with rewards.

signal changed
signal finished(medal: int, title: String)

const DURATION := 180.0
const MEDALS: Array[String] = ["No Medal", "Bronze", "Silver", "Gold"]
const REWARD: Array[int] = [0, 150, 350, 700]

## kind -> [title, [[goal text, activity names (empty = any social), count]...]]
const KINDS := {
	"house_party": ["House Party", [
		["Socialize with the guests", [], 8],
		["Dance or play some music", ["Dance", "Practise Guitar", "Play for Tips", "Practise Piano"], 1],
		["Have a drink or a bite to eat", ["Order a Drink", "Mix a Drink", "Grab a Serving", "Grab a Snack", "Have a Proper Meal"], 2],
		["Tell a joke", ["Tell a Joke", "Do an Impression", "Make Funny Face"], 1],
	]],
	"date": ["Date", [
		["Flirt with your date", ["Flirt"], 2],
		["Share a kiss", ["Kiss", "Make Out"], 1],
		["Eat or drink together", ["Have a Proper Meal", "Grab a Serving", "Order a Drink", "Mix a Drink"], 1],
		["Have a deep conversation", ["Deep Conversation"], 1],
	]],
	"dinner_party": ["Dinner Party", [
		["Cook a group meal", ["Cook..."], 1],
		["Eat together at the table", ["Have a Proper Meal"], 2],
		["Chat with the guests", [], 5],
		["Have a deep conversation", ["Deep Conversation"], 1],
	]],
}

var kind := ""
var title := ""
var ends_at := 0.0
var goals: Array = []
var guests: Array[Sim] = []
var active := false


func start(p_kind: String, household: Array, visitors: Visitors) -> void:
	kind = p_kind
	title = KINDS[kind][0]
	goals = []
	for g in KINDS[kind][1]:
		goals.append({"text": g[0], "names": g[1], "need": g[2], "done": 0})
	ends_at = Clock.total_minutes + DURATION
	active = true
	guests.clear()
	var pool: Array = visitors.townies.filter(func(t: Sim): return t.away and Ages.is_adult(t.age_stage))
	pool.shuffle()
	var count := 3
	if kind == "date":
		# The townie the host likes most romantically comes alone.
		var host: Sim = household[0]
		pool.sort_custom(func(a: Sim, b: Sim): return host.romance_with(a) > host.romance_with(b))
		count = 1
	for t in pool.slice(0, count):
		visitors.bring(t, ends_at)
		guests.append(t)
	for m in household:
		var s := m as Sim
		if not s.activity_done.is_connected(_on_activity):
			s.activity_done.connect(_on_activity)
	changed.emit()


func _on_activity(activity: String) -> void:
	if not active:
		return
	var is_social := Socials.find(activity) != null
	for g in goals:
		var names: Array = g["names"]
		var hit: bool = (names.is_empty() and is_social) or names.has(activity) or (names.has("Cook...") and activity.begins_with("Cook "))
		if hit and g["done"] < g["need"]:
			g["done"] += 1
			if g["done"] == g["need"]:
				Sfx.play("level_up", -6.0)
			changed.emit()


func goals_met() -> int:
	return goals.filter(func(g): return g["done"] >= g["need"]).size()


## 0 none, 1 bronze, 2 silver, 3 gold: two goals for bronze, three silver, all gold.
func medal() -> int:
	var n := goals_met()
	if n >= goals.size():
		return 3
	return clampi(n - 1, 0, 2)


func minutes_left() -> float:
	return maxf(0.0, ends_at - Clock.total_minutes)


func _process(_delta: float) -> void:
	if active and Clock.total_minutes >= ends_at:
		end()


func end() -> void:
	if not active:
		return
	active = false
	var m := medal()
	finished.emit(m, title)
	changed.emit()
