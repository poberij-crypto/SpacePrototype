extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://delivery_isolated.json"
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = path
	game.pending_snapshot.clear()
	game.choose_mission("delivery")
	game.start_selected_mission()
	assert(game.mission.stage=="ДОСТАВКА" and game.mission.cargo_loaded,"cargo loaded on accepting delivery")
	assert(not game.mission.can_dock(),"origin is not delivery destination")
	var start: Vector3 = game.ship.position
	for i in range(4000):
		var goal: Vector3 = game.mission.nav_position()
		var distance: float = game.ship.position.distance_to(goal)
		if distance>.1:game.ship.look_at(goal)
		game.throttle = .65 if distance>45 else (.2 if distance>12 else 0.0)
		game._physics_process(1.0/60.0)
		if game.mission.can_dock():break
	assert(game.mission.can_dock() and game.ship.position.distance_to(start)>400,"delivery destination reachable")
	var before: int = game.credits
	game.mission.dock()
	assert(game.station_id==1 and not game.mission.cargo_loaded,"cargo handed over at station 1")
	assert(game.credits==before+220,"delivery reward")
	game.mission.dock()
	assert(game.credits==before+220,"no duplicate reward")
	var parked = load("res://main.tscn").instantiate()
	parked.store.path = path
	root.add_child(parked)
	parked.set_physics_process(false)
	await process_frame
	assert(parked.station_id==1 and parked.ship.position.distance_to(parked.Sector.dock_point(1))<.01,"docked station persists across launch")
	parked.queue_free()
	game.choose_mission("delivery")
	game.start_selected_mission()
	assert(game.mission.origin==1 and game.mission.destination==0,"reverse route")
	game.throttle = .65
	for i in range(120):game._physics_process(1.0/60.0)
	game._save_progress()
	var other = load("res://main.tscn").instantiate()
	root.add_child(other)
	other.set_physics_process(false)
	await process_frame
	other.store.path = path
	other._load_progress()
	assert(other.resume_flight(),"delivery resume")
	assert(other.mission.origin==1 and other.mission.destination==0 and other.mission.cargo_loaded,"cargo and route restored")
	assert(other.ship.position.distance_to(game.ship.position)<.001,"position on route restored")
	for i in range(4000):
		var goal: Vector3 = other.mission.nav_position()
		var distance: float = other.ship.position.distance_to(goal)
		if distance>.1:other.ship.look_at(goal)
		other.throttle = .65 if distance>45 else (.2 if distance>12 else 0.0)
		other._physics_process(1.0/60.0)
		if other.mission.can_dock():break
	assert(other.mission.can_dock(),"reverse route reachable by flight")
	other.velocity = Vector3(6,0,0)
	assert(not other.mission.can_dock(),"speed gate")
	other.velocity = Vector3.ZERO
	other.mission.dock()
	assert(other.station_id==0,"reverse delivery completed")
	other.choose_mission("combat")
	other.start_selected_mission()
	var legacy: Dictionary = other.snapshots.capture(other)
	legacy.version = 1
	for key in ["origin","destination","cargo"]:legacy.erase(key)
	legacy = JSON.parse_string(JSON.stringify(legacy))
	assert(other.snapshots.restore(other,legacy),"0.6 snapshot migration")
	assert(other.mission.origin==0 and not other.mission.cargo_loaded,"legacy origin default")
	other._toggle_map()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = other.flight_ui.map_panel.project(other.Sector.position(1))
	other.flight_ui.map_panel._gui_input(click)
	assert(other.flight_ui.map_panel.selected==1,"station selection on map")
	var held: Vector3 = other.ship.position
	other._physics_process(1.0)
	assert(other.ship.position==held,"map pauses flight")
	other.flight_ui.map_panel.close_button.pressed.emit()
	assert(not other.flight_ui.map_panel.visible and not other.firing,"map closes safely")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	game.queue_free()
	other.queue_free()
	await process_frame
	print("Delivery and map tests PASS")
	quit()
