class_name Main
extends Node3D
## Game root: builds the world, the lot, the Sim and the camera, and routes clicks.
##
## Dev flags (after `--`): `--screenshot=<path>` saves a frame after a short scripted
## scenario and quits; `--scenario=<menu|sleep|walk>` picks the scenario.

## Where the Create a Sim studio is built, well away from the lot.
const CAS_STUDIO := Vector3(400, 0, 400)

var lot: Lot
## The storey above the ground floor, and both levels; `active_level` is the one
## being viewed, clicked on and built on.
var upper: Lot
var levels: Array = []
var active_level := 0
var sim: Sim
var rig: CameraRig
var hud: Hud
var build: BuildMode
var _marker: MeshInstance3D
var _marker_time := 0.0
var _cas: CreateASim
var _studio: Node3D
var _home_position := Vector3.ZERO
var visitors: Visitors
var work: Work
var daylight: Daylight
var bills: Bills
var carpool: Carpool
var life: LifeCycle
## "home" or a community lot id (see COMMUNITY_LOTS); the home's build is kept in
## _home_snapshot while the household is out.
var location := "home"
var _home_snapshot := {}
## The other households in this world (snapshots, same shape as a saved
## household), and keys of the save that belong to the whole world.
var other_households: Array = []
var _ui_hidden := false
var social_event: SocialEvent
## Decided at midnight; the burglar comes between 2 and 4 AM.
var _burglar_tonight := false
var _event_tick := 0.0
static var _open_manage_next := false
var _autosave_timer := 0.0
var _story_rng := RandomNumberGenerator.new()
const WORLD_KEYS: Array[String] = ["version", "minutes", "townies", "tips", "others"]
## Modal event cards (doorbell, new baby, farewells, first-time tips). Scripted
## dev runs turn them off so nothing waits for an answer.
var dialogs_enabled := true
var _tips_seen := {}
const COMMUNITY_LOTS := {
	"park": {"name": "Willow Park", "description": "Benches, a fountain, grills and picnic tables."},
	"gym": {"name": "Iron Works Gym", "description": "Treadmills and mirrors for working out and showing off."},
	"library": {"name": "Maple Library", "description": "Shelves of books, computers and a quiet chess corner."},
	"lounge": {"name": "The Blue Note Lounge", "description": "A bar, sofas and live guitar. Drinks cost a few Simoleons."},
}
var aspirations: AspirationTracker
## Everyone in the player's household; `sim`, `work` and `aspirations` are the
## active member's.
var household: Array[Sim] = []
var works := {}
var trackers := {}
const MAX_HOUSEHOLD := 4
## Which neighbourhood home is on the lot (its floor plan).
var home_id := "cottage"
var _menu: CanvasLayer
var _menu_orbit := false


func _ready() -> void:
	_setup_environment()
	Settings.apply(get_tree())

	lot = Lot.new()
	lot.name = "Lot"
	add_child(lot)
	upper = Lot.new()
	upper.name = "UpperLevel"
	upper.level = 1
	upper.position.y = Lot.WALL_HEIGHT
	add_child(upper)
	levels = [lot, upper]
	_place_house()

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.position = lot.center()

	_build_marker()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	build = BuildMode.new()
	build.name = "BuildMode"
	build.lot = lot
	build.camera = rig.camera
	add_child(build)
	build.placed.connect(func(f: Furniture):
		# Materialistic Sims love new stuff.
		if f.price >= 100 and f.get_meta("just_bought", false):
			f.remove_meta("just_bought")
			for m in household:
				if (m as Sim).traits.has("materialistic"):
					(m as Sim).emotions.add("new_stuff", "happy", 1, "New Stuff!", "Ooh, a brand new %s!" % f.display_name, 240.0)
		if f.kind == "stairs":
			upper.clear_floor(f.footprint_rect()))
	hud.set_build(build, lot)
	hud.sim_selected.connect(select_sim)
	hud.level_change.connect(func(step: int): set_level(active_level + step))
	hud.hang_item.connect(func(index: int):
		if location != "home":
			hud.show_notice("You can only hang paintings at home.", "Inventory")
			return
		var item: Dictionary = sim.inventory[index]
		var painting := Catalog.make_painting(item)
		painting.set_meta("owner", sim)
		build.enter()
		build.start_place_object(painting))
	build.placed.connect(func(f: Furniture):
		if f.has_meta("owner"):
			var owner: Sim = f.get_meta("owner")
			f.remove_meta("owner")
			var idx := -1
			for i in owner.inventory.size():
				if owner.inventory[i] == f.get_meta("item"):
					idx = i
			if idx >= 0:
				owner.inventory.remove_at(idx)
				owner.inventory_changed.emit())
	build.snapshot = func() -> Dictionary: return {"lot": _lot_dict(), "funds": build.funds}
	build.restore = func(d: Dictionary):
		_apply_lot_dict(d["lot"])
		build.funds = int(d["funds"])
		build.funds_changed.emit(build.funds)
	build.lot_traits_changed.connect(func(t: Array):
		for l in levels:
			(l as Lot).lot_traits = t.duplicate())
	build.foundation_changed.connect(set_foundation)
	build.roof_changed.connect(func(style: int, color: int):
		for l in levels:
			(l as Lot).set_roof(style, color))
	build.entered.connect(func(): tip("build", "Build Mode", "Time stops while you build. Use the tools at the top for walls, doors, windows, paint and floors, and buy objects from the catalogue at the bottom. Press F1 to go back to Live Mode."))
	hud.bubbles.lot = lot
	hud.bubbles.camera = rig.camera
	bills = Bills.new()
	bills.name = "Bills"
	bills.lot = lot
	bills.build = build
	add_child(bills)
	bills.notice.connect(func(t: String, title: String):
		hud.show_notice(t, title)
		if t.begins_with("New bills"):
			tip("bills", "Bills, bills, bills", "Every few days bills arrive in the mailbox. Send a Sim to the mailbox to pay them, or after two days the power will be cut off."))
	life = LifeCycle.new()
	life.name = "LifeCycle"
	life.household = household
	life.works = works
	life.max_size = MAX_HOUSEHOLD
	add_child(life)
	life.notice.connect(func(t: String, title: String): hud.show_notice(t, title))
	life.day_passed.connect(func(day: int):
		for f in lot.furniture:
			if f.kind == "planter":
				f.grow_garden(day)
		_burglar_tonight = location == "home" and Settings.get_value("allow_burglars") and _story_rng.randf() < Burglar.CHANCE
		var news := Story.advance_day(other_households, day, _story_rng)
		news.append_array(visitors.new_day(_story_rng))
		for n in news:
			hud.show_notice(n, "Neighbourhood News"))
	life.born.connect(_on_baby_born)
	life.passed_away.connect(func(s: Sim): _on_died(s, "old_age"))

	var first := _new_sim("Alex")
	var start_needs := {"hunger": 70.0, "energy": 85.0, "bladder": 55.0, "hygiene": 80.0, "fun": 45.0, "social": 60.0}
	for n in start_needs:
		first.needs.set_value(n, start_needs[n])
	var start_traits: Array[String] = ["cheerful", "creative", "bookworm"]
	first.set_traits(start_traits)
	add_to_household(first)
	select_sim(first, false)

	visitors = Visitors.new()
	visitors.name = "Visitors"
	add_child(visitors)
	visitors.setup(lot)
	for t in visitors.townies:
		t.levels = levels
	visitors.arrived.connect(_on_doorbell)
	visitors.left.connect(func(v: Sim): hud.show_notice("%s has gone home." % v.sim_name, "Visitor"))
	hud.phone_invite.connect(func(t: Sim):
		if location != "home":
			hud.show_notice("Invite people over once you're back home.", "Phone")
		elif not t.away:
			hud.show_notice("%s is already here." % t.sim_name, "Phone")
		else:
			hud.show_notice("%s is on their way over!" % t.sim_name, "Phone")
			visitors.invite(t))
	hud.phone_travel.connect(travel)
	hud.phone_service.connect(func(service: String):
		if service.begins_with("chat:"):
			for t in visitors.townies:
				if t.sim_name == service.trim_prefix("chat:"):
					sim.needs.add("social", 30.0)
					sim.change_relationship(t, 4.0, 0.0)
					sim.emotions.add("phone_chat", "happy", 1, "Nice Chat", "Good to catch up on the phone.", 120.0)
					hud.show_notice("%s had a nice chat with %s on the phone." % [sim.sim_name, t.sim_name], "Phone")
			return
		if service.begins_with("event:"):
			if location != "home" or social_event.active:
				hud.show_notice("You can only throw one event at a time, at home.", "Phone")
			else:
				var hosts: Array = [sim] + household.filter(func(m): return m != sim)
				social_event.start(service.trim_prefix("event:"), hosts, visitors)
				hud.show_notice("%s has started! Complete the goals before time runs out." % social_event.title, "Social Event")
			return
		match service:
			"maid":
				var cleanable := lot.messes().filter(func(m): return m.kind in ["dishes", "puddle"])
				var grimy := lot.furniture.filter(func(f): return f.is_dirty())
				if location != "home" or build.funds < 60:
					hud.show_notice("The maid can't come right now.", "Phone")
				else:
					build.earn(-60)
					for m in cleanable:
						lot.remove_furniture(m)
						m.queue_free()
					for f in grimy:
						f.set_dirt(0.0)
						cleanable.append(f)
					hud.show_notice("The maid cleaned up %d mess%s." % [cleanable.size(), "" if cleanable.size() == 1 else "es"], "Maid")
				return
			"repair":
				var broken := lot.furniture.filter(func(f): return f.broken)
				if location != "home" or build.funds < 80:
					hud.show_notice("The repair technician can't come right now.", "Phone")
				else:
					build.earn(-80)
					for f in broken:
						f.set_broken(false)
					hud.show_notice("The repair technician fixed %d object%s." % [broken.size(), "" if broken.size() == 1 else "s"], "Repairs")
				return
			"pay_bills":
				bills.pay()
				return
			"day_off":
				(works[sim] as Work).take_day_off()
				return
		if service == "pizza":
			if location != "home":
				hud.show_notice("Pizza can only be delivered to your home.", "Phone")
			elif build.funds < 40:
				hud.show_notice("Not enough Simoleons for pizza.", "Phone")
			else:
				build.earn(-40)
				_pizza_due = Clock.total_minutes + 45.0
				hud.show_notice("Pizza is on its way! It'll arrive in about 45 minutes.", "Phone"))
	hud.set_phone(visitors, COMMUNITY_LOTS)
	social_event = SocialEvent.new()
	social_event.name = "SocialEvent"
	add_child(social_event)
	social_event.changed.connect(func(): hud.show_event(social_event))
	social_event.finished.connect(func(medal: int, title: String):
		for m in household:
			(m as Sim).count_stat("events")
			if medal >= 2:
				(m as Sim).count_stat("event_silver")
			if medal == 3:
				(m as Sim).count_stat("event_gold")
		var reward: int = SocialEvent.REWARD[medal]
		if reward > 0:
			build.earn(reward)
		for m in household:
			if medal >= 2:
				(m as Sim).emotions.add("great_party", "happy", 2, "Great Party!", "That was a night to remember.", 480.0)
			elif medal == 0:
				(m as Sim).emotions.add("flop_party", "embarrassed", 1, "Party Flop", "Well, that was awkward.", 240.0)
		for g in social_event.guests:
			visitors.send_home(g)
		var msg := "%s is over: %s medal!" % [title, SocialEvent.MEDALS[medal]]
		if reward > 0:
			msg += " The household earned %s." % Hud.money(reward)
		hud.show_notice(msg, "Social Event"))
	hud.set_others(lot)

	hud.menu_requested.connect(func():
		if _menu == null and _cas == null:
			open_game_menu())
	_check_dev_args()


# --- household ------------------------------------------------------------------

func _new_sim(sim_name: String) -> Sim:
	var s := Sim.new()
	s.name = "Sim_%d" % (household.size() + 1)
	s.sim_name = sim_name
	s.lot = lot
	s.levels = levels
	add_child(s)
	s.set_selected(false)
	s.global_position = lot.cell_to_world(Vector2i(10 + household.size(), 14))
	return s


## Adds a Sim to the household with their own job and aspiration tracker.
func add_to_household(s: Sim) -> void:
	household.append(s)
	if not lot.sims.has(s):
		lot.sims.append(s)
	s.earned.connect(build.earn)
	s.baby_tried.connect(func(p: Sim): life.try_for_baby(s, p))
	s.grow_up_requested.connect(func(): life.birthday(s))
	s.died.connect(func(cause: String): _on_died(s, cause))
	s.wallet = build
	s.moving_in.connect(_on_moving_in)
	s.panel_requested.connect(func(p: String):
		if p == "pay_bills":
			bills.pay())
	hud.watch_sim(s)
	var w := Work.new()
	w.name = "Work_" + s.name
	w.sim = s
	w.lot = lot
	add_child(w)
	w.paid.connect(build.earn)
	w.carpool = carpool
	w.branch_choice.connect(func(labels: Array):
		if not dialogs_enabled:
			w.choose_branch(0)
			return
		var opts: Array[String] = []
		opts.assign(labels)
		var d := EventDialog.ask(self, s, "Career Branch", "%s has reached a turning point in the %s career. Which path will they follow?" % [s.sim_name, Careers.label(w.career)], opts)
		d.answered.connect(func(i: int, _t: String): w.choose_branch(i)))
	w.work_event.connect(func(title: String, text: String, choices: Array):
		if not dialogs_enabled:
			w.resolve_event(0)
			return
		var opts: Array[String] = []
		opts.assign(choices)
		var d := EventDialog.ask(self, s, title, text, opts)
		d.answered.connect(func(i: int, _t: String): w.resolve_event(i)))
	s.homework_done.connect(func():
		w.performance = minf(100.0, w.performance + 15.0)
		w.changed.emit())
	hud.watch_work(w)
	works[s] = w
	var t := AspirationTracker.new()
	t.name = "Aspirations_" + s.name
	add_child(t)
	t.setup(s, build, w)
	hud.watch_aspirations(t)
	trackers[s] = t
	build.household = household
	hud.set_household(household)


func _on_baby_born(baby: Sim, parents: Array) -> void:
	baby.name = "Sim_%d" % (household.size() + 1)
	baby.levels = levels
	add_child(baby)
	baby.set_selected(false)
	baby.global_position = (parents[0] as Sim).global_position + Vector3(0.8, 0, 0.4)
	add_to_household(baby)
	for p in parents:
		if is_instance_valid(p):
			baby.change_relationship(p, 60.0, 0.0)
	if dialogs_enabled:
		var d := EventDialog.ask(self, parents[0], "It's a baby!", "%s has had a baby! What would you like to call them?" % (parents[0] as Sim).sim_name, ["Welcome to the family"] as Array[String], baby.sim_name)
		d.answered.connect(func(_c: int, text: String):
			if text != "":
				baby.sim_name = text
				hud.set_household(household))


## Someone rings the doorbell: let them in, or send them on their way.
func _on_doorbell(v: Sim) -> void:
	var hello := "%s from next door rang the doorbell." if v == visitors.neighbour else "%s has come over and is at the door."
	if not dialogs_enabled:
		hud.show_notice((hello % v.sim_name) + " Click them to socialize.", "Visitor")
		return
	var d := EventDialog.ask(self, v, "Ding dong!", hello % v.sim_name, ["Welcome them in", "Send them away"] as Array[String])
	d.answered.connect(func(choice: int, _t: String):
		if choice == 1:
			visitors.send_home(v)
			sim.change_relationship(v, -3.0, 0.0))


## A one-time explanation the first time something happens.
func tip(id: String, title: String, text: String) -> void:
	if _tips_seen.has(id) or not dialogs_enabled or not Settings.get_value("show_tips"):
		return
	_tips_seen[id] = true
	EventDialog.ask(self, null, title, text, ["Got it"] as Array[String])


## Sends for the Grim Reaper; afterwards a tombstone stays where they fell and
## the household mourns. The last Sim dying ends the game.
func _on_died(s: Sim, cause: String) -> void:
	if s.dying or not household.has(s):
		return
	if household.size() <= 1 and cause == "old_age":
		return
	var reaper := GrimReaper.reap(self, s, cause)
	reaper.finished.connect(_after_death)


func _after_death(s: Sim, cause: String) -> void:
	var where := s.global_position
	var home_lot := s.lot if s.lot != null else lot
	var stone := home_lot.add_mess("tombstone", where)
	stone.display_name = "Tombstone of %s" % s.sim_name
	for o in household:
		if o != s:
			var close := o.friendship_with(s) >= 30.0 or o.romance_with(s) >= 30.0 or o.spouse == s
			o.emotions.add("mourning", "sad", 3 if close else 1, "Mourning", "Missing %s." % s.sim_name, 1440.0)
	var text := "%s %s." % [s.sim_name, GrimReaper.CAUSES[cause]]
	if household.size() <= 1:
		if dialogs_enabled:
			var d := EventDialog.ask(self, null, "Game Over", text + " There's no one left in the household.", ["Back to the Main Menu"] as Array[String])
			d.answered.connect(func(_c: int, _t: String): get_tree().reload_current_scene())
		else:
			hud.show_notice(text, "Game Over")
		return
	remove_from_household(s)
	if dialogs_enabled:
		EventDialog.ask(self, null, "Rest in Peace", text + " They'll be missed.", ["Farewell"] as Array[String])
	else:
		hud.show_notice(text, "Rest in Peace")


## A townie said yes to moving in (or marrying): they join the household.
func _on_moving_in(other: Sim) -> void:
	if household.has(other) or not visitors.townies.has(other):
		return
	if household.size() >= MAX_HOUSEHOLD:
		hud.show_notice("The household is full, so %s can't move in." % other.sim_name, "Household")
		return
	visitors.remove_townie(other)
	other.is_visitor = false
	other.reparent(self)
	other.lot = lot
	other.levels = levels
	add_to_household(other)
	hud.show_notice("%s has moved in! Click their portrait to play as them." % other.sim_name, "Household")


func remove_from_household(s: Sim) -> void:
	if household.size() <= 1 or not household.has(s):
		return
	household.erase(s)
	lot.sims.erase(s)
	(works[s] as Node).queue_free()
	(trackers[s] as Node).queue_free()
	works.erase(s)
	trackers.erase(s)
	for o in household:
		o.relationships.erase(s)
	s.queue_free()
	if sim == s:
		select_sim(household[0])
	hud.set_household(household)


## Takes control of `s`: the HUD, panels and camera follow them.
var _pan: Tween


func select_sim(s: Sim, pan := true) -> void:
	if sim != null and is_instance_valid(sim):
		sim.set_selected(false)
	sim = s
	work = works[s]
	aspirations = trackers[s]
	build.sim = s
	s.set_selected(_cas == null)
	hud.set_sim(s)
	hud.set_work(work)
	hud.set_aspirations(aspirations)
	# Pan to them unless the camera is held by a menu or Create a Sim.
	if pan and _cas == null and s.visible and rig.is_processing():
		_stop_pan()
		_pan = create_tween()
		_pan.tween_property(rig, "position", Vector3(s.global_position.x, s.lot.base_y(), s.global_position.z), 0.4).set_trans(Tween.TRANS_SINE)


var _hovered: Node3D
static var _hover_mat: ShaderMaterial


## Highlights the object or Sim under the mouse with a soft glowing rim, and
## shows a pointing hand, like the reference game.
func _hover(at: Vector2) -> void:
	var picked: Object = _pick_at(at)
	var target: Node3D = null
	if picked is Furniture and not (picked as Furniture).available_interactions().is_empty():
		target = picked
	elif picked is Sim and picked != sim:
		target = picked
	if target == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_set_overlay(_hovered, null)
	_hovered = target
	if target != null:
		if _hover_mat == null:
			_hover_mat = ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.35, 0.75, 1.0) * (0.22 + rim * 1.2);
}
"""
			_hover_mat.shader = sh
		_set_overlay(target, _hover_mat)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if target != null else Input.CURSOR_ARROW)


func _set_overlay(n: Node3D, m: Material) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.name == "Plumbob" or mi.get_parent().name == "Plumbob":
			continue
		mi.material_overlay = m


## Cancels a camera pan so a menu or Create a Sim can hold the camera.
func _stop_pan() -> void:
	if _pan != null and _pan.is_valid():
		_pan.kill()


func _unhandled_input(event: InputEvent) -> void:
	if _cas != null or _menu != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE and not build.active:
		open_game_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F1:
				build.exit()
				return
			KEY_F2:
				# Build/Buy on the object catalogue, as in the reference.
				build.enter()
				if build.active:
					build._show_category("all")
				return
			KEY_F3:
				# Build/Buy on the build side: the ready-made Rooms catalogue.
				build.enter()
				if build.active:
					build._show_category("rooms")
				return
			KEY_HOME:
				# Walls up one step (down / cutaway / up).
				lot.wall_view = maxi(0, lot.wall_view - 1) as Lot.WallView
				hud.refresh_walls_button(lot)
				return
			KEY_END:
				lot.wall_view = mini(2, lot.wall_view + 1) as Lot.WallView
				hud.refresh_walls_button(lot)
				return
			KEY_C:
				if not event.is_command_or_control_pressed():
					take_screenshot()
					return
			KEY_TAB:
				# Camera mode: hide the whole interface (Tab again brings it back).
				_ui_hidden = not _ui_hidden
				hud.visible = not _ui_hidden and not build.active
				build.set_ui_hidden(_ui_hidden)
				return
			KEY_PAGEUP:
				set_level(active_level + 1)
				return
			KEY_PAGEDOWN:
				set_level(active_level - 1)
				return
	if build.active:
		build.handle_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_P, KEY_0, KEY_KP_0, KEY_QUOTELEFT:
				Clock.set_speed(1 if Clock.is_paused() else 0)
			KEY_O:
				hud.toggle_page(0)
			KEY_L:
				hud.toggle_page(1)
			KEY_Y:
				hud.toggle_page(2)
			KEY_R:
				hud.toggle_page(3)
			KEY_J:
				hud.toggle_page(4)
			KEY_G:
				hud.toggle_page(5)
			KEY_I:
				hud.toggle_page(6)
			KEY_SPACE:
				# Next Sim in the household.
				var at := household.find(sim)
				for k in range(1, household.size() + 1):
					var nxt: Sim = household[(at + k) % household.size()]
					if not nxt.away and nxt.visible:
						select_sim(nxt)
						break
			KEY_ENTER, KEY_KP_ENTER:
				if Input.is_key_pressed(KEY_SHIFT):
					rig.frame(lot.center(), rig.yaw, rig.pitch, rig.distance)
				else:
					rig.frame(Vector3(sim.global_position.x, sim.lot.base_y(), sim.global_position.z), rig.yaw, rig.pitch, rig.distance)
			KEY_1, KEY_KP_1:
				Clock.set_speed(1)
			KEY_2, KEY_KP_2:
				Clock.set_speed(2)
			KEY_3, KEY_KP_3:
				Clock.set_speed(3)
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if sim.away:
				return
			var picked: Object = _pick_at(mb.position)
			if picked is Furniture:
				open_menu(picked, mb.position)
				return
			if picked is Sim and picked != sim:
				open_sim_menu(picked, mb.position)
				return
			if picked == sim:
				open_self_menu(mb.position)
				return
			var here: Lot = levels[active_level]
			var hit: Variant = _ground_point(mb.position)
			if hit != null and here.contains_point(hit) and here.is_walkable(here.world_to_cell(hit)):
				# As in the reference: a one-option pie, "Go Here", in green.
				var target: Vector3 = hit
				_on_pie_choice(func(_i: int):
					if sim.queue_go(target, here):
						_show_marker(target))
				hud.pie_menu.open(mb.position, "", ["Go Here"] as Array[String], [] as Array[String], [UiTheme.GREEN_DARK])


## Opens the interaction pie menu for `f` at a screen position.
func open_menu(f: Furniture, screen_pos: Vector2) -> void:
	if f.interactions.is_empty():
		return
	var top: Array = []
	var groups := {}
	for i in f.available_interactions():
		if not (Ages.allows_for(sim, i) or i.fixes):
			continue
		if i.menu == "":
			top.append(i)
		else:
			if not groups.has(i.menu):
				groups[i.menu] = []
				top.append(i.menu)
			groups[i.menu].append(i)
	if top.is_empty():
		hud.show_notice("%s can't do anything with the %s right now." % [sim.sim_name, f.display_name], sim.sim_name)
		return
	var names: Array[String] = []
	for t in top:
		names.append(t if t is String else (t as Interaction).name)
	# Groups like "Cook..." open a second ring with their choices.
	_on_pie_choice(func(idx: int):
		if top[idx] is String:
			var sub: Array = groups[top[idx]]
			var sub_names: Array[String] = []
			for i in sub:
				sub_names.append((i as Interaction).name)
			var sub_icons: Array[String] = []
			for i in sub:
				sub_icons.append((i as Interaction).icon)
			_on_pie_choice(func(j: int): sim.queue_interaction(f, sub[j]))
			hud.pie_menu.open(screen_pos, top[idx], sub_names, sub_icons)
		else:
			_queue_with_partner(f, top[idx]))
	var icons: Array[String] = []
	for t in top:
		icons.append(("wrench" if t == "Upgrade..." else "") if t is String else (t as Interaction).icon)
	hud.pie_menu.open(screen_pos, f.display_name, names, icons)


## Queues an object interaction; WooHoo also calls the partner over to the bed.
func _queue_with_partner(f: Furniture, i: Interaction) -> void:
	sim.queue_interaction(f, i)
	if i.with_partner:
		var p := sim.woohoo_partner()
		if p != null:
			p.queue_interaction(f, i)


## Clicking the active Sim: things they can do on their own (Change Outfit...).
func open_self_menu(screen_pos: Vector2) -> void:
	# Checked against the reference: clicking your own Sim offers Outfits..., Sit on
	# Ground, Jog, Ponder Problems, Stargaze, Moonbathe (after dark) and Travel...
	var spot := _self_spot()
	var night := Daylight.is_dark(fmod(Clock.total_minutes / 60.0, 24.0))
	var acts: Array = []
	for i in spot.interactions:
		if i.name == "Moonbathe" and not night:
			continue
		if Ages.allows_for(sim, i):
			acts.append(i)
	var labels: Array[String] = ["Outfits..."]
	var icons: Array[String] = [""]
	for i in acts:
		labels.append(i.name)
		icons.append(i.icon)
	labels.append("Travel...")
	icons.append("walk")
	_on_pie_choice(func(idx: int):
		if idx == 0:
			var cats := [["Everyday", "everyday"], ["Sleepwear", "sleep"], ["Athletic", "athletic"], ["Swimwear", "swim"]]
			var names: Array[String] = []
			for c in cats:
				names.append(c[0])
			_on_pie_choice(func(j: int): sim.change_outfit(cats[j][1]))
			hud.pie_menu.open(screen_pos, "Outfits", names)
		elif idx == labels.size() - 1:
			hud._phone_tab = 1
			hud._toggle_phone()
		else:
			spot.global_position = Vector3(sim.global_position.x, spot.global_position.y, sim.global_position.z)
			sim.queue_interaction(spot, acts[idx - 1]))
	hud.pie_menu.open(screen_pos, sim.sim_name, labels, icons)


var _self_spot_node: Furniture

## An invisible spot that follows the Sim, for things they do on their own (not
## in the object list, so autonomy and saving ignore it).
func _self_spot() -> Furniture:
	if _self_spot_node != null and is_instance_valid(_self_spot_node):
		if _self_spot_node.get_parent() != sim.lot:
			_self_spot_node.reparent(sim.lot)
		return _self_spot_node
	var f := Furniture.new()
	f.kind = "self"
	f.display_name = sim.sim_name
	f.blocks = false
	f.spots = [Vector3.ZERO]
	f.interactions = [
		Interaction.new("Sit on Ground", {"energy": 3.0, "fun": 4.0}, 30.0, "", "sit"),
		Interaction.new("Jog", {"fun": 12.0, "energy": -14.0, "hygiene": -18.0}, 60.0, "", "run").practices("fitness", 65.0).grants("pumped", "energized", 1, "Pumped", "Great workout!", 180.0),
		Interaction.new("Ponder Problems", {"fun": 6.0}, 45.0, "", "stand").practices("logic", 40.0),
		Interaction.new("Stargaze", {"fun": 20.0}, 45.0, "", "stand").grants("starry", "inspired", 1, "Starstruck", "So many stars.", 120.0),
		Interaction.new("Moonbathe", {"fun": 15.0, "energy": 5.0}, 45.0, "", "lie").grants("moonlit", "happy", 1, "Moonlit", "Bathed in moonlight.", 180.0),
	]
	f.interactions[1].icon = "walk"
	f.interactions[2].icon = "bulb"
	sim.lot.add_child(f)
	_self_spot_node = f
	return f


## Social pie menu for another Sim: first a ring of categories, then the socials in
## the chosen one.
func open_sim_menu(other: Sim, screen_pos: Vector2) -> void:
	var options := Socials.available(sim.friendship_with(other), sim.romance_with(other), sim.age_stage, other.age_stage, sim.emotions.mood(), other.emotions.mood(), sim.status_with(other))
	var cats: Array[String] = []
	for i in options:
		var c: String = i.social["category"]
		if not cats.has(c):
			cats.append(c)
	var title := "%s · %s" % [other.sim_name, sim.relationship_label(other)]
	var labels: Array[String] = []
	for c in cats:
		labels.append(c + "...")
	_on_pie_choice(func(ci: int):
		var in_cat: Array[Interaction] = []
		var names: Array[String] = []
		for i in options:
			if i.social["category"] == cats[ci]:
				in_cat.append(i)
				names.append(i.name)
		_on_pie_choice(func(ii: int): sim.queue_social(other, in_cat[ii]))
		hud.pie_menu.open(screen_pos, cats[ci], names))
	hud.pie_menu.open(screen_pos, title, labels)


func _on_pie_choice(callback: Callable) -> void:
	for c in hud.pie_menu.chosen.get_connections():
		hud.pie_menu.chosen.disconnect(c.callable)
	hud.pie_menu.chosen.connect(callback, CONNECT_ONE_SHOT)


## The furniture or Sim under the cursor, if any.
func _pick_at(screen_pos: Vector2) -> Object:
	var cam := rig.camera
	# Other Sims win over the objects they're sitting at: test their on-screen
	# silhouette (feet to head, about a shoulder-width wide) first.
	for other in lot.sims:
		# The active Sim counts too while standing (clicking them opens their own menu).
		if (other == sim and sim.pose_name() != "stand") or not other.visible or cam.is_position_behind(other.global_position):
			continue
		var feet := cam.unproject_position(other.global_position)
		var head := cam.unproject_position(other.global_position + Vector3(0, 1.8, 0))
		var half := (cam.unproject_position(other.global_position + cam.global_basis.x * 0.35) - feet).length()
		var top := minf(feet.y, head.y)
		var bottom := maxf(feet.y, head.y)
		var t := clampf(inverse_lerp(bottom, top, screen_pos.y), 0.0, 1.0)
		var axis_x := lerpf(feet.x, head.x, t)
		if screen_pos.y >= top and screen_pos.y <= bottom and absf(screen_pos.x - axis_x) <= half:
			return other
	var origin := cam.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen_pos) * 500.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var col := hit.collider as Object
	if col.has_meta("furniture"):
		var f := col.get_meta("furniture") as Furniture
		if f.get_parent() is Lot and (f.get_parent() as Lot).level > active_level:
			return null
		return f
	if col.has_meta("sim"):
		return col.get_meta("sim")
	return null


func _furniture_at(screen_pos: Vector2) -> Furniture:
	var picked: Object = _pick_at(screen_pos)
	return picked as Furniture if picked is Furniture else null


func _process(delta: float) -> void:
	_autosave(delta)
	for t in trackers.values():
		(t as AspirationTracker).household_size = household.size()
	if _burglar_tonight and location == "home" and Clock.hour() >= 2 and Clock.hour() < 4:
		_burglar_tonight = false
		send_burglar()
	_event_tick += delta
	if social_event != null and social_event.active and _event_tick > 0.5:
		_event_tick = 0.0
		hud.show_event(social_event)
	_update_window_glow()
	rig.height_keys_enabled = not build.active
	rig.rotate_keys_enabled = not (build.active and build.is_holding())
	_update_audio()
	_update_mess()
	if _menu_orbit:
		rig.frame(lot.center(), rig.yaw + delta * 0.08, deg_to_rad(-32.0), 30.0)
	upper.wall_view = lot.wall_view
	for l in levels:
		l.update_walls(rig.camera.global_position, rig.global_position, delta)
	# With walls up the whole house shows; otherwise floors above the one being
	# viewed are hidden, and the ground roof gives way to the upper storey.
	upper.visible = active_level >= 1 or lot.wall_view == Lot.WallView.UP
	if lot._roof != null and not upper.floor_tiles.is_empty():
		lot._roof.visible = false
	var people: Array[Vector3] = []
	for s in lot.sims:
		people.append(s.global_position)
	for l in levels:
		l.update_doors(people, delta)
	if _marker.visible:
		_marker_time += delta
		_marker.scale = Vector3.ONE * (1.0 + 0.15 * sin(_marker_time * 6.0))
		var walking := false
		for a in sim.queue:
			walking = walking or a.interaction == null
		if not walking:
			_marker.visible = false


## Views (and builds on) another floor; the camera rises with it.
func set_level(n: int) -> void:
	n = clampi(n, 0, levels.size() - 1)
	if n == active_level:
		return
	active_level = n
	build.set_lot(levels[n])
	var tw := create_tween()
	tw.tween_property(rig, "position:y", n * Lot.WALL_HEIGHT, 0.3).set_trans(Tween.TRANS_SINE)
	hud.show_notice("Viewing the %s." % ["ground floor", "upper floor"][n], "Floors")


func _ground_point(screen_pos: Vector2) -> Variant:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var here: Lot = levels[active_level]
	var hit: Variant = Plane(Vector3.UP, here.base_y()).intersects_ray(origin, dir)
	# On a foundation, aim at the raised floor instead.
	if hit != null and here.floor_height(here.world_to_cell(hit)) > 0.0:
		var raised: Variant = Plane(Vector3.UP, here.base_y() + here.foundation).intersects_ray(origin, dir)
		if raised != null and here.floor_height(here.world_to_cell(raised)) > 0.0:
			return raised
	return hit


func _show_marker(at: Vector3) -> void:
	_marker.position = Vector3(at.x, 0.03, at.z)
	_marker_time = 0.0
	_marker.visible = true


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "MoveMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.26
	_marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


## Builds one of the neighbourhood's homes on the lot (see Neighbourhood.LOTS).
func _place_house(layout := "cottage") -> void:
	home_id = layout
	_place_grounds(layout)
	_place("mailbox", Vector2i(8, 16))
	match layout:
		"studio":
			_place_studio()
			return
		"empty":
			return
	# A small starter house: walls with two doors, and basic furniture.
	_place_walls()
	_place("bed", Vector2i(4, 3))
	_place("desk", Vector2i(8, 3))
	_place("tv", Vector2i(12, 3))
	_place("fridge", Vector2i(16, 3))
	_place("bookshelf", Vector2i(17, 6), 3)
	_place("easel", Vector2i(15, 9))
	_place("chess", Vector2i(11, 8))
	_place("toilet", Vector2i(4, 10), 2)
	_place("shower", Vector2i(6, 10), 2)
	_place("lamp", Vector2i(7, 3))
	_place("lamp", Vector2i(14, 7))
	_place("lamp", Vector2i(5, 9))
	_place("counter", Vector2i(14, 3))
	_place("stove", Vector2i(15, 3))
	_place("microwave", Vector2i(14, 3))
	_place("sofa", Vector2i(11, 5), 2)
	_place("plant", Vector2i(17, 11))
	_place("treadmill", Vector2i(16, 9))
	_place("mirror", Vector2i(9, 10))
	_place("guitar", Vector2i(13, 10))
	_place("stereo", Vector2i(14, 5))
	_place("toybox", Vector2i(6, 6))


## Hedges and the floor finish of a home; walls and objects come separately so a
## saved game can put back its own.
func _place_grounds(layout: String) -> void:
	var hedge := Color(0.18, 0.38, 0.16)
	lot.add_block(Rect2i(1, 16, 6, 1), 0.9, hedge, "HedgeFrontWest")
	lot.add_block(Rect2i(15, 16, 7, 1), 0.9, hedge, "HedgeFrontEast")
	match layout:
		"cottage":
			lot.add_floor(Rect2i(3, 2, 15, 10), 0)
			lot.add_floor(Rect2i(3, 8, 5, 4), 3)
		"studio":
			lot.add_floor(Rect2i(6, 4, 10, 7), 1)
			lot.add_floor(Rect2i(6, 8, 3, 3), 4)


## A compact one-room home with a bathroom corner.
func _place_studio() -> void:
	var runs := [
		[Vector2i(6, 4), Vector2i(16, 4)],
		[Vector2i(6, 11), Vector2i(16, 11)],
		[Vector2i(6, 4), Vector2i(6, 11)],
		[Vector2i(16, 4), Vector2i(16, 11)],
		[Vector2i(6, 8), Vector2i(9, 8)],
		[Vector2i(9, 8), Vector2i(9, 11)],
	]
	for r in runs:
		for e in Lot.wall_run(r[0], r[1]):
			lot.add_wall(e)
	lot.add_door(Vector3i(12, 11, 0))
	lot.add_door(Vector3i(7, 8, 0))
	for e in [Vector3i(8, 4, 0), Vector3i(13, 4, 0), Vector3i(16, 6, 1), Vector3i(14, 11, 0)]:
		lot.add_window(e)
	for e in lot.walls.keys():
		lot.paint_wall(e, 1)
	_place("bed", Vector2i(7, 5))
	_place("tv", Vector2i(11, 5))
	_place("fridge", Vector2i(15, 5))
	_place("desk", Vector2i(13, 8))
	_place("toilet", Vector2i(6, 10), 2)
	_place("shower", Vector2i(8, 10), 2)
	_place("lamp", Vector2i(10, 5))
	_place("lamp", Vector2i(15, 9))
	_place("counter", Vector2i(13, 5))
	_place("stove", Vector2i(14, 5))


func _place_walls() -> void:
	# Outer walls around the floor, plus a bathroom in the south-west corner.
	var runs := [
		[Vector2i(3, 2), Vector2i(18, 2)],
		[Vector2i(3, 12), Vector2i(18, 12)],
		[Vector2i(3, 2), Vector2i(3, 12)],
		[Vector2i(18, 2), Vector2i(18, 12)],
		[Vector2i(3, 8), Vector2i(8, 8)],
		[Vector2i(8, 8), Vector2i(8, 12)],
	]
	for r in runs:
		for e in Lot.wall_run(r[0], r[1]):
			lot.add_wall(e)
	lot.add_door(Vector3i(10, 12, 0))
	lot.add_door(Vector3i(7, 8, 0))
	for e in [Vector3i(5, 2, 0), Vector3i(10, 2, 0), Vector3i(14, 2, 0), Vector3i(18, 4, 1), Vector3i(18, 9, 1),
			Vector3i(13, 12, 0), Vector3i(15, 12, 0), Vector3i(3, 4, 1), Vector3i(5, 12, 0)]:
		lot.add_window(e)
	# Striped wallpaper in the bathroom.
	for r in [[Vector2i(3, 8), Vector2i(8, 8)], [Vector2i(8, 8), Vector2i(8, 12)]]:
		for e in Lot.wall_run(r[0], r[1]):
			lot.paint_wall(e, 5)


func _place(kind: String, at: Vector2i, rot := 0) -> Furniture:
	var f := Catalog.create(kind)
	lot.place_furniture(f, at, rot)
	return f


func find_furniture(kind: String) -> Furniture:
	for f in lot.furniture:
		if f.kind == kind:
			return f
	return null


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.56, 0.86)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	# A soft, warm, filmic look like the reference's: ACES tone mapping, contact
	# shadows in corners (SSAO), light bouncing off walls and floors (SSIL), a
	# gentle bloom on bright lamps and windows, and a little colour grading.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	# Glossy floors and tiles reflect the room (screen-space reflections).
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.02
	# Distant haze softens the neighbourhood towards the horizon.
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.9)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 260.0
	env.fog_density = 0.6
	env.fog_sky_affect = 0.0
	Settings.environment = env
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fx-off="):
			for fx in arg.trim_prefix("--fx-off=").split(","):
				env.set(fx + "_enabled", false)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.light_cull_mask = 1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	# Soft shadows that blur with distance from the caster, like the reference.
	sun.light_angular_distance = 1.2
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	add_child(sun)

	carpool = Carpool.new()
	carpool.name = "Carpool"
	add_child(carpool)
	carpool.road_z = 20 + 3.6

	var around := Surroundings.new()
	around.name = "Surroundings"
	add_child(around)
	around.build(Vector2i(24, 20))

	daylight = Daylight.new()
	daylight.name = "Daylight"
	daylight.env = env
	daylight.sky_mat = sky_mat
	daylight.sun = sun
	add_child(daylight)


func _check_dev_args() -> void:
	var shot := ""
	var scenario := "menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	if shot != "" or scenario in ["trace", "saveload", "audiocheck", "travelcheck", "inputcheck", "householdscheck"]:
		dialogs_enabled = false
	if scenario != "" and scenario not in ["new", "skip_cas"]:
		# Checks and screenshots never touch the player's own saves.
		SaveGame.dir = "user://check_saves"
	if shot != "":
		_run_scenario(scenario, shot)
	elif scenario == "trace":
		_trace()
	elif scenario == "saveload":
		_save_load_check()
	elif scenario == "audiocheck":
		_enter_live()
		Clock.total_minutes = 9.0 * 60.0 + 5.0
		await get_tree().create_timer(2.0).timeout
		var jules := visitors.neighbour
		sim.queue_social(jules, Socials.find("Chat"))
		var voiced := false
		for i in 40:
			await get_tree().create_timer(0.1).timeout
			voiced = voiced or sim._voice.playing or jules._voice.playing
		var m: AudioStreamPlayer = Sfx._music[Sfx._music_on]
		print("AUDIO music=%s playing=%s ambience=%s playing=%s voice=%s" % [Sfx._music_name, m.playing, Sfx._ambience_name, Sfx._ambience.playing, voiced])
		get_tree().quit()
	elif scenario == "travelcheck":
		_enter_live()
		var before := lot.furniture.size()
		var walls_before := lot.walls.size()
		await travel("park")
		await get_tree().create_timer(1.0).timeout
		var at_park := lot.furniture.size()
		var townies := visitors.present().size()
		await travel("home")
		await get_tree().create_timer(1.0).timeout
		var ok := lot.furniture.size() == before and lot.walls.size() == walls_before and at_park > 10 and townies == 3 and visitors.present().is_empty()
		print("TRAVEL %s home=%d/%d park=%d townies=%d" % ["OK" if ok else "FAIL", lot.furniture.size(), before, at_park, townies])
		get_tree().quit()
	elif scenario == "inputcheck":
		_input_check()
	elif scenario == "householdscheck":
		_households_check()
	elif scenario == "new":
		open_create_a_sim()
	elif scenario != "skip_cas":
		open_main_menu()


# --- title screen, game menu, saving ---------------------------------------------

## Title screen over a slowly orbiting camera.
var _mess_check := 0.0
var _pizza_due := -1.0


## A messy home makes everyone there tense; more mess, stronger feeling.
func _update_mess() -> void:
	if Clock.total_minutes < _mess_check:
		return
	_mess_check = Clock.total_minutes + 2.0
	# Environment: a well-decorated room lifts spirits, like the reference game.
	for s in lot.sims:
		var sm := s as Sim
		if not lot.is_indoors(lot.world_to_cell(sm.global_position)):
			continue
		var score := 0
		for f in lot.furniture:
			if f.decor > 0 and f.global_position.distance_to(sm.global_position) < 4.5:
				score += f.decor
		if score >= 4:
			sm.emotions.add("decorated", "happy", 1 if score < 8 else 2, "Nicely Decorated" if score < 8 else "Beautiful Room", "This room looks great.", 10.0)
	# Full and new moon nights (Game Options > Environment).
	var night_hour := fmod(Clock.total_minutes / 60.0, 24.0)
	if night_hour >= 20.0 or night_hour < 5.0:
		var lm := Lunar.night_moodlet(Lunar.phase(Clock.day()))
		if not lm.is_empty():
			for s in lot.sims + upper.sims:
				if (s as Sim).pose_name() != "lie":
					(s as Sim).emotions.add(lm[0], lm[1], lm[2], lm[3], lm[4], lm[5])
	# Lot traits keep their moodlets topped up for everyone on the lot.
	var hour := fmod(Clock.total_minutes / 60.0, 24.0)
	for m in LotTraits.moodlets(lot.lot_traits, hour):
		for s in lot.sims + upper.sims:
			(s as Sim).emotions.add(m[0], m[1], m[2], m[3], m[4], 10.0)
	if _pizza_due >= 0.0 and Clock.total_minutes >= _pizza_due and location == "home":
		_pizza_due = -1.0
		lot.add_mess("pizza", lot.cell_to_world(Vector2i(10, 13)))
		Sfx.play("notice", -4.0)
		hud.show_notice("Pizza's here! It's waiting by the front door.", "Delivery")
	var count := lot.messes().size()
	var fires: Array[Furniture] = []
	for m in lot.messes():
		if m.kind == "fire":
			fires.append(m)
	for s in lot.sims:
		for fire in fires:
			if s.global_position.distance_to(fire.global_position) < 14.0:
				s.emotions.add("fire_scared", "tense", 3, "Terrified", "The house is on fire!", 30.0)
	# A fire gets everyone's attention at once: grown-ups drop what they chose
	# to do themselves and decide again (putting it out wins).
	if not fires.is_empty():
		for s in household:
			var cur := s.current_action()
			var on_it := cur != null and cur.furniture != null and cur.furniture.kind == "fire"
			if not on_it and (cur == null or cur.autonomous) and Ages.is_adult(s.age_stage) and not s.away:
				if cur != null:
					s.clear_queue()
				s.think_now()
	for s in household:
		if s.away:
			continue
		var limit := 1 if s.traits.has("neat") else 2
		if count >= limit and not s.traits.has("slob"):
			var w := mini(3, count / 2 + (1 if s.traits.has("neat") else 0))
			s.emotions.add("messy", "tense", maxi(w, 1), "Messy Surroundings", "There are dirty dishes and worse lying around.", 30.0)
		elif s.emotions.has("messy"):
			s.emotions.remove("messy")
		if s.traits.has("loner"):
			var near := 0
			for o in lot.sims:
				if o != s and o.visible and o.global_position.distance_to(s.global_position) < 5.0:
					near += 1
			if near >= 3:
				s.emotions.add("crowded", "tense", 1, "Too Many People", "Could use some alone time.", 30.0)


## Music follows the mode (title / Create a Sim, live, build); ambience follows
## the time of day.
func _update_audio() -> void:
	var title := _cas != null or (_menu != null and _menu is MainMenu) or has_node("Neighbourhood")
	if title:
		Sfx.music("music_cas")
		Sfx.ambience("")
	elif build.active:
		Sfx.music("music_build")
		Sfx.ambience("")
	else:
		Sfx.music("music_live")
		Sfx.ambience("crickets" if Daylight.is_dark(fmod(Clock.total_minutes, 1440.0) / 60.0) else "birds")


func open_main_menu() -> void:
	Clock.set_speed(0)
	hud.visible = false
	sim.set_selected(false)
	_stop_pan()
	rig.set_locked(true)
	_menu_orbit = true
	var menu := MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	menu.setup(SaveGame.exists(), _title_info())
	_menu = menu
	menu.options_pressed.connect(func():
		var gm := GameMenu.new()
		add_child(gm)
		gm.setup(SaveGame.exists(), false))
	if _open_manage_next:
		_open_manage_next = false
		menu.visible = false
		_open_manage_households(menu)
	menu.play_pressed.connect(func():
		_close_main_menu(menu)
		load_game())
	menu.new_game_pressed.connect(func():
		_close_main_menu(menu)
		open_create_a_sim())
	menu.manage_pressed.connect(func():
		# Load Game: pick a save slot, then a household in it.
		menu.visible = false
		var slots := SaveSlots.new()
		add_child(slots)
		slots.setup()
		slots.back.connect(func():
			slots.queue_free()
			menu.visible = true)
		slots.picked.connect(func(slot: String):
			slots.queue_free()
			SaveGame.current = slot
			_open_manage_households(menu)))


# --- several households -------------------------------------------------------------

## C: saves a screenshot to user://screenshots (optionally without the interface).
func take_screenshot() -> String:
	var hide_ui: bool = not Settings.get_value("capture_ui")
	var hud_was := hud.visible
	if hide_ui:
		hud.visible = false
		build.set_ui_hidden(true)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if hide_ui:
		hud.visible = hud_was
		build.set_ui_hidden(_ui_hidden)
	var k: float = Settings.CAPTURE_SCALES[Settings.get_value("capture_size")]
	if k != 1.0:
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/OpenSims_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	Sfx.play("select", -6.0)
	if Settings.get_value("capture_notice"):
		hud.show_notice("Screenshot saved to %s." % ProjectSettings.globalize_path(path), "Screenshot")
	return path


## Achievements for the menu: [title, how to earn it, unlocked?].
func achievements() -> Array:
	var any := func(f: Callable) -> bool: return household.any(f)
	var stat := func(k: String) -> int:
		var t := 0
		for m in household:
			t += int((m as Sim).stats.get(k, 0))
		return t
	return [
		["Making Friends", "Become good friends with someone.", any.call(func(m: Sim): return m.relationships.values().any(func(r: Vector2): return r.x >= 60.0))],
		["Wedding Bells", "Get married.", any.call(func(m: Sim): return m.spouse != null)],
		["Bundle of Joy", "Have a toddler in the household.", any.call(func(m: Sim): return m.age_stage == "toddler")],
		["Jack of All Trades", "Reach level 3 in five skills.", any.call(func(m: Sim): return Skills.ORDER.filter(func(k): return m.skills.level(k) >= 3).size() >= 5)],
		["Master of a Craft", "Max out any skill.", any.call(func(m: Sim): return Skills.ORDER.any(func(k): return m.skills.level(k) >= Skills.MAX_LEVEL))],
		["Top of the Ladder", "Reach the top of a career.", works.values().any(func(w: Work): return w.career != "" and not Careers.is_school(w.career) and w.level >= Careers.max_level(w.career))],
		["Dream Come True", "Complete an aspiration.", trackers.values().any(func(t: AspirationTracker): return t.milestone >= t.milestones().size())],
		["Green Thumb", "Harvest 10 times.", stat.call("harvests") >= 10],
		["Gone Fishing", "Catch 10 fish.", stat.call("fish") >= 10],
		["Art Dealer", "Sell 5 paintings.", stat.call("paintings_sold") >= 5],
		["Social Butterfly", "Socialize 100 times.", stat.call("socials") >= 100],
		["Big Spender", "Have §50,000 in the bank.", build.funds >= 50000],
	]


## "Lived in by" line and funds for the title screen, from the last save.
func _title_info() -> String:
	if not SaveGame.exists():
		return ""
	var s := _summary(_household_part(SaveGame.read()), true)
	return "Lived in by: %s\n%s" % [s["name"], Hud.money(s["funds"])]


## A saved household's summary line for the Manage Households screen.
static func _summary(h: Dictionary, last: bool) -> Dictionary:
	var names: Array = []
	for m in h.get("household", []):
		names.append(m.get("sim", {}).get("name", "?"))
	var home: String = Neighbourhood.LOTS.get(h.get("home", ""), {}).get("name", "A home")
	return {"name": "The %s Household" % (names[0] if not names.is_empty() else "New"), "members": names,
		"home": home, "funds": int(h.get("funds", 0)), "last": last}


## The household part of a saved world (without the world-wide keys).
static func _household_part(world: Dictionary) -> Dictionary:
	var h := world.duplicate(true)
	for k in WORLD_KEYS:
		h.erase(k)
	return h


func _open_manage_households(menu: MainMenu) -> void:
	var world := SaveGame.read()
	var all: Array = [_household_part(world)]
	all.append_array(world.get("others", []))
	var summaries: Array = []
	for i in all.size():
		summaries.append(_summary(all[i], i == 0))
	var screen := ManageHouseholds.new()
	add_child(screen)
	screen.setup(summaries)
	screen.back.connect(func():
		screen.queue_free()
		menu.visible = true)
	screen.play.connect(func(i: int):
		screen.queue_free()
		_close_main_menu(menu)
		# The chosen household becomes the active one; the rest wait in the world.
		var others: Array = []
		for k in all.size():
			if k != i:
				others.append(all[k])
		var next: Dictionary = all[i].duplicate(true)
		for k in WORLD_KEYS:
			if world.has(k):
				next[k] = world[k]
		next["others"] = others
		load_game(next))
	screen.new_household.connect(func():
		screen.queue_free()
		_close_main_menu(menu)
		# Everyone already in the world keeps their home; make a new family.
		other_households = all.duplicate(true)
		Clock.total_minutes = world.get("minutes", Clock.total_minutes)
		var everyone: Array = []
		if world.has("townies"):
			visitors.from_dict(world["townies"], everyone)
		for t in world.get("tips", []):
			_tips_seen[t] = true
		open_create_a_sim())


## Homes that other households live in: id -> household name.
func _occupied_homes() -> Dictionary:
	var out := {}
	for h in other_households:
		out[h.get("home", "")] = _summary(h, false)["name"]
	return out


func _close_main_menu(menu: MainMenu) -> void:
	_menu_orbit = false
	_menu = null
	menu.queue_free()


func open_game_menu() -> void:
	var m := GameMenu.new()
	m.name = "GameMenu"
	add_child(m)
	_menu = m
	m.closed.connect(func(): _menu = null)
	m.save_pressed.connect(save_game)
	m.save_as_pressed.connect(save_game_as)
	m.load_pressed.connect(load_game)
	m.main_menu_pressed.connect(func(): get_tree().reload_current_scene())
	m.manage_pressed.connect(func():
		# Like Manage Worlds: save, then pick a household from the title screen.
		save_game()
		_open_manage_next = true
		get_tree().reload_current_scene())
	m.setup(SaveGame.exists())


## The home's build: walls, finishes and objects (also kept while away travelling).
func _lot_dict() -> Dictionary:
	var walls: Array = []
	for e in lot.walls:
		walls.append([e.x, e.y, e.z, lot.doors.has(e), lot.windows.has(e), lot.wall_styles.get(e, 0)])
	var floors: Array = []
	for c in lot.floor_tiles:
		floors.append([c.x, c.y, lot.floor_tiles[c]])
	var objects: Array = []
	for f in lot.furniture:
		if f.kind in ["fire", "pool", "meal", "pizza"]:
			continue
		objects.append([f.kind, f.cell.x, f.cell.y, f.rot_steps, f.broken, f.variant, f.get_meta("item", {})])
	var pool_rects: Array = []
	for r in lot.pools:
		pool_rects.append([r.position.x, r.position.y, r.size.x, r.size.y, (lot.pools[r] as Furniture).has_ladders()])
	var fences: Array = []
	for e in lot.fences:
		fences.append([e.x, e.y, e.z, lot.gates.has(e), lot.fence_styles.get(e, 0)])
	return {"home": home_id, "walls": walls, "floors": floors, "objects": objects, "pools": pool_rects, "fences": fences, "roof": [lot.roof_style, lot.roof_color], "foundation": lot.foundation, "terrain": lot.terrain_tiles.keys().map(func(c): return [c.x, c.y, lot.terrain_tiles[c]]), "lot_traits": lot.lot_traits.duplicate(), "upper": _level_dict(upper)}


## Windows glow warmly at night while the house has power, as seen from outside.
func _update_window_glow() -> void:
	var on := Daylight.lit_now and not Daylight.power_off
	for l in levels:
		var g: StandardMaterial3D = (l as Lot)._glass_mat
		if g == null or g.emission_enabled == on:
			continue
		g.emission_enabled = on
		g.emission = Color(1.0, 0.78, 0.45)
		g.emission_energy_multiplier = 1.6
		g.albedo_color = Color(1.0, 0.85, 0.6, 0.85) if on else Color(0.7, 0.85, 0.95, 0.3)


func send_burglar() -> Burglar:
	var b := Burglar.start(self, lot, household, _story_rng)
	if b == null:
		return null
	Sfx.play("notice", -6.0)
	b.finished.connect(func(text: String, stolen: Furniture):
		if stolen != null and is_instance_valid(stolen):
			lot.remove_furniture(stolen)
			stolen.queue_free()
		hud.show_notice(text, "Burglar"))
	return b


## Saves on the Autosave interval from Game Options while playing at home.
func _autosave(delta: float) -> void:
	var mins: int = Settings.AUTOSAVE_MINUTES[Settings.get_value("autosave")]
	if mins <= 0 or _menu != null or _cas != null or build.active or location != "home" or not dialogs_enabled:
		_autosave_timer = 0.0
		return
	_autosave_timer += delta
	if _autosave_timer >= mins * 60.0:
		_autosave_timer = 0.0
		save_game()


## Raises (or lowers) the house onto a foundation; the upper storey moves with it.
func set_foundation(h: float) -> void:
	lot.set_foundation(h)
	upper.y_offset = h
	upper.position.y = Lot.WALL_HEIGHT + h
	for s in upper.sims:
		(s as Sim).global_position.y = upper.base_y()


## Walls, floors and objects of an upper level.
func _level_dict(l: Lot) -> Dictionary:
	var walls: Array = []
	for e in l.walls:
		walls.append([e.x, e.y, e.z, l.doors.has(e), l.windows.has(e), l.wall_styles.get(e, 0)])
	var floors: Array = []
	for c in l.floor_tiles:
		floors.append([c.x, c.y, l.floor_tiles[c]])
	var objects: Array = []
	for f in l.furniture:
		objects.append([f.kind, f.cell.x, f.cell.y, f.rot_steps, f.broken])
	return {"walls": walls, "floors": floors, "objects": objects}


func _apply_level_dict(l: Lot, d: Dictionary) -> void:
	l.clear_build()
	for f in d.get("floors", []):
		l.floor_tiles[Vector2i(int(f[0]), int(f[1]))] = int(f[2])
	l.add_floor(Rect2i(), 0)
	for w in d.get("walls", []):
		var e := Vector3i(int(w[0]), int(w[1]), int(w[2]))
		l.add_wall(e)
		if w[3]:
			l.add_door(e)
		if w[4]:
			l.add_window(e)
		l.paint_wall(e, int(w[5]))
	for o in d.get("objects", []):
		if Catalog.INFO.has(o[0]):
			var f := Catalog.create(o[0])
			l.place_furniture(f, Vector2i(int(o[1]), int(o[2])), int(o[3]))
			if o[4]:
				f.set_broken(true)


func _apply_lot_dict(d: Dictionary) -> void:
	lot.clear_build()
	_apply_level_dict(upper, d.get("upper", {}))
	home_id = d.get("home", "cottage")
	_place_grounds(home_id)
	for w in d.get("walls", []):
		var e := Vector3i(int(w[0]), int(w[1]), int(w[2]))
		lot.add_wall(e)
		if w[3]:
			lot.add_door(e)
		if w.size() > 5:
			if w[4]:
				lot.add_window(e)
			lot.paint_wall(e, int(w[5]))
	if d.has("floors"):
		lot.floor_tiles.clear()
		for f in d["floors"]:
			lot.floor_tiles[Vector2i(int(f[0]), int(f[1]))] = int(f[2])
		lot.add_floor(Rect2i(), 0)
	set_foundation(d.get("foundation", 0.0))
	for t in d.get("terrain", []):
		lot.terrain_tiles[Vector2i(int(t[0]), int(t[1]))] = int(t[2])
	lot.paint_terrain(Vector2i(-1, -1), 0)
	var roof: Array = d.get("roof", [0, 0])
	for l in levels:
		(l as Lot).set_roof(int(roof[0]), int(roof[1]))
		(l as Lot).lot_traits = d.get("lot_traits", []).duplicate()
	for fe in d.get("fences", []):
		var fe_e := Vector3i(int(fe[0]), int(fe[1]), int(fe[2]))
		lot.add_fence(fe_e, int(fe[4]) if fe.size() > 4 else 0)
		if fe[3]:
			lot.add_gate(fe_e)
	for p in d.get("pools", []):
		var pl := lot.add_pool(Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3])))
		if pl != null and p.size() > 4 and not p[4]:
			pl.apply_effect("ladders_off")
	for o in d.get("objects", []):
		if o[0] == "painting":
			var art := Catalog.make_painting(o[6] if o.size() > 6 else {})
			lot.place_furniture(art, Vector2i(int(o[1]), int(o[2])), int(o[3]))
			continue
		if Catalog.INFO.has(o[0]) and o[0] != "pool":
			var placed := _place(o[0], Vector2i(int(o[1]), int(o[2])), int(o[3]))
			if o.size() > 4 and o[4]:
				placed.set_broken(true)
			if o.size() > 5 and int(o[5]) > 0:
				placed.set_variant(int(o[5]))
			if o.size() > 6 and o[6] is Dictionary and not (o[6] as Dictionary).is_empty():
				placed.set_meta("item", (o[6] as Dictionary).duplicate())
				placed._update_flies()
				if o[0] == "planter":
					placed.refresh_garden()
				if placed.is_upgraded():
					placed._apply_upgrade()


func save_game() -> void:
	# Like the reference, no saving in the middle of an emergency.
	if lot.messes().any(func(m): return m.kind == "fire"):
		hud.show_notice("You can't save right now: there's a fire on the lot!", "Can't Save")
		return
	if SaveGame.write(_save_data()):
		hud.show_notice("Game saved.", "OpenSims")
	else:
		hud.show_notice("Couldn't save the game.", "OpenSims")


## Save As: asks for a name and saves to a new slot.
func save_game_as() -> void:
	var d := EventDialog.ask(self, null, "Save As", "Name this save:", ["Save", "Cancel"] as Array[String], SaveGame.next_free_name())
	d.answered.connect(func(i: int, text: String):
		if i == 0:
			if SaveGame.write_as(text, _save_data()):
				hud.show_notice("Saved as \"%s\"." % SaveGame.current, "OpenSims"))


func _save_data() -> Dictionary:
	var data := _lot_dict() if location == "home" else _home_snapshot.duplicate()
	data.merge({
		"version": 1,
		"minutes": Clock.total_minutes,
		"funds": build.funds,
		"household": household.map(func(m: Sim): return {
			"sim": m.to_dict(),
			"work": (works[m] as Work).to_dict(),
			"aspiration": (trackers[m] as AspirationTracker).to_dict(),
		}),
		"active": household.find(sim),
		"townies": visitors.to_dict(),
		"bills": bills.to_dict(),
		"tips": _tips_seen.keys(),
		"others": other_households,
	}, true)
	return data


func load_game(world := {}) -> void:
	var d := world if not world.is_empty() else SaveGame.read()
	if d.is_empty():
		hud.show_notice("No saved game found.", "OpenSims")
		_enter_live()
		return
	Clock.total_minutes = d.get("minutes", Clock.total_minutes)
	build.funds = int(d.get("funds", build.funds))
	build.funds_changed.emit(build.funds)
	sim.clear_queue()
	visitors.send_all_home()
	_set_location("home")
	_apply_lot_dict(d)
	var members: Array = d.get("household", [])
	if members.is_empty() and d.has("sim"):
		members = [{"sim": d["sim"], "work": d.get("work", {}), "aspiration": d.get("aspiration", {})}]
	# Match the household size to the save, then fill everyone in.
	while household.size() < members.size():
		add_to_household(_new_sim(""))
	while household.size() > maxi(members.size(), 1):
		remove_from_household(household[household.size() - 1])
	for m in household:
		m.lot = lot
	var everyone: Array = household.duplicate()
	everyone.append_array(visitors.townies)
	for i in members.size():
		var m: Dictionary = members[i]
		household[i].from_dict(m.get("sim", {}), everyone)
		(works[household[i]] as Work).from_dict(m.get("work", {}))
		(trackers[household[i]] as AspirationTracker).from_dict(m.get("aspiration", {}))
	# Townies who moved in live in the household now, not the townie pool.
	for m in household:
		for t in visitors.townies.duplicate():
			if t.sim_name == m.sim_name:
				visitors.remove_townie(t)
				everyone.erase(t)
				lot.sims.erase(t)
				t.queue_free()
	if d.has("townies"):
		visitors.from_dict(d["townies"], everyone)
	elif d.has("neighbour"):
		visitors.from_dict([d["neighbour"]], everyone, false)
	bills.from_dict(d.get("bills", {}))
	other_households = d.get("others", []).duplicate(true)
	for t in d.get("tips", []):
		_tips_seen[t] = true
	select_sim(household[clampi(int(d.get("active", 0)), 0, household.size() - 1)])
	_enter_live(false)
	hud.show_notice("Welcome back! Your game was loaded.", "OpenSims")


# --- travelling --------------------------------------------------------------------

## Takes the whole household to a community lot or back home, with a short
## loading screen. The home is rebuilt exactly as it was.
func travel(dest: String) -> void:
	if dest == location:
		return
	if build.active:
		build.exit()
	var cover := _loading_screen("Travelling to %s..." % ("home" if dest == "home" else COMMUNITY_LOTS[dest]["name"]))
	await get_tree().create_timer(0.6).timeout
	if location == "home":
		_home_snapshot = _lot_dict()
	for m in household:
		m.clear_queue()
	visitors.send_all_home()
	if dest == "home":
		_apply_lot_dict(_home_snapshot)
	else:
		lot.clear_build()
		upper.clear_build()
		_place_community(dest)
	_set_location(dest)
	set_level(0)
	for i in household.size():
		var m := household[i]
		m.lot = lot
		if not m.away:
			m.global_position = lot.cell_to_world(Vector2i(9 + i, lot.size.y - 2))
	if dest != "home":
		visitors.populate(3, [lot.cell_to_world(Vector2i(6, 8)), lot.cell_to_world(Vector2i(16, 6)), lot.cell_to_world(Vector2i(14, 13))])
		hud.show_notice("Welcome to %s! %s" % [COMMUNITY_LOTS[dest]["name"], COMMUNITY_LOTS[dest]["description"]], "Travel")
	else:
		hud.show_notice("Home sweet home.", "Travel")
	rig.frame(lot.center(), rig.yaw, rig.pitch, 22.0)
	var tw := cover.create_tween()
	tw.tween_property(cover.get_child(0), "modulate:a", 0.0, 0.5)
	tw.tween_callback(cover.queue_free)


func _set_location(dest: String) -> void:
	location = dest
	visitors.at_home = dest == "home"
	bills.active = dest == "home"
	build.allowed = dest == "home"


func _loading_screen(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.3, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var plumbob := MainMenu.Logo.new()
	plumbob.custom_minimum_size = Vector2(420, 120)
	plumbob.set_anchors_preset(Control.PRESET_CENTER)
	plumbob.position = Vector2(-210, -120)
	bg.add_child(plumbob)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-300, 30)
	l.size = Vector2(600, 40)
	bg.add_child(l)
	return layer


## A community lot: the park, the gym, the library or the lounge.
func _place_community(dest: String) -> void:
	home_id = dest
	match dest:
		"gym", "library", "lounge":
			_place_venue(dest)
			return
	lot.add_floor(Rect2i(11, 0, 2, lot.size.y), 8)
	lot.add_floor(Rect2i(0, 9, lot.size.x, 2), 8)
	lot.add_floor(Rect2i(9, 7, 6, 6), 8)
	_place("fountain", Vector2i(11, 9))
	_place("bench", Vector2i(9, 6), 0)
	_place("bench", Vector2i(13, 13), 2)
	_place("bench", Vector2i(15, 7), 0)
	_place("picnic_table", Vector2i(3, 3))
	_place("picnic_table", Vector2i(18, 14))
	_place("grill", Vector2i(6, 3), 0)
	_place("grill", Vector2i(21, 14), 0)
	_place("chess", Vector2i(17, 3))
	_place("pond", Vector2i(3, 15))
	_place("monkey_bars", Vector2i(17, 17))
	for c in [Vector2i(22, 5), Vector2i(1, 9)]:
		_place("pine", c)
	for c in [Vector2i(8, 4), Vector2i(14, 11), Vector2i(20, 12)]:
		_place("flower_shrub", c)
	_place("flower_bed", Vector2i(13, 5))
	_place("flower_bed", Vector2i(9, 14))
	_place("telescope", Vector2i(19, 5))
	for c in [Vector2i(1, 1), Vector2i(8, 1), Vector2i(15, 1), Vector2i(21, 2), Vector2i(2, 13), Vector2i(7, 15), Vector2i(20, 8), Vector2i(4, 7)]:
		_place("tree", c)
	for c in [Vector2i(9, 13), Vector2i(14, 6), Vector2i(1, 17), Vector2i(22, 17), Vector2i(5, 11)]:
		_place("bush", c)


## An indoor venue: one big room with the right furniture.
func _place_venue(dest: String) -> void:
	var floor_style: int = {"gym": 8, "library": 2, "lounge": 7}[dest]
	var wall_style: int = {"gym": 3, "library": 6, "lounge": 4}[dest]
	lot.add_floor(Rect2i(3, 2, 18, 12), floor_style)
	for r in [[Vector2i(3, 2), Vector2i(21, 2)], [Vector2i(3, 14), Vector2i(21, 14)], [Vector2i(3, 2), Vector2i(3, 14)], [Vector2i(21, 2), Vector2i(21, 14)]]:
		for e in Lot.wall_run(r[0], r[1]):
			lot.add_wall(e)
			lot.paint_wall(e, wall_style)
	lot.add_door(Vector3i(11, 14, 0))
	lot.add_door(Vector3i(12, 14, 0))
	for e in [Vector3i(6, 14, 0), Vector3i(17, 14, 0), Vector3i(6, 2, 0), Vector3i(12, 2, 0), Vector3i(17, 2, 0), Vector3i(3, 8, 1), Vector3i(21, 8, 1)]:
		lot.add_window(e)
	for c in [Vector2i(4, 3), Vector2i(20, 3), Vector2i(4, 13), Vector2i(20, 13)]:
		_place("lamp", c)
	match dest:
		"gym":
			for i in 4:
				_place("treadmill", Vector2i(6 + i * 2, 3))
			for i in 3:
				_place("mirror", Vector2i(16 + i, 3))
			_place("bench", Vector2i(7, 10), 2)
			_place("plant", Vector2i(20, 8))
			_place("fridge", Vector2i(19, 9), 3)
			_place("toilet", Vector2i(4, 9), 1)
			_place("shower", Vector2i(4, 11), 1)
		"library":
			for i in 6:
				_place("bookshelf", Vector2i(5 + i * 2, 3))
			_place("desk", Vector2i(6, 8))
			_place("desk", Vector2i(10, 8))
			_place("chess", Vector2i(16, 8))
			_place("chess", Vector2i(18, 10))
			_place("sofa", Vector2i(14, 12), 2)
			_place("plant", Vector2i(20, 6))
			_place("toilet", Vector2i(4, 9), 1)
		"lounge":
			_place("bar", Vector2i(9, 4))
			_place("bar", Vector2i(12, 4))
			_place("sofa", Vector2i(5, 8), 1)
			_place("sofa", Vector2i(17, 9), 3)
			_place("guitar", Vector2i(18, 4))
			_place("piano", Vector2i(5, 4))
			_place("chess", Vector2i(10, 10))
			_place("plant", Vector2i(4, 6))
			_place("plant", Vector2i(20, 6))
			_place("toilet", Vector2i(4, 12), 1)
	lot.add_floor(Rect2i(11, 14, 2, 4), 8)


## Shows Create a Sim over a paused game: the Sim stands in a studio away from
## the lot, centred between the panels.
func open_create_a_sim() -> void:
	Clock.set_speed(0)
	hud.visible = false
	sim.set_selected(false)
	_studio = CreateASim.make_studio(CAS_STUDIO)
	add_child(_studio)
	_stop_pan()
	rig.set_locked(true)
	_frame_creator(false)
	var studio_env := Environment.new()
	studio_env.background_mode = Environment.BG_COLOR
	studio_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	studio_env.ambient_light_color = Color(0.78, 0.84, 0.95)
	studio_env.ambient_light_energy = 0.25
	studio_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	studio_env.ssao_enabled = true
	rig.camera.environment = studio_env
	_cas = CreateASim.new()
	_cas.name = "CreateASim"
	add_child(_cas)
	_cas.setup(sim)
	_cas.set_household(household, MAX_HOUSEHOLD)
	_cas.finished.connect(_on_cas_finished)
	_cas.member_selected.connect(_cas_show)
	_cas.view_requested.connect(_frame_creator)
	_cas.add_requested.connect(func():
		var s := _new_sim("")
		add_to_household(s)
		_cas.randomize_sim_for(s)
		_cas_show(s))
	_cas.remove_requested.connect(func(s: Sim):
		remove_from_household(s)
		_cas.set_household(household, MAX_HOUSEHOLD)
		_cas_show(household[0]))
	_cas_show(sim)


## Keep direct-edit regions framed at every supported character scale.
func _frame_creator(close_up: bool) -> void:
	var scale_factor := sim.size_scale()
	rig.frame(CAS_STUDIO + (sim.age_point(Vector3(0,1.69,0)) * scale_factor if close_up else Vector3(0,.95,0)), 0.0, deg_to_rad(-2.0), .8 * scale_factor if close_up else 3.3)


## Puts `s` on the studio floor (the others step out of view) and edits them.
func _cas_show(s: Sim) -> void:
	for m in household:
		m.visible = m == s
		m.away = m != s
		m.clear_queue()
		m.creator_preview = true
	s.global_position = CAS_STUDIO
	for node in s.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.has_meta("cas_original_layers"):
			mesh.set_meta("cas_original_layers", mesh.layers)
		mesh.layers = 8 | Sim.PORTRAIT_LAYER
	# Turned slightly towards the camera, which looks along -Z.
	s.rotation.y = PI - 0.25
	select_sim(s)
	s.set_selected(false)
	_cas.edit(s)
	_cas.set_household(household, MAX_HOUSEHOLD)


func _on_cas_finished() -> void:
	rig.camera.environment = null
	for member in household:
		member.creator_preview = false
		for node in member.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.has_meta("cas_original_layers"):
				mesh.layers = int(mesh.get_meta("cas_original_layers"))
				mesh.remove_meta("cas_original_layers")
	for m in household:
		m.change_outfit("everyday", false)
	_cas = null
	_studio.queue_free()
	for i in household.size():
		var m := household[i]
		m.visible = true
		m.away = false
		m.global_position = lot.cell_to_world(Vector2i(9 + i, 14))
	# Housemates already know each other.
	for a_sim in household:
		for b_sim in household:
			if a_sim != b_sim and not a_sim.relationships.has(b_sim):
				a_sim.change_relationship(b_sim, 35.0, 0.0)
	for m in household:
		life.enrol(m)
	select_sim(household[0])
	open_neighbourhood()


## The world map: pick a home, pay for it, and move in.
func open_neighbourhood() -> void:
	var map := Neighbourhood.new()
	map.name = "Neighbourhood"
	add_child(map)
	map.setup(build.funds, _occupied_homes())
	map.chosen.connect(_on_home_chosen)


func _on_home_chosen(lot_id: String, price: int) -> void:
	lot.clear_build()
	_place_house(lot_id)
	build.funds -= price
	build.funds_changed.emit(build.funds)
	hud.show_notice("Welcome home to %s! %s was spent on the move." % [Neighbourhood.LOTS[lot_id]["name"], Hud.money(price)], "Moved In")
	for i in household.size():
		household[i].global_position = lot.cell_to_world(Vector2i(9 + i, 14))
	_enter_live()


func _enter_live(fresh := true) -> void:
	hud.visible = true
	hud.refresh_identity()
	life._last_day = Clock.day()
	if fresh:
		for m in household:
			(trackers[m] as AspirationTracker).reset()
	sim.set_selected(true)
	rig.set_locked(false)
	rig.frame(lot.center(), deg_to_rad(35.0), deg_to_rad(-50.0), 22.0)
	Clock.set_speed(1)


## Saves, changes things, loads, and prints whether everything came back.
func _save_load_check() -> void:
	await get_tree().process_frame
	_enter_live()
	work.join("painter")
	sim.sim_name = "Saved Sim"
	sim.skills.add_xp("painting", 500.0)
	build.funds = 12345
	_place("lamp", Vector2i(12, 6))
	var objects_before := lot.furniture.size()
	Clock.total_minutes = 1000.0
	save_game()
	sim.sim_name = "Changed"
	build.funds = 1
	work.quit()
	lot.clear_build()
	Clock.total_minutes = 5.0
	load_game()
	await get_tree().process_frame
	var ok := sim.sim_name == "Saved Sim" and build.funds == 12345 and work.career == "painter" 		and lot.furniture.size() == objects_before and absf(Clock.total_minutes - 1000.0) < 5.0 and not lot.walls.is_empty()
	print("SAVELOAD %s name=%s funds=%d career=%s objects=%d/%d" % ["OK" if ok else "FAIL", sim.sim_name, build.funds, work.career, lot.furniture.size(), objects_before])
	get_tree().quit()


## Drives the game with injected mouse and keyboard events (the same path real
## input takes) and prints what worked.
func _input_check() -> void:
	_enter_live()
	await get_tree().create_timer(0.5).timeout
	var results := {}
	# Click the TV: its pie menu opens; pick the first option.
	var tv := find_furniture("tv")
	# Frame the TV so it sits clear of the HUD whatever the window size.
	_stop_pan()
	rig.frame(tv.global_position, deg_to_rad(30.0), deg_to_rad(-45.0), 12.0)
	await get_tree().process_frame
	await _click(rig.camera.unproject_position(tv.global_position + Vector3(0, 0.8, 0)))
	results["pie_opens"] = hud.pie_menu.visible
	var option: Button = null
	for c in hud.pie_menu.get_children():
		if c is Button:
			option = c
			break
	if option != null:
		await _click(option.get_global_rect().get_center())
	results["queued_tv"] = sim.queue.any(func(a): return a.furniture == tv)
	# Click the ground: a Go Here action.
	sim.clear_queue()
	await _click(rig.camera.unproject_position(lot.cell_to_world(Vector2i(10, 15))))
	var go_btn: Button = null
	for c in hud.pie_menu.get_children():
		if c is Button and (c as Button).text == "Go Here":
			go_btn = c
	if go_btn != null:
		await _click(go_btn.get_global_rect().get_center())
	results["go_here"] = sim.queue.size() == 1 and sim.queue[0].label == "Go Here"
	# F3 opens build mode; drag a wall; F1 leaves.
	await _key(KEY_F3)
	results["build_opens"] = build.active
	build.set_tool(BuildMode.Tool.WALL)
	var walls_before := lot.walls.size()
	var a := rig.camera.unproject_position(Vector3(20, 0, 14))
	var b := rig.camera.unproject_position(Vector3(23, 0, 14))
	await _press(a, true)
	await _move(b)
	await _press(b, false)
	results["wall_drag"] = lot.walls.size() == walls_before + 3
	await _key(KEY_F1)
	results["build_closes"] = not build.active
	# Esc opens the game menu, Esc again closes it.
	await _key(KEY_ESCAPE)
	results["menu_opens"] = _menu is GameMenu
	await _key(KEY_ESCAPE)
	results["menu_closes"] = _menu == null
	# Speed keys.
	await _key(KEY_3)
	results["speed_keys"] = Clock.speed == 3
	# The reference game's live-mode hotkeys.
	await _key(KEY_L)
	results["L_skills"] = hud._info_panel.visible and hud._pages[1].visible
	await _key(KEY_G)
	results["G_aspiration"] = hud._pages[5].visible
	var walls_before_view := lot.wall_view
	await _key(KEY_END)
	results["End_walls_down"] = lot.wall_view == mini(2, walls_before_view + 1)
	await _key(KEY_HOME)
	results["Home_walls_up"] = lot.wall_view == walls_before_view
	await _key(KEY_QUOTELEFT)
	results["backtick_pause"] = Clock.speed == 0 and hud._pause_frame.visible
	await _key(KEY_TAB)
	results["Tab_hides_ui"] = not hud.visible
	await _key(KEY_TAB)
	results["Tab_shows_ui"] = hud.visible
	var shots_before := DirAccess.get_files_at("user://screenshots").size() if DirAccess.dir_exists_absolute("user://screenshots") else 0
	await _key(KEY_C)
	for k in 6:
		await get_tree().process_frame
	results["C_screenshot"] = DirAccess.dir_exists_absolute("user://screenshots") and DirAccess.get_files_at("user://screenshots").size() > shots_before
	var ok := results.values().all(func(v): return v)
	print("INPUT %s %s" % ["OK" if ok else "FAIL", results])
	get_tree().quit()


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	await get_tree().process_frame


func _click(at: Vector2) -> void:
	await _move(at)
	await _press(at, true)
	await _press(at, false)
	await get_tree().create_timer(0.1).timeout


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().process_frame


## Two families in one world: save the first, start a second in another home,
## then switch back and check each kept their own life.
func _households_check() -> void:
	await get_tree().process_frame
	_enter_live()
	build.funds = 11111
	save_game()
	# Start a new household the way Manage Households does.
	var world := SaveGame.read()
	other_households = [_household_part(world)]
	household[0].sim_name = "Bea"
	lot.clear_build()
	_place_house("studio")
	build.funds = 22222
	var occupied := _occupied_homes().keys()
	save_game()
	# Now play the first household again.
	world = SaveGame.read()
	var all: Array = [_household_part(world)]
	all.append_array(world.get("others", []))
	var first: Dictionary = all[1].duplicate(true)
	for k in WORLD_KEYS:
		if world.has(k):
			first[k] = world[k]
	first["others"] = [all[0]]
	load_game(first)
	await get_tree().process_frame
	var ok: bool = sim.sim_name == "Alex" and build.funds == 11111 and home_id == "cottage" and occupied == ["cottage"] 		and other_households.size() == 1 and _summary(other_households[0], false)["members"] == ["Bea"] and int(other_households[0]["funds"]) == 22222
	print("HOUSEHOLDS %s sim=%s funds=%d home=%s others=%s occupied=%s" % ["OK" if ok else "FAIL", sim.sim_name, build.funds, home_id, other_households.map(func(h): return _summary(h, false)["name"]), occupied])
	get_tree().quit()


## Headless smoke run: queue a few actions and log what the Sim does.
func _trace() -> void:
	Clock.set_speed(3)
	sim.needs.set_value("bladder", 20.0)
	sim.needs.set_value("fun", 25.0)
	for i in 40:
		await get_tree().create_timer(0.5).timeout
		var cur := sim.current_action()
		print("t=%.1f %s action=%s auto=%s performing=%s needs=%s" % [i * 0.5, Clock.time_string(), cur.label if cur else "-", cur.autonomous if cur else false, cur.performing if cur else false, sim.needs.values])
	get_tree().quit()


func _run_scenario(scenario: String, path: String) -> void:
	if path != "":
		get_viewport().set_disable_input(true)
	await get_tree().create_timer(0.5).timeout
	match scenario:
		"menu":
			# Wait for the catalogue thumbnails (the queue shows them).
			await get_tree().create_timer(2.5).timeout
			sim.emotions.add("lit_inspired", "inspired", 1, "Inspired by Literature", "", 120.0)
			sim.needs.set_value("hunger", 25.0)
			var desk := find_furniture("desk")
			sim.queue_interaction(find_furniture("fridge"), find_furniture("fridge").interactions[0])
			sim.queue_interaction(desk, desk.interactions[1])
			sim.queue_go(lot.cell_to_world(Vector2i(10, 14)))
			await get_tree().create_timer(2.5).timeout
			open_menu(find_furniture("bed"), rig.camera.unproject_position(find_furniture("bed").global_position + Vector3.UP))
		"household":
			var bea := _new_sim("Bea")
			bea.set_part_color("shirt", Color(0.85, 0.3, 0.45))
			bea.set_hair_style("long")
			var bt: Array[String] = ["genius", "lazy"]
			bea.set_traits(bt)
			add_to_household(bea)
			select_sim(bea)
			bea.change_relationship(household[0], 55.0, 20.0)
			hud._show_page(3)
			await get_tree().create_timer(2.0).timeout
		"cas2":
			open_create_a_sim()
			_cas.add_requested.emit()
			await get_tree().create_timer(1.0).timeout
		"bills":
			Clock.total_minutes = 3.0 * 1440.0 + 9.5 * 60.0
			await get_tree().create_timer(0.5).timeout
			var mb := find_furniture("mailbox")
			sim.queue_interaction(mb, mb.interactions[0])
			Clock.set_speed(2)
			await get_tree().create_timer(3.0).timeout
		"loadgame":
			SaveGame.write_as("Willow Creek Family", _save_data())
			build.funds = 54321
			SaveGame.write_as("Holiday Home", _save_data())
			open_main_menu()
			await get_tree().create_timer(0.3).timeout
			(_menu as MainMenu).manage_pressed.emit()
			await get_tree().create_timer(0.8).timeout
		"title":
			open_main_menu()
			await get_tree().create_timer(1.5).timeout
		"gamemenu":
			open_game_menu()
			await get_tree().create_timer(0.8).timeout
		"night", "dusk":
			Clock.total_minutes = (22.0 if scenario == "night" else 19.4) * 60.0
			Clock.set_speed(0)
			await get_tree().create_timer(1.0).timeout
		"sleep":
			Clock.set_speed(3)
			sim.needs.set_value("energy", 30.0)
			sim.queue_interaction(find_furniture("bed"), find_furniture("bed").interactions[0])
			sim.queue_interaction(find_furniture("toilet"), find_furniture("toilet").interactions[0])
			await get_tree().create_timer(2.5).timeout
		"mood":
			var easel := find_furniture("easel")
			var books := find_furniture("bookshelf")
			sim.skills.add_xp("painting", 420.0)
			sim.skills.add_xp("cooking", 120.0)
			sim.needs.set_value("hunger", 25.0)
			sim.emotions.add("lit_inspired", "inspired", 1, "Inspired by Literature", "Browsing books sparked some new ideas.", 120.0)
			sim.emotions.add("trait_creative", "inspired", 1, "Creative Spark", "An idea is forming!", 240.0)
			sim.queue_interaction(easel, easel.interactions[0])
			sim.queue_interaction(books, books.interactions[1])
			hud._show_page(1)
			await get_tree().create_timer(6.0).timeout
		"map":
			hud.visible = false
			open_neighbourhood()
			var map := get_node("Neighbourhood") as Neighbourhood
			map.select("cottage")
			map._view.selected = "cottage"
			map._view.queue_redraw()
			await get_tree().create_timer(1.0).timeout
		"studio":
			open_neighbourhood()
			(get_node("Neighbourhood") as Neighbourhood).choose("studio")
			await get_tree().create_timer(2.0).timeout
		"aspiration":
			sim.skills.add_xp("painting", Skills.xp_for_level(2))
			sim.skills.add_xp("cooking", Skills.xp_for_level(2))
			hud._show_page(5)
			await get_tree().create_timer(1.5).timeout
		"career":
			Clock.total_minutes = 8.0 * 60.0 + 50.0
			work.join("tech")
			hud._show_page(4)
			Clock.set_speed(3)
			await get_tree().create_timer(3.0).timeout
		"street":
			lot.wall_view = Lot.WallView.UP
			hud.refresh_walls_button(lot)
			rig.frame(lot.center() + Vector3(0, 0, 4), deg_to_rad(25.0), deg_to_rad(-28.0), 42.0)
			await get_tree().create_timer(1.0).timeout
		"streetnight":
			lot.wall_view = Lot.WallView.UP
			Clock.total_minutes = 22.0 * 60.0
			Clock.set_speed(0)
			rig.frame(lot.center() + Vector3(0, 0, 4), deg_to_rad(25.0), deg_to_rad(-28.0), 42.0)
			await get_tree().create_timer(1.0).timeout
		"park":
			Clock.total_minutes = 11.0 * 60.0
			await travel("park")
			Clock.set_speed(2)
			await get_tree().create_timer(4.0).timeout
		"phone":
			hud._toggle_phone()
			await get_tree().create_timer(0.6).timeout
		"hobbies":
			var tm := find_furniture("treadmill")
			sim.queue_interaction(tm, tm.interactions[0])
			var bea := _new_sim("Bea")
			add_to_household(bea)
			bea.set_hair_style("long")
			bea.set_part_color("shirt", Color(0.9, 0.4, 0.5))
			bea.global_position = lot.cell_to_world(Vector2i(13, 13))
			var gt := find_furniture("guitar")
			bea.queue_interaction(gt, gt.interactions[0])
			Clock.set_speed(2)
			hud._show_page(1)
			await get_tree().create_timer(4.0).timeout
			Clock.set_speed(1)
			await get_tree().create_timer(0.4).timeout
		"dialog":
			dialogs_enabled = true
			visitors.bring(visitors.townies[2], INF)
			_on_doorbell(visitors.townies[2])
			await get_tree().create_timer(0.8).timeout
		"pool":
			var pool := lot.add_pool(Rect2i(13, 13, 5, 2))
			sim.queue_interaction(pool, pool.interactions[0])
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(15, 13)), deg_to_rad(20.0), deg_to_rad(-38.0), 14.0)
			await get_tree().create_timer(5.0).timeout
		"fishing":
			Clock.total_minutes = 11.0 * 60.0
			await travel("park")
			var pond := find_furniture("pond")
			sim.queue_interaction(pond, pond.interactions[0])
			Clock.set_speed(2)
			rig.frame(pond.global_position, deg_to_rad(20.0), deg_to_rad(-25.0), 7.0)
			await get_tree().create_timer(2.5).timeout
		"piano":
			await travel("lounge")
			var pn := find_furniture("piano")
			sim.queue_interaction(pn, pn.interactions[0])
			Clock.set_speed(2)
			lot.wall_view = Lot.WallView.CUTAWAY
			rig.frame(pn.global_position, deg_to_rad(25.0), deg_to_rad(-35.0), 8.0)
			await get_tree().create_timer(4.0).timeout
		"gamemenu":
			open_game_menu()
			await get_tree().create_timer(0.8).timeout
		"achievements":
			dialogs_enabled = true
			open_game_menu()
			await get_tree().process_frame
			(_menu as GameMenu)._open_achievements()
			await get_tree().create_timer(0.8).timeout
		"rooms":
			build.enter()
			build._show_category("rooms")
			build.start_place_room(2)
			build.handle_input(_fake_click(lot.cell_to_world(Vector2i(1, 17))))
			build.start_place_room(3)
			build.handle_input(_fake_click(lot.cell_to_world(Vector2i(9, 17))))
			build.start_place_room(3)
			build.handle_input(_fake_click(lot.cell_to_world(Vector2i(16, 17))))
			build.undo()
			rig.frame(lot.cell_to_world(Vector2i(10, 17)), deg_to_rad(10.0), deg_to_rad(-50.0), 19.0)
			await get_tree().create_timer(1.0).timeout
			print("ROOMS undo=%d redo=%d" % [build._undo.size(), build._redo.size()])
		"showroom5":
			lot.add_floor(Rect2i(1, 12, 22, 7), 0)
			var row := [["toybox", Vector2i(1, 12)], ["piano", Vector2i(3, 12)], ["telescope", Vector2i(6, 12)], ["single_bed", Vector2i(8, 12)], ["dollhouse", Vector2i(10, 12)], ["activity_table", Vector2i(12, 12)], ["sculpture", Vector2i(14, 12)], ["column", Vector2i(16, 12)], ["bathroom_sink", Vector2i(18, 12)],
				["coffee_table", Vector2i(2, 16)], ["end_table", Vector2i(5, 16)], ["trash_can", Vector2i(7, 16)], ["planter", Vector2i(9, 16)], ["pond", Vector2i(11, 16)], ["basketball_hoop", Vector2i(16, 16)]]
			for k in row:
				_place(k[0], k[1])
			rig.frame(lot.cell_to_world(Vector2i(10, 14)), deg_to_rad(5.0), deg_to_rad(-45.0), 16.0)
			await get_tree().create_timer(1.2).timeout
		"showroom4":
			lot.add_floor(Rect2i(2, 13, 20, 6), 0)
			for k in [["loveseat", Vector2i(2, 13)], ["armchair", Vector2i(5, 13)], ["wardrobe", Vector2i(7, 13)], ["dresser", Vector2i(10, 13)], ["bathtub", Vector2i(13, 13)], ["cactus", Vector2i(16, 13)], ["patio_lounger", Vector2i(3, 16)], ["patio_table", Vector2i(6, 17)], ["counter", Vector2i(9, 17)], ["counter", Vector2i(10, 17)]]:
				_place(k[0], k[1])
			var mw := Catalog.create("microwave")
			lot.place_furniture(mw, Vector2i(9, 17), 0)
			var cm := Catalog.create("coffee_maker")
			lot.place_furniture(cm, Vector2i(10, 17), 0)
			rig.frame(lot.cell_to_world(Vector2i(9, 15)), deg_to_rad(5.0), deg_to_rad(-42.0), 13.0)
			await get_tree().create_timer(1.2).timeout
		"showroom3":
			lot.add_floor(Rect2i(2, 15, 18, 4), 0)
			_place("loveseat", Vector2i(3, 16))
			_place("cactus", Vector2i(6, 16))
			_place("patio_lounger", Vector2i(9, 15))
			_place("patio_table", Vector2i(13, 16))
			rig.frame(lot.cell_to_world(Vector2i(9, 16)), deg_to_rad(5.0), deg_to_rad(-38.0), 12.0)
			await get_tree().create_timer(1.0).timeout
		"uniform":
			sim.wear_uniform("culinary")
			rig.frame(sim.global_position, deg_to_rad(20.0), deg_to_rad(-25.0), 4.5)
			await get_tree().create_timer(1.2).timeout
		"cake":
			var cake := Catalog.create("cake")
			lot.place_furniture(cake, Vector2i(11, 9), 0)
			rig.frame(cake.global_position, deg_to_rad(20.0), deg_to_rad(-40.0), 4.0)
			await get_tree().create_timer(0.5).timeout
			open_menu(cake, rig.camera.unproject_position(cake.global_position + Vector3(0, 0.2, 0)))
			await get_tree().create_timer(0.6).timeout
		"selfmenu":
			Clock.total_minutes = 22 * 60.0
			rig.frame(sim.global_position, deg_to_rad(20.0), deg_to_rad(-45.0), 8.0)
			await get_tree().create_timer(0.6).timeout
			open_self_menu(rig.camera.unproject_position(sim.global_position + Vector3(0, 1.0, 0)))
			await get_tree().create_timer(0.6).timeout
			hud.pie_menu.chosen.emit(2)
			await get_tree().create_timer(1.5).timeout
			print("SELF queue=%s" % [sim.queue.map(func(q): return q.label)])
			open_self_menu(rig.camera.unproject_position(sim.global_position + Vector3(0, 1.0, 0)))
			await get_tree().create_timer(0.6).timeout
		"simology":
			hud.toggle_page(2)
			await get_tree().create_timer(0.6).timeout
		"decor":
			var desk := find_furniture("desk")
			var dc := desk.cell
			for pair in [["table_lamp", dc], ["book_stack", dc + Vector2i(1, 0)]]:
				var d := Catalog.create(pair[0])
				if lot.can_place(d, pair[1], desk.rot_steps):
					lot.place_furniture(d, pair[1], desk.rot_steps)
				else:
					d.free()
			var mw := find_furniture("microwave")
			for pair in [["fruit_bowl", mw.cell + Vector2i(0, 0)], ["vase_flowers", mw.cell + Vector2i(-1, 0)]]:
				var d2 := Catalog.create(pair[0])
				if lot.can_place(d2, pair[1], 0):
					lot.place_furniture(d2, pair[1], 0)
				else:
					d2.free()
			Clock.total_minutes = 21 * 60.0
			rig.frame(desk.global_position, deg_to_rad(15.0), deg_to_rad(-40.0), 7.0)
			await get_tree().create_timer(1.0).timeout
		"countertop":
			var mw := find_furniture("microwave")
			rig.frame(mw.global_position, deg_to_rad(15.0), deg_to_rad(-35.0), 5.0)
			await get_tree().create_timer(1.0).timeout
		"showroom2":
			lot.add_floor(Rect2i(2, 15, 18, 4), 3)
			for e in Lot.wall_run(Vector2i(2, 15), Vector2i(20, 15)):
				lot.add_wall(e)
			_place("microwave", Vector2i(3, 15))
			_place("coffee_maker", Vector2i(4, 15))
			_place("bathroom_sink", Vector2i(6, 15))
			_place("nightstand", Vector2i(8, 15))
			_place("wardrobe", Vector2i(10, 15))
			_place("wall_lamp", Vector2i(13, 15), 0)
			_place("basketball_hoop", Vector2i(16, 16))
			Clock.total_minutes = 21 * 60.0
			lot.wall_view = Lot.WallView.UP
			rig.frame(lot.cell_to_world(Vector2i(10, 16)), deg_to_rad(0.0), deg_to_rad(-30.0), 12.0)
			await get_tree().create_timer(1.2).timeout
		"dirty":
			var tl := find_furniture("toilet")
			tl.set_dirt(90.0)
			rig.frame(tl.global_position, deg_to_rad(20.0), deg_to_rad(-45.0), 6.0)
			await get_tree().create_timer(1.0).timeout
			open_menu(tl, rig.camera.unproject_position(tl.global_position + Vector3(0, 0.5, 0)))
			await get_tree().create_timer(0.6).timeout
		"upgrademenu":
			var st := find_furniture("stove")
			rig.frame(st.global_position, deg_to_rad(20.0), deg_to_rad(-50.0), 12.0)
			await get_tree().create_timer(0.5).timeout
			var at := rig.camera.unproject_position(st.global_position + Vector3(0, 0.5, 0))
			open_menu(st, at)
			await get_tree().create_timer(0.4).timeout
			var labels: Array = []
			for c in hud.pie_menu._items:
				if c is Button:
					labels.append((c as Button).text)
			hud.pie_menu.chosen.emit(labels.find("Upgrade..."))
			await get_tree().create_timer(0.6).timeout
		"piemenu":
			var bed := find_furniture("desk") if "--desk" in OS.get_cmdline_user_args() else find_furniture("bed")
			rig.frame(bed.global_position, deg_to_rad(20.0), deg_to_rad(-50.0), 12.0)
			await get_tree().create_timer(0.5).timeout
			open_menu(bed, rig.camera.unproject_position(bed.global_position + Vector3(0, 0.5, 0)))
			await get_tree().create_timer(0.6).timeout
		"burglar":
			Clock.total_minutes = 2 * 60.0 + 30.0
			sim.global_position = lot.cell_to_world(Vector2i(4, 4))
			sim.visible = false
			lot.wall_view = Lot.WallView.CUTAWAY
			var target := Burglar.pick_target(lot)
			var b := send_burglar()
			rig.frame(lot.cell_to_world(Vector2i(11, 13)), deg_to_rad(10.0), deg_to_rad(-45.0), 16.0)
			await get_tree().create_timer(3.0).timeout
			print("BURGLAR target=%s" % target.display_name)
		"party":
			hud.phone_service.emit("event:house_party")
			for k in 5:
				sim.activity_done.emit("Chat")
			sim.activity_done.emit("Dance")
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(11, 12)), deg_to_rad(20.0), deg_to_rad(-40.0), 17.0)
			await get_tree().create_timer(2.0).timeout
		"phonecheck":
			lot.add_mess("dishes", lot.cell_to_world(Vector2i(10, 8)))
			var tv := find_furniture("tv")
			tv.set_broken(true)
			var funds0 := build.funds
			hud.phone_service.emit("maid")
			hud.phone_service.emit("repair")
			await get_tree().process_frame
			var ok: bool = lot.messes().is_empty() and not tv.broken and build.funds == funds0 - 140
			print("PHONE %s funds=%d messes=%d broken=%s" % ["OK" if ok else "FAIL", funds0 - build.funds, lot.messes().size(), tv.broken])
			get_tree().quit()
		"phonetabs":
			hud._phone_tab = 2
			hud._toggle_phone()
			await get_tree().create_timer(0.8).timeout
		"parktrees":
			Clock.total_minutes = 11 * 60.0
			await travel("park")
			rig.frame(lot.cell_to_world(Vector2i(12, 7)), deg_to_rad(20.0), deg_to_rad(-38.0), 20.0)
			await get_tree().create_timer(1.5).timeout
		"nightout", "dayout":
			Clock.total_minutes = (22 if scenario == "nightout" else 12) * 60.0
			lot.wall_view = Lot.WallView.UP
			rig.frame(lot.cell_to_world(Vector2i(11, 10)), deg_to_rad(15.0), deg_to_rad(-22.0), 22.0)
			await get_tree().create_timer(1.2).timeout
		"fullmoon":
			Clock.total_minutes = (4 * 24 + 22) * 60.0
			await get_tree().create_timer(1.0).timeout
			print("MOON phase=%s mood=%s" % [Lunar.PHASES[Lunar.phase(Clock.day())], sim.emotions.mood()])
		"envoptions":
			var eo := GameOptions.new()
			add_child(eo)
			eo.setup()
			eo._show_tab(5)
			await get_tree().create_timer(0.8).timeout
		"options":
			var o := GameOptions.new()
			add_child(o)
			o.setup()
			o._show_tab(3)
			await get_tree().create_timer(0.8).timeout
		"paused":
			Clock.set_speed(0)
			await get_tree().create_timer(0.6).timeout
		"garden":
			var crops := ["tomato", "lettuce", "carrot", "strawberry"]
			var pl: Array = []
			for k in 4:
				var f := _place("planter", Vector2i(14 + k * 2, 18))
				f.apply_effect("plant:" + crops[k])
				var g: Dictionary = f.get_meta("item").duplicate()
				g["growth"] = [0.1, 0.5, 1.0, 1.0][k]
				f.set_meta("item", g)
				f.refresh_garden()
				pl.append(f)
			sim.global_position = lot.cell_to_world(Vector2i(13, 19))
			sim.queue_interaction(pl[0], pl[0].available_interactions()[0])
			Clock.set_speed(2)
			rig.frame(lot.cell_to_world(Vector2i(17, 18)), deg_to_rad(15.0), deg_to_rad(-35.0), 7.0)
			await get_tree().create_timer(2.5).timeout
		"fencestyles":
			for st in 4:
				for e in Lot.wall_run(Vector2i(2 + st * 5, 16), Vector2i(6 + st * 5, 16)):
					lot.add_fence(e, st)
			lot.add_gate(Vector3i(4, 16, 0))
			_place("column", Vector2i(10, 14))
			_place("column", Vector2i(12, 14))
			rig.frame(lot.cell_to_world(Vector2i(11, 16)), deg_to_rad(10.0), deg_to_rad(-25.0), 14.0)
			await get_tree().create_timer(1.0).timeout
		"terrain":
			for x in range(1, 23):
				for y in range(14, 19):
					lot.terrain_tiles[Vector2i(x, y)] = 3 if (x + y) % 7 < 3 else (1 if x < 8 else (2 if x < 15 else 4))
			lot.paint_terrain(Vector2i(-1, -1), 0)
			rig.frame(lot.cell_to_world(Vector2i(11, 16)), deg_to_rad(10.0), deg_to_rad(-40.0), 12.0)
			await get_tree().create_timer(1.0).timeout
		"foundationcut":
			set_foundation(Lot.FOUNDATION_HEIGHT)
			lot.wall_view = Lot.WallView.CUTAWAY
			rig.frame(lot.cell_to_world(Vector2i(11, 9)), deg_to_rad(30.0), deg_to_rad(-30.0), 17.0)
			await get_tree().create_timer(1.5).timeout
		"foundation":
			set_foundation(Lot.FOUNDATION_HEIGHT)
			sim.global_position = lot.cell_to_world(Vector2i(11, 16))
			sim.queue_go(lot.cell_to_world(Vector2i(11, 10)))
			lot.wall_view = Lot.WallView.UP
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(11, 13)), deg_to_rad(15.0), deg_to_rad(-22.0), 10.0)
			for k in 6:
				await get_tree().create_timer(0.5).timeout
				print("FOUNDATION t=%d cell=%s sim_y=%.2f floor=%.2f" % [k, lot.world_to_cell(sim.global_position), sim.global_position.y, lot.floor_y_at(sim.global_position)])
		"monkeybars":
			await travel("park")
			sim.set_age("child")
			var mb := find_furniture("monkey_bars")
			sim.queue_interaction(mb, mb.interactions[0])
			Clock.set_speed(2)
			rig.frame(mb.global_position, deg_to_rad(20.0), deg_to_rad(-25.0), 7.0)
			await get_tree().create_timer(3.0).timeout
		"showroom":
			lot.add_floor(Rect2i(2, 14, 20, 5), 2)
			_place("rug", Vector2i(4, 15))
			_place("armchair", Vector2i(4, 14))
			_place("coffee_table", Vector2i(4, 16), 2)
			_place("end_table", Vector2i(6, 14))
			_place("sculpture", Vector2i(8, 15))
			_place("bathtub", Vector2i(10, 15))
			_place("single_bed", Vector2i(13, 14))
			_place("dollhouse", Vector2i(15, 15))
			_place("activity_table", Vector2i(17, 15))
			sim.global_position = lot.cell_to_world(Vector2i(12, 17))
			rig.frame(lot.cell_to_world(Vector2i(10, 15)), deg_to_rad(190.0), deg_to_rad(-45.0), 12.0)
			await get_tree().create_timer(1.0).timeout
		"toddlermenu":
			sim.pregnant_days = 0
			life._give_birth(sim)
			await get_tree().create_timer(0.5).timeout
			var kid: Sim = household[household.size() - 1]
			kid.global_position = sim.global_position + Vector3(1.2, 0, 0)
			rig.frame(kid.global_position, deg_to_rad(20.0), deg_to_rad(-35.0), 6.0)
			await get_tree().create_timer(0.6).timeout
			open_sim_menu(kid, rig.camera.unproject_position(kid.global_position + Vector3(0, 0.6, 0)))
			await get_tree().create_timer(0.4).timeout
			hud.pie_menu.chosen.emit(1)
			await get_tree().create_timer(0.6).timeout
		"jog":
			sim.walk_style = "bouncy"
			sim.global_position = lot.cell_to_world(Vector2i(2, 17))
			sim.queue_go(lot.cell_to_world(Vector2i(22, 17)))
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(6, 17)), deg_to_rad(80.0), deg_to_rad(-15.0), 6.0)
			await get_tree().create_timer(1.3).timeout
			print("JOG jogging=%s speed=%.2f" % [sim._jogging, sim.move_speed()])
		"workevent":
			dialogs_enabled = true
			var w: Work = works[sim]
			w.join("tech", true)
			w._rng.seed = 2
			w._raise_event()
			await get_tree().create_timer(1.0).timeout
		"lottraits":
			build.enter()
			build.open_lot_traits()
			await get_tree().create_timer(1.0).timeout
		"rooftool":
			build.enter()
			build.set_tool(BuildMode.Tool.ROOF)
			await get_tree().create_timer(1.0).timeout
		"roof", "hiproof", "flatroof":
			var style: int = {"roof": Lot.RoofStyle.GABLE, "hiproof": Lot.RoofStyle.HIP, "flatroof": Lot.RoofStyle.FLAT}[scenario]
			for l in levels:
				(l as Lot).set_roof(style, 2 if style == Lot.RoofStyle.HIP else 1)
			lot.wall_view = Lot.WallView.UP
			rig.frame(lot.center(), deg_to_rad(35.0), deg_to_rad(-30.0), 26.0)
			await get_tree().create_timer(1.0).timeout
		"fence":
			for r in [[Vector2i(1, 15), Vector2i(23, 15)], [Vector2i(1, 15), Vector2i(1, 19)], [Vector2i(23, 15), Vector2i(23, 19)]]:
				for e in Lot.wall_run(r[0], r[1]):
					lot.add_fence(e)
			lot.add_gate(Vector3i(10, 15, 0))
			sim.global_position = lot.cell_to_world(Vector2i(10, 17))
			sim.move_to(lot.cell_to_world(Vector2i(10, 13)))
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(10, 15)), deg_to_rad(25.0), deg_to_rad(-35.0), 13.0)
			await get_tree().create_timer(1.6).timeout
		"upstairs", "twostorey", "twostoreyfound":
			if scenario == "twostoreyfound":
				set_foundation(Lot.FOUNDATION_HEIGHT)
			upper.add_floor(Rect2i(3, 2, 15, 10), 2)
			for r in [[Vector2i(3, 2), Vector2i(18, 2)], [Vector2i(3, 12), Vector2i(18, 12)], [Vector2i(3, 2), Vector2i(3, 12)], [Vector2i(18, 2), Vector2i(18, 12)]]:
				for e in Lot.wall_run(r[0], r[1]):
					upper.add_wall(e)
					upper.paint_wall(e, 2)
			for e in [Vector3i(6, 12, 0), Vector3i(11, 12, 0), Vector3i(15, 12, 0), Vector3i(8, 2, 0), Vector3i(18, 6, 1)]:
				upper.add_window(e)
			var st := Catalog.create("stairs")
			lot.place_furniture(st, Vector2i(10, 6), 0)
			upper.clear_floor(st.footprint_rect())
			var bed2 := Catalog.create("bed")
			upper.place_furniture(bed2, Vector2i(13, 3), 0)
			var lamp2 := Catalog.create("lamp")
			upper.place_furniture(lamp2, Vector2i(16, 3), 0)
			sim.needs.set_value("energy", 20.0)
			sim.queue_interaction(bed2, bed2.interactions.filter(func(i): return i.name == "Sleep")[0])
			Clock.set_speed(2)
			if scenario == "upstairs":
				set_level(1)
				rig.frame(Vector3(11, Lot.WALL_HEIGHT, 7), deg_to_rad(35.0), deg_to_rad(-50.0), 20.0)
			else:
				lot.wall_view = Lot.WallView.UP
				rig.frame(lot.center() + Vector3(0, 0, 3), deg_to_rad(25.0), deg_to_rad(-25.0), 34.0)
			await get_tree().create_timer(6.0).timeout
			print("UPSTAIRS lot_level=%d action=%s y=%.2f" % [sim.lot.level, sim.current_action().label if sim.current_action() else "-", sim.global_position.y])
		"lounge", "gym", "library":
			Clock.total_minutes = 20.0 * 60.0
			await travel(scenario)
			Clock.set_speed(2)
			await get_tree().create_timer(4.0).timeout
		"moveinsave":
			var jj := visitors.neighbour
			sim.change_relationship(jj, 70.0, 0.0)
			_on_moving_in(jj)
			save_game()
			load_game()
			await get_tree().process_frame
			var names := visitors.townies.map(func(t): return t.sim_name)
			print("MOVEINSAVE household=%s townies=%s neighbour=%s" % [household.map(func(m): return m.sim_name), names, visitors.neighbour.sim_name])
		"woohoo":
			var jules := visitors.neighbour
			visitors.bring(jules, INF, lot.cell_to_world(Vector2i(10, 9)))
			sim.change_relationship(jules, 70.0, 80.0)
			sim.partner = jules
			jules.partner = sim
			var bed: Furniture = lot.furniture.filter(func(f): return f.kind == "bed")[0]
			var wh: Interaction = bed.interactions.filter(func(i): return i.name == "WooHoo")[0]
			_queue_with_partner(bed, wh)
			Clock.set_speed(2)
			rig.frame(bed.global_position, deg_to_rad(30.0), deg_to_rad(-40.0), 8.0)
			await get_tree().create_timer(4.0).timeout
			print("WOOHOO users=%d" % bed.users.size())
		"movein":
			var jules := visitors.neighbour
			visitors.bring(jules, INF, lot.cell_to_world(Vector2i(10, 9)))
			sim.global_position = lot.cell_to_world(Vector2i(13, 9))
			sim.change_relationship(jules, 70.0, 80.0)
			sim.partner = jules
			jules.partner = sim
			sim.queue_social(jules, Socials.find("Propose"))
			Clock.set_speed(3)
			await get_tree().create_timer(4.0).timeout
			print("MOVEIN household=%d spouse=%s jules_visitor=%s" % [household.size(), sim.spouse.sim_name if sim.spouse else "-", jules.is_visitor])
		"hover":
			_hover(rig.camera.unproject_position(find_furniture("sofa").global_position + Vector3(0, 0.4, 0)))
			await get_tree().create_timer(0.6).timeout
		"dance":
			var st := find_furniture("stereo")
			sim.queue_interaction(st, st.interactions[0])
			sim.queue_interaction(st, st.interactions[2])
			Clock.set_speed(2)
			await get_tree().create_timer(4.0).timeout
			print("DANCE on=%s action=%s anim=%s" % [st.get_meta("on", false), sim.current_action().label if sim.current_action() else "-", sim._anim.current_animation])
		"carpool":
			work.join("tech")
			Clock.total_minutes = 8.0 * 60.0 + 58.0
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(13, 17)), deg_to_rad(10.0), deg_to_rad(-30.0), 22.0)
			await get_tree().create_timer(6.5).timeout
			print("CARPOOL state=%d away=%s" % [work.state, sim.away])
		"careers":
			hud._show_page(4)
			await get_tree().create_timer(0.6).timeout
		"careerjob":
			work.join("business")
			work.work_style = "hard"
			hud._show_page(4)
			await get_tree().create_timer(0.6).timeout
		"death":
			var gus := _new_sim("Gus")
			add_to_household(gus)
			gus.set_age("elder")
			gus.global_position = lot.cell_to_world(Vector2i(11, 9))
			sim.global_position = lot.cell_to_world(Vector2i(13, 9))
			sim.change_relationship(gus, 50.0, 0.0)
			gus._starving = Sim.STARVE_MINUTES - 1.0
			gus.needs.set_value("hunger", 0.0)
			Clock.set_speed(1)
			rig.frame(lot.cell_to_world(Vector2i(12, 9)), deg_to_rad(20.0), deg_to_rad(-30.0), 9.0)
			await get_tree().create_timer(2.2).timeout
		"deathafter":
			var gus2 := _new_sim("Gus")
			add_to_household(gus2)
			gus2.global_position = lot.cell_to_world(Vector2i(11, 9))
			gus2._starving = Sim.STARVE_MINUTES - 1.0
			gus2.needs.set_value("hunger", 0.0)
			Clock.set_speed(1)
			await get_tree().create_timer(7.0).timeout
			print("DEATH household=%d tombstones=%d mourning=%s" % [household.size(), lot.furniture.filter(func(f): return f.kind == "tombstone").size(), sim.emotions.has("mourning")])
		"swatches":
			find_furniture("sofa").set_variant(1)
			find_furniture("bed").set_variant(3)
			find_furniture("fridge").set_variant(2)
			build.enter()
			build.start_place("sofa")
			build._held.set_variant(4)
			build._show_object_swatches()
			build._refresh_overlays(Vector3(12, 0, 14))
			await get_tree().create_timer(2.5).timeout
		"paintings":
			sim.skills.add_xp("painting", Skills.xp_for_level(7))
			var easel := find_furniture("easel")
			var paint: Interaction = easel.interactions[0]
			for k in 3:
				sim._reward(paint, 999.0, true)
			var items: Array = sim.inventory.duplicate()
			for k in 2:
				var art := Catalog.make_painting(items[k])
				var spots := [[Vector2i(7, 2), 0], [Vector2i(12, 2), 0]]
				if lot.can_hang(art, spots[k][0], spots[k][1]):
					lot.place_furniture(art, spots[k][0], spots[k][1])
				sim.inventory.erase(items[k])
			hud._show_page(6)
			await get_tree().create_timer(1.0).timeout
			print("PAINT inventory=%d hung=%d" % [sim.inventory.size(), lot.furniture.filter(func(f): return f.kind == "painting").size()])
		"cooking":
			sim.skills.add_xp("cooking", Skills.xp_for_level(4))
			var bea := _new_sim("Bea")
			add_to_household(bea)
			bea.global_position = lot.cell_to_world(Vector2i(11, 9))
			var stove := find_furniture("stove")
			var mac: Interaction = stove.interactions.filter(func(i): return i.recipe == "Spaghetti")[0]
			sim.queue_interaction(stove, mac)
			Clock.set_speed(3)
			while lot.furniture.filter(func(f): return f.kind == "meal").is_empty() and Clock.total_minutes < 11 * 60:
				await get_tree().process_frame
			Clock.set_speed(1)
			sim.needs.set_value("hunger", 20.0)
			bea.needs.set_value("hunger", 15.0)
			bea.clear_queue()
			sim.clear_queue()
			await get_tree().create_timer(9.0).timeout
			var meals := lot.furniture.filter(func(f): return f.kind == "meal")
			print("COOK meals=%d servings=%s sim=%s bea=%s" % [meals.size(), meals[0].get_meta("servings") if not meals.is_empty() else -1, sim.current_action().label if sim.current_action() else "-", bea.current_action().label if bea.current_action() else "-"])
			rig.frame(stove.global_position, deg_to_rad(10.0), deg_to_rad(-35.0), 9.0)
			await get_tree().create_timer(0.3).timeout
		"manage":
			var bea := _new_sim("Bea")
			add_to_household(bea)
			other_households = [{"home": "studio", "funds": 9300, "household": [{"sim": {"name": "Marco"}}, {"sim": {"name": "Priya"}}, {"sim": {"name": "Leo"}}]}]
			save_game()
			open_main_menu()
			var menu: MainMenu = _menu
			menu.visible = false
			_open_manage_households(menu)
			await get_tree().create_timer(1.0).timeout
		"mapoccupied":
			hud.visible = false
			other_households = [{"home": "studio", "funds": 9300, "household": [{"sim": {"name": "Marco"}}]}]
			open_neighbourhood()
			var map := get_node("Neighbourhood") as Neighbourhood
			map.show_card("studio")
			await get_tree().create_timer(1.0).timeout
		"cozy":
			var bea := _new_sim("Bea")
			bea.set_hair_style("long")
			bea.set_part_color("shirt", Color(0.9, 0.45, 0.6))
			add_to_household(bea)
			sim.change_relationship(bea, 70.0, 70.0)
			var bed := find_furniture("bed")
			var sleep: Interaction = bed.interactions.filter(func(i): return i.name == "Sleep")[0]
			sim.queue_interaction(bed, sleep)
			bea.queue_interaction(bed, sleep)
			Clock.set_speed(2)
			rig.frame(bed.global_position, deg_to_rad(30.0), deg_to_rad(-45.0), 7.0)
			await get_tree().create_timer(4.0).timeout
			print("COZY users=%d alex=%s bea=%s cozy=%s" % [bed.users.size(), sim.current_action().label if sim.current_action() else "-", bea.current_action().label if bea.current_action() else "-", sim.emotions.has("cozy")])
		"store":
			aspirations.satisfaction = 2300
			hud._show_page(5)
			hud._open_store()
			await get_tree().create_timer(0.8).timeout
		"fire":
			var stove := find_furniture("stove")
			lot.add_mess("fire", stove.global_position + Vector3(0, 0, 1.2))
			stove.set_broken(true)
			find_furniture("tv").set_broken(true)
			Clock.set_speed(1)
			await get_tree().create_timer(2.5).timeout
			print("FIRE fires=%d action=%s" % [lot.messes().filter(func(m): return m.kind == "fire").size(), sim.current_action().label if sim.current_action() else "-"])
		"mess":
			lot.add_mess("dishes", lot.cell_to_world(Vector2i(13, 7)))
			lot.add_mess("dishes", lot.cell_to_world(Vector2i(10, 4)))
			lot.add_mess("puddle", lot.cell_to_world(Vector2i(9, 9)))
			for n in Needs.ORDER:
				sim.needs.set_value(n, 80.0)
			Clock.set_speed(3)
			await get_tree().create_timer(9.0).timeout
			Clock.set_speed(0)
			print("MESS left=%d action=%s" % [lot.messes().size(), sim.current_action().label if sim.current_action() else "-"])
		"family":
			var stages := ["toddler", "child", "teen", "adult", "elder"]
			for i in stages.size():
				var m := _new_sim(["Tia", "Kit", "Ted", "Ann", "Gus"][i])
				add_to_household(m)
				m.set_age(stages[i])
				m.autonomy_enabled = false
				m.global_position = lot.cell_to_world(Vector2i(6 + i * 2, 14))
				m.set_part_color("shirt", Color.from_hsv(i * 0.18, 0.5, 0.9))
			sim.global_position = lot.cell_to_world(Vector2i(4, 14))
			select_sim(household[3])
			hud._show_page(2)
			rig.frame(lot.cell_to_world(Vector2i(10, 14)), deg_to_rad(20.0), deg_to_rad(-25.0), 11.0)
			await get_tree().create_timer(1.0).timeout
		"bubbles":
			Clock.total_minutes = 9.0 * 60.0 + 1.0
			await get_tree().create_timer(0.3).timeout
			var jules2 := visitors.neighbour
			jules2.global_position = lot.cell_to_world(Vector2i(10, 9))
			jules2.clear_queue()
			sim.global_position = lot.cell_to_world(Vector2i(13, 9))
			sim.change_relationship(jules2, 40.0, 0.0)
			sim.queue_social(jules2, Socials.find("Flirt"))
			var bea := _new_sim("Bea")
			add_to_household(bea)
			bea.global_position = lot.cell_to_world(Vector2i(6, 14))
			bea.needs.set_value("hunger", 5.0)
			bea.autonomy_enabled = false
			await get_tree().create_timer(2.6).timeout
		"social":
			Clock.total_minutes = 9.0 * 60.0 + 1.0
			await get_tree().create_timer(0.3).timeout
			var jules := visitors.neighbour
			jules.global_position = lot.cell_to_world(Vector2i(10, 9))
			jules.clear_queue()
			sim.global_position = lot.cell_to_world(Vector2i(13, 9))
			sim.queue_social(jules, Socials.find("Tell a Joke"))
			hud._show_page(3)
			await get_tree().create_timer(2.5).timeout
		"casfemale", "casfemaleface", "casfemaleheavy", "casfemalefit", "casfemalelong":
			open_create_a_sim()
			_cas._pick_frame("feminine")
			sim.set_body(.95 if scenario == "casfemaleheavy" else .1, 1.0 if scenario == "casfemalefit" else .35)
			sim.set_outfit(true, false)
			_cas._pick_hair("long" if scenario == "casfemalelong" else "bob")
			sim.set_part_color("shirt", Color(.62, .3, .47))
			sim.set_part_color("pants", Color(.3, .3, .37))
			_cas._sync_body()
			_cas._sync_swatches()
			if scenario == "casfemaleface":
				_cas.view_requested.emit(true)
			await get_tree().create_timer(1.0).timeout
		"casclothes", "casshorts", "casskirt":
			open_create_a_sim()
			sim.set_body(1.0, 1.0)
			sim.set_outfit(scenario == "casclothes", scenario == "casshorts")
			if scenario == "casskirt":
				sim.set_legs("skirt")
			_cas._sync_body()
			await get_tree().create_timer(1.0).timeout
		"caspalm", "castorso", "castorsomax":
			open_create_a_sim()
			sim.set_body(1.0 if scenario == "castorsomax" else .25, 1.0 if scenario == "castorsomax" else .5)
			sim.set_outfit(true, false)
			_cas._sync_body()
			rig.frame(CAS_STUDIO + (Vector3(-.24, .83, 0) if scenario == "caspalm" else Vector3(0, 1.15, 0)), 0.0, deg_to_rad(-2.0), .65 if scenario == "caspalm" else 1.75)
			await get_tree().create_timer(1.0).timeout
		"cashair-short", "cashair-long", "cashair-bob", "cashair-ponytail", "cashair-curly", "cashair-bun":
			open_create_a_sim()
			sim.set_body(.25, .5)
			sim.set_outfit(true, false)
			sim.set_hair_style(scenario.trim_prefix("cashair-"))
			_cas.view_requested.emit(true)
			await get_tree().create_timer(1.0).timeout
		"casface":
			open_create_a_sim()
			_cas.view_requested.emit(true)
			await get_tree().create_timer(1.0).timeout
		"cas":
			open_create_a_sim()
			_cas.randomize_sim()
			await get_tree().create_timer(1.0).timeout
		"paint":
			build.enter()
			build.set_tool(BuildMode.Tool.PAINT)
			await get_tree().create_timer(1.0).timeout
		"build":
			build.enter()
			build.set_tool(BuildMode.Tool.WALL)
			for e in Lot.wall_run(Vector2i(12, 8), Vector2i(18, 8)):
				lot.add_wall(e)
			build.start_place("tv")
			build._refresh_overlays(Vector3(15.0, 0.0, 10.0))
			await get_tree().create_timer(1.0).timeout
		_:
			sim.queue_go(lot.cell_to_world(Vector2i(20, 8)))
			await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## A left click on a ground point, for scripted build-mode screenshots.
func _fake_click(at: Vector3) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = rig.camera.unproject_position(at)
	return e
