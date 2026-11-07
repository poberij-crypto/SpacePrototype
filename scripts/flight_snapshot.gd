extends RefCounted
const STAGES := ["ВЫЛЕТ","БОЙ","ВОЗВРАЩЕНИЕ","СКАНИРОВАНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"]
const Armament = preload("res://scripts/armament_state.gd")
const Combat = preload("res://scripts/weapon_combat.gd")
const Planet = preload("res://scripts/planet_flight.gd")
const TACTICS := ["СБЛИЖЕНИЕ","АТАКА","УКЛОНЕНИЕ","РАЗВОРОТ"]

func vec(v: Vector3) -> Array:return [v.x,v.y,v.z]
func quat(node: Node3D) -> Array:
	var q := node.basis.get_rotation_quaternion()
	return [q.x,q.y,q.z,q.w]
func vector(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func rotation(value: Array) -> Basis:return Basis(Quaternion(value[0],value[1],value[2],value[3]).normalized())

func capture(game: Node3D) -> Dictionary:
	if game.mission.stage not in STAGES+Planet.STAGES or game.destroyed:return {}
	var targets: Array = []
	for target in game.enemies:
		var data := {"id":target.get_meta("id"),"pos":vec(target.position),"rot":quat(target),"hp":target.get_meta("health"),"shield":target.get_meta("shield",0.0),"visible":target.visible}
		var pilot = target.get_node_or_null("PilotAI")
		if pilot != null:
			data["ai"] = {"state":pilot.state,"time":pilot.state_time,"cooldown":pilot.cooldown,"waypoint":vec(pilot.waypoint),"passes":pilot.passes,"enabled":pilot.enabled}
		targets.append(data)
	return {"contract_id":game.mission.contract_id,"armament":game.armament.runtime_capture(),"projectiles":game.combat.capture(),"orbital_target":game.orbital_target if game.has_orbital_target() else -1,"planet":game.planet.capture() if game.planet!=null and game.mission.kind=="planet" else {},"version":4,"origin":game.mission.origin,"destination":game.mission.destination,"cargo":game.mission.cargo_loaded,"stage":game.mission.stage,"kind":game.mission.kind,"scan":game.mission.scan_elapsed,"pos":vec(game.ship.position),"rot":quat(game.ship),"velocity":vec(game.velocity),"throttle":game.throttle,"stabilized":game.stabilized,"hull":game.hull,"shield":game.shield,"cockpit":game.cockpit,"fire_timer":game.fire_timer,"targets":targets}

func _number(v, low: float, high: float) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v)>=low and float(v)<=high
func _array(v, count: int) -> bool:
	if typeof(v) != TYPE_ARRAY or v.size()!=count:return false
	for item in v:
		if not _number(item,-1000000,1000000):return false
	return true
func _rotation(v) -> bool:
	if not _array(v,4):return false
	var length := Quaternion(v[0],v[1],v[2],v[3]).length()
	return length>.5 and length<1.5

func valid(s: Dictionary) -> bool:
	if s.has("armament") and not Armament.valid_runtime(s.armament):return false
	if not Combat.valid(s.get("projectiles", [])):return false
	var contract = s.get("contract_id", 0)
	if not _number(contract, 0, 2147483646) or float(int(contract)) != float(contract):return false
	if contract > 0 and (s.get("version") != 4 or s.get("kind") not in ["delivery","scout","combat"]):return false
	var orbital = s.get("orbital_target", -1)
	if not _number(orbital, -1, 2) or float(int(orbital)) != float(orbital):return false
	if orbital >= 0 and (s.get("kind") != "planet" or s.get("stage") != "К ПЛАНЕТЕ"):return false
	if s.get("version") != 1 and s.get("version") != 2 and s.get("version") != 3 and s.get("version") != 4:return false
	if s.get("stage") not in STAGES+Planet.STAGES or s.get("kind") not in ["combat","scout","delivery","trade","planet"]:return false
	if s.kind=="planet":
		if s.version!=4 or s.stage not in Planet.STAGES+["ВОЗВРАЩЕНИЕ"] or not Planet.valid(s.get("planet"),s.stage):return false
	elif s.stage in Planet.STAGES:return false
	if s.version==1 and s.kind=="delivery":return false
	if s.version<3 and (s.kind=="trade" or s.stage=="ПЕРЕЛЁТ"):return false
	if (s.kind=="trade") != (s.stage=="ПЕРЕЛЁТ"):return false
	if s.version>=2:
		for key in ["origin","destination"]:
			if not _number(s.get(key),0,1) or float(int(s[key]))!=float(s[key]):return false
		if int(s.origin)==int(s.destination) or typeof(s.get("cargo"))!=TYPE_BOOL:return false
		if s.kind=="delivery" and (s.stage!="ДОСТАВКА" or not s.cargo):return false
		if s.kind!="delivery" and (s.stage=="ДОСТАВКА" or s.cargo):return false
	for key in ["pos","velocity"]:
		if not _array(s.get(key),3):return false
	if not _rotation(s.get("rot")):return false
	for key in ["stabilized","cockpit"]:
		if typeof(s.get(key)) != TYPE_BOOL:return false
	if not _number(s.get("hull"),.01,100) or not _number(s.get("shield"),0,175) or not _number(s.get("throttle"),-.3 if s.version>=4 else 0,1) or not _number(s.get("scan"),0,3) or not _number(s.get("fire_timer"),-100000,1):return false
	if typeof(s.get("targets")) != TYPE_ARRAY or s.targets.size()>3:return false
	var ids: Array = []
	for target in s.targets:
		if typeof(target)!=TYPE_DICTIONARY or not _number(target.get("id"),0,2):return false
		if not _number(target.get("shield",0),0,30):return false
		var id := int(target.id)
		if float(id)!=float(target.id) or id in ids:return false
		ids.append(id)
		if not _array(target.get("pos"),3) or not _rotation(target.get("rot")) or not _number(target.get("hp"),.01,90) or typeof(target.get("visible"))!=TYPE_BOOL:return false
		if id==2:
			var ai = target.get("ai")
			if typeof(ai)!=TYPE_DICTIONARY or ai.get("state") not in TACTICS or not _array(ai.get("waypoint"),3):return false
			if typeof(ai.get("enabled"))!=TYPE_BOOL or not _number(ai.get("time"),0,1000000) or not _number(ai.get("cooldown"),0,2) or not _number(ai.get("passes"),0,1000000):return false
	return true

func restore(game: Node3D, s: Dictionary) -> bool:
	if not valid(s):return false
	var order_id := int(s.get("contract_id", 0))
	if order_id > 0:
		var order: Dictionary = game.contracts.order(order_id)
		if order.is_empty() or order.kind != s.kind or order.origin != int(s.origin) or order.destination != int(s.destination):
			return false
	game.mission.assign_contract(order_id)
	game.mission.origin = int(s.get("origin",0))
	game.mission.destination = int(s.get("destination",1))
	game.mission.cargo_loaded = bool(s.get("cargo",false))
	game.station_id = game.mission.origin
	game.selected_mission = s.kind
	game.orbital_target = int(s.get("orbital_target", -1))
	game.mission.kind = s.kind
	game.mission.stage = s.stage
	game.mission.scan_elapsed = s.scan
	game.ship.position = vector(s.pos)
	game.ship.basis = rotation(s.rot)
	game.velocity = vector(s.velocity)
	game.throttle = s.throttle
	game.stabilized = s.stabilized
	game.hull = s.hull
	game.shield = minf(s.shield,100+game.upgrades.shield*25)
	game.fire_timer = s.fire_timer
	game.cockpit = s.cockpit
	game.cockpit_camera.current = game.cockpit
	game.external_camera.current = not game.cockpit
	game.visuals.set_camera(game.cockpit)
	game.visuals.update_flight(game.throttle)
	for target in game.enemies.duplicate():
		var found := false
		for data in s.targets:
			if data.id!=target.get_meta("id"):continue
			found = true
			target.position = vector(data.pos)
			target.basis = rotation(data.rot)
			target.set_meta("health",float(data.hp))
			target.set_meta("shield",float(data.get("shield",0)))
			target.visible = data.visible
			var pilot = target.get_node_or_null("PilotAI")
			if pilot!=null:
				pilot.state = data.ai.state
				pilot.state_time = data.ai.time
				pilot.cooldown = data.ai.cooldown
				pilot.waypoint = vector(data.ai.waypoint)
				pilot.passes = int(data.ai.passes)
				pilot.enabled = data.ai.enabled
				target.set_meta("tactic",pilot.state)
		if not found:
			game.enemies.erase(target)
			target.queue_free()
	if s.has("armament"):game.armament.restore_runtime(s.armament)
	game.combat.restore(s.get("projectiles", []))
	if s.kind=="planet":game.planet.restore(s.planet)
	game.mission.beacon.visible = game.mission.stage in ["ВЫЛЕТ","СКАНИРОВАНИЕ",Planet.OUTBOUND,Planet.INBOUND]
	game.clear_held_input()
	game.mission.step()
	return true
