extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_ui_test.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	game.mission.launch()
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	assert(game.flight_ui != null, "new flight HUD must exist")
	var ui = game.flight_ui
	assert(ui.fire_button.get_rect().size.x >= 120, "fire touch area")
	assert(ui.to_design(ui.from_design(Vector2(150, 560))).distance_to(Vector2(150, 560)) < 0.1, "scaled coordinates round trip")
	var down := InputEventScreenTouch.new()
	down.index = 1
	down.position = ui.from_design(Vector2(150, 560))
	down.pressed = true
	game._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = ui.from_design(Vector2(215, 560))
	game._input(drag)
	assert(game.turn_input.x > 0.9, "joystick drag mapped")
	var second := InputEventScreenTouch.new()
	second.index = 2
	second.position = ui.from_design(Vector2(1150, 560))
	second.pressed = true
	game._input(second)
	assert(game.steer_touch == 1, "second touch must not steal steering")
	assert(game.firing, "second finger fires while steering")
	second.pressed = false
	game._input(second)
	assert(not game.firing, "second finger release stops firing")
	down.pressed = false
	game._input(down)
	assert(game.turn_input == Vector2.ZERO, "release resets steering")
	ui.fire_button.button_down.emit()
	assert(game.firing, "hold fire starts firing")
	ui.fire_button.button_up.emit()
	assert(not game.firing, "release fire stops firing")
	game._toggle_upgrades()
	assert(game.upgrades_panel.visible, "upgrade menu opens")
	game._toggle_upgrades()
	assert(not game.upgrades_panel.visible, "upgrade menu closes")
	print("UI tests PASS")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	quit()
