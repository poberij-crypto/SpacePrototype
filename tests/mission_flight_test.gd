extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://space_prototype.json"
	var previous := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_mission_flight_test.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	var before: int = game.credits
	game.flight_ui.mission_button.pressed.emit()
	game.stabilized = true
	game.throttle = .6
	for i in range(1200):
		game._physics_process(1.0/60.0)
		if game.mission.stage == "БОЙ":break
	assert(game.mission.stage == "БОЙ", "beacon reachable by flight")
	game.throttle = 0
	for i in range(1200):
		for enemy in game.enemies:
			if enemy.get_meta("hostile"):game.ship.look_at(enemy.global_position)
		game.firing = true
		game._physics_process(1.0/60.0)
		if game.mission.stage != "БОЙ":break
	assert(game.mission.stage == "ВОЗВРАЩЕНИЕ", "combat can be won")
	game.firing = false
	for i in range(3000):
		var distance: float = game.ship.position.distance_to(game.mission.DOCK_POINT)
		if distance > .1:game.ship.look_at(game.mission.DOCK_POINT)
		game.throttle = .5 if distance > 45 else (.2 if distance > 12 else 0.0)
		game._physics_process(1.0/60.0)
		if game.mission.can_dock():break
	assert(game.mission.can_dock(), "return and braking reach dock conditions")
	game.flight_ui._update_mission_panel()
	game.flight_ui.dock_button.pressed.emit()
	assert(game.mission.stage == "ЗАВЕРШЕНО" and game.credits == before+400, "full flight awards kill and mission credits")
	game.choose_mission("scout")
	game.start_selected_mission()
	for i in range(3000):
		var distance: float = game.ship.position.distance_to(game.mission.BEACON)
		if distance>.1:game.ship.look_at(game.mission.BEACON)
		game.throttle = .5 if distance>65 else (.15 if distance>12 else 0.0)
		game._physics_process(1.0/60.0)
		if game.mission.stage=="ВОЗВРАЩЕНИЕ":break
	assert(game.mission.stage=="ВОЗВРАЩЕНИЕ","scout beacon and scan reachable by flight")
	for i in range(3000):
		var distance: float = game.ship.position.distance_to(game.mission.DOCK_POINT)
		if distance>.1:game.ship.look_at(game.mission.DOCK_POINT)
		game.throttle = .5 if distance>45 else (.2 if distance>12 else 0.0)
		game._physics_process(1.0/60.0)
		if game.mission.can_dock():break
	assert(game.mission.can_dock(),"scout return flight")
	before = game.credits
	game.mission.dock()
	assert(game.credits==before+150,"scout full flight reward")
	if previous.is_empty():DirAccess.remove_absolute(path)
	else:
		var restore := FileAccess.open(path,FileAccess.WRITE)
		restore.store_buffer(previous)
		restore.close()
	print("Mission flight integration PASS")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	quit()
