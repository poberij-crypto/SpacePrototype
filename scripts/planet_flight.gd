extends Node
const ENTRY := Vector3(100,20,-270)
const REGION_PATH := "res://planet_region.tscn"
const Region = preload("res://scripts/planet_region.gd")
const STAGES := ["К ПЛАНЕТЕ","СПУСК","ПОВЕРХНОСТЬ","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ","ВЫХОД НА ОРБИТУ"]
const TRANSITIONS := ["СПУСК","ПОСАДКА","ВЗЛЁТ","ВЫХОД НА ОРБИТУ"]
var game: Node3D
var loading_requested := false
var region: Node3D
var surface := false
var elapsed := 0.0
var vertical := 0.0
var start := Vector3.ZERO
var target := Vector3.ZERO
var gear: Node3D

func setup(owner_game: Node3D) -> void:
	game=owner_game
	gear=Node3D.new();game.ship.add_child(gear)
	for point in [Vector3(-1.5,0,1.2),Vector3(1.5,0,1.2),Vector3(0,0,-2.2)]:
		game.visuals.rod(gear,point+Vector3(0,-.2,0),point+Vector3(0,-1.6,0),.07,game.visuals.steel)
		game.visuals.box(gear,Vector3(.8,.16,1.0),point+Vector3(0,-1.65,0),game.visuals.dark)
	gear.visible=false

func active() -> bool:return game.mission.kind=="planet"
func on_surface() -> bool:return surface
func busy() -> bool:return game.mission.stage in TRANSITIONS
func altitude() -> float:return game.ship.position.y-Region.height_at(game.ship.position.x,game.ship.position.z)
func can_enter() -> bool:return active() and game.mission.stage=="К ПЛАНЕТЕ" and not game.destroyed and game.ship.position.distance_to(ENTRY)<=35 and game.velocity.length()<=25
func can_land() -> bool:
	return active() and game.mission.stage=="ПОВЕРХНОСТЬ" and not game.destroyed and altitude()<=25 and game.velocity.length()<=8 and Region.landing_safe(game.ship.position.x,game.ship.position.z)
func can_exit() -> bool:return active() and game.mission.stage=="ПОВЕРХНОСТЬ" and not game.destroyed and altitude()>=100

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
	region=packed.instantiate();game.add_child(region);region.visible=false
	return true

func _set_surface(value: bool) -> void:
	surface=value
	game.visuals.sun_light.shadow_enabled=value
	game.visuals.sun_light.light_energy=1.2 if value else 2.0
	if region!=null:region.visible=value
	game.visuals.space_root.visible=not value
	game.visuals.world_environment.environment=region.environment if value else game.visuals.space_environment
	game.external_camera.far=2200 if value else 1500
	gear.visible=value and not game.cockpit
	for enemy in game.enemies:enemy.visible=false

func _begin(stage: String, finish: Vector3) -> void:
	elapsed=0;start=game.ship.position;target=finish
	game.mission.stage=stage;game.throttle=0;game.velocity=Vector3.ZERO
	game.clear_held_input();game._save_progress()

func action() -> void:
	if can_enter():
		_request_region()
		_begin("СПУСК",Vector3(0,85,220))
	elif can_land():
		var p: Vector3=game.ship.position
		_begin("ПОСАДКА",Vector3(p.x,Region.height_at(p.x,p.z)+1.8,p.z))
	elif active() and game.mission.stage=="НА ПОВЕРХНОСТИ" and not game.destroyed:
		_begin("ВЗЛЁТ",game.ship.position+Vector3(0,22,0))

func exit_orbit() -> void:
	if can_exit():_begin("ВЫХОД НА ОРБИТУ",ENTRY+Vector3(-15,8,25))

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
			_set_surface(false);game.ship.position=target;game.ship.look_at(game.Sector.dock_point(game.mission.origin))
		if surface:game.ship.position=start+Vector3(0,150,-40)*minf(elapsed/2,1)
		else:game.ship.position=target
		if elapsed>=4:
			game.mission.stage="ВОЗВРАЩЕНИЕ";elapsed=0;game._save_progress()
	else:
		game.ship.position=start.lerp(target,smoothstep(0.0,2.0,elapsed))
		if elapsed>=2:
			game.mission.stage="НА ПОВЕРХНОСТИ" if stage=="ПОСАДКА" else "ПОВЕРХНОСТЬ"
			game.ship.rotation.x=0;game.ship.rotation.z=0;elapsed=0;game._save_progress()
	return true

func constrain_motion(delta: float) -> void:
	if not surface or game.mission.stage!="ПОВЕРХНОСТЬ":return
	var previous_y: float=game.velocity.y
	game.velocity.y=move_toward(game.velocity.y,vertical*16.0,24.0*delta)
	game.ship.position.y+=(game.velocity.y-previous_y)*delta
	var p: Vector3=game.ship.position
	var floor_height:=Region.height_at(p.x,p.z)+1.8
	if p.y<floor_height:
		var impact: float=absf(game.velocity.y)
		p.y=floor_height;game.velocity.y=0
		if impact>8:
			game.hull=maxf(0,game.hull-(impact-8)*2)
			game.destroyed=game.hull<=0
	p.x=clampf(p.x,-900,900);p.z=clampf(p.z,-900,900)
	if absf(p.x)>=900 or absf(p.z)>=900:game.velocity=Vector3.ZERO;game.throttle=0
	p.y=minf(p.y,Region.height_at(p.x,p.z)+400)
	game.ship.position=p

func capture() -> Dictionary:
	return {"surface":surface,"elapsed":elapsed,"start":game.snapshots.vec(start),"target":game.snapshots.vec(target)}

static func valid(data, stage: String) -> bool:
	if typeof(data)!=TYPE_DICTIONARY or typeof(data.get("surface"))!=TYPE_BOOL:return false
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
	elapsed=float(data.elapsed);start=game.snapshots.vector(data.start);target=game.snapshots.vector(data.target)
	if data.surface:
		if region==null:
			var packed: PackedScene=load(REGION_PATH);region=packed.instantiate();game.add_child(region)
	_set_surface(data.surface)
	if game.mission.stage=="СПУСК" and not surface:_request_region()
	vertical=0
