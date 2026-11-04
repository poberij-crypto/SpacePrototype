extends Control
const Sector = preload("res://scripts/sector_data.gd")
const CYAN := Color("64e3ff")
const DIM := Color("6991a7")
var game: Node3D
var selected := 0
var close_button: Button

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button = Button.new()
	close_button.text = "ЗАКРЫТЬ КАРТУ"
	close_button.size = Vector2(210,48)
	game.flight_ui.decorate(close_button)
	close_button.pressed.connect(game._toggle_map)
	add_child(close_button)
	visible = false

func panel_rect() -> Rect2:
	return Rect2(24,250,672,780) if game.flight_ui.portrait else Rect2(160,70,960,580)
func chart_rect() -> Rect2:
	return Rect2(50,360,620,440) if game.flight_ui.portrait else Rect2(220,160,840,310)
func project(pos: Vector3) -> Vector2:
	var chart := chart_rect()
	var uv := Vector2((pos.x+900.0)/1800.0,(pos.z+900.0)/1800.0) if game.planet.on_surface() else Vector2((pos.x+400.0)/800.0,(pos.z+650.0)/650.0)
	return chart.position+Vector2(clampf(uv.x,0,1),clampf(uv.y,0,1))*chart.size

func _process(_delta: float) -> void:
	if game==null:return
	var rect := panel_rect()
	close_button.position = rect.end-Vector2(230,64)
	queue_redraw()

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
		for i in range(2):
			if point.distance_to(project(Sector.position(i)))<30:selected = i
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
	text_at(rect.position+Vector2(24,38),"КАРТА СЕКТОРА / XZ",24,CYAN)
	text_at(rect.position+Vector2(24,66),"Нажмите на станцию для просмотра",15,DIM)
	var chart := chart_rect()
	draw_rect(chart,Color("07111d"))
	for i in range(9):
		var x: float = chart.position.x+chart.size.x*i/8.0
		draw_line(Vector2(x,chart.position.y),Vector2(x,chart.end.y),Color("183040"))
	for i in range(6):
		var y: float = chart.position.y+chart.size.y*i/5.0
		draw_line(Vector2(chart.position.x,y),Vector2(chart.end.x,y),Color("183040"))
	if not game.mission.flight_locked():
		draw_line(project(game.ship.position),project(game.mission.nav_position()),Color(.25,.7,.8,.65),2,true)
		var goal := project(game.mission.nav_position())
		draw_polyline(PackedVector2Array([goal+Vector2(0,-11),goal+Vector2(11,0),goal+Vector2(0,11),goal+Vector2(-11,0),goal+Vector2(0,-11)]),CYAN,2,true)
	for i in range(2):
		var p := project(Sector.position(i))
		draw_circle(p,8,Color("ffbf6c"))
		draw_arc(p,16 if selected==i else 12,0,TAU,32,CYAN if selected==i else DIM,1.5,true)
		text_at(p+Vector2(20,-9),Sector.title(i),16)
	var beacon := project(game.mission.BEACON)
	draw_circle(beacon,4,DIM)
	text_at(beacon+Vector2(10,-9),"Учебный маяк",14,DIM)
	var player := project(game.ship.position)
	var forward: Vector3 = -game.ship.global_basis.z
	var direction := Vector2(forward.x,forward.z).normalized()
	if direction.length()<.01:direction = Vector2.UP
	var tangent := Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([player+direction*13,player-direction*9+tangent*7,player-direction*9-tangent*7]),CYAN)
	text_at(player+Vector2(13,20),"ВЫ",13,CYAN)
	var footer := chart.end.y+40
	var distance: int = int(game.ship.position.distance_to(Sector.position(selected)))
	text_at(Vector2(rect.position.x+24,footer),"Станция «%s» · %d м" % [Sector.title(selected),distance],20)
	text_at(Vector2(rect.position.x+24,footer+28),"Рынок, задания, ремонт и модули",15,DIM)
	text_at(Vector2(rect.position.x+24,rect.end.y-78),"ПОЛЁТ ПРИОСТАНОВЛЕН",14,CYAN)

func _draw_surface() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.015,.03,.97))
	var rect:=panel_rect();var chart:=chart_rect()
	draw_style_box(game.flight_ui.style(Color("0c1b2b"),Color("285366")),rect)
	text_at(rect.position+Vector2(24,38),"АСТРА / РАЙОН МЕРИДИАН",24,CYAN)
	text_at(rect.position+Vector2(24,66),"Локальная карта · 1.8 × 1.8 км",15,DIM)
	draw_rect(chart,Color("172b31"))
	for i in range(7):
		var f:=float(i)/6
		draw_line(chart.position+Vector2(chart.size.x*f,0),chart.position+Vector2(chart.size.x*f,chart.size.y),Color("31515b"))
		draw_line(chart.position+Vector2(0,chart.size.y*f),chart.position+Vector2(chart.size.x,chart.size.y*f),Color("31515b"))
	var pad:=project(Vector3.ZERO);draw_circle(pad,7,Color("ffc46a"));text_at(pad+Vector2(15,-12),"Посадочная площадка",16)
	var marker := project(game.planet.mining_target())
	var mine = game.mining
	var amber := Color("ffc46a")
	if mine.surveyed:
		var site := project(game.planet.region.ground_point(mine.SITE))
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
	text_at(marker + Vector2(12,32), "Меридиан-1" if mine.surveyed else "Область сигнала", 16, amber)
	var p:=project(game.ship.position);draw_circle(p,6,CYAN);text_at(p+Vector2(12,20),"ВЫ",14,CYAN)
	text_at(Vector2(rect.position.x+24,chart.end.y+40),"Высота %d м · Скорость %d м/с" % [int(game.planet.altitude()),int(game.velocity.length())],20)
	var info := "Посадка на ровных участках · орбита от 100 м"
	if mine.surveyed:
		info = "Запас %d ед. · склад %d/%d · голубая точка: посадка у залежи" % [mine.reserve, mine.stock, mine.CAPACITY]
	text_at(Vector2(rect.position.x+24,chart.end.y+70),info,15,DIM)
	text_at(Vector2(rect.position.x+24,rect.end.y-78),"ПОЛЁТ ПРИОСТАНОВЛЕН",14,CYAN)
