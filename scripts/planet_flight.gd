extends Node
const ENTRY := Vector3(100,20,-270)
const REGION_PATH := "res://planet_region.tscn"
const World = preload("res://scripts/world_generator.gd")
const OUTBOUND := "К ПРЫЖКУ"
const INBOUND := "К ОБРАТНОМУ ПРЫЖКУ"
const Mining = preload("res://scripts/mining_state.gd")
const Region = preload("res://scripts/planet_region.gd")
const STAGES := [OUTBOUND,INBOUND,"К ПЛАНЕТЕ","СПУСК","ПОВЕРХНОСТЬ","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ","ВЫХОД НА ОРБИТУ"]
const TRANSITIONS := ["СПУСК","ПОСАДКА","ВЗЛЁТ","ВЫХОД НА ОРБИТУ"]
const HORIZON_RESPONSE := 2.4
var game: Node3D
var neighbor_route := false
var generated: Dictionary = World.neighbor()
var loading_requested := false
var region: Node3D
var surface := false
var elapsed := 0.0
var vertical := 0.0
var start := Vector3.ZERO
var target := Vector3.ZERO
var gear: Node3D
var survey_elapsed := -1.0

func setup(owner_game: Node3D) -> void:
	game=owner_game
	game.visuals.build_neighbor(generated)
	gear=Node3D.new();game.ship.add_child(gear)
	for point in [Vector3(-1.5,0,1.2),Vector3(1.5,0,1.2),Vector3(0,0,-2.2)]:
		game.visuals.rod(gear,point+Vector3(0,-.2,0),point+Vector3(0,-1.6,0),.07,game.visuals.steel)
		game.visuals.box(gear,Vector3(.8,.16,1.0),point+Vector3(0,-1.65,0),game.visuals.dark)
	gear.visible=false

func active() -> bool:return game.mission.kind=="planet"
func on_surface() -> bool:return surface
func busy() -> bool:return game.mission.stage in TRANSITIONS
func in_neighbor() -> bool:
	return active() and neighbor_route and game.mission.stage not in [OUTBOUND, "ВОЗВРАЩЕНИЕ", "ЗАВЕРШЕНО", "ИНСТРУКТАЖ", "ПРОВАЛ"]

func configure_route(to_neighbor: bool) -> void:
	if neighbor_route != to_neighbor and region != null:
		region.free()
		region = null
	neighbor_route = to_neighbor

func mine():
	return game.neighbor_mining if neighbor_route else game.mining

func region_title() -> String:
	return "%s / РАЙОН 01" % generated.planet_name if neighbor_route else "АСТРА / РАЙОН МЕРИДИАН"

func site_title() -> String:
	return "%s-1" % generated.planet_name if neighbor_route else "Меридиан-1"

func signal_point() -> Vector2:
	return generated.signal if neighbor_route else Mining.SIGNAL_POINT

func landing_point() -> Vector2:
	return generated.landing if neighbor_route else Mining.LANDING_POINT

func site_point() -> Vector2:
	return generated.site if neighbor_route else Mining.SITE

func entry_point() -> Vector3:
	return generated.entry if neighbor_route else ENTRY

func nav_point() -> Vector3:
	match game.mission.stage:
		OUTBOUND: return World.HOME_GATE
		INBOUND: return World.ARRIVAL_GATE
	return Vector3.ZERO if surface else entry_point()

func altitude() -> float:
	var point: Vector3 = game.ship.position
	return point.y - (region.terrain_height(point.x, point.z) if region != null else Region.height_at(point.x, point.z))

func can_jump() -> bool:
	if not active() or game.destroyed or game.velocity.length() > 25.0:
		return false
	if game.mission.stage == OUTBOUND:
		return game.ship.position.distance_to(World.HOME_GATE) <= 35.0
	if neighbor_route and game.mission.stage in [INBOUND, "К ПЛАНЕТЕ"]:
		return game.ship.position.distance_to(World.ARRIVAL_GATE) <= 35.0
	return false

func sync_space() -> void:
	game.visuals.space_root.visible = not surface and not in_neighbor()
	game.visuals.neighbor_root.visible = not surface and in_neighbor()
	if in_neighbor():
		for enemy in game.enemies:
			enemy.visible = false
	if active():
		game.mission.beacon.visible = game.mission.stage in [OUTBOUND, INBOUND]
		if game.mission.beacon.visible:
			game.mission.beacon.position = nav_point()

func jump() -> void:
	if not can_jump():
		return
	var outbound: bool = game.mission.stage == OUTBOUND
	game.orbital_target = -1
	game.mission.stage = "К ПЛАНЕТЕ" if outbound else "ВОЗВРАЩЕНИЕ"
	game.ship.position = World.ARRIVAL_GATE if outbound else World.HOME_GATE
	game.ship.look_at(game.mission.nav_position())
	game.velocity = Vector3.ZERO
	game.throttle = 0.0
	game.clear_held_input()
	sync_space()
	game._save_progress()

func can_enter() -> bool:return not game.has_orbital_target() and active() and game.mission.stage=="К ПЛАНЕТЕ" and not game.destroyed and game.ship.position.distance_to(entry_point())<=35 and game.velocity.length()<=25
func can_land() -> bool:
	return active() and game.mission.stage=="ПОВЕРХНОСТЬ" and not game.destroyed and altitude()<=25 and game.velocity.length()<=8 and region!=null and region.landing_clear(game.ship.position.x,game.ship.position.z)
func can_exit() -> bool:return active() and game.mission.stage=="ПОВЕРХНОСТЬ" and not game.destroyed and altitude()>=100

func mining_distance(point: Vector2) -> float:
	var position: Vector3 = game.ship.position
	return Vector2(position.x, position.z).distance_to(point)

func mining_target() -> Vector3:
	return region.ground_point(landing_point() if mine().surveyed else signal_point())

func can_survey() -> bool:
	return active() and surface and not game.destroyed and game.mission.stage == "ПОВЕРХНОСТЬ" \
		and not mine().surveyed and mining_distance(signal_point()) <= Mining.SURVEY_RADIUS \
		and altitude() <= 100.0 and game.velocity.length() <= 20.0

func start_survey() -> bool:
	if survey_elapsed >= 0 or not can_survey():
		return false
	survey_elapsed = 0.0
	return true

func step_survey(delta: float) -> void:
	if survey_elapsed < 0:
		return
	if not can_survey():
		survey_elapsed = -1.0
		return
	survey_elapsed += delta
	if survey_elapsed >= Mining.SURVEY_SECONDS:
		survey_elapsed = -1.0
		mine().surveyed = true
		if not game._save_progress():
			mine().surveyed = false
		else:
			region.show_mining_site(true, false)

func can_service_mine() -> bool:
	return active() and surface and not game.destroyed and game.mission.stage == "НА ПОВЕРХНОСТИ" \
		and mine().surveyed and mining_distance(site_point()) <= Mining.SERVICE_RADIUS

func deploy_mine() -> bool:
	if not can_service_mine() or mine().installed:
		return false
	var previous: Dictionary = mine().capture()
	mine().deploy(randi_range(1, 2147483647))
	if not game._save_progress():
		mine().restore(previous)
		return false
	game.mining_active_at = Time.get_ticks_msec()
	region.show_mining_site(true, true)
	return true

func load_ore() -> int:
	if not can_service_mine() or not mine().installed:
		return 0
	var quantity := mini(mine().stock, game.Trade.CAPACITY - game.cargo_used())
	if quantity <= 0:
		return 0
	mine().stock -= quantity
	game.cargo.ore += quantity
	if not game._save_progress():
		mine().stock += quantity
		game.cargo.ore -= quantity
		return 0
	return quantity

func _request_region() -> void:
	if region==null and not loading_requested:
		ResourceLoader.load_threaded_request(REGION_PATH)
		loading_requested=true

func _exit_tree() -> void:
	if loading_requested:
		ResourceLoader.load_threaded_get(REGION_PATH)
		loading_requested=false

func _load_region() -> bool:
	if region!=null:return true
	if ResourceLoader.load_threaded_get_status(REGION_PATH)!=ResourceLoader.THREAD_LOAD_LOADED:return false
	var packed: PackedScene = ResourceLoader.load_threaded_get(REGION_PATH)
	loading_requested=false
	if packed==null:return false
	_instantiate_region(packed)
	return true

func _instantiate_region(packed: PackedScene) -> void:
	region = packed.instantiate()
	if neighbor_route:
		region.layout = generated
	region.visible = false
	game.add_child(region)

func _set_surface(value: bool) -> void:
	surface=value
	game.visuals.sun_light.shadow_enabled=value
	game.visuals.sun_light.light_energy=1.2 if value else 2.0
	if region != null:
		region.visible = value
		if value:
			region.show_mining_site(mine().surveyed, mine().installed)
	sync_space()
	game.visuals.world_environment.environment=region.environment if value else game.visuals.space_environment
	game.external_camera.far=2200 if value else 5000
	game.cockpit_camera.far=2200 if value else 5000
	if value:
		game.visuals.sun_light.rotation_degrees = Vector3(-35,-30,0)
	gear.visible=value and not game.cockpit
	for enemy in game.enemies:enemy.visible=false

func _begin(stage: String, finish: Vector3) -> void:
	survey_elapsed = -1.0
	elapsed=0;start=game.ship.position;target=finish
	game.mission.stage=stage;game.throttle=0;game.velocity=Vector3.ZERO
	game.clear_held_input();game._save_progress()

func action() -> void:
	if can_jump():
		jump()
	elif can_enter():
		_request_region()
		_begin("СПУСК",Vector3(0,85,220))
	elif can_land():
		var p: Vector3=game.ship.position
		_begin("ПОСАДКА",Vector3(p.x,region.terrain_height(p.x,p.z)+1.8,p.z))
	elif active() and game.mission.stage=="НА ПОВЕРХНОСТИ" and not game.destroyed:
		_begin("ВЗЛЁТ",game.ship.position+Vector3(0,22,0))

func exit_orbit() -> void:
	if can_exit():_begin("ВЫХОД НА ОРБИТУ",entry_point()+Vector3(-15,8,25))

func step(delta: float) -> bool:
	if not active() or game.destroyed:return false
	gear.visible=surface and not game.cockpit
	if game.mission.stage=="НА ПОВЕРХНОСТИ":
		game.throttle=0;game.velocity=Vector3.ZERO;game.clear_held_input();return true
	if not busy():return false
	elapsed+=delta
	game.clear_held_input()
	var stage: String=game.mission.stage
	if stage=="СПУСК":
		if elapsed>=2 and not surface:
			if not _load_region():elapsed=2;return true
			_set_surface(true)
			game.ship.position=target+Vector3(0,100,100)
			game.ship.look_at(Vector3(0,25,0))
		if surface:game.ship.position=(target+Vector3(0,100,100)).lerp(target,smoothstep(2.0,4.0,elapsed))
		else:game.ship.position=start+Vector3(10,-20,-40)*minf(elapsed/2,1)
		if elapsed>=4:
			game.mission.stage="ПОВЕРХНОСТЬ";game.ship.rotation.x=0;elapsed=0;game._save_progress()
	elif stage=="ВЫХОД НА ОРБИТУ":
		if elapsed>=2 and surface:
			_set_surface(false);game.ship.position=target;game.ship.look_at(World.ARRIVAL_GATE if neighbor_route else game.Sector.dock_point(game.mission.origin))
		if surface:game.ship.position=start+Vector3(0,150,-40)*minf(elapsed/2,1)
		else:game.ship.position=target
		if elapsed>=4:
			game.mission.stage=INBOUND if neighbor_route else "ВОЗВРАЩЕНИЕ"
			sync_space()
			elapsed=0;game._save_progress()
	else:
		game.ship.position=start.lerp(target,smoothstep(0.0,2.0,elapsed))
		if elapsed>=2:
			game.mission.stage="НА ПОВЕРХНОСТИ" if stage=="ПОСАДКА" else "ПОВЕРХНОСТЬ"
			game.ship.rotation.x=0;game.ship.rotation.z=0;elapsed=0;game._save_progress()
	return true

func constrain_motion(delta: float) -> void:
	if not surface or game.mission.stage!="ПОВЕРХНОСТЬ":return
	_level_horizon(delta)
	var previous_y: float=game.velocity.y
	game.velocity.y=move_toward(game.velocity.y,vertical*16.0,24.0*delta)
	game.ship.position.y+=(game.velocity.y-previous_y)*delta
	var p: Vector3=game.ship.position
	var floor_height: float=region.terrain_height(p.x,p.z)+1.8
	if p.y<floor_height:
		var normal: Vector3=region.terrain_normal(p.x,p.z)
		var impact: float=maxf(0,-game.velocity.dot(normal))
		p.y=floor_height
		if game.velocity.dot(normal)<0:game.velocity=game.velocity.slide(normal)
		if impact>8:
			game.hull=maxf(0,game.hull-(impact-8)*2)
			game.destroyed=game.hull<=0
	p.x=clampf(p.x,-900,900);p.z=clampf(p.z,-900,900)
	if absf(p.x)>=900 or absf(p.z)>=900:game.velocity=Vector3.ZERO;game.throttle=0
	p.y=minf(p.y,region.terrain_height(p.x,p.z)+400)
	game.ship.position=p

func _level_horizon(delta: float) -> void:
	if not game.stabilized or delta <= 0.0:return
	var attitude: Basis = game.ship.global_basis.orthonormalized()
	var forward := -attitude.z
	var horizontal := Vector3(forward.x, 0, forward.z)
	# At a vertical nose direction the heading is undefined; the ship's right
	# axis still supplies a stable horizontal direction without a zero cross product.
	if horizontal.length_squared() < .0001:
		var horizontal_right := Vector3(attitude.x.x, 0, attitude.x.z).normalized()
		horizontal = Vector3.UP.cross(horizontal_right)
	else:
		horizontal = horizontal.normalized()
	var right := horizontal.cross(Vector3.UP).normalized()
	var upright := right.cross(forward).normalized()
	var roll := upright.signed_angle_to(attitude.y, forward)
	var remaining := exp(-HORIZON_RESPONSE * delta)
	var steering: Vector2 = game.turn_input if game.steer_touch != -1 else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if steering == Vector2.ZERO:
		var pitch := asin(clampf(forward.y, -1.0, 1.0)) * remaining
		forward = horizontal * cos(pitch) + Vector3.UP * sin(pitch)
	# Pitch and roll decay separately so leveling cannot alter the horizontal
	# heading, and active steering keeps the pilot's current nose direction.
	right = forward.cross(upright).normalized()
	upright = right.cross(forward).normalized()
	game.ship.global_basis = Basis(right, upright, -forward).rotated(forward, roll * remaining).orthonormalized()

func capture() -> Dictionary:
	return {"neighbor":neighbor_route,"generation":World.VERSION if neighbor_route else 0,"surface":surface,"elapsed":elapsed,"start":game.snapshots.vec(start),"target":game.snapshots.vec(target)}

static func valid(data, stage: String) -> bool:
	if typeof(data)!=TYPE_DICTIONARY or typeof(data.get("surface"))!=TYPE_BOOL:return false
	var neighbor = data.get("neighbor", false)
	if typeof(neighbor) != TYPE_BOOL or (neighbor and data.get("generation") != World.VERSION):return false
	if stage in [OUTBOUND, INBOUND] and (not neighbor or data.surface):return false
	var time=data.get("elapsed")
	if typeof(time) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(time)) or time<0 or time>4.5:return false
	for key in ["start","target"]:
		var point=data.get(key)
		if typeof(point)!=TYPE_ARRAY or point.size()!=3:return false
		for n in point:
			if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(n)>10000:return false
	if stage in ["ПОВЕРХНОСТЬ","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ"] and not data.surface:return false
	if stage in ["К ПЛАНЕТЕ","ВОЗВРАЩЕНИЕ"] and data.surface:return false
	return true

func restore(data: Dictionary) -> void:
	survey_elapsed = -1.0
	configure_route(data.get("neighbor", false))
	elapsed=float(data.elapsed);start=game.snapshots.vector(data.start);target=game.snapshots.vector(data.target)
	if data.surface:
		if region==null:
			var packed: PackedScene=load(REGION_PATH)
			_instantiate_region(packed)
	_set_surface(data.surface)
	if game.mission.stage=="СПУСК" and not surface:_request_region()
	vertical=0
