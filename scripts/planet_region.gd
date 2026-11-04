extends Node3D
const Mining = preload("res://scripts/mining_state.gd")
var layout: Dictionary = {}
var mining_beacons: Node3D
var mining_complex: Node3D

var environment: Environment
var rock_bounds: Array[Rect2] = []

static func height_at(x: float, z: float) -> float:
	var distance := Vector2(x,z).length()
	var blend := smoothstep(55.0,170.0,distance)
	return blend*(18.0*sin(x*.008)*cos(z*.006)+11.0*sin(z*.014+x*.004)+7.0*cos(x*.019-z*.009))

static func slope_at(x: float, z: float) -> float:
	return Vector2((height_at(x+2,z)-height_at(x-2,z))/4,(height_at(x,z+2)-height_at(x,z-2))/4).length()

static func landing_safe(x: float, z: float) -> bool:
	if Rect2(30,-5,22,20).grow(5).has_point(Vector2(x,z)) or Rect2(-48,-29,16,47).grow(5).has_point(Vector2(x,z)):return false
	var center:=height_at(x,z)
	for delta in [Vector2.ZERO,Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4)]:
		if slope_at(x+delta.x,z+delta.y)>.35 or absf(height_at(x+delta.x,z+delta.y)-center)>1.5:return false
	return true

static func normal_at(x: float, z: float) -> Vector3:
	return Vector3((height_at(x-1,z)-height_at(x+1,z))*.5,1,(height_at(x,z-1)-height_at(x,z+1))*.5).normalized()

func terrain_height(x: float, z: float) -> float:
	if layout.is_empty():
		return height_at(x, z)
	var point := Vector2(x, z)
	var shifted: Vector2 = point + layout.offset
	var flatten := smoothstep(48.0, 105.0, point.distance_to(layout.landing))
	var center_clearance := smoothstep(55.0, 170.0, point.length())
	return height_at(shifted.x, shifted.y) * float(layout.amplitude) * flatten * center_clearance

func terrain_normal(x: float, z: float) -> Vector3:
	return Vector3((terrain_height(x-1,z)-terrain_height(x+1,z))*.5, 1, (terrain_height(x,z-1)-terrain_height(x,z+1))*.5).normalized()

func safe_terrain(x: float, z: float) -> bool:
	if layout.is_empty():
		return landing_safe(x, z)
	var center := terrain_height(x, z)
	for offset in [Vector2.ZERO, Vector2(4,0), Vector2(-4,0), Vector2(0,4), Vector2(0,-4)]:
		var point: Vector2 = Vector2(x, z) + offset
		if terrain_normal(point.x, point.y).y < .95 or absf(terrain_height(point.x, point.y) - center) > 1.5:
			return false
	return true

func landing_clear(x: float, z: float) -> bool:
	var site: Vector2 = layout.get("site", Mining.SITE)
	if mining_beacons != null and Rect2(site - Vector2(9, 7), Vector2(18, 14)).grow(5).has_point(Vector2(x, z)):
		return false
	if not safe_terrain(x,z):return false
	for footprint in rock_bounds:
		if footprint.grow(4.0).has_point(Vector2(x,z)):return false
	return true

func ground_point(point: Vector2) -> Vector3:
	return Vector3(point.x, terrain_height(point.x, point.y), point.y)

func show_mining_site(surveyed: bool, installed: bool) -> void:
	if surveyed and mining_beacons == null:
		mining_beacons = Node3D.new()
		add_child(mining_beacons)
		for offset in [Vector2(-8, -8), Vector2(-8, 8), Vector2(8, -8), Vector2(8, 8)]:
			var point := ground_point(layout.get("landing", Mining.LANDING_POINT) + offset)
			_mining_box(mining_beacons, Vector3(.7, .5, .7), point + Vector3.UP * .25, Color("73dbd1"))
	if installed and mining_complex == null:
		mining_complex = Node3D.new()
		add_child(mining_complex)
		var point := ground_point(layout.get("site", Mining.SITE))
		_mining_box(mining_complex, Vector3(14, 1.4, 10), point, Color("354956"))
		_mining_box(mining_complex, Vector3(7, 3, 7), point + Vector3(1, 1.8, 0), Color("738897"))
		_mining_box(mining_complex, Vector3(1.2, 8, 1.2), point + Vector3(0, 4, 0), Color("db9b49"))
		_mining_box(mining_complex, Vector3(4, 1.0, 4), point + Vector3(0, 7.7, 0), Color("6cddc5"))
		for z in [-3.0, 3.0]:
			_mining_box(mining_complex, Vector3(3.2, 2.6, 3.0), point + Vector3(-4.7, 1.2, z), Color("b57a45"))

func _mining_box(parent: Node3D, dimensions: Vector3, point: Vector3, color: Color) -> void:
	box(dimensions, point, color).reparent(parent)

func _ready() -> void:
	_terrain()
	if layout.is_empty():
		_outpost()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/planet_sky.gdshader")
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c8d0")
	environment.ambient_light_energy = .7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = layout.get("sky_color", Color("b6bdc1"))
	environment.fog_density = .00065
	environment.fog_sky_affect = .15

func _terrain() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEP := 30.0
	var ground_color: Color = layout.get("ground_color", Color("a68b6d"))
	for z in range(-32,32):
		for x in range(-32,32):
			var a := Vector2(x*STEP,z*STEP)
			var b := a+Vector2(STEP,0)
			var c := a+Vector2(0,STEP)
			var d := a+Vector2(STEP,STEP)
			for p in [a,b,c,b,d,c]:
				var height := terrain_height(p.x,p.y)
				var color := ground_color.lerp(Color("51585a"),clampf(1.0 - terrain_normal(p.x,p.y).y,0,1)) if not layout.is_empty() else ground_color.lerp(Color("51585a"),clampf(slope_at(p.x,p.y)*1.6,0,1))
				mesh.set_normal(terrain_normal(p.x,p.y))
				mesh.set_color(color)
				mesh.add_vertex(Vector3(p.x,height,p.y))
	var ground := MeshInstance3D.new()
	ground.mesh = mesh.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/terrain.gdshader")
	ground.material_override = material
	add_child(ground)
	var rng := RandomNumberGenerator.new();rng.seed=int(layout.get("rock_seed", 90210))
	var rock_material := StandardMaterial3D.new();rock_material.albedo_color=Color("645d56");rock_material.roughness=1
	var rocks := MultiMesh.new()
	rocks.transform_format=MultiMesh.TRANSFORM_3D
	var shape := SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=10;shape.rings=5
	rocks.mesh=shape;rocks.instance_count=160
	for i in range(160):
		var x:=rng.randf_range(-850,850);var z:=rng.randf_range(-850,850)
		if Vector2(x,z).length()<75:x+=100
		if not layout.is_empty() and Vector2(x,z).distance_to(layout.landing)<55.0:
			x += 115.0
		var scale:=Vector3(rng.randf_range(1,5),rng.randf_range(1,4),rng.randf_range(1,6))
		var radius:=maxf(scale.x,scale.z)
		rock_bounds.append(Rect2(Vector2(x-radius,z-radius),Vector2.ONE*radius*2))
		rocks.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(scale),Vector3(x,terrain_height(x,z)+scale.y*.2,z)))
	var instances:=MultiMeshInstance3D.new();instances.multimesh=rocks;instances.material_override=rock_material;add_child(instances)

func box(size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new();var shape := BoxMesh.new();shape.size=size
	item.mesh=shape;item.position=point
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.7
	item.material_override=material;add_child(item);return item

func _outpost() -> void:
	var pad:=MeshInstance3D.new();var shape:=CylinderMesh.new()
	shape.top_radius=22;shape.bottom_radius=22;shape.height=.4;shape.radial_segments=64
	pad.mesh=shape;pad.position.y=.05
	var material:=StandardMaterial3D.new();material.albedo_color=Color("354651");material.metallic=.35;material.roughness=.8
	pad.material_override=material;add_child(pad)
	box(Vector3(2,.1,15),Vector3(-5,.31,0),Color("d6dfe1"))
	box(Vector3(2,.1,15),Vector3(5,.31,0),Color("d6dfe1"))
	box(Vector3(10,.1,2),Vector3(0,.31,0),Color("d6dfe1"))
	for side in [-1,1]:
		for z in [-12,0,12]:box(Vector3(.8,.4,.8),Vector3(side*18,.4,z),Color("e5ba67"))
	box(Vector3(12,6,9),Vector3(39,3,4),Color("9aa8ac"))
	box(Vector3(13,1,10),Vector3(39,6.5,4),Color("344b5d"))
	box(Vector3(1,15,1),Vector3(48,7.5,-8),Color("53656d"))
	for z in [-24,-12,0,12]:
		var panel:=box(Vector3(10,.3,7),Vector3(-40,2,z),Color("1e415e"));panel.rotation_degrees.z=-15
		box(Vector3(.6,2,.6),Vector3(-40,1,z),Color("65757d"))
