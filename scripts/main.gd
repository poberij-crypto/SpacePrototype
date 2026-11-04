extends Node3D

const SAVE_PATH := "user://space_prototype.json"
const Sector = preload("res://scripts/sector_data.gd")
const Trade = preload("res://scripts/trade_data.gd")
var cargo: Dictionary = Trade.empty_cargo()
var trade_note := ""
var station_id := 0
var store = preload("res://scripts/checkpoint_store.gd").new()
var snapshots = preload("res://scripts/flight_snapshot.gd").new()
var pending_snapshot: Dictionary = {}
var selected_mission := "combat"
var autosave_time := 0.0
var save_error := ""
var profile_note := ""
var planet: Node
var mission: Node
var training_runs := 0
var visuals: Node3D
var fx: Node3D
var flight_ui: Control
var ship: Node3D
var external_camera: Camera3D
var cockpit_camera: Camera3D
var cockpit := false
var stabilized := true
var velocity := Vector3.ZERO
var throttle := 0.0
var turn_input := Vector2.ZERO
var steer_touch := -1
var steer_start := Vector2.ZERO
var fire_touch := -1
var firing := false
var fire_timer := 0.0
var enemy_timer := 1.0
var shield := 100.0
var hull := 100.0
var credits := 0
var upgrades := {"engine": 0, "shield": 0, "weapon": 0}
var enemies: Array[Node3D] = []
var hud: Label
var help_label: Label
var joystick: Control
var upgrades_panel: PanelContainer
var upgrade_info: Label
var stable_button: Button
var destroyed := false

func _ready() -> void:
	_load_progress()
	_build_world()
	mission = preload("res://scripts/training_mission.gd").new()
	add_child(mission)
	mission.setup(self)
	planet = preload("res://scripts/planet_flight.gd").new()
	add_child(planet)
	planet.setup(self)
	_build_hud()
	_update_hud()

func _material(color: Color, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, emission := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color, emission)
	parent.add_child(item)
	return item

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, color, emission)

func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(parent, mesh, pos, color)

func _build_world() -> void:
	ship = Node3D.new()
	add_child(ship)
	external_camera = Camera3D.new()
	ship.add_child(external_camera)
	external_camera.position = Vector3(0,3.2,11)
	external_camera.rotation_degrees.x = -10
	external_camera.far = 1500
	external_camera.current = true
	cockpit_camera = Camera3D.new()
	ship.add_child(cockpit_camera)
	cockpit_camera.position = Vector3(0,.65,-1.3)
	cockpit_camera.far = 1500
	visuals = preload("res://scripts/visuals.gd").new()
	add_child(visuals)
	visuals.setup(self)
	fx = preload("res://scripts/combat_fx.gd").new()
	add_child(fx)
	_create_target(Vector3(-10,2,-65),false)
	_create_target(Vector3(9,-4,-90),false)
	_create_target(Vector3(0,5,-120),true)

func _create_target(pos: Vector3, hostile: bool) -> void:
	var target := Node3D.new()
	target.position = pos
	target.set_meta("id",enemies.size())
	target.set_meta("hostile", hostile)
	target.set_meta("health", 90.0 if hostile else 40.0)
	add_child(target)
	visuals.target_model(target,hostile)
	if hostile:
		var pilot := preload("res://scripts/enemy_ai.gd").new()
		pilot.name = "PilotAI"
		target.add_child(pilot)
		pilot.setup(self,target)
	enemies.append(target)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	flight_ui = preload("res://scripts/flight_ui.gd").new()
	layer.add_child(flight_ui)
	flight_ui.setup(self)
	joystick = flight_ui
	help_label = flight_ui.help_label
	upgrades_panel = flight_ui.upgrades_panel
	upgrade_info = flight_ui.upgrade_info
	stable_button = flight_ui.stable_button

func _input(event: InputEvent) -> void:
	if mission.flight_locked() or flight_ui.map_panel.visible or flight_ui.market_panel.visible:return
	if event is InputEventScreenTouch:
		if not event.pressed and event.index == fire_touch:
			fire_touch = -1
			firing = false
			get_viewport().set_input_as_handled()
			return
		if event.pressed and fire_touch == -1 and mission.kind!="planet" and not upgrades_panel.visible and flight_ui.fire_button.get_rect().has_point(flight_ui.to_design(event.position)):
			fire_touch = event.index
			firing = true
			get_viewport().set_input_as_handled()
			return
		if event.pressed and steer_touch == -1 and flight_ui.steering_rect().has_point(flight_ui.to_design(event.position)) and not upgrades_panel.visible:
			steer_touch = event.index
			steer_start = flight_ui.to_design(event.position)
		elif not event.pressed and event.index == steer_touch:
			steer_touch = -1
			turn_input = Vector2.ZERO
			joystick.queue_redraw()
	elif event is InputEventScreenDrag and event.index == steer_touch:
		turn_input = ((flight_ui.to_design(event.position) - steer_start) / 65.0).limit_length(1.0)
		joystick.queue_redraw()

func _physics_process(delta: float) -> void:
	if upgrades_panel.visible or flight_ui.map_panel.visible or flight_ui.market_panel.visible:return
	mission.step(delta)
	if planet.step(delta):
		autosave_time += delta
		if autosave_time>=3:
			autosave_time=0
			_save_progress()
		_update_hud()
		return
	if destroyed or mission.flight_locked():
		if destroyed and not pending_snapshot.is_empty():pending_snapshot.clear()
		_update_hud()
		return
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var steering := turn_input if steer_touch != -1 else keyboard
	ship.rotate_object_local(Vector3.UP, -steering.x * delta * 1.25)
	ship.rotate_object_local(Vector3.RIGHT, -steering.y * delta * 1.0)
	var forward := -ship.global_transform.basis.z
	var target_velocity: Vector3 = forward * throttle * (36.0 + upgrades.engine * 5.0)
	if stabilized:
		velocity = velocity.move_toward(target_velocity, delta * 14.0)
	else:
		velocity += forward * throttle * delta * (6.0 + upgrades.engine)
		velocity = velocity.limit_length(65.0 + upgrades.engine * 5.0)
	ship.position += velocity * delta
	planet.constrain_motion(delta)
	visuals.update_flight(throttle)
	fire_timer -= delta
	if firing and fire_timer <= 0:
		_shoot()
		fire_timer = 0.35
	for target in enemies:
		var pilot = target.get_node_or_null("PilotAI")
		if pilot != null: pilot.step(delta)
	_enemy_attack()
	mission.step()
	autosave_time += delta
	if autosave_time >= 3.0 or destroyed:
		autosave_time = 0
		_save_progress()
	_update_hud()

func _shoot() -> void:
	if mission.flight_locked() or mission.kind=="planet":return
	var chosen: Node3D = null
	var best := 0.96
	for target in enemies:
		if not is_instance_valid(target) or not target.visible:
			continue
		var direction := target.global_position - ship.global_position
		if direction.length() > 160.0 or direction.length() < 0.1:
			continue
		var aim := (-ship.global_transform.basis.z).dot(direction.normalized())
		if aim > best:
			best = aim
			chosen = target
	var impact: Vector3 = chosen.global_position if chosen != null else ship.global_position - ship.global_basis.z * 160.0
	for side in [-1.0,1.0]:
		var muzzle: Vector3 = ship.to_global(Vector3(side*2.8,0,-1.5))
		fx.beam(muzzle, impact)
	if chosen != null:
		fx.burst(chosen.global_position)
		var hp: float = chosen.get_meta("health") - (20.0 + upgrades.weapon * 8.0)
		chosen.set_meta("health", hp)
		if hp > 0:
			var pilot = chosen.get_node_or_null("PilotAI")
			if pilot != null: pilot.on_hit()
		if hp <= 0:
			fx.burst(chosen.global_position,true)
			credits += 100 if chosen.get_meta("hostile") else 50
			enemies.erase(chosen)
			chosen.queue_free()
			_save_progress()
	help_label.text = "Попадание!" if chosen != null else "Выстрел: наведите прицел на цель"

func _enemy_attack() -> void:
	for target in enemies:
		var pilot = target.get_node_or_null("PilotAI")
		if pilot != null and pilot.can_fire():
			pilot.consume_shot()
			fx.beam(target.global_position,ship.global_position,true)
			var damage := 6.0
			var absorbed := minf(shield, damage)
			shield -= absorbed
			hull -= damage - absorbed
			if hull <= 0:
				destroyed = true
				help_label.text = "Корабль потерян. Откройте «МЕНЮ» для новой попытки."
			break

func _toggle_camera() -> void:
	cockpit = not cockpit
	cockpit_camera.current = cockpit
	external_camera.current = not cockpit
	visuals.set_camera(cockpit)

func _toggle_stabilization() -> void:
	stabilized = not stabilized
	stable_button.text = "СТАБ: ВКЛ" if stabilized else "СТАБ: ВЫКЛ"

func _toggle_upgrades() -> void:
	upgrades_panel.visible = not upgrades_panel.visible
	clear_held_input()
	_update_hud()

func _buy(kind: String) -> void:
	if at_station() and pending_snapshot.is_empty() and kind in upgrades and credits >= 100 and upgrades[kind] < 3:
		credits -= 100
		upgrades[kind] += 1
		if kind == "shield":
			shield = 100.0 + upgrades.shield * 25.0
		_save_progress()
	_update_hud()

func _update_hud() -> void:
	flight_ui.queue_redraw()
	upgrade_info.text = "УЛУЧШЕНИЯ  •  Кредиты: %d\nДвигатель: %d/3   Щит: %d/3\nОружие: %d/3\n" % [credits, upgrades.engine, upgrades.shield, upgrades.weapon]
	if not at_station() or not pending_snapshot.is_empty():upgrade_info.text += "Установка — только на станции"

func _save_progress() -> bool:
	if destroyed:cargo = Trade.empty_cargo()
	var flight: Dictionary = snapshots.capture(self) if mission!=null and ship!=null else {}
	if flight.is_empty() and not pending_snapshot.is_empty() and not destroyed:flight = pending_snapshot.duplicate(true)
	var data := {"schema":3,"cargo":cargo,"credits":credits,"upgrades":upgrades,"training_runs":training_runs,"station_id":station_id,"selected_mission":selected_mission,"station_hull":100.0 if destroyed else hull,"flight":flight}
	var ok: bool = store.write_document(data)
	save_error = "" if ok else "Не удалось сохранить игру"
	return ok

func _load_progress() -> void:
	var data: Dictionary = store.read_document()
	if data.is_empty():return
	credits = maxi(0,int(data.get("credits",0)))
	cargo = Trade.read_cargo(data.get("cargo",{}))
	training_runs = maxi(0,int(data.get("training_runs",0)))
	station_id = clampi(int(data.get("station_id",0)),0,1)
	for key in upgrades:upgrades[key] = clampi(int(data.upgrades.get(key,0)),0,3)
	shield = 100.0+upgrades.shield*25.0
	hull = clampf(float(data.get("station_hull",100.0)),1,100)
	selected_mission = str(data.get("selected_mission","combat"))
	if selected_mission not in ["combat","scout","delivery","trade","planet"]:selected_mission = "combat"
	var flight = data.get("flight",{})
	pending_snapshot = flight.duplicate(true) if typeof(flight)==TYPE_DICTIONARY else {}
	profile_note = "Загружена резервная копия сохранения." if store.recovered else ""

func at_station() -> bool:
	return mission!=null and mission.stage in ["ИНСТРУКТАЖ","ЗАВЕРШЕНО"]

func repair_cost() -> int:return int(ceil(maxf(0,100-hull)*2))

func repair_at_station() -> void:
	if not at_station() or not pending_snapshot.is_empty():return
	var cost := repair_cost()
	if cost<=0 or credits<cost:return
	credits -= cost
	hull = 100
	_save_progress()
	_update_hud()

func choose_mission(kind: String) -> void:
	if not at_station() or not pending_snapshot.is_empty() or kind not in ["combat","scout","delivery","trade","planet"]:return
	selected_mission = kind
	_save_progress()

func start_selected_mission() -> void:
	if not at_station() or not pending_snapshot.is_empty():return
	if selected_mission=="delivery" and cargo_used()+Trade.CONTRACT_SIZE>Trade.CAPACITY:
		trade_note = "Для контейнера нужны 2 свободные единицы отсека."
		return
	if mission.stage == "ЗАВЕРШЕНО":
		for target in enemies:target.queue_free()
		enemies.clear()
		_create_target(Vector3(-10,2,-65),false)
		_create_target(Vector3(9,-4,-90),false)
		_create_target(Vector3(0,5,-120),true)
		mission.stage = "ИНСТРУКТАЖ"
		mission.scan_elapsed = 0
		mission.beacon.queue_free()
		mission.setup(self)
	mission.kind = selected_mission
	mission.launch()

func resume_flight() -> bool:
	if pending_snapshot.is_empty():return false
	if not snapshots.restore(self,pending_snapshot):
		profile_note = "Снимок вылета повреждён. Можно отменить его."
		return false
	pending_snapshot.clear()
	profile_note = ""
	autosave_time = 0
	_save_progress()
	return true

func discard_flight() -> void:
	if not at_station():return
	pending_snapshot.clear()
	profile_note = "Вылет отменён. Можно выбрать новое задание."
	_save_progress()

func save_to_menu() -> void:
	clear_held_input()
	if not _save_progress():return
	get_tree().reload_current_scene()

func clear_held_input() -> void:
	steer_touch = -1
	fire_touch = -1
	turn_input = Vector2.ZERO
	firing = false
	if planet!=null:planet.vertical=0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]:
		clear_held_input()
		if is_node_ready() and mission!=null:_save_progress()

func _toggle_map() -> void:
	clear_held_input()
	flight_ui.map_panel.visible = not flight_ui.map_panel.visible

func cargo_used() -> int:
	var contract: bool = mission!=null and mission.cargo_loaded
	if not pending_snapshot.is_empty():contract = bool(pending_snapshot.get("cargo",false))
	return Trade.used(cargo)+(Trade.CONTRACT_SIZE if contract and not destroyed else 0)

func can_trade() -> bool:
	return at_station() and pending_snapshot.is_empty() and not destroyed

func can_trade_goods(good: String, quantity: int, buying: bool) -> bool:
	if not can_trade() or good not in Trade.GOODS or quantity<=0 or quantity>Trade.CAPACITY:return false
	if buying:return cargo_used()+quantity<=Trade.CAPACITY and credits>=Trade.price(good,station_id,true)*quantity
	return int(cargo.get(good,0))>=quantity

func trade_goods(good: String, quantity: int, buying: bool) -> bool:
	if not can_trade_goods(good,quantity,buying):
		trade_note = "Сделка недоступна: проверьте станцию, баланс и место в отсеке."
		return false
	var previous_credits := credits
	var previous_cargo: Dictionary = cargo.duplicate()
	var total := Trade.price(good,station_id,buying)*quantity
	credits += -total if buying else total
	cargo[good] += quantity if buying else -quantity
	if not _save_progress():
		credits = previous_credits
		cargo = previous_cargo
		trade_note = "Не удалось сохранить сделку. Кредиты и груз возвращены."
		return false
	trade_note = "%s: %d ед. · %d кр." % ["Куплено" if buying else "Продано",quantity,total]
	_update_hud()
	return true

func _toggle_market() -> void:
	clear_held_input()
	flight_ui.market_panel.visible = not flight_ui.market_panel.visible
	if flight_ui.market_panel.visible:
		flight_ui.map_panel.visible = false
		upgrades_panel.visible = false
		trade_note = ""

func start_trade_flight() -> void:
	if not can_trade():return
	choose_mission("trade")
	start_selected_mission()
	flight_ui.market_panel.visible = false

func adjust_throttle(amount: float) -> void:
	var next := clampf(snappedf(throttle+amount,.1),-.3,1.0)
	throttle = 0.0 if next*throttle<0 else next

func start_planet_flight() -> void:
	if not can_trade():return
	choose_mission("planet")
	start_selected_mission()
