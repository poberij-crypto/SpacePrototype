extends Control
const Sector = preload("res://scripts/sector_data.gd")
const CYAN := Color("64e3ff")
const DIM := Color("6991a7")
var game: Node3D
var selected := 0
var close_button: Button
var planet_choices: HBoxContainer
var navigation_button: Button
var selected_planet := -1
var last_remote := false

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button = Button.new()
	close_button.text = "ЗАКРЫТЬ КАРТУ"
	close_button.size = Vector2(210,48)
	game.flight_ui.decorate(close_button)
	close_button.pressed.connect(game._toggle_map)
	add_child(close_button)
	planet_choices = HBoxContainer.new()
	planet_choices.add_theme_constant_override("separation", 8)
	for index in range(3):
		var choice := Button.new()
		game.flight_ui.decorate(choice)
		choice.add_theme_font_size_override("font_size", 15)
		choice.pressed.connect(choose_planet.bind(index))
		planet_choices.add_child(choice)
	add_child(planet_choices)
	navigation_button = Button.new()
	game.flight_ui.decorate(navigation_button, true)
	navigation_button.add_theme_font_size_override("font_size", 16)
	navigation_button.pressed.connect(_navigate_selected)
	add_child(navigation_button)
	_update_controls()
	visible = false

func panel_rect() -> Rect2:
	var design: Vector2 = game.flight_ui.design_size
	var dimensions := Vector2(minf(1100, design.x-48), minf(850 if game.flight_ui.portrait else 650, design.y-48))
	return Rect2((design - dimensions) * .5, dimensions)

func chart_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(30,142), rect.size - Vector2(60,330))

func project(pos: Vector3) -> Vector2:
	var chart := chart_rect()
	var uv: Vector2
	if game.planet.on_surface():
		uv = Vector2((pos.x+900.0)/1800.0,(pos.z+900.0)/1800.0)
	else:
		var center: Vector3 = game.orbit_system().star.position
		uv = Vector2(.5 + (pos.x-center.x)/3000.0, .5 + (pos.z-center.z)/3000.0)
	return chart.position + Vector2(clampf(uv.x,0,1),clampf(uv.y,0,1)) * chart.size

func _process(_delta: float) -> void:
	if game == null:
		return
	var remote: bool = game.planet.in_neighbor()
	if remote != last_remote:
		selected_planet = -1
		last_remote = remote
	_update_controls()
	queue_redraw()

func _update_controls() -> void:
	var rect := panel_rect()
	close_button.position = rect.end - Vector2(230,64)
	var surface: bool = game.planet.on_surface()
	planet_choices.visible = not surface
	planet_choices.position = rect.position + Vector2(24,80)
	var planets: Array = game.orbit_system().planets
	for index in range(planet_choices.get_child_count()):
		var choice: Button = planet_choices.get_child(index)
		choice.text = planets[index].name
		choice.custom_minimum_size = Vector2((rect.size.x - 64) / 3, 44)
		choice.disabled = selected_planet == index
	navigation_button.visible = not surface and selected_planet >= 0
	navigation_button.position = rect.position + Vector2(24,rect.size.y-64)
	navigation_button.size = Vector2(minf(380, rect.size.x-280), 48)
	navigation_button.text = "КУРС НА ПЛАНЕТУ" if game.can_select_orbit() else "МАРШРУТ ЗАДАН ТЕКУЩЕЙ МИССИЕЙ"
	navigation_button.disabled = not game.can_select_orbit()

func choose_planet(index: int) -> void:
	if game.planet.on_surface() or index < 0 or index >= game.orbit_system().planets.size():
		return
	selected_planet = index
	last_remote = game.planet.in_neighbor()
	_update_controls()
	queue_redraw()

func _navigate_selected() -> void:
	if game.select_orbital_target(selected_planet):
		visible = false
		game.clear_held_input()

func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		point = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		point = event.position
	if pressed and not game.planet.on_surface():
		var planets: Array = game.orbit_system().planets
		for index in range(planets.size()):
			if point.distance_to(project(planets[index].position)) < 25:
				choose_planet(index)
				accept_event()
				return
		if not game.planet.in_neighbor():
			for i in range(2):
				if point.distance_to(project(Sector.position(i))) < 24:
					selected = i
					selected_planet = -1
					_update_controls()
		accept_event()

func text_at(point: Vector2, value: String, font_size := 18, color := Color("e9f5fc")) -> void:
	draw_string(get_theme_default_font(),point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if game==null:return
	if game.planet.on_surface():
		_draw_surface()
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.015,.03,.97))
	var rect := panel_rect()
	draw_style_box(game.flight_ui.style(Color("0c1b2b"),Color("285366")),rect)
	var remote: bool = game.planet.in_neighbor()
	text_at(rect.position+Vector2(24,38),"СИСТЕМА %s" % game.orbit_system().name,24,CYAN)
	text_at(rect.position+Vector2(24,66),"Выберите планету на карте или кнопками",15,DIM)
	var chart := chart_rect()
	draw_rect(chart,Color("07111d"))
	for i in range(9):
		var x: float = chart.position.x+chart.size.x*i/8.0
		draw_line(Vector2(x,chart.position.y),Vector2(x,chart.end.y),Color("183040"))
	for i in range(6):
		var y: float = chart.position.y+chart.size.y*i/5.0
		draw_line(Vector2(chart.position.x,y),Vector2(chart.end.x,y),Color("183040"))
	if not game.mission.flight_locked():
		draw_line(project(game.ship.position),project(game.flight_nav_position()),Color(.25,.7,.8,.65),2,true)
		var goal := project(game.flight_nav_position())
		draw_polyline(PackedVector2Array([goal+Vector2(0,-11),goal+Vector2(11,0),goal+Vector2(0,11),goal+Vector2(-11,0),goal+Vector2(0,-11)]),CYAN,2,true)
	_draw_orbits(chart)
	if remote:
		var gate := project(game.planet.World.ARRIVAL_GATE)
		draw_circle(gate, 4, CYAN)
		text_at(gate + Vector2(10,-12), "Врата домой", 13, CYAN)
	else:
		for i in range(2):
			var p := project(Sector.position(i))
			draw_circle(p,5,Color("ffbf6c"))
			draw_arc(p,12 if selected==i and selected_planet<0 else 8,0,TAU,24,CYAN if selected==i else DIM,1.5,true)
			text_at(p+Vector2(12,-9 if i==0 else 16),Sector.title(i),13)
		var beacon := project(game.mission.BEACON)
		draw_circle(beacon,3,DIM)
		if game.mission.stage == game.planet.OUTBOUND:
			var gate := project(game.planet.World.HOME_GATE)
			text_at(gate + Vector2(12,-9), "Прыжковый маяк", 13, CYAN)
	var player := project(game.ship.position)
	var forward: Vector3 = -game.ship.global_basis.z
	var direction := Vector2(forward.x,forward.z).normalized()
	if direction.length()<.01:direction = Vector2.UP
	var tangent := Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([player+direction*13,player-direction*9+tangent*7,player-direction*9-tangent*7]),CYAN)
	text_at(player+Vector2(13,20),"ВЫ",13,CYAN)
	var footer := chart.end.y+40
	var distance: int = int(game.ship.position.distance_to(Sector.position(selected)))
	if selected_planet >= 0:
		var body: Dictionary = game.orbit_system().planets[selected_planet]
		text_at(Vector2(rect.position.x+24,footer), "%s · %d м" % [body.name, roundi(game.ship.position.distance_to(body.approach))],20)
		var detail := "Посадочный район и месторождение" if body.landable else ("Газовый гигант · орбитальное исследование" if body.kind == "gas" else "Каменистая планета · орбитальное исследование")
		text_at(Vector2(rect.position.x+24,footer+28),detail,15,DIM)
	else:
		text_at(Vector2(rect.position.x+24,footer),game.planet.region_title() if remote else "Станция «%s» · %d м" % [Sector.title(selected),distance],20)
		text_at(Vector2(rect.position.x+24,footer+28),"Возвращение через прыжковый маяк" if remote else "Рынок, задания, ремонт и модули",15,DIM)
	text_at(Vector2(rect.position.x+24,rect.end.y-78),"ПОЛЁТ ПРИОСТАНОВЛЕН",14,CYAN)

func _draw_orbits(chart: Rect2) -> void:
	var data: Dictionary = game.orbit_system()
	var center: Vector3 = data.star.position
	for index in range(data.planets.size()):
		var body: Dictionary = data.planets[index]
		var radius: float = Vector2(body.position.x-center.x,body.position.z-center.z).length()
		var points := PackedVector2Array()
		for step in range(97):
			var angle := TAU * step / 96.0
			points.append(project(center+Vector3(cos(angle)*radius,0,sin(angle)*radius)))
		draw_polyline(points,Color("34404b"),1.0,true)
		var point := project(body.position)
		draw_circle(point,7 if body.kind == "gas" else 5,body.color)
		if index == selected_planet:
			draw_arc(point,13,0,TAU,32,CYAN,2,true)
		var label := Vector2(12, -10) if point.x < chart.get_center().x else Vector2(-100, -10)
		text_at(point+label,body.name,14)
	var star_point := project(center)
	draw_circle(star_point,12,Color(1,.63,.24,.15))
	draw_circle(star_point,7,data.star.color)
	text_at(star_point+Vector2(12,18),data.star.name,14,data.star.color)

func _draw_surface() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.015,.03,.97))
	var rect:=panel_rect();var chart:=chart_rect()
	draw_style_box(game.flight_ui.style(Color("0c1b2b"),Color("285366")),rect)
	text_at(rect.position+Vector2(24,38),game.planet.region_title(),24,CYAN)
	text_at(rect.position+Vector2(24,66),"Локальная карта · 1.8 × 1.8 км",15,DIM)
	draw_rect(chart,Color("172b31"))
	for i in range(7):
		var f:=float(i)/6
		draw_line(chart.position+Vector2(chart.size.x*f,0),chart.position+Vector2(chart.size.x*f,chart.size.y),Color("31515b"))
		draw_line(chart.position+Vector2(0,chart.size.y*f),chart.position+Vector2(chart.size.x,chart.size.y*f),Color("31515b"))
	if not game.planet.in_neighbor():
		var pad:=project(Vector3.ZERO);draw_circle(pad,7,Color("ffc46a"));text_at(pad+Vector2(15,-12),"Посадочная площадка",16)
	var marker := project(game.planet.mining_target())
	var mine = game.planet.mine()
	var amber := Color("ffc46a")
	if mine.surveyed:
		var site := project(game.planet.region.ground_point(game.planet.site_point()))
		draw_circle(marker, 4, CYAN)
		draw_rect(Rect2(site - Vector2(4,4), Vector2(8,8)), amber)
		marker = site
	else:
		var radii: Vector2 = chart.size / 1800.0 * mine.SURVEY_RADIUS
		var contour := PackedVector2Array()
		for i in range(33):
			contour.append(marker + Vector2.from_angle(TAU * i / 32.0) * radii)
		draw_colored_polygon(contour, Color(1.0,.67,.3,.17))
		draw_polyline(contour, amber, 1.5, true)
	text_at(marker + Vector2(12,32), game.planet.site_title() if mine.surveyed else "Область сигнала", 16, amber)
	var p:=project(game.ship.position);draw_circle(p,6,CYAN);text_at(p+Vector2(12,20),"ВЫ",14,CYAN)
	text_at(Vector2(rect.position.x+24,chart.end.y+40),"Высота %d м · Скорость %d м/с" % [int(game.planet.altitude()),int(game.velocity.length())],20)
	var info := "Посадка на ровных участках · орбита от 100 м"
	if mine.surveyed:
		info = "Запас %d ед. · склад %d/%d · голубая точка: посадка у залежи" % [mine.reserve, mine.stock, mine.CAPACITY]
	text_at(Vector2(rect.position.x+24,chart.end.y+70),info,15,DIM)
	text_at(Vector2(rect.position.x+24,rect.end.y-78),"ПОЛЁТ ПРИОСТАНОВЛЕН",14,CYAN)
