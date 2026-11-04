extends SceneTree

const SAVE := "user://generated_system_test.json"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func open_game():
	var game = load("res://main.tscn").instantiate()
	game.store.path = SAVE
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	return game

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE + suffix)
	var game = open_game()
	if not game.has_method("start_neighbor_flight"):
		check(false, "The station must offer a flight to a generated system")
		game.free()
		quit(1)
		return

	game.start_planet_flight()
	var legacy: Dictionary = game.snapshots.capture(game)
	legacy.planet.erase("neighbor")
	legacy.planet.erase("generation")
	check(game.snapshots.restore(game, legacy) and not game.planet.in_neighbor(), "A pre-generation Astra checkpoint still resumes")
	game.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE + suffix)
	game = open_game()

	var world = game.planet.World
	var descriptor: Dictionary = world.neighbor()
	check(descriptor == world.neighbor(), "The shared starting galaxy is reproducible")
	check(descriptor != world.generate_system(world.START_SEED + 1, 1), "Another galaxy seed changes system generation")
	for seed in range(1, 17):
		var data: Dictionary = world.generate_system(seed, 1)
		var district = load("res://planet_region.tscn").instantiate()
		district.layout = data
		check(district.terrain_height(300, 300) != district.height_at(300, 300), "Generated terrain differs from Astra")
		check(district.safe_terrain(data.landing.x, data.landing.y), "Each generated site reserves flat terrain")
		district.free()

	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(884, 1104)]:
		root.size = dimensions
		for frame in range(3):
			await process_frame
		var panel = game.flight_ui.planet_panel
		check(panel.neighbor_launch.visible and not panel.neighbor_launch.get_rect().intersects(panel.launch.get_rect()), "Both station routes are visible and separate")
		var hull_panel := Rect2(24, 96, 300, 126) if game.flight_ui.portrait else Rect2(24, 86, 260, 126)
		check(not panel.neighbor_launch.get_rect().intersects(hull_panel), "The expedition button leaves hull and shield indicators visible")

	game.flight_ui.planet_panel.neighbor_launch.pressed.emit()
	check(game.mission.stage == "К ПРЫЖКУ", "Station starts the neighboring system route")
	game.free()
	game = open_game()
	check(game.resume_flight() and game.mission.stage == "К ПРЫЖКУ", "A saved outbound flight keeps its jump target")
	game.planet.action()
	check(game.mission.stage == "К ПРЫЖКУ", "Jump requires arrival at the gate")
	game.ship.position = game.mission.nav_position()
	game.velocity = Vector3(26, 0, 0)
	game.planet.action()
	check(game.mission.stage == "К ПРЫЖКУ", "Gate blocks a jump at excess speed")
	game.velocity = Vector3.ZERO
	game.planet.action()
	check(game.planet.in_neighbor() and game.mission.stage == "К ПЛАНЕТЕ", "Gate enters the generated system")
	check(game.planet.can_jump(), "Exploration can be aborted at the arrival gate before descent")
	for target in game.enemies:
		check(not target.visible, "Home-sector training targets do not appear in the neighboring system")
	game.ship.position = game.mission.nav_position()
	game.planet.action()
	for frame in range(300):
		game._physics_process(.05)
		if game.mission.stage == "ПОВЕРХНОСТЬ":
			break
		await process_frame
	check(game.planet.on_surface(), "Generated area loads through the normal descent")
	if not game.planet.on_surface():
		game.free()
		quit(1)
		return
	var pad: Vector3 = game.planet.region.ground_point(descriptor.landing)
	game.ship.position = pad + Vector3.UP * 12.0
	check(game.planet.start_survey(), "Generated signal can be surveyed")
	game._physics_process(5)
	check(game.planet.can_land(), "The suggested landing point is clear in the loaded scene")
	game.planet.action()
	game._physics_process(2)
	check(game.planet.deploy_mine(), "Generated deposit supports deployment")
	check(game.planet.load_ore() == 1 and not game.mining.surveyed, "The two deposits have independent state")
	game.free()

	game = open_game()
	check(game.resume_flight() and game.planet.in_neighbor() and game.planet.on_surface(), "A landed flight restores the correct system")
	check(game.planet.region.ground_point(descriptor.landing).is_equal_approx(pad), "The regenerated landing point is unchanged")
	check(game.neighbor_mining.installed and game.neighbor_mining.stock == 0 and game.cargo.ore == 1, "Mine and cargo survive restart")
	game.planet.action()
	game._physics_process(2)
	game.ship.position.y += 120
	game.planet.exit_orbit()
	game._physics_process(4)
	check(game.mission.stage == "К ОБРАТНОМУ ПРЫЖКУ", "Ascent leads back to the jump gate")
	game.free()
	game = open_game()
	check(game.resume_flight() and game.planet.in_neighbor() and game.mission.stage == "К ОБРАТНОМУ ПРЫЖКУ", "A saved return flight keeps the neighboring system")
	game.ship.position = game.mission.nav_position()
	game.velocity = Vector3.ZERO
	game.planet.action()
	check(not game.planet.in_neighbor() and game.mission.stage == "ВОЗВРАЩЕНИЕ", "Return jump restores the home sector")
	game.ship.position = game.mission.nav_position()
	check(game.mission.can_dock(), "The ship can dock after the jump")
	game.mission.dock()
	check(game.trade_goods("ore", 1, false), "Ore from the generated system sells at the existing market")
	game.free()
	print("Generated system tests: %d failures" % failures)
	quit(1 if failures else 0)
