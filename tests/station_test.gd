extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://station_isolated.json"
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = path
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"credits":99,"upgrades":{"engine":1,"shield":0,"weapon":0},"training_runs":2}))
	file.close()
	game._load_progress()
	assert(game.credits==99 and game.upgrades.engine==1 and game.pending_snapshot.is_empty(),"legacy save migration")
	game.hull = 60
	game.credits = 70
	game.repair_at_station()
	assert(game.hull==60 and game.credits==70,"repair funds gate")
	game.credits = 150
	game.repair_at_station()
	assert(game.hull==100 and game.credits==70,"repair cost")
	game.choose_mission("scout")
	game.start_selected_mission()
	assert(game.mission.kind=="scout","chosen task launched")
	game.credits = 200
	var engine: int = game.upgrades.engine
	game._buy("engine")
	assert(game.upgrades.engine==engine and game.credits==200,"modules not installed in flight")
	game.hull = 90
	game.repair_at_station()
	assert(game.hull==90,"no remote repair")
	game.ship.position = game.mission.BEACON
	game.velocity = Vector3.ZERO
	game.mission.step()
	game.mission.step(2.0)
	assert(game.mission.stage=="СКАНИРОВАНИЕ" and is_equal_approx(game.mission.scan_elapsed,2),"scanning progress")
	assert(not game.enemies[2].get_node("PilotAI").enabled,"scout does not spawn active enemy")
	game._save_progress()
	var restored = load("res://main.tscn").instantiate()
	root.add_child(restored)
	restored.set_physics_process(false)
	await process_frame
	restored.store.path = path
	restored._load_progress()
	restored.choose_mission("combat")
	assert(restored.selected_mission=="scout","pending mission cannot be replaced")
	assert(restored.resume_flight(),"scout resume")
	assert(is_equal_approx(restored.mission.scan_elapsed,2),"scan restored")
	restored.mission.step(1.0)
	assert(restored.mission.stage=="ВОЗВРАЩЕНИЕ","scan completes")
	restored.ship.position = restored.mission.DOCK_POINT
	restored.velocity = Vector3.ZERO
	var before: int = restored.credits
	restored.mission.dock()
	assert(restored.credits==before+150 and restored.hull==90,"scout reward and repair required")
	restored.choose_mission("combat")
	restored.start_selected_mission()
	assert(restored.enemies.size()==3 and restored.mission.kind=="combat","new task after docking")
	restored._physics_process(3.1)
	assert(not restored.store.read_document().flight.is_empty(),"periodic autosave")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	game.queue_free()
	restored.queue_free()
	await process_frame
	print("Station and scout tests PASS")
	quit()
