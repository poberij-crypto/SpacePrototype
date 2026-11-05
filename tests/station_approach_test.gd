extends SceneTree
var failures := 0
const PATH := "user://station_approach_test.json"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.store.path = PATH
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.pending_snapshot.clear()
	game.start_planet_flight()
	game.ship.position = game.Sector.position(0) + Vector3(25, 0, 0)
	game.velocity = Vector3.ZERO
	game.flight_ui._update_mission_panel()
	check(game.flight_ui.dock_button.visible, "Approaching a station offers interaction before mission completion")
	if not game.has_method("request_station_dock"):
		check(false, "Station interaction must work through the normal UI")
		game.free()
		quit(1)
		return
	var credits: int = game.credits
	var runs: int = game.training_runs
	game.flight_ui.dock_button.pressed.emit()
	check(game.station_dock_dialog.visible and not game.at_station(), "Unfinished expedition asks before cancellation")
	var stage: String = game.mission.stage
	game._physics_process(1)
	check(game.mission.stage == stage, "Docking confirmation pauses flight")
	var working_path: String = game.store.path
	game.store.path = "user://missing-dock-test-dir/save.json"
	game.station_dock_dialog.confirmed.emit()
	check(not game.at_station() and game.credits == credits and game.training_runs == runs, "Failed docking save retains the unfinished flight")
	game.store.path = working_path
	game.station_dock_dialog.confirmed.emit()
	game.station_dock_dialog.hide()
	check(game.at_station() and game.can_trade(), "Confirmed approach opens station services")
	check(game.credits == credits and game.training_runs == runs, "Unfinished mission grants no reward")
	game.choose_mission("delivery")
	game.start_selected_mission()
	game.ship.position = game.Sector.position(1) + Vector3(25, 0, 0)
	game.velocity = Vector3(6, 0, 0)
	game.flight_ui._update_mission_panel()
	check(game.flight_ui.dock_button.visible and game.flight_ui.dock_button.disabled, "Nearby station explains speed restriction")
	game.velocity = Vector3.ZERO
	game.flight_ui._update_mission_panel()
	check(not game.flight_ui.dock_button.disabled and game.mission.can_dock(), "Approach works next to station geometry")
	game.store.path = "user://missing-dock-test-dir/save.json"
	game.flight_ui.dock_button.pressed.emit()
	check(game.mission.stage == "ДОСТАВКА" and game.mission.cargo_loaded and game.credits == credits and game.station_id == 0, "Failed completed docking restores reward and contract")
	game.store.path = working_path
	game.flight_ui.dock_button.pressed.emit()
	check(game.station_id == 1 and game.credits == credits + 220, "Completed delivery docks and pays through UI")
	game.request_station_dock()
	check(game.credits == credits + 220, "Station contact cannot duplicate rewards")
	game.start_neighbor_flight()
	game.ship.position = game.mission.nav_position()
	game.velocity = Vector3.ZERO
	game.planet.action()
	game.ship.position = game.Sector.position(0)
	game.flight_ui._update_mission_panel()
	check(not game.flight_ui.dock_button.visible, "Home stations are unavailable in a different system")
	game.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	print("Station approach tests: %d failures" % failures)
	quit(1 if failures else 0)
