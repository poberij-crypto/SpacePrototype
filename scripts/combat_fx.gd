extends Node3D
const LIMIT := 48
var effects: Array[Node3D] = []

func active_count() -> int:
	return effects.size()

func _register(node: Node3D, life: float) -> void:
	while effects.size() >= LIMIT:
		var old: Node3D = effects.pop_front()
		old.queue_free()
	add_child(node)
	effects.append(node)
	node.set_meta("life", life)
	node.set_meta("frames", 0)

func _process(delta: float) -> void:
	for node in effects.duplicate():
		if not is_instance_valid(node): continue
		var left: float = node.get_meta("life") - delta
		var frames: int = node.get_meta("frames") + 1
		node.set_meta("life", left)
		node.set_meta("frames", frames)
		if left <= 0 and frames >= 3: _expire(node.get_instance_id())

func _expire(id: int) -> void:
	if not is_instance_id_valid(id): return
	var node := instance_from_id(id) as Node3D
	effects.erase(node)
	node.queue_free()

func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	return m

func beam(start: Vector3, end: Vector3, hostile := false) -> void:
	var length := start.distance_to(end)
	if length < 0.05: return
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035 if not hostile else 0.045
	mesh.bottom_radius = mesh.top_radius
	mesh.height = length
	mesh.radial_segments = 6
	node.mesh = mesh
	node.material_override = _glow(Color("ff6652") if hostile else Color("83f4ff"))
	_register(node, 0.14)
	node.global_position = (start + end) * 0.5
	var axis := (end-start).normalized()
	node.quaternion = Quaternion(Vector3.UP, axis)

func burst(pos: Vector3, destroyed := false) -> void:
	var node := Node3D.new()
	_register(node, 0.65 if destroyed else 0.22)
	node.global_position = pos
	var count := 12 if destroyed else 5
	for i in range(count):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.18 if destroyed else 0.08
		mesh.height = mesh.radius*2
		mesh.radial_segments = 8
		mesh.rings = 4
		spark.mesh = mesh
		spark.material_override = _glow(Color("ffd99a") if i%2 else Color("ff713f"))
		node.add_child(spark)
		var angle := i*2.39996
		var direction := Vector3(cos(angle),sin(angle),sin(angle*1.7)).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(spark,"position",direction*(3.0 if destroyed else 0.65),0.5 if destroyed else 0.18)
		tween.tween_property(spark,"scale",Vector3.ONE*0.01,0.6 if destroyed else 0.2)
