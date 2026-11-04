extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://resume_isolated.json"
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = path
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	game.mission.launch()
	game.mission.begin_combat()
	game.ship.position = Vector3(10,4,-280)
	game.velocity = Vector3(2,3,4)
	game.throttle = .4
	game.hull = 67
	game.shield = 43
	game.credits = 123
	var pilot = game.enemies[2].get_node("PilotAI")
	pilot.state = "УКЛОНЕНИЕ"
	pilot.state_time = .7
	pilot.waypoint = Vector3(40,10,-340)
	game.enemies[2].set_meta("health",33.0)
	var dead = game.enemies.pop_front()
	dead.queue_free()
	assert(game._save_progress(),"checkpoint saved")
	var other = load("res://main.tscn").instantiate()
	root.add_child(other)
	other.set_physics_process(false)
	await process_frame
	other.store.path = path
	other._load_progress()
	assert(not other.pending_snapshot.is_empty(),"resume available")
	assert(other.resume_flight(),"resume accepted")
	assert(other.mission.stage == "БОЙ" and other.enemies.size()==2,"stage and destroyed target restored")
	assert(other.ship.position.distance_to(game.ship.position)<.001 and other.velocity == game.velocity,"flight state restored")
	assert(other.hull == 67 and other.shield == 43 and other.credits == 123,"health and money restored")
	var restored = other.enemies[1].get_node("PilotAI")
	assert(restored.state == "УКЛОНЕНИЕ" and is_equal_approx(restored.state_time,.7),"AI state restored")
	assert(other.enemies[1].get_meta("health")==33,"opponent health restored")
	other._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(not other.store.read_document().flight.is_empty(),"background saves active flight")
	other.pending_snapshot = {"version":1,"stage":"БОЙ"}
	assert(not other.resume_flight(),"broken snapshot rejected")
	other.pending_snapshot.clear()
	other.mission.stage = "ВОЗВРАЩЕНИЕ"
	other.ship.position = other.mission.DOCK_POINT
	other.velocity = Vector3.ZERO
	other.mission.dock()
	assert(other.store.read_document().flight.is_empty(),"dock clears resume slot")
	var amount: int = other.credits
	other.mission.dock()
	assert(other.credits==amount,"dock reward once after restore")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	game.queue_free()
	other.queue_free()
	await process_frame
	print("Resume checkpoint tests PASS")
	quit()
