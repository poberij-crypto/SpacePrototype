extends Node3D
var body: Node3D
var cabin: Node3D
var plumes: Array[MeshInstance3D] = []
var game: Node3D
var steel: StandardMaterial3D
var dark: StandardMaterial3D
var blue: StandardMaterial3D
var gold: StandardMaterial3D
var cyan: StandardMaterial3D
var glass: StandardMaterial3D

func mat(color: Color, metal := 0.0, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.42
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
	return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, material)

func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent, shape, pos, material)

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var n := cylinder(parent,radius,a.distance_to(b),(a+b)*0.5,material)
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func loft(parent: Node3D, rings: Array, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(rings.size()-1):
		for i in range(8):
			var a: Vector3 = rings[k]
			var b: Vector3 = rings[k+1]
			var angle := float(i)*TAU/8.0+PI/8.0
			var next := float(i+1)*TAU/8.0+PI/8.0
			var p0 := Vector3(cos(angle)*a.x,sin(angle)*a.y,a.z)
			var p1 := Vector3(cos(next)*a.x,sin(next)*a.y,a.z)
			var p2 := Vector3(cos(angle)*b.x,sin(angle)*b.y,b.z)
			var p3 := Vector3(cos(next)*b.x,sin(next)*b.y,b.z)
			for v in [p0,p2,p1,p1,p2,p3]:st.add_vertex(v)
	st.generate_normals()
	return mesh(parent, st.commit(), Vector3.ZERO, material)

func wing(parent: Node3D, points: Array, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var thickness := 0.11
	for i in range(1,points.size()-1):
		for index in [0,i,i+1]:st.add_vertex(Vector3(points[index].x,thickness,points[index].y))
		for index in [0,i+1,i]:st.add_vertex(Vector3(points[index].x,-thickness,points[index].y))
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		for v in [Vector3(a.x,thickness,a.y),Vector3(b.x,-thickness,b.y),Vector3(a.x,-thickness,a.y),Vector3(a.x,thickness,a.y),Vector3(b.x,thickness,b.y),Vector3(b.x,-thickness,b.y)]:st.add_vertex(v)
	st.generate_normals()
	var m := material.duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh(parent,st.commit(),Vector3.ZERO,m)

func setup(owner_game: Node3D) -> void:
	game = owner_game
	steel = mat(Color("9baebe"),0.65)
	dark = mat(Color("182733"),0.55)
	blue = mat(Color("294459"),0.5)
	gold = mat(Color("cd9450"),0.4)
	cyan = mat(Color("71d9ec"),0.0,true)
	glass = mat(Color("246c87"),0.7)
	body = Node3D.new()
	game.ship.add_child(body)
	_build_ship(body)
	cabin = Node3D.new()
	game.cockpit_camera.add_child(cabin)
	_build_cabin()
	set_camera(false)
	_build_space()

func _build_ship(parent: Node3D) -> void:
	loft(parent,[Vector3(.04,.04,-4.4),Vector3(.55,.23,-3.1),Vector3(.95,.48,-1.0),Vector3(1.05,.50,1.4),Vector3(.8,.35,2.35),Vector3(.01,.01,2.36)],steel)
	var canopy := loft(parent,[Vector3(.02,.02,-2.4),Vector3(.42,.27,-1.65),Vector3(.52,.36,-.4),Vector3(.48,.26,.3),Vector3(.02,.02,.65)],glass)
	canopy.position.y = .42
	for side in [-1.0,1.0]:
		wing(parent,[Vector2(side*.7,-1.3),Vector2(side*3.6,.7),Vector2(side*3.1,2.0),Vector2(side*.8,1.5)],blue)
		box(parent,Vector3(.12,.025,1.9),Vector3(side*2.0,.13,.72),gold)
		box(parent,Vector3(.4,.3,1.8),Vector3(side*3.1,0,1.1),dark)
		var gun := cylinder(parent,.09,2.2,Vector3(side*2.8,0,-.3),dark)
		gun.rotation_degrees.x = 90
		box(parent,Vector3(.14,.06,.14),Vector3(side*3.35,.18,1.0),cyan)
		var engine := cylinder(parent,.55,1.7,Vector3(side*1.0,-.16,1.5),dark)
		engine.rotation_degrees.x = 90
		for z in [.9,1.4,2.1]:
			var collar := cylinder(parent,.59,.10,Vector3(side*1.0,-.16,z),steel)
			collar.rotation_degrees.x = 90
		var core := cylinder(parent,.40,.06,Vector3(side*1.0,-.16,2.4),cyan)
		core.rotation_degrees.x = 90
		var flame := CylinderMesh.new()
		flame.top_radius = .05
		flame.bottom_radius = .34
		flame.height = 1.7
		flame.radial_segments = 16
		var glow := mat(Color(0.18,0.65,1.0,0.5),0,true)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var plume := mesh(parent,flame,Vector3(side*1.0,-.16,3.0),glow)
		plume.rotation_degrees.x = 90
		plumes.append(plume)
		for z in [-.2,.1,.4,.7]:
			box(parent,Vector3(.24,.04,.09),Vector3(side*.78,.48,z),dark)
		var fin := box(parent,Vector3(.09,.8,.9),Vector3(side*.7,.7,1.35),blue)
		fin.rotation_degrees.z = side*-18
	box(parent,Vector3(.20,.035,1.3),Vector3(0,.27,-2.8),gold)

func _build_cabin() -> void:
	box(cabin,Vector3(3.4,.34,.5),Vector3(0,-.92,-1.5),dark)
	for side in [-1.0,1.0]:
		rod(cabin,Vector3(side*1.0,-.82,-1.4),Vector3(side*1.35,.9,-1.65),.045,dark)
		rod(cabin,Vector3(side*1.35,.9,-1.65),Vector3(side*.75,1.15,-1.9),.035,steel)
		var screen := box(cabin,Vector3(.54,.22,.04),Vector3(side*.62,-.68,-1.37),blue)
		screen.rotation_degrees.x = -12
		for row in range(3):
			box(cabin,Vector3(.32,.012,.045),Vector3(side*.62,-.62-row*.045,-1.33),cyan)
		for i in range(3):box(cabin,Vector3(.04,.025,.04),Vector3(side*(.20+i*.1),-.77,-1.24),gold)
	rod(cabin,Vector3(-.75,1.15,-1.9),Vector3(.75,1.15,-1.9),.04,dark)

func set_camera(in_cockpit: bool) -> void:
	body.visible = not in_cockpit
	cabin.visible = in_cockpit

func update_flight(thrust: float) -> void:
	for plume in plumes:
		plume.scale.y = .15 + thrust*.9
		plume.position.z = 2.4 + .85*plume.scale.y

func _build_space() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/space.gdshader")
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8da5c3")
	settings.ambient_light_energy = .45
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	game.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_color = Color("ffe4cb")
	sun.light_energy = 2.0
	game.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20,140,0)
	rim.light_color = Color("5c9bc9")
	rim.light_energy = .65
	game.add_child(rim)
	var sphere := SphereMesh.new()
	sphere.radius = 70
	sphere.height = 140
	sphere.radial_segments = 96
	sphere.rings = 48
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/planet.gdshader")
	var planet := mesh(game,sphere,Vector3(170,-40,-360),material)
	planet.rotation_degrees = Vector3(25,-20,0)
	var air_mesh := sphere.duplicate() as SphereMesh
	air_mesh.radius = 71.2
	air_mesh.height = 142.4
	var air := ShaderMaterial.new()
	air.shader = preload("res://shaders/atmosphere.gdshader")
	mesh(game,air_mesh,planet.position,air)
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	var stone := mat(Color("363339"))
	stone.roughness = 1.0
	stone.metallic_specular = 0.0
	for i in range(30):
		var shape := SphereMesh.new()
		shape.radius = rng.randf_range(1.0,3.5)
		shape.height = shape.radius*2
		shape.radial_segments = 12
		shape.rings = 6
		var rock := mesh(game,shape,Vector3(rng.randf_range(-140,140),rng.randf_range(-70,70),rng.randf_range(-300,-35)),stone)
		rock.scale = Vector3(rng.randf_range(.7,1.5),rng.randf_range(.6,1.3),rng.randf_range(.8,1.7))
		rock.rotation = Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
	_build_station(Vector3(35,0,-105))
	_build_station(Vector3(-300,30,-490),true)

func _build_station(location: Vector3, outpost := false) -> void:
	var station := Node3D.new()
	station.position = location
	if outpost:station.rotation_degrees.z = 30
	game.add_child(station)
	var spine := cylinder(station,1.7,15,Vector3.ZERO,steel)
	spine.rotation_degrees.x = 90
	var ring := TorusMesh.new()
	ring.inner_radius = 7.8
	ring.outer_radius = 9.0
	ring.rings = 32
	ring.ring_segments = 12
	var torus := mesh(station,ring,Vector3.ZERO,blue)
	torus.rotation_degrees.x = 90
	for i in range(6):
		var a := i*TAU/6.0
		var pos := Vector3(cos(a)*8.4,sin(a)*8.4,0)
		rod(station,Vector3.ZERO,pos,.23,dark)
		box(station,Vector3(2,1,3.5),pos,steel)
		box(station,Vector3(.15,.4,2.5),pos+Vector3(0,.6,0),gold if outpost else cyan)
	for side in [-1.0,1.0]:
		box(station,Vector3(10,.1,7),Vector3(side*15,0,0),blue)
		rod(station,Vector3(side*8,0,0),Vector3(side*20,0,0),.14,steel)
		for x in range(9):box(station,Vector3(.06,.025,7),Vector3(side*(10+x),.08,0),steel)

func target_model(target: Node3D, hostile: bool) -> void:
	if hostile:
		var red := mat(Color("a3473d"),.4)
		loft(target,[Vector3(.03,.03,-2.8),Vector3(.9,.4,-.8),Vector3(1.1,.4,1.3),Vector3(.03,.03,1.6)],red)
		for side in [-1.0,1.0]:
			wing(target,[Vector2(side*.7,-1.1),Vector2(side*2.7,.5),Vector2(side*2.5,1.5),Vector2(side*.8,1.1)],dark)
			var core := cylinder(target,.22,.08,Vector3(side*.8,0,1.65),mat(Color("ff9471"),0,true))
			core.rotation_degrees.x = 90
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = 1.0
		ring.outer_radius = 1.4
		ring.rings = 20
		ring.ring_segments = 8
		var node := mesh(target,ring,Vector3.ZERO,gold)
		node.rotation_degrees.x = 90
		box(target,Vector3(.5,.5,.7),Vector3.ZERO,mat(Color("ffbe50"),0,true))
		for side in [-1.0,1.0]:rod(target,Vector3.ZERO,Vector3(side*1.3,0,0),.08,dark)
