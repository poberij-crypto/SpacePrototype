extends SceneTree

const SAVE := "user://contracts_test.json"

func _initialize() -> void:
	call_deferred("run")

func _game(path := SAVE):
	var game = load("res://main.tscn").instantiate()
	game.store.path = path
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _dock_position(game, station: int) -> void:
	game.ship.position = game.Sector.dock_point(station)
	game.velocity = Vector3.ZERO
	game.request_station_dock()

func run() -> void:
	var game = _game()
	await process_frame
	var board = game.contract_board
	game.flight_ui.contract_button.pressed.emit()
	await process_frame
	assert(board.visible and not game.flight_ui.mission_panel.visible)
	assert(board.cards.get_child_count() == 5 and board.reputation.text.count("+0") == 2)
	for dimensions in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(884, 1104)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		assert(game.flight_ui.safe_bounds.encloses(board.panel.get_rect()), "Contract board fits %s · %s vs %s" % [dimensions, board.panel.get_rect(), game.flight_ui.safe_bounds])
		assert(board.scroll.size.y >= 160, "Scrollable offer list at %s" % dimensions)
	var first = board.cards.get_child(0).get_child(0)
	first.get_child(-1).get_child(0).pressed.emit()
	assert(board.journal and game.contracts.active.size() == 1)
	var delivery: int = game.contracts.next_id - 1
	var survey: int = game.accept_contract("survey")
	var pirate: int = game.accept_contract("pirate")
	assert(game.accept_contract("priority") == 0 and game.accept_contract("raider") == 0)
	var cancelled: int = game.accept_contract("delivery")
	var order: Dictionary = game.contracts.order(cancelled)
	assert(game.contracts.penalty(cancelled, order.accepted + 599) == 0)
	assert(game.contracts.penalty(cancelled, order.accepted + 600) == 5)
	assert(game.cancel_contract(cancelled) and game.contracts.reputation.guild == 0)
	cancelled = game.contracts.accept("survey", 0, int(Time.get_unix_time_from_system()) - 600)
	assert(game.cancel_contract(cancelled))
	assert(game.contracts.reputation.guard == -5 and game.contracts.reputation.guild == 0)
	var before: int = game.credits
	board.refresh()
	var row = board.cards.get_child(-1).get_child(0).get_child(-1)
	row.get_child(0).pressed.emit()
	assert(game.mission.contract_id == delivery and not board.visible)
	_dock_position(game, 0)
	assert(game.station_dock_dialog.visible)
	game.station_dock_dialog.hide()
	game.station_dock_dialog.confirmed.emit()
	assert(game.at_station() and game.contracts.active.size() == 3 and game.credits == before)
	assert(game.start_contract(delivery))
	var resumed = _game()
	await process_frame
	assert(resumed.pending_snapshot.contract_id == delivery)
	assert(resumed.contracts.active.size() == 3 and resumed.resume_flight())
	assert(resumed.mission.contract_id == delivery and resumed.mission.cargo_loaded)
	for frame in range(4000):
		var goal: Vector3 = resumed.mission.nav_position()
		var distance: float = resumed.ship.position.distance_to(goal)
		if distance > 0.1:
			resumed.ship.look_at(goal)
		resumed.throttle = 0.65 if distance > 45 else (0.2 if distance > 12 else 0.0)
		resumed._physics_process(1.0 / 60.0)
		if resumed.mission.can_dock():
			break
	assert(resumed.mission.can_dock(), "Contract destination is reachable")
	resumed.store.path = "user://missing_directory/contract.json"
	resumed.request_station_dock()
	assert(resumed.credits == before and resumed.contracts.reputation.guild == 0)
	assert(resumed.mission.can_dock() and resumed.contracts.active.size() == 3)
	resumed.store.path = SAVE
	resumed.request_station_dock()
	resumed.request_station_dock()
	assert(resumed.station_id == 1 and resumed.credits == before + 240)
	assert(resumed.contracts.reputation.guild == 5 and resumed.contracts.order(delivery).is_empty())
	assert(not resumed.can_launch_contract(survey))
	var reverse: int = resumed.accept_contract("survey")
	assert(resumed.start_contract(reverse))
	resumed.ship.position = resumed.mission.field_point()
	resumed.velocity = Vector3.ZERO
	resumed.mission.step()
	assert(resumed.mission.stage == "СКАНИРОВАНИЕ")
	resumed.mission.step(3.0)
	assert(resumed.mission.nav_position() == resumed.Sector.dock_point(0))
	_dock_position(resumed, 0)
	assert(resumed.credits == before + 420 and resumed.contracts.reputation.guard == 0)
	assert(resumed.start_contract(pirate))
	resumed.ship.position = resumed.mission.field_point()
	resumed.mission.step()
	var target: Node3D = resumed.combat.target_by_id(2)
	assert(target != null and target.get_meta("shield") == 15.0)
	for pirate_target in resumed.enemies.duplicate():
		if pirate_target.visible and pirate_target.get_meta("hostile"):
			resumed.combat.apply_damage(pirate_target, 300.0, "laser")
	assert(resumed.credits == before + 420, "Interception is paid at destination")
	resumed.mission.step()
	_dock_position(resumed, 1)
	assert(resumed.credits == before + 800 and resumed.contracts.reputation.guard == 8)
	assert(resumed.contracts.active.size() == 1)
	var parked = _game()
	await process_frame
	assert(parked.credits == resumed.credits and parked.contracts.capture() == resumed.contracts.capture())
	assert(parked.contracts.finish(survey, 0).is_empty())
	assert(not parked.contracts.finish(survey, 1).is_empty())
	var last: int = parked.contracts.accept("pirate", 0, 0)
	assert(not parked.contracts.finish(last, 1).is_empty() and parked.contracts.can_accept("raider", 0))
	for node in [parked, resumed, game]:
		node.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE + suffix)
	print("Contract tests PASS")
	quit()
