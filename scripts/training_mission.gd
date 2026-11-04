extends Node
const Sector = preload("res://scripts/sector_data.gd")
var origin := 0
var destination := 1
var cargo_loaded := false
const DOCK_POINT := Vector3(35,0,-123)
const BEACON := Vector3(0,0,-300)
const REWARD := 300
var kind := "combat"
var scan_elapsed := 0.0
var beacon: MeshInstance3D
var game: Node3D
var stage := "ИНСТРУКТАЖ"

func setup(owner_game: Node3D) -> void:
	game = owner_game
	kind = game.selected_mission
	origin = game.station_id
	destination = 1-origin
	cargo_loaded = false
	beacon = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 4.5
	ring.outer_radius = 5.0
	ring.rings = 32
	ring.ring_segments = 8
	beacon.mesh = ring
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("54dfff")
	beacon.material_override = glow
	game.add_child(beacon)
	beacon.position = BEACON
	beacon.rotation_degrees.x = 90
	beacon.visible = false
	game.ship.position = Sector.dock_point(origin)
	game.ship.look_at(BEACON)
	game.enemies[0].position = BEACON+Vector3(-16,4,10)
	game.enemies[1].position = BEACON+Vector3(18,-4,-15)
	for target in game.enemies:
		if target.get_meta("hostile"):
			target.position = BEACON+Vector3(0,5,-50)
			target.visible = false
			target.get_node("PilotAI").enabled = false

func flight_locked() -> bool:
	return stage == "ИНСТРУКТАЖ" or stage == "ЗАВЕРШЕНО" or stage == "ПРОВАЛ"

func launch() -> void:
	if stage != "ИНСТРУКТАЖ":return
	stage = "ДОСТАВКА" if kind=="delivery" else "ВЫЛЕТ"
	cargo_loaded = kind=="delivery"
	beacon.visible = not cargo_loaded
	if cargo_loaded:game.ship.look_at(nav_position())
	game.clear_held_input()
	game._save_progress()

func begin_combat() -> void:
	if stage != "ВЫЛЕТ":return
	stage = "БОЙ"
	beacon.visible = false
	for target in game.enemies:
		if target.get_meta("hostile"):
			target.visible = true
			var pilot = target.get_node("PilotAI")
			pilot.enabled = true
			pilot.setup(game,target)

func step(delta := 0.0) -> void:
	if game.destroyed:
		stage = "ПРОВАЛ"
		return
	if stage == "ВЫЛЕТ" and game.ship.position.distance_to(BEACON) <= 70.0:
		if kind == "scout":stage = "СКАНИРОВАНИЕ"
		else:begin_combat()
	elif stage == "СКАНИРОВАНИЕ":
		if game.ship.position.distance_to(BEACON)<=35 and game.velocity.length()<=8:
			scan_elapsed = minf(3,scan_elapsed+delta)
		else:scan_elapsed = 0
		if scan_elapsed>=3:
			stage = "ВОЗВРАЩЕНИЕ"
			beacon.visible = false
			game.clear_held_input()
	elif stage == "БОЙ":
		var hostiles := 0
		for target in game.enemies:
			if target.get_meta("hostile"):hostiles += 1
		if hostiles == 0:
			stage = "ВОЗВРАЩЕНИЕ"
			game.clear_held_input()

func can_dock() -> bool:
	return stage in ["ВОЗВРАЩЕНИЕ","ДОСТАВКА"] and (kind!="delivery" or cargo_loaded) and not game.destroyed and game.ship.position.distance_to(nav_position()) <= 14.0 and game.velocity.length() <= 5.0

func dock() -> void:
	if not can_dock():return
	var arrival: Vector3 = nav_position()
	if kind=="delivery":game.station_id = destination
	cargo_loaded = false
	stage = "ЗАВЕРШЕНО"
	game.velocity = Vector3.ZERO
	game.throttle = 0
	game.ship.position = arrival
	game.clear_held_input()
	game.shield = 100.0+game.upgrades.shield*25.0
	game.visuals.update_flight(0)
	game.credits += reward()
	game.training_runs += 1
	game._save_progress()

func nav_position() -> Vector3:
	if stage=="ДОСТАВКА":return Sector.dock_point(destination)
	return Sector.dock_point(origin) if stage=="ВОЗВРАЩЕНИЕ" else BEACON

func objective() -> String:
	match stage:
		"ИНСТРУКТАЖ":return "МЕНЮ СТАНЦИИ"
		"ВЫЛЕТ":return "ЛЕТИТЕ К МАЯКУ"
		"БОЙ":return "УНИЧТОЖЬТЕ ПРОТИВНИКА"
		"СКАНИРОВАНИЕ":return "ПРОСКАНИРУЙТЕ МАЯК"
		"ВОЗВРАЩЕНИЕ":return "ВЕРНИТЕСЬ НА СТАНЦИЮ"
		"ДОСТАВКА":return "ДОСТАВЬТЕ КОНТЕЙНЕР"
		"ЗАВЕРШЕНО":return "МИССИЯ ВЫПОЛНЕНА"
		_:return "ВЫЛЕТ ПРЕРВАН"

func hint() -> String:
	var distance: int = int(game.ship.position.distance_to(nav_position()))
	match stage:
		"ВЫЛЕТ":return "До маяка %d м · прибавьте тягу" % distance
		"СКАНИРОВАНИЕ":return "Сканирование %.1f/3 с · до 35 м, скорость до 8 м/с" % scan_elapsed
		"ВОЗВРАЩЕНИЕ", "ДОСТАВКА":
			if distance > 14:return "%s · до стыковки %d м" % [Sector.title(destination if kind=="delivery" else origin),distance]
			if game.velocity.length() > 5:return "Снизьте скорость до 5 м/с · тяга 0, стабилизация ВКЛ"
			return "Стыковка разрешена · нажмите «СТЫКОВКА»"
		_:return ""

func reward() -> int:
	if kind=="delivery":return 220
	return 150 if kind=="scout" else REWARD
