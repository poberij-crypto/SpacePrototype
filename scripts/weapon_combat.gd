extends Node3D
const Arms = preload("res://scripts/armament_state.gd")
const MAX_PROJECTILES := 48
var game: Node3D
var projectiles: Array[Dictionary] = []
var lock_target: Node3D
var lock_progress := 0.0

func setup(owner_game: Node3D) -> void:
	game = owner_game

func allowed() -> bool:
	return not game.destroyed and not game.mission.flight_locked() and game.mission.kind != "planet" \
		and not game.flight_ui.map_panel.visible and not game.flight_ui.market_panel.visible \
		and not game.upgrades_panel.visible and not game.station_dock_dialog.visible \
		and not game.weapon_shop.visible

func aimed_target(distance: float, threshold := .985) -> Node3D:
	var selected: Node3D
	var best := threshold
	for target in game.enemies:
		if not is_instance_valid(target) or not target.visible: continue
		var direction: Vector3 = target.global_position - game.ship.global_position
		if direction.length() < .1 or direction.length() > distance: continue
		var alignment: float = (-game.ship.global_basis.z).dot(direction.normalized())
		if alignment > best:
			best = alignment
			selected = target
	return selected

func reset_lock() -> void:
	lock_target = null
	lock_progress = 0.0

func reset() -> void:
	reset_lock()
	for shot in projectiles:
		shot.node.free()
	projectiles.clear()

func step(delta: float) -> void:
	if not allowed():
		reset_lock()
		return
	var target: Node3D = aimed_target(400, .97) if game.armament.launcher != "" else null
	if target != lock_target:
		lock_target = target
		lock_progress = 0.0
	if is_instance_valid(lock_target): lock_progress = minf(1.0, lock_progress + delta / .8)
	for shot in projectiles.duplicate():
		var previous: Vector3 = shot.pos
		if shot.kind == "launcher":
			var tracked := target_by_id(shot.target)
			if tracked != null:
				var delta_position: Vector3 = tracked.global_position - previous
				if delta_position.length_squared() > .01:
					var desired := delta_position.normalized()
					var direction: Vector3 = shot.velocity.normalized()
					var axis := direction.cross(desired)
					if axis.length_squared() < .0001:
						axis = direction.cross(Vector3.RIGHT if absf(direction.y) > .9 else Vector3.UP)
					shot.velocity = direction.rotated(axis.normalized(), minf(direction.angle_to(desired), delta * 3.0)) * 105.0
		shot.pos += shot.velocity * delta
		shot.life -= delta
		shot.node.position = shot.pos
		shot.node.quaternion = Quaternion(Vector3.UP, shot.velocity.normalized())
		var hit: Node3D
		var first := INF
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or not enemy.visible: continue
			var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, previous, shot.pos)
			if closest.distance_to(enemy.global_position) <= 3.5 and previous.distance_squared_to(closest) < first:
				hit = enemy
				first = previous.distance_squared_to(closest)
		if hit != null or shot.life <= 0:
			projectiles.erase(shot)
			shot.node.queue_free()
		if hit != null:
			apply_damage(hit, shot.damage, shot.kind)

func fire_primary() -> bool:
	if not allowed(): return false
	var fired := false
	for slot in range(2):
		if not game.armament.ready(slot): continue
		var kind: String = game.armament.loadout[slot]
		if kind != "laser" and projectiles.size() >= MAX_PROJECTILES: continue
		game.armament.consume_shot(slot)
		fired = true
		var weapon: Dictionary = Arms.CATALOG[kind]
		var damage: float = float(weapon.damage) * (1.0 + game.upgrades.weapon * .4)
		var muzzle: Vector3 = game.ship.to_global(Vector3(-2.8 if slot == 0 else 2.8, 0, -1.5))
		if kind == "laser":
			var target := aimed_target(weapon.range)
			var impact: Vector3 = target.global_position if target != null else muzzle - game.ship.global_basis.z * float(weapon.range)
			game.fx.beam(muzzle, impact)
			if target != null: apply_damage(target, damage, kind)
		else:
			var speed := 260.0 if kind == "cannon" else 85.0
			_spawn({"kind":kind,"pos":muzzle,"velocity":-game.ship.global_basis.z * speed,"life":float(weapon.range)/speed,"target":-1,"damage":damage})
	return fired

func launch_missile() -> bool:
	var arms = game.armament
	if not allowed() or arms.launcher == "" or arms.rockets <= 0 or arms.missile_cooldown > 0 \
		or not is_instance_valid(lock_target) or not lock_target.visible or lock_progress < 1.0 \
		or projectiles.size() >= MAX_PROJECTILES or lock_target != aimed_target(400, .97):
		return false
	var previous: Dictionary = arms.runtime_capture()
	arms.rockets -= 1
	arms.missile_cooldown = 3.0
	_spawn({"kind":"launcher","pos":game.ship.to_global(Vector3(0,-.6,-3)),"velocity":-game.ship.global_basis.z*105.0,"life":4.0,"target":int(lock_target.get_meta("id")),"damage":45.0*(1.0+game.upgrades.weapon*.4)})
	if not game._save_progress():
		var shot: Dictionary = projectiles.pop_back()
		shot.node.free()
		arms.restore_runtime(previous)
		return false
	return true

func target_by_id(id: int) -> Node3D:
	for target in game.enemies:
		if is_instance_valid(target) and int(target.get_meta("id")) == id and target.visible:
			return target
	return null

func apply_damage(target: Node3D, damage: float, kind: String) -> void:
	if not is_instance_valid(target) or target not in game.enemies: return
	var weapon: Dictionary = Arms.CATALOG[kind]
	var shield: float = float(target.get_meta("shield", 0.0))
	var absorbed := minf(shield, damage * float(weapon.shield))
	target.set_meta("shield", shield - absorbed)
	var remaining := maxf(0, damage - absorbed / float(weapon.shield))
	var hp: float = float(target.get_meta("health")) - remaining * float(weapon.hull)
	target.set_meta("health", hp)
	game.fx.burst(target.global_position)
	game.help_label.text = "Попадание · щит %d · корпус %d" % [ceili(shield-absorbed), maxi(0,ceili(hp))]
	if hp > 0:
		var pilot = target.get_node_or_null("PilotAI")
		if pilot != null: pilot.on_hit()
	else:
		game.fx.burst(target.global_position, true)
		if game.mission.contract_id == 0:
			game.credits += 100 if target.get_meta("hostile") else 50
		game.enemies.erase(target)
		target.queue_free()
		game._save_progress()

func _spawn(data: Dictionary) -> void:
	var shot := data.duplicate()
	var node := MeshInstance3D.new()
	if shot.kind == "plasma":
		var sphere := SphereMesh.new()
		sphere.radius = .34
		sphere.height = .68
		sphere.radial_segments = 12
		sphere.rings = 6
		node.mesh = sphere
	else:
		var body := CylinderMesh.new()
		body.top_radius = .12 if shot.kind == "launcher" else .045
		body.bottom_radius = body.top_radius
		body.height = 1.6 if shot.kind == "launcher" else .7
		body.radial_segments = 8
		node.mesh = body
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("7bff9a") if shot.kind == "plasma" else (Color("ff9d55") if shot.kind == "launcher" else Color("ffe5a1"))
	material.emission_enabled = true
	material.emission = material.albedo_color
	node.material_override = material
	add_child(node)
	node.position = shot.pos
	node.quaternion = Quaternion(Vector3.UP, shot.velocity.normalized())
	shot["node"] = node
	projectiles.append(shot)

func capture() -> Array:
	var result: Array = []
	for shot in projectiles:
		result.append({"kind":shot.kind,"pos":[shot.pos.x,shot.pos.y,shot.pos.z],"velocity":[shot.velocity.x,shot.velocity.y,shot.velocity.z],"life":shot.life,"target":shot.target,"damage":shot.damage})
	return result

static func valid(data, max_target_id: int) -> bool:
	if typeof(data) != TYPE_ARRAY or data.size() > MAX_PROJECTILES: return false
	for shot in data:
		if typeof(shot) != TYPE_DICTIONARY or shot.get("kind") not in ["cannon","plasma","launcher"]: return false
		if not Arms.number(shot.get("life"),0,4) or not Arms.number(shot.get("damage"),0,100) or not Arms.number(shot.get("target"),-1,max_target_id,true): return false
		for key in ["pos","velocity"]:
			if typeof(shot.get(key)) != TYPE_ARRAY or shot[key].size() != 3: return false
			for value in shot[key]:
				if not Arms.number(value,-1000000,1000000): return false
		var velocity := Vector3(shot.velocity[0],shot.velocity[1],shot.velocity[2])
		if velocity.length() < 1 or velocity.length() > 300: return false
	return true

func restore(data: Array) -> void:
	reset()
	for raw in data:
		var shot: Dictionary = raw.duplicate()
		shot.pos = Vector3(raw.pos[0],raw.pos[1],raw.pos[2])
		shot.velocity = Vector3(raw.velocity[0],raw.velocity[1],raw.velocity[2])
		_spawn(shot)
