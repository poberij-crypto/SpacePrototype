extends Control
var game: Node3D
var launch: Button
var neighbor_launch: Button
var report_for_neighbor := false
var action_button: Button
var orbit: Button
var up: Button
var down: Button
var mine_action: Button
var report_button: Button
var report_dialog: AcceptDialog

func setup(owner_game: Node3D) -> void:
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	launch=_button("ПЛАНЕТА · АСТРА",game.start_planet_flight)
	neighbor_launch=_button(game.planet.generated.system_name, game.start_neighbor_flight)
	launch.add_theme_font_size_override("font_size",12)
	neighbor_launch.add_theme_font_size_override("font_size",14)
	action_button=_button("СПУСК",game.planet.action)
	orbit=_button("ВЫЙТИ НА ОРБИТУ",game.planet.exit_orbit)
	up=_button("ПОДЪЁМ ↑",func():pass)
	down=_button("СНИЖЕНИЕ ↓",func():pass)
	up.button_down.connect(func():game.planet.vertical=1.0)
	down.button_down.connect(func():game.planet.vertical=-1.0)
	up.button_up.connect(func():game.planet.vertical=0.0)
	down.button_up.connect(func():game.planet.vertical=0.0)
	mine_action = _button("СКАНИРОВАТЬ", _mining_action)
	report_button = _button("ОТЧЁТ", show_report)
	report_dialog = AcceptDialog.new()
	report_dialog.title = "Меридиан-1 · отчёт комплекса"
	report_dialog.ok_button_text = "Прочитано"
	report_dialog.confirmed.connect(func():
		game.acknowledge_mining_report(report_for_neighbor)
	)
	add_child(report_dialog)

func _button(text: String, callback: Callable) -> Button:
	var b:=Button.new();b.text=text;game.flight_ui.decorate(b,true);b.pressed.connect(callback);add_child(b);return b
func rect(b: Button, r: Rect2) -> void:b.position=r.position;b.size=r.size
func modal() -> bool:return game.flight_ui.map_panel.visible or game.flight_ui.market_panel.visible or game.upgrades_panel.visible or (game.weapon_shop != null and game.weapon_shop.visible) or (game.contract_board != null and game.contract_board.visible)

func _mining_action() -> void:
	if game.mission.stage == "ПОВЕРХНОСТЬ":
		game.planet.start_survey()
	elif not game.planet.mine().installed:
		game.planet.deploy_mine()
	else:
		game.planet.load_ore()

func show_report() -> void:
	if not (game.mining.has_report() or game.neighbor_mining.has_report()) or not is_inside_tree():
		return
	game.clear_held_input()
	report_for_neighbor = not game.mining.has_report()
	var m = game.neighbor_mining if report_for_neighbor else game.mining
	report_dialog.title = "%s · отчёт комплекса" % (game.planet.generated.planet_name if report_for_neighbor else "Меридиан-1")
	report_dialog.dialog_text = "Добыто в фоне: %d ед.\nПотеряно при налётах: %d ед.\nПоломок: %d · Налётов: %d\nСклад: %d/%d ед. · %s" % [
		m.report_produced, m.report_lost, m.report_breakdowns, m.report_raids,
		m.stock, m.CAPACITY, m.production_status()
	]
	report_dialog.popup_centered()

func _process(_delta: float) -> void:
	if game==null:return
	size=game.flight_ui.design_size
	var portrait: bool=game.flight_ui.portrait
	var ui = game.flight_ui
	var routes: Rect2 = ui.shortcut_rect(3)
	var route_width := (routes.size.x-12)*.5
	rect(launch,Rect2(routes.position,Vector2(route_width,48)))
	rect(neighbor_launch,Rect2(routes.position+Vector2(route_width+12,0),Vector2(route_width,48)))
	rect(orbit,ui.shortcut_rect(3))
	rect(action_button,Rect2(ui.context_position(90 if portrait else 85),Vector2(260,56)))
	var fire: Rect2 = ui.fire_button.get_rect()
	rect(up,Rect2(fire.position,Vector2(fire.size.x,64)))
	rect(down,Rect2(fire.position+Vector2(0,76),Vector2(fire.size.x,64)))
	rect(mine_action,Rect2(ui.context_position(18 if portrait else 150),Vector2(260,52)))
	var report_rect: Rect2 = ui.shortcut_rect(4)
	var report_width := (report_rect.size.x-12)*.5
	rect(report_button,Rect2(report_rect.position+Vector2(report_width+12,0),Vector2(report_width,48)))
	var blocked:=modal()
	report_button.visible = (game.mining.has_report() or game.neighbor_mining.has_report()) and not blocked
	var stage: String=game.mission.stage
	launch.visible=game.at_station() and game.pending_snapshot.is_empty() and not blocked
	neighbor_launch.visible=launch.visible
	var active: bool=game.planet.active() and not game.destroyed
	orbit.visible=active and stage=="ПОВЕРХНОСТЬ" and not blocked
	orbit.disabled=not game.planet.can_exit()
	up.visible=active and stage=="ПОВЕРХНОСТЬ" and not blocked
	down.visible=up.visible
	action_button.visible=active and not game.flight_ui.dock_button.visible and stage in [game.planet.OUTBOUND, game.planet.INBOUND, "К ПЛАНЕТЕ","ПОВЕРХНОСТЬ","НА ПОВЕРХНОСТИ"] and not blocked and not game.has_orbital_target()
	if stage in [game.planet.OUTBOUND, game.planet.INBOUND]:
		action_button.text = "ПРЫЖОК"
		action_button.disabled = not game.planet.can_jump()
	elif stage=="К ПЛАНЕТЕ":
		var can_return: bool = game.planet.can_jump()
		action_button.text = "ПРЫЖОК ДОМОЙ" if can_return else "НАЧАТЬ СПУСК"
		action_button.disabled = not can_return and not game.planet.can_enter()
	elif stage=="ПОВЕРХНОСТЬ":action_button.text="ПОСАДКА";action_button.disabled=not game.planet.can_land()
	else:action_button.text="ВЗЛЁТ";action_button.disabled=false
	_update_mining_action(active and not blocked, stage)
	queue_redraw()

func _update_mining_action(available: bool, stage: String) -> void:
	var m = game.planet.mine()
	var airborne: bool = stage == "ПОВЕРХНОСТЬ" and not m.surveyed
	var landed: bool = stage == "НА ПОВЕРХНОСТИ" and game.planet.can_service_mine()
	mine_action.visible = available and (airborne or landed)
	if airborne:
		var scanning: bool = game.planet.survey_elapsed >= 0
		mine_action.text = "СКАНИРОВАНИЕ · %d%%" % int(game.planet.survey_elapsed / m.SURVEY_SECONDS * 100.0) if scanning else "СКАНИРОВАТЬ"
		mine_action.disabled = scanning or not game.planet.can_survey()
	elif landed and not m.installed:
		mine_action.text = "РАЗВЕРНУТЬ КОМПЛЕКС"
		mine_action.disabled = false
	elif landed:
		var free: int = game.Trade.CAPACITY - game.cargo_used()
		var quantity := mini(free, m.stock)
		mine_action.text = "ЗАГРУЗИТЬ РУДУ · %d ЕД." % quantity
		if free == 0:
			mine_action.text = "ОТСЕК ЗАПОЛНЕН"
		elif m.stock == 0:
			mine_action.text = "СКЛАД ПУСТ"
		mine_action.disabled = quantity == 0

func text_at(p: Vector2, value: String, font_size:=18, color:=Color("e9f5fc")) -> void:
	draw_string(get_theme_default_font(),p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	if game==null or not game.planet.active() or modal() or game.destroyed:return
	var stage: String=game.mission.stage
	var portrait: bool=game.flight_ui.portrait
	if stage in ["СПУСК","ВЫХОД НА ОРБИТУ"]:
		var opacity:=clampf(sin(PI*minf(game.planet.elapsed,4.0)/4.0),0,1)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.48,.63,.72,opacity))
		for i in range(6):
			var x:=fmod(i*280.0+game.planet.elapsed*140.0,size.x+400)-200
			draw_circle(Vector2(x,size.y*.45+sin(i*2.0)*120),200,Color(.8,.84,.87,opacity*.12))
		var center:=Vector2(size.x*.5-150,size.y*.5-28)
		draw_rect(Rect2(center-Vector2(24,28),Vector2(380,116)),Color(.025,.07,.11,.9))
		text_at(center,stage,23)
		text_at(center+Vector2(0,36),"%s · %d%%" % [game.planet.region_title(), mini(100,int(game.planet.elapsed/4.0*100))],18,Color("64e3ff"))
		return
	if stage not in [game.planet.OUTBOUND, game.planet.INBOUND, "К ПЛАНЕТЕ","ПОВЕРХНОСТЬ","ПОСАДКА","НА ПОВЕРХНОСТИ","ВЗЛЁТ"]:return
	var r: Rect2 = game.flight_ui.planet_status_rect()
	var lines: Array[String] = []
	if stage in [game.planet.OUTBOUND, game.planet.INBOUND]:
		var destination: String = game.planet.generated.system_name if stage == game.planet.OUTBOUND else "СТАРТОВАЯ СИСТЕМА"
		lines = ["ПРЫЖОК → %s" % destination,
			"До маяка: %d м" % int(game.ship.position.distance_to(game.planet.nav_point())),
			"До 35 м · скорость до 25 м/с", "Действие: ПРЫЖОК"]
	elif stage == "К ПЛАНЕТЕ":
		lines = [game.flight_nav_title(),
			"Расстояние: %d м" % int(game.ship.position.distance_to(game.flight_nav_position())),
			"До 35 м · скорость до 25 м/с", "Действие: НАЧАТЬ СПУСК"]
		if game.has_orbital_target():
			var primary: String = game.orbit_system().planets[0].name
			lines[2] = "Посадка: %s" % primary
			lines[3] = "Выберите планету на карте"
	else:
		lines = [game.planet.region_title(),
			"ВЫСОТА %d м · %s" % [int(game.planet.altitude()),stage],
			"Посадка: до 25 м · до 8 м/с", "Выход на орбиту: от 100 м"]
		if stage == "НА ПОВЕРХНОСТИ":
			lines[2] = "Посадка выполнена"
			lines[3] = "Действие: ВЗЛЁТ"
		elif stage in ["ПОСАДКА","ВЗЛЁТ"]:
			lines[2] = "Посадочная автоматика"
			lines[3] = "Дождитесь завершения манёвра"
	_draw_status_lines(r,lines,Color("64e3ff"))
	if stage in ["ПОВЕРХНОСТЬ", "НА ПОВЕРХНОСТИ"]:
		_draw_mining_status()

func _draw_status_lines(r: Rect2, lines: Array[String], title_color: Color) -> void:
	draw_style_box(game.flight_ui.style(Color(.025,.07,.11,.92),Color("285366")),r)
	var font := get_theme_default_font()
	for i in range(mini(lines.size(),4)):
		var font_size := 14 if i == 0 else 13
		var line := lines[i]
		# Long generated site/body names must remain inside their corner panel.
		if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > r.size.x-28:
			while line.length() > 0 and font.get_string_size(line+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > r.size.x-28:
				line = line.left(line.length()-1)
			line += "…"
		text_at(r.position+Vector2(14,20+i*20),line,font_size,title_color if i == 0 else Color("e9f5fc"))

func _draw_mining_status() -> void:
	var m = game.planet.mine()
	var lines: Array[String] = [
		"СИГНАЛ РУДЫ · %d м" % roundi(game.planet.mining_distance(game.planet.signal_point())),
		"Скан: до 150 м · высота до 100 м",
		"Скорость: до 20 м/с", "Сканируйте участок с воздуха"]
	if m.surveyed:
		lines = [game.planet.site_title(),
			"ЗАПАС %d ЕД. · НИЗКИЙ РИСК" % m.reserve,
			"Посадка у маркера", "Комплекс доступен до 40 м"]
	if m.installed:
		lines = [game.planet.site_title(),
			"СКЛАД %d/%d · ЗАПАС %d" % [m.stock,m.CAPACITY,m.reserve],
			m.production_status(), "ГРУЗ %d/%d" % [game.cargo_used(),game.Trade.CAPACITY]]
	_draw_status_lines(game.flight_ui.mining_status_rect(),lines,Color("ffc46a"))
