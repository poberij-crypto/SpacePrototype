extends Node
const Sector = preload("res://scripts/sector_data.gd")
var contract_id := 0
var origin := 0
var destination := 1
var cargo_loaded := false
var interrupted := false
const DOCK_POINT := Vector3(35,0,-123)
const BEACON := Vector3(0,0,-300)
const REWARD := 300
const PIRATE_OFFSETS := [Vector3(0, 5, -50), Vector3(57, 14, -18), Vector3(-55, -14, 25)]
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
	interrupted = false
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

func field_point() -> Vector3:
	return beacon.position

func assign_contract(id: int) -> void:
	var was_assigned := contract_id > 0
	contract_id = id
	var order: Dictionary = game.contracts.order(id)
	beacon.position = order.site if not order.is_empty() else BEACON
	if id == 0 and not was_assigned:
		return
	for target in game.enemies.duplicate():
		if int(target.get_meta("id")) >= 3:
			game.enemies.erase(target)
			target.queue_free()
	for index in range(1, int(order.get("pirates", 1))):
		game._create_target(beacon.position + PIRATE_OFFSETS[index], true, 2 + index)
	for target in game.enemies:
		var hostile: bool = target.get_meta("hostile")
		target.visible = id == 0 and not hostile
		if hostile:
			var index := int(target.get_meta("id")) - 2
			target.position = beacon.position + PIRATE_OFFSETS[index]
			target.set_meta("shield", order.get("target_shield", 30.0))
			target.get_node("PilotAI").enabled = false

func hostiles_remaining() -> int:
	var count := 0
	for target in game.enemies:
		if target.get_meta("hostile"):
			count += 1
	return count

func flight_locked() -> bool:
	return stage in ["ИНСТРУКТАЖ","ЗАВЕРШЕНО","ПРОВАЛ","СПУСК","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ","ВЫХОД НА ОРБИТУ"]

func launch() -> void:
	if stage != "ИНСТРУКТАЖ":return
	if kind=="delivery" and game.cargo_used()+game.Trade.CONTRACT_SIZE>game.Trade.CAPACITY:return
	stage = "ПЕРЕЛЁТ" if kind=="trade" else ("ДОСТАВКА" if kind=="delivery" else "ВЫЛЕТ")
	if kind=="planet":stage=game.planet.OUTBOUND if game.planet.neighbor_route else "К ПЛАНЕТЕ"
	cargo_loaded = kind=="delivery"
	beacon.visible = kind not in ["delivery","trade","planet"]
	if contract_id > 0 or kind in ["delivery","trade","planet"]:game.ship.look_at(nav_position())
	if kind=="planet":game.planet.sync_space()
	game.clear_held_input()
	if not game._save_progress() and contract_id > 0:
		stage = "ИНСТРУКТАЖ"
		cargo_loaded = false
		beacon.visible = false
		assign_contract(0)

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
			pilot.cooldown = (int(target.get_meta("id")) - 2) * 0.35

func step(delta := 0.0) -> void:
	if game.destroyed:
		stage = "ПРОВАЛ"
		return
	if stage == "ВЫЛЕТ" and game.ship.position.distance_to(field_point()) <= 70.0:
		if kind == "scout":stage = "СКАНИРОВАНИЕ"
		else:begin_combat()
	elif stage == "СКАНИРОВАНИЕ":
		if game.ship.position.distance_to(field_point())<=35 and game.velocity.length()<=8:
			scan_elapsed = minf(3,scan_elapsed+delta)
		else:scan_elapsed = 0
		if scan_elapsed>=3:
			stage = "ВОЗВРАЩЕНИЕ"
			beacon.visible = false
			game.clear_held_input()
	elif stage == "БОЙ" and hostiles_remaining() == 0:
		stage = "ВОЗВРАЩЕНИЕ"
		game.clear_held_input()

func nearby_station() -> int:
	if game.destroyed or flight_locked() or game.planet.on_surface() or game.planet.in_neighbor():
		return -1
	var nearest := -1
	var distance := Sector.CONTACT_RADIUS
	for id in range(Sector.POSITIONS.size()):
		var current: float = game.ship.position.distance_to(Sector.position(id))
		if current <= distance:
			distance = current
			nearest = id
	return nearest

func can_station_dock(id: int) -> bool:
	return id >= 0 and id < Sector.POSITIONS.size() and nearby_station() == id \
		and game.ship.position.distance_to(Sector.position(id)) <= Sector.DOCK_RADIUS \
		and game.velocity.length() <= Sector.DOCK_SPEED

func arrival_station() -> int:
	return destination if contract_id > 0 or kind in ["delivery", "trade"] else origin

func can_dock() -> bool:
	return stage in ["ВОЗВРАЩЕНИЕ", "ДОСТАВКА", "ПЕРЕЛЁТ"] \
		and (kind != "delivery" or cargo_loaded) and can_station_dock(arrival_station())

func dock() -> void:
	if can_dock():
		_finish_docking(arrival_station(), true)

func interrupt_and_dock(id: int) -> void:
	if can_station_dock(id):
		_finish_docking(id, false)

func _finish_docking(id: int, completed: bool) -> void:
	var receipt: Dictionary = {}
	var previous_contracts: Dictionary = {}
	if completed and contract_id > 0:
		previous_contracts = game.contracts.capture()
		receipt = game.contracts.finish(contract_id, id)
		if receipt.is_empty():
			return
	var previous := {"stage":stage, "cargo":cargo_loaded, "interrupted":interrupted,
		"station":game.station_id, "velocity":game.velocity, "throttle":game.throttle,
		"position":game.ship.position, "shield":game.shield,
		"credits":game.credits, "runs":game.training_runs}
	game.station_id = id
	cargo_loaded = false
	stage = "ЗАВЕРШЕНО"
	interrupted = not completed
	game.velocity = Vector3.ZERO
	game.throttle = 0
	game.ship.position = Sector.dock_point(id)
	game.clear_held_input()
	game.shield = 100.0 + game.upgrades.shield * 25.0
	if completed:
		if receipt.is_empty():
			game.credits += reward()
			game.training_runs += 1
		else:
			game.credits += int(receipt.reward)
	if not game._save_progress():
		if not previous_contracts.is_empty():
			game.contracts.restore(previous_contracts)
		stage = previous.stage
		cargo_loaded = previous.cargo
		interrupted = previous.interrupted
		game.station_id = previous.station
		game.velocity = previous.velocity
		game.throttle = previous.throttle
		game.ship.position = previous.position
		game.shield = previous.shield
		game.credits = previous.credits
		game.training_runs = previous.runs
		return
	if not receipt.is_empty():
		game.contract_note = "Оплачено %d кр. · %s %+d" % [receipt.reward, game.contracts.FACTIONS[receipt.faction], receipt.trust]
	beacon.visible = false
	game.combat.reset()
	for target in game.enemies:
		target.visible = false
		var pilot = target.get_node_or_null("PilotAI")
		if pilot != null:
			pilot.enabled = false
	game.visuals.update_flight(0)

func nav_position() -> Vector3:
	if kind=="planet" and stage!="ВОЗВРАЩЕНИЕ":
		return game.planet.nav_point()
	if stage in ["ДОСТАВКА","ПЕРЕЛЁТ"]:return Sector.dock_point(destination)
	return Sector.dock_point(arrival_station()) if stage=="ВОЗВРАЩЕНИЕ" else field_point()

func objective() -> String:
	var order: Dictionary = game.contracts.order(contract_id)
	if not order.is_empty() and not flight_locked():
		match stage:
			"БОЙ":return "ПИРАТЫ · ОСТАЛОСЬ %d" % hostiles_remaining()
			"СКАНИРОВАНИЕ":return "ПРОСКАНИРУЙТЕ МАЯК"
			"ВОЗВРАЩЕНИЕ":return "СДАЙТЕ КОНТРАКТ"
			_:return str(order.title)
	if game.has_orbital_target():return "ИССЛЕДУЙТЕ %s" % game.flight_nav_title()
	if kind=="planet" and stage not in ["ИНСТРУКТАЖ","ЗАВЕРШЕНО","ПРОВАЛ","ВОЗВРАЩЕНИЕ"]:return game.planet.region_title()
	match stage:
		"ИНСТРУКТАЖ":return "МЕНЮ СТАНЦИИ"
		"ВЫЛЕТ":return "ЛЕТИТЕ К МАЯКУ"
		"БОЙ":return "УНИЧТОЖЬТЕ ПРОТИВНИКА"
		"СКАНИРОВАНИЕ":return "ПРОСКАНИРУЙТЕ МАЯК"
		"ВОЗВРАЩЕНИЕ":return "ВЕРНИТЕСЬ НА СТАНЦИЮ"
		"ДОСТАВКА":return "ДОСТАВЬТЕ КОНТЕЙНЕР"
		"ПЕРЕЛЁТ":return "ПЕРЕЛЁТ К ДРУГОЙ СТАНЦИИ"
		"ЗАВЕРШЕНО":return "МИССИЯ ВЫПОЛНЕНА"
		_:return "ВЫЛЕТ ПРЕРВАН"

func hint() -> String:
	var distance: int = int(game.ship.position.distance_to(nav_position()))
	match stage:
		"ВЫЛЕТ":return "До маяка %d м · прибавьте тягу" % distance
		"СКАНИРОВАНИЕ":return "Сканирование %.1f/3 с · до 35 м, скорость до 8 м/с" % scan_elapsed
		"ВОЗВРАЩЕНИЕ", "ДОСТАВКА", "ПЕРЕЛЁТ":
			if not can_station_dock(arrival_station()) and game.ship.position.distance_to(Sector.position(arrival_station())) > Sector.DOCK_RADIUS:return "%s · до стыковки %d м" % [Sector.title(arrival_station()),distance]
			if game.velocity.length() > 5:return "Снизьте скорость до 5 м/с · тяга 0, стабилизация ВКЛ"
			return "Стыковка разрешена · нажмите «СТЫКОВКА»"
		_:return ""

func reward() -> int:
	if kind in ["trade","planet"]:return 0
	if kind=="delivery":return 220
	return 150 if kind=="scout" else REWARD
