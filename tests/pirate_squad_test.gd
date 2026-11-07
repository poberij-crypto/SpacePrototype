extends SceneTree

const SAVE := "user://pirate_squad_test.json"

func _initialize() -> void:
	call_deferred("run")

func _new_game():
	var game = load("res://main.tscn").instantiate()
	game.store.path = SAVE
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _hostiles(game) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for target in game.enemies:
		if target.visible and target.get_meta("hostile"):
			result.append(target)
	return result

func run() -> void:
	var game = _new_game()
	await process_frame
	var order: int = game.accept_contract("pirate")
	assert(game.start_contract(order))
	game.ship.position = game.mission.field_point()
	game.mission.step()
	var pirates := _hostiles(game)
	assert(pirates.size() == 2, "Standard pirate contract activates two targets together")
	assert(pirates[0].position.distance_to(pirates[1].position) >= 40, "Pirates attack from separate starting positions")
	game.ship.basis = Basis.IDENTITY
	for i in range(pirates.size()):
		var target := pirates[i]
		target.position = game.ship.position + [Vector3(-60, 0, -20), Vector3(60, 0, 20)][i]
		target.look_at(game.ship.global_position)
		var pilot = target.get_node("PilotAI")
		pilot.state = "АТАКА"
		pilot.cooldown = 0.0
	var previous_shield: float = game.shield
	game._enemy_attack()
	assert(game.shield == previous_shield - 12.0, "Both pirates land a hit on the shield")
	var hud = game.flight_ui
	assert(hud.get("incoming_hits") is Dictionary, "Damage HUD records the source of each hit")
	assert(hud.incoming_hits.size() == 2, "Overlapping hits keep both incoming directions")
	var left: Vector3 = hud.incoming_hits[2].direction
	var right: Vector3 = hud.incoming_hits[3].direction
	assert(left.x < 0 and left.z < 0 and right.x > 0 and right.z > 0)
	assert(hud.hit_bearing(left).offset.x < 0 and not hud.hit_bearing(left).rear)
	assert(hud.hit_bearing(right).offset.x > 0 and hud.hit_bearing(right).rear)
	var front_right: Dictionary = hud.hit_bearing(Vector3(60, 0, -20).normalized())
	assert(front_right.offset.distance_to(hud.hit_bearing(right).offset) >= 35.0, "Front and rear hit cues with the same bearing do not cover each other")
	game._toggle_camera()
	assert(game.cockpit and hud.incoming_hits.size() == 2)
	game.ship.basis = Basis(Vector3.UP, PI)
	assert(hud.hit_bearing(left).offset.x > 0 and hud.hit_bearing(left).rear, "Damage bearing follows the ship's rotation")
	hud.age_hits(2.0)
	assert(hud.incoming_hits.is_empty(), "Damage indicators expire")
	game.shield = 0.0
	var previous_hull: float = game.hull
	pirates[1].get_node("PilotAI").cooldown = 0.0
	game._enemy_attack()
	assert(game.hull == previous_hull - 6.0 and hud.incoming_hits.has(3), "Hull damage also shows an indicator")
	var before: int = game.credits
	game.combat.apply_damage(pirates[0], 300.0, "laser")
	game.mission.step()
	assert(game.mission.stage == "БОЙ" and game.credits == before)
	var resumed = _new_game()
	await process_frame
	assert(resumed.resume_flight())
	var survivors := _hostiles(resumed)
	assert(survivors.size() == 1 and survivors[0].get_meta("id") == 3, "The remaining pirate survives a reload")
	assert(survivors[0].get_node("PilotAI").state == "АТАКА")
	resumed.combat.apply_damage(survivors[0], 300.0, "laser")
	resumed.mission.step()
	assert(resumed.mission.stage == "ВОЗВРАЩЕНИЕ")
	resumed.ship.position = resumed.Sector.dock_point(1)
	resumed.velocity = Vector3.ZERO
	resumed.request_station_dock()
	assert(resumed.credits == before + 380)
	resumed.contracts.change_reputation("guard", 7)
	var raider_order: int = resumed.accept_contract("raider")
	assert(resumed.start_contract(raider_order))
	resumed.ship.position = resumed.mission.field_point()
	resumed.mission.step()
	assert(_hostiles(resumed).size() == 3, "Raider contract activates three targets together")
	var raider: Node3D = resumed.combat.target_by_id(4)
	resumed.ship.look_at(raider.global_position)
	resumed.armament.launcher = "launcher"
	resumed.armament.rockets = 1
	resumed.combat.step(0.8)
	assert(resumed.combat.launch_missile(), "Missile can lock onto the third pirate")
	var snapshot: Dictionary = resumed.snapshots.capture(resumed)
	assert(snapshot.projectiles[0].target == 4)
	assert(resumed.snapshots.restore(resumed, JSON.parse_string(JSON.stringify(snapshot))))
	assert(resumed.combat.capture()[0].target == 4, "In-flight missile retains its target after loading")
	var legacy := snapshot.duplicate(true)
	legacy.version = 4
	legacy.projectiles = []
	legacy.targets = legacy.targets.filter(func(target): return target.id <= 2)
	assert(resumed.snapshots.restore(resumed, legacy))
	assert(_hostiles(resumed).size() == 1, "A legacy sortie resumes with its original pirate")
	var last_pirate: Node3D = _hostiles(resumed)[0]
	last_pirate.position = resumed.ship.position + Vector3(0, 0, 60)
	last_pirate.look_at(resumed.ship.global_position)
	last_pirate.get_node("PilotAI").state = "АТАКА"
	last_pirate.get_node("PilotAI").cooldown = 0.0
	resumed.shield = 0.0
	resumed.hull = 5.0
	resumed._enemy_attack()
	resumed.mission.step()
	resumed.flight_ui.age_hits(0.1)
	assert(resumed.destroyed and resumed.mission.stage == "ПРОВАЛ")
	assert(resumed.flight_ui.incoming_hits.has(2), "The last hit remains visible after the ship is destroyed")
	for node in [game, resumed]:
		node.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE + suffix)
	print("Pirate squad and damage direction tests PASS")
	quit()
