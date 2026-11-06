extends SceneTree
var failures := 0
const PATH := "user://weapon_combat_test.json"
func _initialize() -> void: call_deferred("run")
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
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(PATH+suffix)
	var game = fresh()
	game.start_selected_mission()
	game.mission.begin_combat()
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	for target in game.enemies.duplicate():
		if not target.get_meta("hostile"):
			game.enemies.erase(target)
			target.free()
	var enemy = game.enemies[0]
	enemy.position = Vector3(0,0,-80)
	enemy.get_node("PilotAI").enabled = false
	game._shoot()
	check(enemy.get_meta("shield") == 0 and enemy.get_meta("health") < 90, "Laser volley removes shields before damaging the hull")
	check(game.armament.energy == 90 and game.armament.cooldowns[0] > 0, "Laser fire consumes energy and starts mount cooldown")
	var hp: float = enemy.get_meta("health")
	game._shoot()
	check(enemy.get_meta("health") == hp, "Repeated input cannot bypass weapon cooldown")
	game.armament.tick(.36)
	game.armament.group = 1
	game._shoot()
	check(is_equal_approx(game.armament.energy,91.48), "Left group fires only its own laser")
	game.armament.loadout = ["cannon", "plasma"]
	game.armament.cooldowns = [0.0,0.0]
	game.armament.heat = [0.0,0.0]
	game.armament.group = 0
	game.armament.energy = 100
	game.armament.ammo = 2
	enemy.set_meta("health",90.0)
	enemy.set_meta("shield",30.0)
	game._shoot()
	check(game.combat.projectiles.size() == 2 and game.armament.ammo == 1, "Cannon and plasma create projectiles and consume the correct resources")
	game.combat.step(.1)
	check(enemy.get_meta("health") == 90, "Projectile damage waits for arrival")
	check(game._save_progress(), "Flying projectiles are checkpointed")
	game.free()
	game = fresh()
	check(game.resume_flight() and game.combat.projectiles.size() == 2, "A resumed battle restores in-flight projectiles")
	check(game.armament.ammo == 1 and is_equal_approx(game.armament.energy,78), "Resume retains consumed ammunition and energy")
	enemy = game.enemies[0]
	for frame in range(90): game.combat.step(1.0/60.0)
	check(game.combat.projectiles.is_empty() and enemy.get_meta("health") < 90, "Both projectiles arrive exactly once after resume")
	game.armament.launcher = "launcher"
	game.armament.rockets = 2
	game.combat.step(.8)
	check(game.combat.lock_progress == 1, "The launcher acquires a visible aligned target")
	var working_path: String = game.store.path
	game.store.path = "user://missing-missile-save-dir/save.json"
	check(not game.combat.launch_missile() and game.armament.rockets == 2 and game.combat.projectiles.is_empty(), "A failed missile checkpoint rolls back ammunition and launch")
	game.store.path = working_path
	game.flight_ui.map_panel.visible = true
	check(not game.combat.launch_missile() and game.armament.rockets == 2, "Missiles cannot fire beneath a paused map")
	game.flight_ui.map_panel.visible = false
	enemy.set_meta("health",40.0)
	enemy.set_meta("shield",0.0)
	var balance: int = game.credits
	check(game.combat.launch_missile() and game.armament.rockets == 1 and game.armament.missile_cooldown == 3, "Full lock launches exactly one missile")
	check(not game.combat.launch_missile(), "Launcher reload prevents repeated launches")
	enemy.position.x = 12
	for frame in range(180): game.combat.step(1.0/60.0)
	check(game.enemies.is_empty() and game.credits == balance + 100 and game.combat.projectiles.is_empty(), "Guided missile follows a maneuvering target and awards one bounty")
	game.free()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(PATH+suffix)
	print("Weapon combat tests: %d failures" % failures)
	quit(1 if failures else 0)
