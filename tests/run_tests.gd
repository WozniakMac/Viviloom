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
	_test_moods_and_rewards()
	_test_pools()
	_test_upper_floor()
	_test_outfits()
	_test_more_traits()
	_test_swatches()
	_test_fences()
	_test_romance()
	_test_room_and_roof()
	_test_new_skills()
	_test_lot_traits()
	_test_career_tasks()
	_test_walk_styles()
	_test_story()
	_test_toddler_parenting()
	_test_new_furniture()
	_test_townie_lives()
	_test_child_skills()
	_test_foundation()
	_test_terrain()
	_test_townie_babies()
	_test_fence_styles()
	_test_gardening()
	_test_produce_quality()
	_test_options_and_achievements()
	_test_save_slots()
	_test_lunar_cycle()
	_test_room_presets_and_undo()
	_test_sticky_outfits()
	_test_social_events()
	_test_date_event()
	_test_burglars()
	_test_bed_assign_and_upgrade()
	_test_dirty_fixtures()
	_test_everyday_objects()
	_test_counter_tops()
	_test_surface_decor()
	_test_more_aspirations()
	_test_trait_batch_two()
	_test_likes_dislikes()
	_test_birthday_cake()
	_test_trait_batch_three()
	_test_jealousy()
	_test_family_ties()
	_test_wider_family()
	_test_paintings()
	_test_cooking()
	_test_kids()
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
	sim.skills.add_xp(Careers.INFO["tech"]["skill"], Skills.xp_for_level(2))
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
	_check(tv.available_interactions().slice(0, tv.interactions.size()) == tv.interactions, "working objects offer their usual interactions (plus Upgrade)")
	tv.set_broken(true)
	var offered := tv.available_interactions()
	_check(offered.size() == 1 and offered[0].fixes and offered[0].skill == "handiness", "broken objects can only be repaired")
	tv.set_broken(false)
	_check(not tv.broken, "repairing fixes it")
	tv.free()
	var fire := Catalog.create("fire")
	_check(not fire.blocks and fire.interactions[0].consumes, "fires can be put out")
	fire.free()


func _test_moods_and_rewards() -> void:
	var a := Sim.new()
	var b := Sim.new()
	var none: Array = Socials.available(30.0, 0.0, "adult", "adult", "fine", "fine").filter(func(i): return i.name == "Cheer Up")
	_check(none.is_empty(), "Cheer Up only shows for sad Sims")
	var cheer: Array = Socials.available(30.0, 0.0, "adult", "adult", "fine", "sad").filter(func(i): return i.name == "Cheer Up")
	_check(cheer.size() == 1, "Cheer Up shows when the other Sim is sad")
	b.emotions.add("down", "sad", 3, "Down", "", 300.0)
	b.emotions.clear_emotion("sad")
	_check(b.emotions.mood() == Emotions.FINE, "clearing an emotion removes its moodlets")
	var bed := Catalog.create("bed")
	var cry: Interaction = bed.interactions.filter(func(i): return i.name == "Cry It Out")[0]
	_check(not Ages.allows_for(a, cry), "crying isn't offered when not sad")
	a.emotions.add("down", "sad", 2, "Down", "", 300.0)
	_check(Ages.allows_for(a, cry) and cry.clears_emotion == "sad", "sad Sims can cry it out")
	bed.free()
	var t := AspirationTracker.new()
	t.sim = a
	t.satisfaction = 1600
	Rewards.buy("fast_learner", a, t)
	var paint: Interaction = Interaction.new("Paint", {}, 60.0).practices("painting", 60.0)
	a.emotions.clear_emotion("sad")
	_check(a.perks.has("fast_learner") and t.satisfaction == 100 and is_equal_approx(a.skill_gain(paint, 60.0), 75.0), "Fast Learner costs points and speeds up skills")
	_check(Rewards.buy("fast_learner", a, t).contains("already"), "perks can't be bought twice")
	t.free()
	a.free()
	b.free()


func _test_pools() -> void:
	var lot := _make_lot()
	var pool := lot.add_pool(Rect2i(4, 4, 4, 3))
	_check(pool != null and lot.is_pool(Vector2i(5, 5)) and not lot.is_walkable(Vector2i(5, 5)), "pools can't be walked on")
	_check(lot.add_pool(Rect2i(6, 5, 3, 3)) == null, "pools can't overlap")
	_check(pool.interactions[0].name == "Swim" and pool.interactions[0].pose == "swim", "pools are for swimming")
	var reachable := 0
	for s in pool.spots:
		# The lot isn't in the scene tree here, so use the local transform.
		if lot.is_walkable(lot.world_to_cell(pool.transform * s)):
			reachable += 1
	_check(reachable == 4, "every side of the pool can be reached")
	lot.remove_pool(pool)
	_check(lot.pools.is_empty() and lot.is_walkable(Vector2i(5, 5)), "removing a pool fills it in")
	lot.free()


func _test_upper_floor() -> void:
	var up := Lot.new()
	up.level = 1
	up.size = Vector2i(16, 16)
	up.setup()
	_check(not up.is_walkable(Vector2i(3, 3)), "upper floors are only walkable where there's floor")
	up.add_floor(Rect2i(2, 2, 6, 6), 0)
	_check(up.is_walkable(Vector2i(3, 3)) and is_equal_approx(up.cell_to_world(Vector2i(3, 3)).y, Lot.WALL_HEIGHT), "floor upstairs can be walked on, one storey up")
	_check(not up.find_path(up.cell_to_world(Vector2i(2, 2)), up.cell_to_world(Vector2i(7, 7))).is_empty(), "Sims can walk across an upper floor")
	_check(up.find_path(up.cell_to_world(Vector2i(2, 2)), up.cell_to_world(Vector2i(12, 12))).size() <= 1 or not up.is_walkable(Vector2i(12, 12)), "they can't walk off the edge")
	up.clear_floor(Rect2i(4, 4, 1, 3))
	_check(not up.is_walkable(Vector2i(4, 5)), "a stairwell removes the floor")
	var stairs := Catalog.create("stairs")
	_check(stairs.footprint == Vector2i(1, 3) and stairs.interactions.is_empty(), "stairs take a 1x3 space")
	stairs.free()
	up.free()


func _test_outfits() -> void:
	var s := Sim.new()
	add_child(s)
	s.set_part_color("shirt", Color.RED)
	_check(s.outfits["everyday"]["shirt"] == Color.RED, "everyday colours are remembered")
	s.change_outfit("sleep", false)
	_check(s.outfit == "sleep" and s.long_sleeves and s.shirt_color != Color.RED, "sleepwear is a different outfit")
	s.change_outfit("everyday", false)
	_check(s.shirt_color == Color.RED, "changing back restores the everyday clothes")
	var bed := Catalog.create("bed")
	var sleep: Interaction = bed.interactions.filter(func(i): return i.name == "Sleep")[0]
	_check(Sim.outfit_for(sleep) == "sleep", "Sims sleep in sleepwear")
	var tm := Catalog.create("treadmill")
	_check(Sim.outfit_for(tm.interactions[0]) == "athletic", "Sims jog in athletic wear")
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := Sim.new()
	add_child(t)
	t.from_dict(data, [])
	_check(t.outfits["everyday"]["shirt"].is_equal_approx(Color.RED), "outfits are saved")
	bed.free()
	tm.free()
	s.queue_free()
	t.queue_free()


func _test_more_traits() -> void:
	var neat: Array[String] = ["neat"]
	_check(not Traits.can_add(neat, "slob"), "neat and slob conflict")
	var romantic: Array[String] = ["romantic"]
	_check(Traits.liking(romantic, "", Socials.find("Flirt")) > Traits.liking(romantic, "", Socials.find("Chat")), "romantics prefer flirting")
	var loner: Array[String] = ["loner"]
	_check(Traits.liking(loner, "", Socials.find("Chat")) < 1.0 and Traits.decay_mult(loner)["social"] < 1.0, "loners need less company")
	var foodie: Array[String] = ["foodie"]
	_check(Traits.skill_mult(foodie, "cooking") > 1.0, "foodies learn cooking faster")
	for t in Traits.ORDER:
		_check(TraitHex.TRAIT_COLORS.has(t), "trait %s has a colour" % t)


func _test_swatches() -> void:
	var sofa := Catalog.create("sofa")
	var cols := sofa.swatch_colors()
	_check(cols.size() == 6, "sofas come in six colours")
	sofa.set_variant(2)
	_check(sofa.variant == 2, "a colour can be picked")
	var other := Catalog.create("sofa")
	_check(other.swatch_colors()[0] == cols[0], "recolouring one sofa leaves others alone")
	sofa.free()
	other.free()


func _test_paintings() -> void:
	var lot := _make_lot()
	for e in Lot.wall_run(Vector2i(0, 4), Vector2i(10, 4)):
		lot.add_wall(e)
	var art := Catalog.make_painting({"seed": 5, "quality": 2, "value": 150})
	_check(art.wall_mounted and art.price == 150, "paintings hang on walls and are worth their value")
	_check(lot.can_hang(art, Vector2i(3, 4), 0), "a painting can hang on a plain wall")
	_check(not lot.can_hang(art, Vector2i(3, 6), 0), "not where there is no wall")
	lot.place_furniture(art, Vector2i(3, 4), 0)
	_check(lot.is_walkable(Vector2i(3, 4)), "hanging art doesn't block the floor")
	var other := Catalog.make_painting({"seed": 6})
	_check(not lot.can_hang(other, Vector2i(3, 4), 0), "one painting per spot")
	lot.remove_wall(Vector3i(3, 4, 0))
	_check(not lot.furniture.has(art), "knocking the wall down takes the painting with it")
	var s := Sim.new()
	s.inventory.append({"kind": "painting", "seed": 1, "quality": 1, "value": 80})
	var paid: Array = []
	s.earned.connect(func(a): paid.append(a))
	s.sell_item(0)
	_check(paid == [80] and s.inventory.is_empty() and s.stats.get("paintings_sold", 0) == 1, "selling a painting pays its value")
	s.free()
	other.free()
	lot.free()


func _test_cooking() -> void:
	var stove := Catalog.create("stove")
	var names: Array = stove.interactions.map(func(i): return i.name)
	_check(names.has("Cook Mac and Cheese") and names.has("Cook Baked Alaska"), "the stove can cook every recipe")
	var a := Sim.new()
	var alaska: Interaction = stove.interactions.filter(func(i): return i.recipe == "Baked Alaska")[0]
	var grilled: Interaction = stove.interactions.filter(func(i): return i.recipe == "Grilled Cheese")[0]
	_check(not Ages.allows_for(a, alaska) and Ages.allows_for(a, grilled), "fancy recipes need Cooking skill")
	_check(Autonomy.advertised(grilled).get("hunger", 0.0) > 0.0, "hungry Sims will think of cooking")
	var meal := Catalog.make_meal("Spaghetti", 3)
	_check(meal.get_meta("servings") == 6 and meal.interactions[0].moodlet[0] == "great_food", "an excellent meal serves six and tastes great")
	var bad := Catalog.make_meal("Spaghetti", 0)
	_check(bad.interactions[0].moodlet[1] == "uncomfortable", "burnt food is unpleasant")
	meal.free()
	bad.free()
	stove.free()
	a.free()


func _test_kids() -> void:
	var kid := Sim.new()
	kid.age_stage = "child"
	var desk := Catalog.create("desk")
	var hw: Interaction = desk.interactions.filter(func(i): return i.name == "Do Homework")[0]
	_check(not Ages.allows_for(kid, hw), "no homework, nothing to do")
	kid.inventory.append({"kind": "homework"})
	_check(Ages.allows_for(kid, hw), "kids with homework can do it at a desk")
	var done: Array = []
	kid.homework_done.connect(func(): done.append(1))
	kid._reward(hw, 999.0, true)
	_check(kid.inventory.is_empty() and done.size() == 1, "finishing homework uses it up and raises the grade")
	var toys := Catalog.create("toybox")
	_check(Ages.allows("toddler", toys.interactions[0]), "toddlers can play with toys")
	toys.free()
	desk.free()
	kid.free()


func _test_fences() -> void:
	var lot := _make_lot()
	for e in Lot.wall_run(Vector2i(0, 4), Vector2i(lot.size.x, 4)):
		lot.add_fence(e)
	_check(lot.fences.size() == lot.size.x, "a fence runs the width of the lot")
	_check(not lot.can_step(Vector2i(2, 3), Vector2i(2, 4)), "fences block walking")
	_check(lot.find_path(lot.cell_to_world(Vector2i(2, 2)), lot.cell_to_world(Vector2i(2, 6))).is_empty(), "no way round a full fence")
	_check(not lot.add_wall(Vector3i(5, 4, 0)), "no wall on top of a fence")
	lot.add_gate(Vector3i(5, 4, 0))
	_check(lot.can_step(Vector2i(5, 3), Vector2i(5, 4)), "gates let Sims through")
	_check(not lot.find_path(lot.cell_to_world(Vector2i(2, 2)), lot.cell_to_world(Vector2i(2, 6))).is_empty(), "the path goes through the gate")
	_check(not lot.is_indoors(Vector2i(2, 2)), "fenced yards are not rooms")
	lot.remove_fence(Vector3i(3, 4, 0))
	_check(lot.can_step(Vector2i(3, 3), Vector2i(3, 4)), "a removed fence no longer blocks")


func _names(list: Array) -> Array:
	return list.map(func(i): return i.name)


func _test_romance() -> void:
	var cats := {}
	for i in Socials.all():
		cats[i.social["category"]] = true
	_check(cats.size() == 6, "socials come in Friendly, Funny, Romance, Mischief, Mean and Parenting")
	var single := _names(Socials.available(50.0, 55.0, "adult", "adult"))
	_check(single.has("Ask to Be Partner") and not single.has("Propose") and not single.has("Break Up"), "ask to go steady before proposing")
	var steady := _names(Socials.available(50.0, 80.0, "adult", "adult", "fine", "fine", "partner"))
	_check(steady.has("Propose") and steady.has("Break Up") and not steady.has("Ask to Be Partner"), "partners can propose or break up")
	_check(not _names(Socials.available(50.0, 80.0, "child", "child")).has("Make Out"), "no romance for children")
	var a := Sim.new()
	var b := Sim.new()
	a.sim_name = "Ana"
	b.sim_name = "Ben"
	a.change_relationship(b, 50.0, 50.0)
	var act := Sim.SimAction.new()
	act.target_sim = b
	act.interaction = Socials.find("Ask to Be Partner")
	act.outcome = true
	act.elapsed = 999.0
	a._social_result(act)
	_check(a.partner == b and b.partner == a and a.relationship_label(b) in ["Boyfriend", "Girlfriend"], "going steady sets partners on both sides")
	_check(a.to_dict()["partner"] == "Ben", "partners are saved")
	act.interaction = Socials.find("Break Up")
	a._social_result(act)
	_check(a.partner == null and b.partner == null and b.emotions.mood() == "sad", "breaking up hurts")
	var bed := Catalog.create("bed")
	var woohoo: Array = bed.interactions.filter(func(i): return i.name == "WooHoo")
	_check(woohoo.size() == 1 and woohoo[0].with_partner, "beds offer WooHoo for couples")
	_check(not Ages.allows_for(a, woohoo[0]), "no WooHoo without someone special around")
	bed.free()
	a.free()
	b.free()


func _test_room_and_roof() -> void:
	var lot := _make_lot()
	add_child(lot)
	var build := BuildMode.new()
	build.lot = lot
	build.funds = 10000
	build.tool = BuildMode.Tool.ROOM
	build._wall_preview = MeshInstance3D.new()
	build._floor_start = Vector2i(2, 2)
	build._floor_end = Vector2i(5, 4)
	build._finish_room()
	_check(lot.walls.size() == 14, "the room tool walls in a 4x3 room in one drag")
	_check(build.funds == 10000 - 14 * Catalog.WALL_PRICE, "each room wall is paid for")
	lot._compute_interior()
	_check(lot.is_indoors(Vector2i(3, 3)), "the new room counts as indoors")
	for style in [Lot.RoofStyle.GABLE, Lot.RoofStyle.HIP, Lot.RoofStyle.FLAT]:
		lot.set_roof(style, 2)
		_check(lot._roof.mesh != null, "%s roofs are built" % Lot.ROOF_STYLE_NAMES[style])
	lot.set_roof(Lot.RoofStyle.NONE, 0)
	_check(lot._roof.mesh == null, "no roof at all is an option")
	build._wall_preview.free()
	build.free()
	lot.queue_free()


func _test_new_skills() -> void:
	for sk in ["comedy", "mischief", "mixology", "programming", "piano", "fishing"]:
		_check(Skills.ORDER.has(sk), "%s is a skill" % sk)
	_check(Socials.find("Tell a Joke").skill == "comedy" and Socials.find("Prank").skill == "mischief", "funny and mischievous socials train their skills")
	var a := Sim.new()
	var b := Sim.new()
	var act := Sim.SimAction.new()
	act.target_sim = b
	act.interaction = Socials.find("Tell a Joke")
	act.outcome = true
	act.elapsed = 999.0
	a._social_result(act)
	_check(a.skills.xp["comedy"] > 0.0, "telling jokes builds Comedy")
	var pond := Catalog.create("pond")
	_check(pond.interactions[0].creates == "fish", "ponds are for fishing")
	a._rng.seed = 3
	for k in 12:
		a._catch_fish(10)
	var fish := a.inventory.filter(func(it): return it.get("kind") == "fish")
	_check(not fish.is_empty() and fish[0].get("value", 0) > 0, "fishing lands fish worth Simoleons")
	a.sell_item(a.inventory.find(fish[0]))
	_check(a.inventory.size() == fish.size() - 1, "fish can be sold")
	for kind in ["piano", "telescope"]:
		var f := Catalog.create(kind)
		_check(not f.interactions.is_empty(), "%s has something to do" % kind)
		f.free()
	pond.free()
	a.free()
	b.free()


func _test_lot_traits() -> void:
	var t := ["chefs_kitchen", "gremlins"]
	_check(LotTraits.skill_mult(t, "cooking") == 1.5 and LotTraits.skill_mult(t, "logic") == 1.0, "Chef's Kitchen speeds up cooking only")
	_check(LotTraits.break_mult(t) > 1.0 and LotTraits.break_mult([]) == 1.0, "Gremlins break things more")
	_check(LotTraits.moodlets(["natural_light"], 12.0).size() == 1 and LotTraits.moodlets(["natural_light"], 22.0).is_empty(), "Natural Light only shines by day")
	var lot := _make_lot()
	add_child(lot)
	var s := Sim.new()
	s.lot = lot
	var cook := Interaction.new("Cook", {}, 60.0).practices("cooking", 60.0)
	var plain := s.skill_gain(cook, 60.0)
	lot.lot_traits = ["chefs_kitchen"]
	_check(is_equal_approx(s.skill_gain(cook, 60.0), plain * 1.5), "Sims learn faster on a lot with the right trait")
	lot.clear_build()
	_check(lot.lot_traits.is_empty(), "a cleared lot has no traits")
	s.free()
	lot.queue_free()


func _test_career_tasks() -> void:
	var sim := Sim.new()
	var w := Work.new()
	w.sim = sim
	w.join("culinary", true)
	_check(not w.daily_task_done(), "the daily task starts undone")
	sim.skills.add_xp("cooking", 50.0)
	_check(w.daily_task_done(), "practising the career skill completes the daily task")
	w._raise_event()
	var before := w.performance
	w.resolve_event(0)
	_check(w._event.is_empty() and w.performance >= before - 10.0, "work events resolve")
	# A skill-gated choice fails without the skill.
	w._event = Careers.EVENTS[3]
	w.performance = 50.0
	w.resolve_event(0)
	_check(w.performance == 45.0, "fixing the printer without Handiness backfires")
	w.free()
	sim.free()


func _test_walk_styles() -> void:
	var s := Sim.new()
	var base := s.move_speed()
	s.walk_style = "energetic"
	_check(s.move_speed() > base, "energetic Sims walk faster")
	s.walk_style = "lazy"
	_check(s.move_speed() < base, "lazy Sims dawdle")
	s.path = PackedVector3Array([Vector3(20, 0, 0)])
	s._path_index = 0
	_check(s._remaining_path() > Sim.JOG_DISTANCE, "long trips are measured for jogging")
	_check(s.to_dict().get("walk_style") == "lazy", "walk style is saved")
	s.free()


func _test_story() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var grandpa := {"sim": {"name": "Hal", "age": ["elder", 9, -1]}, "work": {"career": ""}}
	var mum := {"sim": {"name": "Ann", "age": ["adult", 0, -1], "spouse": "Bob"}, "work": {"career": "culinary", "level": 0, "performance": 95.0}}
	var dad := {"sim": {"name": "Bob", "age": ["adult", 0, -1], "spouse": "Ann"}, "work": {"career": ""}}
	var h := {"household": [mum, dad, grandpa], "funds": 1000, "home": "cottage"}
	var world := [h]
	var news := Story.advance_day(world, 1, rng)
	_check(h["household"].size() >= 2 and not h["household"].any(func(m): return m["sim"]["name"] == "Hal"), "elders pass away off-screen")
	_check(news.any(func(n): return "Hal" in n), "deaths make the neighbourhood news")
	_check(h["funds"] > 1000 and mum["work"]["level"] == 1, "working Sims earn and get promoted off-screen")
	var babies := 0
	for d in range(2, 60):
		Story.advance_day(world, d, rng)
		babies = h["household"].size()
	_check(world.is_empty() or babies >= 2, "households carry on (or end) over time")
	var lone := {"household": [{"sim": {"name": "Old", "age": ["elder", 50, -1]}, "work": {}}], "funds": 0}
	var w2 := [lone]
	Story.advance_day(w2, 1, rng)
	_check(w2.is_empty(), "a household with no one left is removed")


func _test_toddler_parenting() -> void:
	var to_toddler := _names(Socials.available(20.0, 0.0, "adult", "toddler"))
	_check(to_toddler.has("Teach to Talk") and to_toddler.has("Potty Train") and not to_toddler.has("Insult") and not to_toddler.has("Flirt"), "grown-ups get parenting socials for toddlers")
	var to_adult := _names(Socials.available(20.0, 0.0, "adult", "adult"))
	_check(not to_adult.has("Teach to Talk"), "no toddler teaching between adults")
	_check(_names(Socials.available(20.0, 0.0, "adult", "child")).has("Tell a Story"), "children love stories too")
	var mum := Sim.new()
	var kid := Sim.new()
	kid.age_stage = "toddler"
	var act := Sim.SimAction.new()
	act.target_sim = kid
	act.interaction = Socials.find("Teach to Talk")
	act.outcome = true
	act.elapsed = 999.0
	mum._social_result(act)
	_check(kid.skills.xp["communication"] > 0.0, "teaching builds the toddler's skill")
	var life := LifeCycle.new()
	for sk in Skills.TODDLER_SKILLS:
		kid.skills.add_xp(sk, Skills.xp_for_level(2))
	life.birthday(kid)
	_check(kid.perks.has("top_notch_toddler") and kid.age_stage == "child", "well-taught toddlers grow up top-notch")
	life.free()
	mum.free()
	kid.free()


func _test_new_furniture() -> void:
	for kind in ["single_bed", "armchair", "coffee_table", "end_table", "bathtub", "dollhouse", "activity_table", "rug", "sculpture"]:
		_check(Catalog.INFO.has(kind) and Catalog.CATEGORY_OF.has(kind) and Catalog.KINDS.has(kind), "%s is in the catalogue" % kind)
		var f := Catalog.create(kind)
		_check(f.display_name != "", "%s builds" % kind)
		f.free()
	var rug := Catalog.create("rug")
	_check(not rug.blocks and rug.decor > 0, "rugs decorate and can be walked on")
	rug.free()
	var bed := Catalog.create("single_bed")
	_check(bed.capacity() == 1 and bed.get_node_or_null("Covers") != null, "single beds sleep one under a duvet")
	bed.free()
	var art := Catalog.make_painting({"quality": 3, "value": 300})
	_check(art.decor == 4, "better paintings decorate more")
	art.free()


func _test_townie_lives() -> void:
	var lot := _make_lot()
	add_child(lot)
	var v := Visitors.new()
	add_child(v)
	v.setup(lot)
	var hank: Sim = v.townies.filter(func(t): return t.sim_name == "Hank")[0]
	hank.age_days = Ages.INFO["elder"]["days"] - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var count := v.townies.size()
	var news := v.new_day(rng)
	_check(not v.townies.has(hank) and v.townies.size() == count, "an old townie passes on and a newcomer arrives")
	_check(news.size() >= 2, "both make the news")
	var married := false
	for d in 200:
		v.new_day(rng)
		if v.townies.any(func(t): return t.spouse != null):
			married = true
			break
	_check(married, "townies pair up and marry over time")
	var saved := v.to_dict()
	var v2 := Visitors.new()
	add_child(v2)
	v2.setup(lot)
	v2.from_dict(saved, [])
	var names := v2.townies.map(func(t): return t.sim_name)
	_check(not names.has("Hank") and names.size() == count, "the townie roster survives a reload")
	_check(v2.townies.any(func(t): return t.spouse != null), "townie marriages survive a reload")
	v.queue_free()
	v2.queue_free()
	lot.queue_free()


func _test_child_skills() -> void:
	_check(Skills.for_stage("logic", "child") == "mental" and Skills.for_stage("painting", "child") == "creativity", "children learn child skills from grown-up activities")
	_check(Skills.for_stage("motor", "adult") == "" and Skills.for_stage("logic", "toddler") == "", "skills stay with their life stage")
	var kid := Sim.new()
	kid.age_stage = "child"
	var chess := Interaction.new("Play Chess", {}, 60.0).practices("logic", 60.0)
	kid._practise(chess, 60.0)
	_check(kid.skills.xp["mental"] > 0.0 and kid.skills.xp["logic"] == 0.0, "chess builds a child's Mental skill")
	var bars := Catalog.create("monkey_bars")
	_check(Ages.allows_for(kid, bars.interactions[0]), "children can play on the monkey bars")
	var grown := Sim.new()
	_check(not Ages.allows_for(grown, bars.interactions[0]), "grown-ups can't")
	bars.free()
	kid.free()
	grown.free()


func _test_foundation() -> void:
	var lot := _make_lot()
	add_child(lot)
	var corners := [Vector2i(2, 2), Vector2i(6, 2), Vector2i(6, 6), Vector2i(2, 6)]
	for k in 4:
		for e in Lot.wall_run(corners[k], corners[(k + 1) % 4]):
			lot.add_wall(e)
	lot.add_door(Vector3i(3, 6, 0))
	var chair := Catalog.create("chair")
	lot.place_furniture(chair, Vector2i(4, 4))
	lot.set_foundation(Lot.FOUNDATION_HEIGHT)
	_check(lot.floor_height(Vector2i(4, 4)) == Lot.FOUNDATION_HEIGHT and lot.floor_height(Vector2i(10, 10)) == 0.0, "rooms are raised, the garden isn't")
	_check(is_equal_approx(chair.position.y, Lot.FOUNDATION_HEIGHT), "furniture sits on the foundation")
	_check(is_equal_approx((lot.walls[Vector3i(3, 2, 0)] as Node3D).position.y, Lot.FOUNDATION_HEIGHT), "walls stand on the foundation")
	_check(lot._steps.size() == 1, "the outer door gets steps")
	_check(not lot.find_path(lot.cell_to_world(Vector2i(3, 9)), lot.cell_to_world(Vector2i(4, 4))).is_empty(), "Sims can still walk in")
	lot.set_foundation(0.0)
	_check(chair.position.y == 0.0 and lot._steps.is_empty(), "removing the foundation lowers everything")
	lot.queue_free()


func _test_terrain() -> void:
	var lot := _make_lot()
	add_child(lot)
	var build := BuildMode.new()
	build.lot = lot
	build.funds = 1000
	build.tool = BuildMode.Tool.TERRAIN
	build._wall_preview = MeshInstance3D.new()
	build.terrain_style = 2
	build._floor_start = Vector2i(1, 1)
	build._floor_end = Vector2i(3, 2)
	build._finish_terrain()
	_check(lot.terrain_tiles.size() == 6 and lot.terrain_tiles[Vector2i(2, 2)] == 2, "terrain paint covers the dragged area")
	_check(build.funds == 1000 - 6 * Finishes.TERRAIN[2][3], "terrain paint costs a little per tile")
	_check(lot._terrain_mesh.mesh != null, "painted ground is drawn")
	build.terrain_style = 0
	build._floor_start = Vector2i(1, 1)
	build._floor_end = Vector2i(3, 2)
	build._finish_terrain()
	_check(lot.terrain_tiles.is_empty(), "painting lawn erases")
	build._wall_preview.free()
	build.free()
	lot.queue_free()


func _test_townie_babies() -> void:
	var lot := _make_lot()
	add_child(lot)
	var v := Visitors.new()
	add_child(v)
	v.setup(lot)
	var a: Sim = v.townies[1]
	var b: Sim = v.townies[2]
	a.spouse = b
	b.spouse = a
	a.age_stage = "adult"
	b.age_stage = "adult"
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var born := false
	for d in 120:
		for n in v.new_day(rng):
			if "baby" in n:
				born = true
		if born:
			break
	_check(born and v.townies.any(func(t): return t.age_stage == "toddler"), "townie couples have children")
	v.queue_free()
	lot.queue_free()


func _test_fence_styles() -> void:
	var lot := _make_lot()
	add_child(lot)
	lot.add_fence(Vector3i(3, 4, 0), 1)
	_check(lot.fence_styles[Vector3i(3, 4, 0)] == 1 and lot.edge_blocks(Vector3i(3, 4, 0)), "half walls block walking")
	_check(not lot.add_gate(Vector3i(3, 4, 0)), "half walls can't have gates")
	lot.add_fence(Vector3i(4, 4, 0), 2)
	_check(lot.add_gate(Vector3i(4, 4, 0)), "iron railings can")
	lot.remove_fence(Vector3i(3, 4, 0))
	_check(not lot.fence_styles.has(Vector3i(3, 4, 0)), "removing a fence forgets its style")
	var col := Catalog.create("column")
	_check(col.blocks and col.decor > 0, "columns stand in the way and look nice")
	col.free()
	lot.queue_free()


func _test_gardening() -> void:
	var p := Catalog.create("planter")
	_check(p.garden_state() == "empty" and _names(p.available_interactions()).has("Plant Tomatoes"), "an empty planter offers seeds")
	p.apply_effect("plant:tomato")
	_check(p.garden_state() == "growing" and _names(p.available_interactions()).has("Water"), "planted crops want watering")
	var day := Clock.day()
	p.grow_garden(day + 1)
	var watered: float = p.get_meta("item")["growth"]
	p.grow_garden(day + 5)
	var dry: float = p.get_meta("item")["growth"] - watered
	_check(watered > dry, "watered plants grow faster")
	for k in 6:
		p.apply_effect("water")
		p.grow_garden(Clock.day())
	_check(p.garden_state() == "ripe" and _names(p.available_interactions()) == ["Harvest"], "ripe crops are ready to harvest")
	var s := Sim.new()
	s._harvest(p, 3)
	var produce := s.inventory.filter(func(it): return it.get("kind") == "produce")
	_check(produce.size() >= 3 and produce[0]["name"] == "Tomato", "harvesting fills the inventory")
	_check(p.garden_state() == "empty", "the planter is ready to sow again")
	s.free()
	p.free()


func _test_produce_quality() -> void:
	_check(Catalog.produce_quality(0, 0, 0) == 0 and Catalog.produce_quality(9, 6, 2) == 4, "quality grows with skill, care and fertilizer")
	var p := Catalog.create("planter")
	p.apply_effect("plant:carrot")
	var s := Sim.new()
	_check(not Ages.allows_for(s, p.available_interactions().filter(func(i): return i.name == "Fertilize")[0]), "fertilizing needs produce in the inventory")
	p.apply_effect("weed")
	p.apply_effect("fertilize")
	var g: Dictionary = p.get_meta("item").duplicate()
	g["growth"] = 1.0
	p.set_meta("item", g)
	s._harvest(p, 6)
	_check(s.inventory[0]["quality"] >= 3, "a well-tended, fertilized crop comes out excellent")
	s.free()
	p.free()


func _test_options_and_achievements() -> void:
	_check(Settings.DEFAULTS.has("sims3_camera") and Settings.get_value("edge_scrolling") is bool, "options have defaults")
	var tabs := GameOptions.TABS.map(func(t): return t[0])
	_check(tabs == ["Graphics", "Sound", "Music", "Gameplay", "Save Settings", "Environment", "Camera", "Screen Capture", "Tutorial & Tips", "Other", "Accessibility"], "options tabs follow the reference's order")
	Ages.lifespan_mult = 2.0
	_check(Ages.stage_days("adult") == Ages.INFO["adult"]["days"] * 2, "a long lifespan doubles each life stage")
	Ages.lifespan_mult = 1.0


func _test_save_slots() -> void:
	var old_dir := SaveGame.dir
	var old_cur := SaveGame.current
	SaveGame.dir = "user://test_slots_%d" % Time.get_ticks_msec()
	SaveGame.current = ""
	_check(not SaveGame.exists(), "no saves to begin with")
	SaveGame.write({"funds": 1})
	_check(SaveGame.current == "Save 1" and SaveGame.read()["funds"] == 1, "the first save becomes Save 1")
	SaveGame.write_as("Holiday Home", {"funds": 2})
	_check(SaveGame.slots().size() == 2 and SaveGame.current == "Holiday Home", "Save As starts a new slot and keeps playing it")
	SaveGame.write({"funds": 3})
	_check(SaveGame.read("Holiday Home")["funds"] == 3 and SaveGame.read("Save 1")["funds"] == 1, "Save writes the slot being played")
	for f in DirAccess.get_files_at(SaveGame.dir):
		DirAccess.remove_absolute(SaveGame.dir + "/" + f)
	DirAccess.remove_absolute(SaveGame.dir)
	SaveGame.dir = old_dir
	SaveGame.current = old_cur


func _test_lunar_cycle() -> void:
	var seen := {}
	for d in range(1, 9):
		seen[Lunar.phase(d)] = true
	_check(seen.size() == 8 and Lunar.phase(1) == 0 and Lunar.phase(5) == 4, "eight phases over the default 8-day cycle")
	_check(Lunar.illumination(4) > 0.99 and Lunar.illumination(0) < 0.01, "full moons are bright, new moons dark")
	_check(not Lunar.night_moodlet(4).is_empty() and Lunar.night_moodlet(2).is_empty(), "full moon nights have a mood")


func _test_room_presets_and_undo() -> void:
	var lot := _make_lot()
	add_child(lot)
	var build := BuildMode.new()
	build.lot = lot
	build.funds = 50000
	var states: Array = []
	build.snapshot = func() -> Dictionary: return {"walls": lot.walls.size(), "objects": lot.furniture.size(), "funds": build.funds}
	build.restore = func(d: Dictionary): states.append(d)
	var before := build.funds
	_check(build.place_room(3, Vector2i(2, 2)), "a ready-made bathroom drops in")
	_check(lot.walls.size() == 12 and lot.doors.size() == 1 and lot.furniture.any(func(f): return f.kind == "toilet"), "with walls, a door and its fixtures")
	_check(before - build.funds == Catalog.room_price(Catalog.ROOM_PRESETS[3]), "and costs what the catalogue says")
	_check(not build.place_room(3, Vector2i(2, 2)), "rooms can't overlap furniture")
	build._begin_change()
	build.funds -= 100
	build._end_change()
	_check(build._undo.size() == 1, "changes are recorded for undo")
	build.undo()
	_check(states.size() == 1 and build._redo.size() == 1, "undo restores and can be redone")
	build.free()
	lot.queue_free()


func _test_sticky_outfits() -> void:
	var s := Sim.new()
	s.change_outfit("sleep", false)
	var tv := Interaction.new("Watch TV", {"fun": 10.0}, 30.0, "fun", "sit")
	_check(Sim.outfit_for(tv) == "everyday", "most activities don't ask for a change")
	var d := Catalog.create("dresser")
	var swim: Interaction = d.interactions.filter(func(i): return i.outfit == "swim")[0]
	_check(swim.menu == "Change Outfit..." and d.interactions.size() == 4, "the dresser changes outfits")
	d.free()
	s.free()


func _test_social_events() -> void:
	var lot := _make_lot()
	add_child(lot)
	var v := Visitors.new()
	add_child(v)
	v.setup(lot)
	var host := Sim.new()
	var ev := SocialEvent.new()
	add_child(ev)
	ev.start("house_party", [host], v)
	_check(ev.active and ev.guests.size() == 3, "a house party brings three guests")
	_check(ev.medal() == 0, "no medal before any goal")
	for k in 8:
		host.activity_done.emit("Chat")
	host.activity_done.emit("Dance")
	_check(ev.goals_met() == 2 and ev.medal() == 1, "two goals earn bronze")
	host.activity_done.emit("Order a Drink")
	host.activity_done.emit("Grab a Snack")
	host.activity_done.emit("Tell a Joke")
	_check(ev.medal() == 3, "every goal earns gold")
	var got: Array = []
	ev.finished.connect(func(m, _t): got.append(m))
	ev.end()
	_check(got == [3] and not ev.active, "the event ends with its medal")
	ev.queue_free()
	host.free()
	v.queue_free()
	lot.queue_free()


func _test_date_event() -> void:
	var lot := _make_lot()
	add_child(lot)
	var v := Visitors.new()
	add_child(v)
	v.setup(lot)
	var host := Sim.new()
	var crush: Sim = v.townies[2]
	host.change_relationship(crush, 30.0, 40.0)
	var ev := SocialEvent.new()
	add_child(ev)
	ev.start("date", [host], v)
	_check(ev.guests == [crush], "a date brings your romantic interest, alone")
	ev.queue_free()
	host.free()
	v.queue_free()
	lot.queue_free()


func _test_burglars() -> void:
	var lot := _make_lot()
	add_child(lot)
	var cheap := Catalog.create("plant")
	var pricey := Catalog.create("tv")
	var bed := Catalog.create("bed")
	lot.place_furniture(bed, Vector2i(10, 10))
	lot.place_furniture(cheap, Vector2i(2, 2))
	lot.place_furniture(pricey, Vector2i(6, 6))
	_check(Burglar.pick_target(lot) == pricey, "burglars go for the most valuable thing they can carry (the TV, not the pricier bed)")
	_check(not Burglar.has_alarm(lot), "no alarm yet")
	var alarm := Catalog.create("burglar_alarm")
	_check(alarm.wall_mounted and Catalog.KINDS.has("burglar_alarm"), "the burglar alarm hangs on a wall")
	alarm.free()
	_check(Settings.DEFAULTS["allow_burglars"] == true, "burglar visits are on by default, as in the reference")
	lot.queue_free()


func _test_bed_assign_and_upgrade() -> void:
	var bed := Catalog.create("bed")
	var names := _names(bed.available_interactions())
	_check(names.has("Assign Bed") and names.has("Better Mattress"), "beds offer Assign Bed and a mattress upgrade")
	var up: Interaction = bed.available_interactions().filter(func(i): return i.name == "Better Mattress")[0]
	_check(up.icon == "wrench" and up.menu == "Upgrade...", "upgrades sit under Upgrade... with a wrench")
	var energy_before: float = bed.interactions.filter(func(i): return i.name == "Sleep")[0].rates["energy"]
	bed.apply_effect("upgrade:better_mattress")
	_check(not _names(bed.available_interactions()).has("Better Mattress"), "an installed upgrade isn't offered again")
	_check(bed.interactions.filter(func(i): return i.name == "Sleep")[0].rates["energy"] > energy_before, "a better mattress restores energy faster")
	bed.free()
	var stove := Catalog.create("stove")
	stove.apply_effect("upgrade:fireproof")
	_check(stove.has_upgrade_effect("fireproof") and not stove.is_upgraded(), "a fireproof stove can still break")
	stove.apply_effect("upgrade:unbreakable")
	_check(stove.is_upgraded(), "an unbreakable stove can't")
	stove.free()
	var bin := Catalog.create("trash_can")
	_check(bin.interactions[0].creates == "upgrade_part", "trash cans hide upgrade parts")
	bin.free()


func _test_dirty_fixtures() -> void:
	var t := Catalog.create("toilet")
	_check(not t.is_dirty(), "new fixtures are clean")
	for k in 3:
		t.add_dirt()
	_check(t.is_dirty() and t.available_interactions()[0].name == "Clean" and t.get_node_or_null("Flies") != null, "used fixtures get grimy, draw flies and need cleaning")
	t.apply_effect("clean")
	_check(not t.is_dirty(), "cleaning fixes it")
	t.apply_effect("upgrade:self_cleaning")
	for k in 5:
		t.add_dirt()
	_check(not t.is_dirty(), "a self-cleaning toilet stays clean")
	t.free()


func _test_everyday_objects() -> void:
	for kind in ["microwave", "coffee_maker", "bathroom_sink", "nightstand", "wardrobe", "wall_lamp", "basketball_hoop"]:
		_check(Catalog.INFO.has(kind) and Catalog.CATEGORY_OF.has(kind) and Catalog.KINDS.has(kind), "%s is in the catalogue" % kind)
		var f := Catalog.create(kind)
		_check(f.display_name != "", "%s builds" % kind)
		f.free()
	var lamp := Catalog.create("wall_lamp")
	_check(lamp.wall_mounted and lamp.is_in_group("lamps"), "wall lamps hang on walls and light up at night")
	lamp.free()


func _test_counter_tops() -> void:
	var lot := _make_lot()
	add_child(lot)
	var counter := Catalog.create("counter")
	lot.place_furniture(counter, Vector2i(3, 3))
	var mw := Catalog.create("microwave")
	_check(not lot.can_place(mw, Vector2i(6, 6), 0), "microwaves don't go on the floor")
	_check(lot.can_place(mw, Vector2i(3, 3), 0), "they go on counters")
	lot.place_furniture(mw, Vector2i(3, 3))
	_check(is_equal_approx(mw.position.y, counter.surface_height), "and sit on top")
	var cm := Catalog.create("coffee_maker")
	_check(not lot.can_place(cm, Vector2i(3, 3), 0), "one small object per counter spot")
	cm.free()
	lot.remove_furniture(counter)
	_check(mw.get_parent() == counter and not lot.furniture.has(mw), "picking up the counter takes the microwave along")
	lot.place_furniture(counter, Vector2i(8, 8))
	_check(lot.furniture.has(mw) and mw.cell == Vector2i(8, 8), "and it comes back down on the counter")
	lot.queue_free()


func _test_surface_decor() -> void:
	var lot := _make_lot()
	add_child(lot)
	var table := Catalog.create("dining_table")
	lot.place_furniture(table, Vector2i(4, 4))
	for kind in ["table_lamp", "vase_flowers", "book_stack", "desk_clock", "candles", "fruit_bowl"]:
		var f := Catalog.create(kind)
		_check(f.small and Catalog.KINDS.has(kind) and f.decor > 0, "%s is a surface decoration" % kind)
		f.free()
	var vase := Catalog.create("vase_flowers")
	_check(lot.can_place(vase, Vector2i(5, 4), 0), "decor goes on a dining table")
	vase.free()
	lot.queue_free()


func _test_more_aspirations() -> void:
	_check(Aspirations.ORDER.size() >= 19 and Aspirations.ORDER.all(func(a): return Aspirations.INFO.has(a)), "a wide choice of aspirations")
	var cats := {}
	for a in Aspirations.ORDER:
		cats[Aspirations.INFO[a]["category"]] = true
	_check(cats.size() >= 10, "in many categories, as in the reference")
	var s := Sim.new()
	s.skills.add_xp("piano", Skills.xp_for_level(5))
	_check(Aspirations.goal_met({"any_of": ["guitar", "piano"], "level": 5}, {"sim": s}), "either instrument counts for Musical Genius")
	_check(not Aspirations.goal_met({"all_of": ["guitar", "piano"], "level": 4}, {"sim": s}), "but both are needed for the third milestone")
	_check(Aspirations.goal_met({"household": 3}, {"sim": s, "household": 3}), "family goals count the household")
	s.free()


func _test_trait_batch_two() -> void:
	_check(Traits.ORDER.size() >= 24 and Traits.ORDER.all(func(t): return Traits.INFO.has(t)), "two dozen traits")
	var t: Array[String] = ["good"]
	_check(not Traits.can_add(t, "mean"), "Good and Mean conflict")
	var insult := Socials.find("Insult")
	var mean: Array[String] = ["mean"]
	_check(Traits.liking(mean, "", insult) > 1.0 and Traits.liking(t, "", insult) < 1.0, "mean Sims enjoy insults, good ones avoid them")
	var g: Array[String] = ["geek"]
	_check(Traits.skill_mult(g, "gaming") > 1.0, "geeks learn gaming faster")


func _test_likes_dislikes() -> void:
	var s := Sim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	s.roll_likes(rng)
	_check(s.likes.size() >= 2 and s.dislikes.size() == 1 and not s.likes.has(s.dislikes[0]), "Sims get a few likes and a dislike")
	_check(s.like_mult(s.likes[0]) > 1.0 and s.like_mult(s.dislikes[0]) < 1.0, "they seek out likes and avoid dislikes")
	var d := s.to_dict()
	_check(d["likes"] == s.likes and d["dislikes"] == s.dislikes, "likes and dislikes are saved")
	s.free()


func _test_birthday_cake() -> void:
	var fridge := Catalog.create("fridge")
	_check(fridge.interactions.any(func(i): return i.creates == "cake"), "the fridge can bake a birthday cake")
	fridge.free()
	var cake := Catalog.create("cake")
	_check(cake.interactions[0].effect == "age_up", "blowing out the candles ages a Sim up")
	var s := Sim.new()
	s.age_stage = "child"
	add_child(s)
	var grew: Array = []
	s.grow_up_requested.connect(func(): grew.append(true))
	var act := Sim.SimAction.new()
	act.interaction = cake.interactions[0]
	act.furniture = cake
	act.performing = true
	act.elapsed = 10.0
	s._end_perform(act, true)
	_check(grew.size() == 1, "the candles trigger a birthday")
	cake.free()
	s.queue_free()


func _test_trait_batch_three() -> void:
	_check(Traits.ORDER.size() >= 32, "32 traits")
	var fam: Array[String] = ["family_oriented"]
	_check(not Traits.can_add(fam, "hates_children"), "Family-Oriented and Hates Children conflict")
	_check(Traits.liking(fam, "", Socials.find("Teach to Talk")) > 1.0, "family-oriented Sims love parenting")
	for t in Traits.ORDER:
		_check(TraitHex.TRAIT_COLORS.has(t), "trait %s has a hex colour" % t)


func _test_jealousy() -> void:
	var lot := _make_lot()
	add_child(lot)
	var a := Sim.new()
	var b := Sim.new()
	var c := Sim.new()
	for s in [a, b, c]:
		lot.add_child(s)
		s.lot = lot
		lot.sims.append(s)
	c.partner = a
	a.partner = c
	c.set_traits(["jealous"] as Array[String])
	a.change_relationship(b, 30.0, 30.0)
	var act := Sim.SimAction.new()
	act.target_sim = b
	act.interaction = Socials.find("Flirt")
	act.outcome = true
	act.elapsed = 999.0
	a._social_result(act)
	_check(c.emotions.mood() == "angry" or c.emotions.has("jealous"), "partners get jealous when their Sim flirts with someone else")
	lot.queue_free()


func _test_family_ties() -> void:
	var mum := Sim.new()
	mum.sim_name = "Ann"
	mum.body_frame = "feminine"
	var kid := Sim.new()
	kid.sim_name = "Bo"
	kid.body_frame = "masculine"
	kid.parents = ["Ann"]
	var sis := Sim.new()
	sis.sim_name = "Cy"
	sis.body_frame = "feminine"
	sis.parents = ["Ann"]
	_check(kid.relationship_label(mum) == "Mother" and mum.relationship_label(kid) == "Son" and kid.relationship_label(sis) == "Sister", "family ties are named")
	_check(kid.to_dict()["parents"] == ["Ann"], "parents are saved")
	for s in [mum, kid, sis]:
		s.free()


func _test_wider_family() -> void:
	var names := ["Gran", "Mum", "Aunty", "Kid", "Cuz"]
	var sims := {}
	for n in names:
		var s := Sim.new()
		s.sim_name = n
		s.body_frame = "feminine"
		sims[n] = s
	sims["Mum"].parents = ["Gran"]
	sims["Aunty"].parents = ["Gran"]
	sims["Kid"].parents = ["Mum"]
	sims["Cuz"].parents = ["Aunty"]
	_check(sims["Kid"].relationship_label(sims["Gran"]) == "Grandmother", "grandparents are named")
	_check(sims["Gran"].relationship_label(sims["Kid"]) == "Granddaughter", "and grandchildren")
	_check(sims["Kid"].relationship_label(sims["Aunty"]) == "Aunt", "and aunts")
	_check(sims["Aunty"].relationship_label(sims["Kid"]) == "Niece", "and nieces")
	_check(sims["Kid"].relationship_label(sims["Cuz"]) == "Cousin", "and cousins")
	for n in names:
		sims[n].free()
