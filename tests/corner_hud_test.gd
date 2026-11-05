extends SceneTree

const SAVE := "user://corner_hud_test.json"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE+suffix)
	var game = load("res://main.tscn").instantiate()
	game.store.path = SAVE
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	var ui = game.flight_ui
	# These include phone aspect ratios in both orientations and an unfolded device.
	for dimensions in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(720,1280),Vector2i(1080,2400),Vector2i(884,1104)]:
		game.steer_touch = 3
		game.fire_touch = 4
		game.turn_input = Vector2.ONE
		game.firing = true
		game.planet.vertical = 1.0
		root.size = dimensions
		for frame in range(3):
			await process_frame
		ui._layout()
		ui.planet_panel._process(0)
		var viewport: Vector2 = ui.size
		var bounds: Rect2 = ui.safe_bounds
		check(ui.from_design(ui.design_size).is_equal_approx(viewport), "Design surface fills viewport %s" % dimensions)
		check(ui.origin == Vector2.ZERO, "No letterbox moves corners inward %s" % dimensions)
		check(ui.camera_button.position.is_equal_approx(Vector2(bounds.end.x-ui.camera_button.size.x,bounds.position.y)), "Camera anchors at upper right %s" % dimensions)
		check(ui.stable_button.get_rect().end.is_equal_approx(bounds.end), "Stabilization anchors at lower right %s" % dimensions)
		check(is_equal_approx(ui.steering_rect().position.x,bounds.position.x) and is_equal_approx(ui.steering_rect().end.y,bounds.end.y), "Steering anchors at lower left %s" % dimensions)
		check(ui.from_design(ui.camera_button.get_rect().end).x >= viewport.x-24*ui.factor-.1, "Camera reaches the physical right edge %s" % dimensions)
		check(ui.from_design(ui.stable_button.get_rect().end).y >= viewport.y-24*ui.factor-.1, "Bottom controls reach physical bottom edge %s" % dimensions)
		var sample: Vector2 = ui.steering_rect().get_center()
		check(ui.to_design(ui.from_design(sample)).distance_to(sample)<.1, "Touch coordinates round trip %s" % dimensions)
		var rects: Array[Rect2] = [ui.steering_rect(),ui.speed_rect(),Rect2(ui.radar_center()-Vector2(61,61),Vector2(122,122)),ui.help_label.get_rect(),ui.planet_status_rect(),ui.mining_status_rect()]
		for button in [ui.camera_button,ui.controls["МОДУЛИ"],ui.controls["МЕНЮ"],ui.map_button,ui.market_button,ui.planet_panel.launch,ui.planet_panel.neighbor_launch,ui.planet_panel.report_button,ui.controls["+"],ui.controls["−"],ui.fire_button,ui.stable_button]:
			rects.append(button.get_rect())
		for i in range(rects.size()):
			check(bounds.encloses(rects[i]), "HUD rectangle %d stays in safe viewport %s" % [i,dimensions])
			for j in range(i):
				check(not rects[i].intersects(rects[j]), "Corner HUD rectangles %d/%d do not collide %s" % [i,j,dimensions])
		check(ui.planet_status_rect().end.x <= ui.design_size.x*.5 and ui.mining_status_rect().end.x <= ui.design_size.x*.5, "Planet status leaves the center clear %s" % dimensions)
		# Up/down replace fire in surface flight without covering the throttle buttons.
		check(ui.fire_button.get_rect().encloses(ui.planet_panel.up.get_rect()) and ui.fire_button.get_rect().encloses(ui.planet_panel.down.get_rect()), "Vertical controls use the fire area %s" % dimensions)
		check(not ui.planet_panel.up.get_rect().intersects(ui.planet_panel.down.get_rect()), "Vertical controls stay separate %s" % dimensions)
		check(absf(ui.dock_button.get_rect().get_center().x-ui.design_size.x*.5)<.1, "Context action remains central %s" % dimensions)
		if dimensions != Vector2i(1280,720):
			check(game.steer_touch == -1 and game.fire_touch == -1 and game.turn_input == Vector2.ZERO and not game.firing and game.planet.vertical == 0.0, "Resizing clears held touch input %s" % dimensions)
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE+suffix)
	print("Corner HUD tests: %d failures" % failures)
	quit(1 if failures else 0)
