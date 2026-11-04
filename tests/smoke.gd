extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var previous = FileAccess.get_file_as_bytes("user://space_prototype.json") if FileAccess.file_exists("user://space_prototype.json") else PackedByteArray()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.store.path = "user://fixture_smoke.json"
	game.pending_snapshot.clear()
	game.selected_mission = "combat"
	game.mission.kind = "combat"
	game.mission.launch()
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	check(game.enemies.size() == 3, "three targets loaded")
	check(game.external_camera.current, "external camera initially active")
	game._toggle_camera()
	check(game.cockpit_camera.current and not game.external_camera.current, "cockpit switch")
	game.throttle = 1.0
	game._physics_process(1.0)
	check(game.velocity.length() > 0.0, "throttle accelerates ship")
	game.throttle = 0.0
	game.velocity = Vector3(10, 0, 0)
	game.stabilized = false
	game._physics_process(0.1)
	check(is_equal_approx(game.velocity.x, 10.0), "inertia retains sideways motion")
	game.stabilized = true
	game._physics_process(0.1)
	check(game.velocity.x < 10.0, "stabilization damps sideways motion")
	game.ship.position = Vector3.ZERO
	game.ship.rotation = Vector3.ZERO
	var target = game.enemies[0]
	target.position = Vector3(0, 0, -30)
	target.set_meta("health", 1.0)
	var before: int = game.credits
	game._shoot()
	check(game.enemies.size() == 2 and game.credits == before + 50, "destroyed target awards credits")
	game.mission.stage = "ИНСТРУКТАЖ"
	game.credits = 0
	game.upgrades.engine = 0
	game._buy("engine")
	check(game.upgrades.engine == 0 and game.credits == 0, "purchase blocked without credits")
	game.credits = 100
	game._buy("engine")
	check(game.upgrades.engine == 1 and game.credits == 0, "purchase spends credits and upgrades")
	game._load_progress()
	check(game.upgrades.engine == 1, "saved upgrade restored")
	if previous.is_empty():
		DirAccess.remove_absolute("user://space_prototype.json")
	else:
		var restore := FileAccess.open("user://space_prototype.json", FileAccess.WRITE)
		restore.store_buffer(previous)
		restore.close()
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(game.store.path+suffix)
	game.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
