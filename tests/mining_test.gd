extends SceneTree

const PATH := "user://meridian_mining_test.json"
const Store = preload("res://scripts/checkpoint_store.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(PATH + suffix)

func fresh():
	var g = load("res://main.tscn").instantiate()
	g.store.path = PATH
	root.add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	return g

func run() -> void:
	cleanup()
	var old := Store.new()
	old.path = PATH
	check(old.write_document({"schema":3,"credits":0,"upgrades":{"engine":0,"shield":0,"weapon":0},"cargo":{"ore":0,"medicine":2,"electronics":0}}), "0.9.0 test profile written")
	var g = fresh()
	if not "mining" in g:
		check(false, "The profile has no mining model")
		g.queue_free()
		await process_frame
		quit(1)
		return

	var m = g.mining
	check(g.cargo.medicine == 2, "Old cargo survives migration")
	g.cargo.medicine = 0
	m.restore({"surveyed":"yes","installed":true})
	check(not m.surveyed and not m.installed, "Invalid survey flag cannot load a mine")
	m.restore({"surveyed":true,"installed":"yes"})
	check(m.surveyed and not m.installed, "Invalid installation flag retains the survey only")
	m.restore({})
	check(not m.surveyed and not m.installed and m.reserve == 120, "Old profile gets the initial deposit and one kit")
	check(not g.planet.deploy_mine() and g.planet.load_ore() == 0, "Station cannot install or load")
	g.start_planet_flight()
	g.ship.position = g.planet.ENTRY
	g.velocity = Vector3.ZERO
	g.planet.action()
	for i in range(300):
		g._physics_process(.05)
		if g.planet.on_surface() and g.mission.stage == "ПОВЕРХНОСТЬ":
			break
		await process_frame
	check(g.planet.on_surface(), "Descent loads Meridian")
	check(not g.planet.start_survey(), "Distant ship cannot survey")
	var pad: Vector3 = g.planet.region.ground_point(m.LANDING_POINT)
	g.ship.position = pad + Vector3.UP * 12
	g.velocity = Vector3(21, 0, 0)
	check(not g.planet.start_survey(), "Survey rejects high speed")
	g.velocity = Vector3.ZERO
	check(g.planet.start_survey(), "Survey starts in the correct window")
	g._physics_process(2)
	g.ship.position.y += 101
	g._physics_process(.1)
	check(not m.surveyed and g.planet.survey_elapsed < 0, "Leaving the envelope cancels survey")
	g.ship.position = pad + Vector3.UP * 12
	check(g.planet.start_survey(), "Survey can be retried")
	for i in range(5):
		g._physics_process(1)
	check(m.surveyed and not g.planet.deploy_mine(), "Survey persists and installation requires landing")
	check(not g.planet.region.landing_clear(m.SITE.x,m.SITE.y), "The surveyed machinery footprint is reserved before installation")
	check(g.planet.can_land(), "First site provides unobstructed, landable terrain")
	g.planet.action()
	g._physics_process(2)
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(884,1104)]:
		root.size = dimensions
		for i in range(3):
			await process_frame
		var ui = g.flight_ui.planet_panel
		check(ui.mine_action.visible and not ui.mine_action.disabled, "Installation action available on landing")
		check(Rect2(Vector2.ZERO,g.flight_ui.design_size).encloses(ui.mine_action.get_rect()), "Mining action fits display")
		check(not ui.mine_action.get_rect().intersects(ui.action_button.get_rect()), "Mining action stays clear of takeoff")
	var valid_path: String = g.store.path
	g.store.path = "user://missing-meridian-test-dir/checkpoint.json"
	check(not g.planet.deploy_mine() and not m.installed and m.stock == 0 and m.reserve == 120, "Failed install retains the kit and the full deposit")
	g.store.path = valid_path
	check(g.planet.deploy_mine() and m.stock == 1 and m.reserve == 119, "Install consumes kit and starts with one ore")
	check(not g.planet.deploy_mine(), "Installation cannot be repeated")
	check(not g.planet.region.landing_clear(m.SITE.x,m.SITE.y), "Deployed equipment blocks landing on top of it")
	m.advance(29, false)
	check(m.stock == 1, "Active rate waits for a full 30 seconds")
	m.advance(1, false)
	check(m.stock == 2, "Active rate 30 seconds")
	m.advance(60, true)
	check(m.stock == 3, "Offline rate 60 seconds")
	m.advance(1200, false)
	check(m.stock == 20 and m.reserve == 100, "Full stock stops reserve consumption")
	g.cargo.electronics = 7
	var saved_path: String = g.store.path
	g.store.path = "user://missing-meridian-test-dir/checkpoint.json"
	check(g.planet.load_ore() == 0 and g.cargo.ore == 0 and m.stock == 20, "A failed checkpoint rolls back both sides of loading")
	g.store.path = saved_path
	check(g.planet.load_ore() == 3 and g.cargo.ore == 3 and m.stock == 17, "Loading respects existing cargo and warehouse")
	check(g.planet.load_ore() == 0 and m.stock == 17, "Full ship cannot remove more ore")
	var now := int(Time.get_unix_time_from_system())
	var checkpoint: Dictionary = g.store.read_document()
	checkpoint.mining.saved_at = now - 60
	checkpoint.mining.report_produced = 0
	g.store.write_document(checkpoint)
	var resumed = fresh()
	check(resumed.mining.stock == 18 and resumed.mining.report_produced == 1, "Cold start applies one minute once and persists the report")
	await process_frame
	check(resumed.flight_ui.planet_panel.report_dialog.visible, "Cold start displays the report")
	resumed.queue_free()
	await process_frame
	var again = fresh()
	check(again.mining.stock == 18 and again.mining.report_produced == 1, "Reopen does not replay the same elapsed time")
	await process_frame
	var report: AcceptDialog = again.flight_ui.planet_panel.report_dialog
	report.confirmed.emit()
	report.hide()
	check(not again.mining.has_report() and again.store.read_document().mining.report_produced == 0, "Acknowledgement clears the saved report")
	check(again.resume_flight() and again.mission.stage == "НА ПОВЕРХНОСТИ", "Mining and landing survive a restart")
	check(again.cargo.ore == 3 and again.cargo.electronics == 7, "Landed checkpoint preserves cargo")
	again.planet.action()
	again._physics_process(2)
	check(again.mission.stage == "ПОВЕРХНОСТЬ", "Mined cargo can take off")
	again.ship.position.y += 120
	again.planet.exit_orbit()
	again._physics_process(4)
	again.ship.position = again.Sector.dock_point(again.mission.origin)
	again.velocity = Vector3.ZERO
	check(again.mission.can_dock(), "Expedition can return to its station")
	again.mission.dock()
	check(again.trade_goods("ore", 3, false) and again.credits == 72, "Mined ore sells through the existing station market")

	m.offline_until_event = 1
	m.event_index = 0
	m.advance(1, true)
	check(m.repair_left == 120 and m.report_breakdowns == 1, "Offline breakdown automatically starts timed repair")
	var stored: int = m.stock
	m.advance(120, true)
	check(m.repair_left == 0 and m.stock == stored, "Repair interval has no production")
	m.offline_until_event = 1
	m.advance(1, true)
	check(m.stock < stored and m.installed and m.report_lost > 0, "Offline raid takes some stored ore and preserves equipment")
	m.reserve = 1
	m.stock = 0
	m.work = 0
	m.advance(60, false)
	check(m.reserve == 0 and m.stock == 1, "Last unit can be produced and stays available for hauling")

	again._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	again.mining.saved_at -= 60
	again._process(60)
	check(again.mining.stock == 18, "Active production stops in the background")
	again._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(again.mining.stock == 19 and again.mining.report_produced == 1, "Android resume uses the offline rate")
	again._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(again.mining.stock == 19, "Duplicate resume cannot repeat the offline grant")

	for game in [g, again]:
		game.queue_free()
	await process_frame
	cleanup()
	print("Mining tests: %d failures" % failures)
	quit(1 if failures else 0)
