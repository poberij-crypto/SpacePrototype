extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_ai_test.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	game.mission.launch()
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	game.mission.begin_combat()
	game.enemies[2].position = Vector3(0,5,-120)
	game.enemies[2].look_at(game.ship.position)
	var target = game.enemies[2]
	var ai = target.get_node("PilotAI")
	var distance: float = target.position.distance_to(game.ship.position)
	for i in range(60): ai.step(1.0/60.0)
	assert(target.position.distance_to(game.ship.position) < distance, "enemy closes distance")
	assert(ai.state == "АТАКА", "enemy enters attack range")
	assert(ai.can_fire(), "aligned enemy can fire")
	ai.consume_shot()
	assert(not ai.can_fire(), "fire cooldown")
	target.look_at(target.global_position + Vector3.RIGHT)
	assert(not ai.can_fire(), "cannot fire away from player")
	ai.on_hit()
	assert(ai.state == "УКЛОНЕНИЕ", "damage triggers evade")
	for i in range(90):ai.step(1.0/60.0)
	assert(ai.state == "РАЗВОРОТ", "evade transitions into disengage")
	for i in range(190):ai.step(1.0/60.0)
	assert(ai.state == "СБЛИЖЕНИЕ" or ai.state == "АТАКА", "returns for another pass")
	ai.state = "АТАКА"
	ai.cooldown = 0
	target.position = Vector3(0,0,-60)
	target.look_at(game.ship.global_position)
	var shield_before: float = game.shield
	game._enemy_attack()
	assert(game.shield < shield_before, "aimed attack causes damage")
	ai.cooldown = 0
	target.look_at(target.position+Vector3.RIGHT)
	shield_before = game.shield
	game._enemy_attack()
	assert(game.shield == shield_before, "off-axis enemy does not damage player")
	var paused_position: Vector3 = target.position
	game.upgrades_panel.visible = true
	game._physics_process(1.0)
	assert(target.position == paused_position, "menu pauses AI")
	game.upgrades_panel.visible = false
	var ui = game.flight_ui
	ui.size = Vector2(720,1280)
	game.firing = true
	game.turn_input = Vector2.ONE
	ui._layout()
	assert(ui.portrait, "portrait layout")
	assert(not game.firing and game.turn_input == Vector2.ZERO, "rotation clears held input")
	assert(Rect2(Vector2.ZERO,ui.design_size).encloses(ui.fire_button.get_rect()), "portrait fire fits")
	assert(not ui.fire_button.get_rect().intersects(ui.steering_rect()), "touch zones separated")
	ui.size = Vector2(1280,720)
	ui._layout()
	assert(not ui.portrait, "landscape restored")
	print("AI and orientation tests PASS")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	quit()
