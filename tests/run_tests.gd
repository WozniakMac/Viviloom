extends Node
## Headless logic tests, run as a scene so autoloads exist:
##   Godot_console.exe --headless --path . res://tests/run_tests.tscn

var _failures := 0


func _ready() -> void:
	_test_path_avoids_obstacles()
	_test_unreachable_goal()
	_test_blocked_goal_snaps_to_neighbour()
	_test_needs_decay()
	_test_needs_activity_rates()
	_test_autonomy_prefers_urgent_need()
	_test_walls_and_doors()
	_test_placement_rules()
	_test_emotions_from_moodlets()
	_test_skills_level_up()
	_test_traits_and_skill_gain()
	_test_relationships()
	_test_career_day()
	_test_aspiration_goals()
	_test_clear_build()
	_test_daylight()
	_test_sim_round_trip()
	_test_new_objects()
	_test_finishes()
	_test_life_cycle()
	_test_messes()
	_test_repairs_and_fire()
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _make_lot() -> Lot:
	var lot := Lot.new()
	lot.size = Vector2i(16, 16)
	lot.setup()
	return lot


func _test_path_avoids_obstacles() -> void:
	var lot := _make_lot()
	lot.set_rect_blocked(Rect2i(6, 0, 1, 12), true)
	var from := lot.cell_to_world(Vector2i(2, 2))
	var to := lot.cell_to_world(Vector2i(10, 2))
	var path := lot.find_path(from, to)
	_check(not path.is_empty(), "path around wall exists")
	var prev := from
	for p in path:
		_check(lot.has_line_of_sight(prev, p), "segment %s -> %s is clear" % [prev, p])
		prev = p
	_check(prev.distance_to(to) < 0.01, "path ends at target")
	lot.free()


func _test_unreachable_goal() -> void:
	var lot := _make_lot()
	lot.set_rect_blocked(Rect2i(9, 9, 5, 1), true)
	lot.set_rect_blocked(Rect2i(9, 13, 5, 1), true)
	lot.set_rect_blocked(Rect2i(9, 10, 1, 3), true)
	lot.set_rect_blocked(Rect2i(13, 10, 1, 3), true)
	var path := lot.find_path(lot.cell_to_world(Vector2i(1, 1)), lot.cell_to_world(Vector2i(11, 11)))
	_check(path.is_empty(), "enclosed cell is unreachable")
	lot.free()


func _test_blocked_goal_snaps_to_neighbour() -> void:
	var lot := _make_lot()
	lot.set_blocked(Vector2i(5, 5), true)
	var path := lot.find_path(lot.cell_to_world(Vector2i(1, 1)), lot.cell_to_world(Vector2i(5, 5)))
	_check(not path.is_empty(), "clicking an obstacle walks next to it")
	if not path.is_empty():
		var end_cell := lot.world_to_cell(path[path.size() - 1])
		_check(end_cell != Vector2i(5, 5) and lot.is_walkable(end_cell), "ends on a free cell")
	lot.free()


func _test_needs_decay() -> void:
	var needs := Needs.new()
	needs.tick(60.0)
	_check(is_equal_approx(needs.get_value("hunger"), 80.0 - Needs.DECAY_PER_HOUR["hunger"]), "hunger decays per hour")
	needs.tick(60.0 * 100.0)
	_check(needs.get_value("bladder") == 0.0, "needs clamp at zero")
	_check(needs.mood() == "Miserable", "empty needs are miserable")


func _test_needs_activity_rates() -> void:
	var needs := Needs.new()
	needs.tick(30.0, {"hunger": 40.0})
	_check(is_equal_approx(needs.get_value("hunger"), 100.0), "eating rate restores hunger and clamps")
	_check(needs.get_value("fun") < 80.0, "other needs still decay")


func _test_autonomy_prefers_urgent_need() -> void:
	var needs := Needs.new()
	needs.set_value("bladder", 10.0)
	needs.set_value("fun", 60.0)
	var toilet := Interaction.new("Use Toilet", {"bladder": 350.0}, 20.0, "bladder")
	var tv := Interaction.new("Watch TV", {"fun": 35.0}, 240.0, "fun")
	_check(Autonomy.score(needs, toilet) > Autonomy.score(needs, tv), "nearly empty bladder beats moderate fun")
	needs.set_value("bladder", 95.0)
	_check(Autonomy.score(needs, toilet) == 0.0, "satisfied needs are not advertised")
	needs.set_value("bladder", 20.0)
	var urgent := Autonomy.urgent_needs(needs)
	_check(urgent == ["bladder"], "only low needs are urgent")
	_check(Autonomy.restores_any(toilet, urgent) and not Autonomy.restores_any(tv, urgent), "hobbies wait while a need is low")


func _test_walls_and_doors() -> void:
	var lot := _make_lot()
	# A full-width wall along line z = 8, splitting the lot in two.
	for e in Lot.wall_run(Vector2i(0, 8), Vector2i(16, 8)):
		lot.add_wall(e)
	var a := lot.cell_to_world(Vector2i(3, 3))
	var b := lot.cell_to_world(Vector2i(3, 12))
	_check(lot.find_path(a, b).is_empty(), "a solid wall cuts the lot in two")
	_check(lot.crosses_wall(a, b), "segment through the wall is detected")
	lot.add_door(Vector3i(10, 8, 0))
	var path := lot.find_path(a, b)
	_check(not path.is_empty(), "a door makes the other side reachable")
	var prev := a
	var through_door := false
	for p in path:
		_check(not lot.crosses_wall(prev, p), "path segments never pass through walls")
		if prev.z < 8.0 and p.z > 8.0:
			var x := lerpf(prev.x, p.x, (8.0 - prev.z) / (p.z - prev.z))
			through_door = x > 10.0 and x < 11.0
		prev = p
	_check(through_door, "path crosses the wall line at the door")
	var box := _make_lot()
	for r in [[Vector2i(2, 2), Vector2i(6, 2)], [Vector2i(2, 6), Vector2i(6, 6)], [Vector2i(2, 2), Vector2i(2, 6)], [Vector2i(6, 2), Vector2i(6, 6)]]:
		for e in Lot.wall_run(r[0], r[1]):
			box.add_wall(e)
	box.add_door(Vector3i(3, 6, 0))
	_check(box.is_indoors(Vector2i(4, 4)), "tiles inside four walls are indoors")
	_check(not box.is_indoors(Vector2i(8, 8)), "tiles outside are not")
	box.free()
	lot.free()


func _test_placement_rules() -> void:
	var lot := _make_lot()
	var bed := Furniture.new()
	bed.footprint = Vector2i(2, 2)
	_check(lot.can_place(bed, Vector2i(2, 2), 0), "free area accepts a bed")
	lot.add_wall(Vector3i(3, 2, 1))
	_check(not lot.can_place(bed, Vector2i(2, 2), 0), "objects cannot straddle a wall")
	_check(not lot.can_place(bed, Vector2i(15, 2), 0), "objects must stay inside the lot")
	lot.place_furniture(bed, Vector2i(6, 6), 0)
	_check(not lot.is_walkable(Vector2i(7, 7)), "placed objects block their tiles")
	_check(not lot.add_wall(Vector3i(7, 6, 1)), "walls cannot cut through an object")
	lot.remove_furniture(bed)
	_check(lot.is_walkable(Vector2i(7, 7)), "removing frees the tiles")
	bed.free()
	lot.free()


func _test_emotions_from_moodlets() -> void:
	var e := Emotions.new()
	_check(e.mood() == Emotions.FINE, "no moodlets means fine")
	e.add("a", "happy", 1, "A")
	e.add("b", "inspired", 2, "B", "", 60.0)
	_check(e.mood() == "inspired", "strongest emotion wins")
	e.add("c", "inspired", 1, "C")
	_check(e.mood_label() == "Very Inspired", "a total of 3 is 'very'")
	e.add("b", "inspired", 2, "B", "", 30.0)
	_check(e.moodlets.size() == 3, "same id refreshes instead of stacking")
	e.tick(31.0)
	_check(not e.has("b") and e.mood() == "happy", "timed moodlets expire and mood updates")
	var needs := Needs.new()
	needs.set_value("hunger", 10.0)
	e.sync_needs(needs)
	_check(e.has("need_starving") and not e.has("need_hungry"), "very low hunger gives only the strong moodlet")
	needs.set_value("hunger", 25.0)
	e.sync_needs(needs)
	_check(e.has("need_hungry") and not e.has("need_starving"), "moodlet follows the need back up")
	needs.set_value("hunger", 90.0)
	e.sync_needs(needs)
	_check(not e.has("need_hungry"), "full need clears its moodlet")


func _test_skills_level_up() -> void:
	var s := Skills.new()
	var ups: Array = []
	s.leveled_up.connect(func(sk, l): ups.append([sk, l]))
	_check(s.known().is_empty() and s.level("painting") == 0, "skills start unknown at level 0")
	s.add_xp("painting", Skills.xp_for_level(2) + 1.0)
	_check(s.level("painting") == 2 and ups.size() == 1, "levels come from total experience")
	s.add_xp("painting", 1e9)
	_check(s.level("painting") == Skills.MAX_LEVEL and s.progress("painting") == 1.0, "experience caps at max level")
	_check(s.known() == ["painting"], "only practised skills are listed")


func _test_traits_and_skill_gain() -> void:
	var current: Array[String] = ["cheerful"]
	_check(not Traits.can_add(current, "gloomy"), "cheerful and gloomy conflict")
	_check(Traits.can_add(current, "creative"), "unrelated traits combine")
	var sim := Sim.new()
	var t: Array[String] = ["creative"]
	sim.set_traits(t)
	var paint: Interaction = Interaction.new("Paint", {"fun": 25.0}, 180.0).practices("painting", 60.0)
	_check(is_equal_approx(sim.skill_gain(paint, 60.0), 90.0), "creative paints 1.5x faster")
	sim.emotions.add("x", "inspired", 2, "X")
	_check(is_equal_approx(sim.skill_gain(paint, 60.0), 135.0), "being inspired speeds painting further")
	var cheerful: Array[String] = ["cheerful"]
	sim.set_traits(cheerful)
	_check(sim.emotions.has("trait_cheerful") and not sim.emotions.has("trait_creative"), "lasting trait moodlets follow traits")
	sim.free()


func _test_relationships() -> void:
	var a := Sim.new()
	var b := Sim.new()
	a.change_relationship(b, 25.0, 0.0)
	_check(a.friendship_with(b) == 25.0 and b.friendship_with(a) == 25.0, "relationships are shared both ways")
	_check(a.relationship_label(b) == "Acquaintance", "25 friendship is an acquaintance")
	a.change_relationship(b, 500.0, 40.0)
	_check(a.friendship_with(b) == 100.0 and a.relationship_label(b) == "Romantic Interest", "friendship caps and romance shows")
	var flirt := Socials.find("Flirt")
	var no_traits: Array[String] = []
	_check(Socials.success_chance(flirt, 5.0, 0.0, "fine", no_traits) == 0.0, "flirting with a stranger is turned down")
	_check(Socials.success_chance(flirt, 40.0, 0.0, "fine", no_traits) == 1.0, "friends accept a flirt")
	var joke := Socials.find("Tell a Joke")
	_check(Socials.success_chance(joke, 0.0, 0.0, "playful", no_traits) > Socials.success_chance(joke, 0.0, 0.0, "fine", no_traits), "playful Sims tell better jokes")
	a.free()
	b.free()


func _test_career_day() -> void:
	var sim := Sim.new()
	var w := Work.new()
	w.sim = sim
	w.join("tech")
	_check(w.has_job() and w.level == 0, "joining starts at level 1")
	var pay: Array = []
	w.paid.connect(func(a): pay.append(a))
	w._mood_at_start = "focused"
	w._finish_shift()
	_check(pay == [Careers.hourly("tech", 0) * Careers.shift_hours("tech")], "a shift pays hourly wage times hours")
	_check(w.performance == Careers.shift_performance("focused", 0) and w.performance > Careers.shift_performance("sad", 0), "good moods help performance")
	w.performance = 100.0
	w._try_promotion()
	_check(w.level == 0, "no promotion without the skill")
	sim.skills.add_xp("logic", Skills.xp_for_level(2))
	w._try_promotion()
	_check(w.level == 1 and sim.emotions.has("promoted"), "full performance and skill earn a promotion")
	w.free()
	sim.free()


func _test_aspiration_goals() -> void:
	var sim := Sim.new()
	var ctx := {"sim": sim, "funds": 30000, "career_level": 0}
	_check(Aspirations.goal_met({"funds": 25000}, ctx), "funds goal checks household money")
	_check(not Aspirations.goal_met({"career_level": 1}, ctx), "career goal needs a job")
	_check(not Aspirations.goal_met({"any_skills": 2, "count": 2}, ctx), "skill goals start unmet")
	sim.skills.add_xp("painting", Skills.xp_for_level(2))
	sim.skills.add_xp("logic", Skills.xp_for_level(2))
	_check(Aspirations.goal_met({"any_skills": 2, "count": 2}, ctx), "two skills at level 2 meet the goal")
	sim.count_stat("paintings_sold", 3)
	_check(Aspirations.goal_met({"stat": "paintings_sold", "count": 3}, ctx), "stat goals count activities")
	var t: Array[String] = ["creative"]
	sim.set_traits(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var paint := 0
	for i in 200:
		if Aspirations.roll_want(sim, [], rng)[0] == "paint":
			paint += 1
	_check(paint > 200 / Aspirations.WANTS.size(), "creative Sims want to paint more often")
	sim.free()


func _test_clear_build() -> void:
	var lot := _make_lot()
	for e in Lot.wall_run(Vector2i(2, 2), Vector2i(8, 2)):
		lot.add_wall(e)
	lot.add_block(Rect2i(10, 10, 2, 1), 1.0, Color.GREEN)
	var bed := Catalog.create("bed")
	lot.place_furniture(bed, Vector2i(4, 4), 0)
	lot.clear_build()
	_check(lot.walls.is_empty() and lot.furniture.is_empty(), "clearing removes walls and objects")
	_check(lot.is_walkable(Vector2i(10, 10)) and lot.is_walkable(Vector2i(4, 4)), "cleared tiles are walkable again")
	lot.free()


func _test_daylight() -> void:
	_check(Daylight.sun_height(13.0) > 0.9, "the sun is high around 1 PM")
	_check(not Daylight.is_dark(18.5), "evenings stay light until sunset")
	_check(Daylight.is_dark(22.0) and Daylight.is_dark(3.0), "nights are dark")
	_check(Daylight.sun_height(20.0) < 0.05 and Daylight.sun_height(6.0) < 0.05, "sunrise and sunset sit on the horizon")


func _test_sim_round_trip() -> void:
	var a := Sim.new()
	var b := Sim.new()
	b.sim_name = "Jules"
	a.sim_name = "Ada"
	var t: Array[String] = ["genius", "lazy"]
	a.set_traits(t)
	a.aspiration = "wealthy"
	a.needs.set_value("hunger", 33.0)
	a.skills.add_xp("logic", 300.0)
	a.emotions.add("fresh", "happy", 1, "Freshly Showered", "", 90.0)
	a.count_stat("jokes", 2)
	a.change_relationship(b, 42.0, 10.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var c := Sim.new()
	c.from_dict(data, [b])
	_check(c.sim_name == "Ada" and c.traits == t and c.aspiration == "wealthy", "identity survives saving")
	_check(is_equal_approx(c.needs.get_value("hunger"), 33.0) and c.skills.level("logic") == a.skills.level("logic"), "needs and skills survive saving")
	_check(c.emotions.has("fresh") and c.emotions.has("trait_genius") == a.emotions.has("trait_genius"), "moodlets survive saving")
	_check(c.stats.get("jokes", 0) == 2 and is_equal_approx(c.friendship_with(b), 42.0), "stats and relationships survive saving")
	a.free()
	b.free()
	c.free()


func _test_new_objects() -> void:
	var lot := _make_lot()
	for kind in Catalog.KINDS:
		var f := Catalog.create(kind)
		_check(f.display_name != "" and f.price > 0, "%s has a name and price" % kind)
		f.free()
	var sofa := Catalog.create("sofa")
	_check(lot.can_place(sofa, Vector2i(2, 2), 0) and not lot.can_place(sofa, Vector2i(14, 2), 0), "a 3-wide sofa must fit inside the lot")
	sofa.free()
	_check(Bills.amount_for(5000) > Bills.amount_for(1000), "pricier homes get bigger bills")
	lot.free()


func _test_finishes() -> void:
	var lot := _make_lot()
	for e in Lot.wall_run(Vector2i(0, 8), Vector2i(16, 8)):
		lot.add_wall(e)
	var e := Vector3i(4, 8, 0)
	_check(lot.add_window(e) and lot.windows.has(e), "windows go on walls")
	_check(not lot.add_window(Vector3i(4, 3, 0)), "no window without a wall")
	lot.add_door(e)
	_check(lot.doors.has(e) and not lot.windows.has(e), "a door replaces a window")
	_check(lot.find_path(lot.cell_to_world(Vector2i(4, 2)), lot.cell_to_world(Vector2i(4, 12))).size() > 0, "the door still lets Sims through")
	lot.add_window(Vector3i(6, 8, 0))
	_check(lot.find_path(lot.cell_to_world(Vector2i(6, 7)), lot.cell_to_world(Vector2i(6, 9))).size() > 2, "windows don't let Sims through")
	_check(lot.paint_wall(Vector3i(6, 8, 0), 3) and lot.wall_styles[Vector3i(6, 8, 0)] == 3, "walls take paint")
	lot.add_floor(Rect2i(1, 1, 3, 2), 2)
	_check(lot.floor_tiles.size() == 6 and lot.floor_tiles[Vector2i(2, 2)] == 2, "floors cover their rectangle")
	lot.clear_build()
	_check(lot.floor_tiles.is_empty() and lot.windows.is_empty() and lot.wall_styles.is_empty(), "clearing removes finishes")
	lot.free()


func _test_life_cycle() -> void:
	var life := LifeCycle.new()
	add_child(life)
	var kid := Sim.new()
	kid.age_stage = "child"
	var w := Work.new()
	w.sim = kid
	add_child(w)
	life.household = [kid] as Array[Sim]
	life.works = {kid: w}
	life.enrol(kid)
	_check(w.career == "school", "children go to grade school")
	for i in Ages.INFO["child"]["days"]:
		life.new_day()
	_check(kid.age_stage == "teen" and w.career == "high_school" and kid.emotions.has("birthday"), "a birthday makes a child a teen who goes to high school")
	var mom := Sim.new()
	var dad := Sim.new()
	life.household = [mom, dad] as Array[Sim]
	life._rng.seed = 1
	var babies: Array = []
	life.born.connect(func(b, _p): babies.append(b))
	for i in 20:
		life.try_for_baby(mom, dad)
	_check(mom.pregnant_days == 0, "trying for a baby can lead to a pregnancy")
	life.aging_enabled = false
	for i in LifeCycle.PREGNANCY_DAYS:
		life.new_day()
	_check(babies.size() == 1 and babies[0].age_stage == "toddler" and mom.pregnant_days == -1, "a toddler arrives after the pregnancy")
	var gran := Sim.new()
	gran.age_stage = "elder"
	gran.age_days = Ages.INFO["elder"]["days"] - 1
	life.household = [gran, mom] as Array[Sim]
	life.aging_enabled = true
	var gone: Array = []
	life.passed_away.connect(func(s): gone.append(s))
	life.new_day()
	_check(gone == [gran] and mom.emotions.has("mourning"), "elders pass on and are mourned")
	_check(not Ages.romance_ok("child", "adult") and Ages.romance_ok("adult", "elder"), "romance is for grown-ups")
	for s in [kid, mom, dad, gran] + babies:
		s.free()
	w.free()
	life.free()


func _test_messes() -> void:
	var lot := _make_lot()
	add_child(lot)
	var sim := Sim.new()
	sim.lot = lot
	add_child(sim)
	sim.global_position = lot.cell_to_world(Vector2i(5, 5))
	var dishes := lot.add_mess("dishes", sim.global_position)
	_check(lot.messes().size() == 1 and lot.is_walkable(Vector2i(5, 5)), "dishes sit on a tile without blocking it")
	sim.needs.set_value("bladder", 0.0)
	sim._check_limits()
	_check(lot.messes().size() == 2 and sim.emotions.has("accident") and sim.needs.get_value("bladder") == 100.0, "an empty bladder leaves a puddle")
	sim.needs.set_value("energy", 0.0)
	sim._check_limits()
	_check(sim._passed_out > 0.0 and sim.emotions.has("passed_out"), "zero energy means passing out")
	var salad := Catalog.create("counter")
	_check(salad.interactions[0].leaves_mess == "dishes" and dishes.interactions[0].consumes, "meals leave dishes and cleaning removes them")
	salad.free()
	sim.queue_free()
	lot.queue_free()


func _test_repairs_and_fire() -> void:
	var tv := Catalog.create("tv")
	_check(tv.available_interactions() == tv.interactions, "working objects offer their usual interactions")
	tv.set_broken(true)
	var offered := tv.available_interactions()
	_check(offered.size() == 1 and offered[0].fixes and offered[0].skill == "handiness", "broken objects can only be repaired")
	tv.set_broken(false)
	_check(not tv.broken, "repairing fixes it")
	tv.free()
	var fire := Catalog.create("fire")
	_check(not fire.blocks and fire.interactions[0].consumes, "fires can be put out")
	fire.free()
