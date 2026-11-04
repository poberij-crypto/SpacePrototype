extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://space_prototype.json"
	var previous := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_mission_test.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	var m = game.mission
	assert(m.flight_locked(), "briefing freezes movement")
	assert(not game.enemies[2].get_node("PilotAI").enabled, "enemy inactive before departure")
	m.dock()
	assert(m.stage == "ИНСТРУКТАЖ", "cannot dock before mission")
	m.launch()
	assert(m.stage == "ВЫЛЕТ" and not m.flight_locked(), "launch starts flight")
	game.ship.position = m.BEACON
	m.step()
	assert(m.stage == "БОЙ" and game.enemies[2].visible, "beacon starts combat")
	var enemy = game.enemies[2]
	game.enemies.erase(enemy)
	enemy.queue_free()
	m.step()
	assert(m.stage == "ВОЗВРАЩЕНИЕ", "victory gives return objective")
	game.ship.position = Vector3.ZERO
	game.velocity = Vector3.ZERO
	assert(not m.can_dock(), "distance gate")
	game.ship.position = m.DOCK_POINT
	game.velocity = Vector3(6,0,0)
	assert(not m.can_dock(), "speed gate")
	game.velocity = Vector3.ZERO
	assert(m.can_dock(), "safe approach accepted")
	var before: int = game.credits
	var runs: int = game.training_runs
	m.dock()
	assert(m.stage == "ЗАВЕРШЕНО", "docked report")
	assert(game.credits == before+300 and game.training_runs == runs+1, "mission reward and log")
	m.dock()
	assert(game.credits == before+300, "no duplicate reward")
	game._load_progress()
	assert(game.credits == before+300 and game.training_runs == runs+1, "reward persisted")
	game.destroyed = true
	m.stage = "БОЙ"
	m.step()
	assert(m.stage == "ПРОВАЛ" and not m.can_dock(), "death blocks mission reward")
	if previous.is_empty():DirAccess.remove_absolute(path)
	else:
		var restore := FileAccess.open(path,FileAccess.WRITE)
		restore.store_buffer(previous)
		restore.close()
	print("Mission lifecycle tests PASS")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	quit()
