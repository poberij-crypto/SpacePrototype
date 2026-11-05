extends SceneTree
const PATH := "user://orbital_system_test.json"
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func fresh():
	var game = load("res://main.tscn").instantiate()
	game.store.path = PATH
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	return game
func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	var game = fresh()
	if not game.has_method("orbit_system"):
		check(false, "Each star system must expose its central star and planets")
		game.free()
		quit(1)
		return
	for remote in [false, true]:
		var data: Dictionary = game.orbit_system(remote)
		check(data.planets.size() == 3 and data.star.radius > 0, "Both systems contain a star and three planets")
		for body in data.planets:
			check(body.position.distance_to(data.star.position) > data.star.radius + body.radius, "A planet is outside its host star")
			check(body.approach.distance_to(body.position) > body.radius + 8, "Approach point is outside the planet")
		var root_node = game.visuals.neighbor_root if remote else game.visuals.space_root
		check(root_node.get_node_or_null("CentralStar") != null, "The central star has visible geometry")
		check(root_node.get_node_or_null("PlanetaryBodies").get_child_count() == 3, "The scene renders every catalogued planet")
	var neighbor: Dictionary = game.planet.World.neighbor()
	check(neighbor.landing == Vector2(172,-163) and neighbor.reserve == 116, "Existing generated deposit retains its v1 seed geometry")
	check(game.orbit_system(true).planets[0].approach == neighbor.entry, "Terra Nova keeps its original entry point")
	check(game.orbit_system(false).planets[0].approach == game.planet.ENTRY, "Astra keeps its original entry point")
	var map = game.flight_ui.map_panel
	map.choose_planet(1)
	check(map.navigation_button.visible and not map.navigation_button.disabled, "Map selection offers navigation from the station")
	map.navigation_button.pressed.emit()
	check(game.has_orbital_target() and game.orbital_target == 1, "Map starts a flight toward the selected planet")
	check(game.flight_nav_position() == game.orbit_system(false).planets[1].approach, "Flight points at the selected planetary approach")
	check(not game.select_orbital_target(3) and game.orbital_target == 1, "Invalid target cannot replace navigation")
	check(not game.planet.can_enter(), "Orbit-only target cannot activate an unrelated surface")
	check(game._save_progress(), "Orbital navigation is saved")
	game.free()
	game = fresh()
	check(game.resume_flight() and game.orbital_target == 1, "Reopening restores the selected planet")
	game.ship.position = game.orbit_system(false).star.position
	game.velocity = Vector3(0,0,-10)
	game.constrain_orbit()
	check(game.ship.position.distance_to(game.orbit_system(false).star.position) > game.orbit_system(false).star.radius, "The ship cannot fly inside the star")
	var legacy: Dictionary = game.snapshots.capture(game)
	legacy.erase("orbital_target")
	check(game.snapshots.restore(game, legacy) and game.orbital_target == -1, "Older flight snapshots retain the original planetary route")
	game.select_orbital_target(0)
	check(not game.has_orbital_target() and game.flight_nav_position() == game.planet.ENTRY, "Choosing Astra restores the existing descent route")
	game.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	print("Orbital system tests: %d failures" % failures)
	quit(1 if failures else 0)
