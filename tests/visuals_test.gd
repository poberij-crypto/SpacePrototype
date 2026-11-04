extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_visuals_test.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	game.mission.launch()
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	assert(game.visuals != null, "visual module loaded")
	assert(game.visuals.body.visible, "body visible externally")
	assert(not game.visuals.cabin.visible, "cabin hidden externally")
	game._toggle_camera()
	assert(not game.visuals.body.visible and game.visuals.cabin.visible, "cockpit shows cabin only")
	game._toggle_camera()
	assert(game.visuals.body.visible and not game.visuals.cabin.visible, "external model restored")
	game.visuals.update_flight(0.0)
	var idle: float = game.visuals.plumes[0].scale.y
	game.visuals.update_flight(1.0)
	assert(game.visuals.plumes[0].scale.y > idle, "throttle increases exhaust")
	game._shoot()
	assert(game.fx.get_child_count() > 0, "shot creates visible effects")
	game.fx.burst(Vector3(0,0,-20), true)
	for i in range(100):game.fx.beam(Vector3.ZERO,Vector3(0,0,-10))
	assert(game.fx.active_count() <= 48, "effect count bounded")
	await create_timer(1.3).timeout
	assert(game.fx.active_count() == 0, "effects expire")
	print("Visual effects tests PASS")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	quit()
