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
	neighbor_launch=_button("СИСТЕМА «%s»" % game.planet.generated.system_name, game.start_neighbor_flight)
	action_button=_button("СПУСК",game.planet.action)
	orbit=_button("ВЫЙТИ НА ОРБИТУ",game.planet.exit_orbit)
	up=_button("ПОДЪЁМ ↑",func():pass)
	down=_button("СНИЖЕНИЕ ↓",func():pass)
	up.button_down.connect(func():game.planet.vertical=1.0)
	down.button_down.connect(func():game.planet.vertical=-1.0)
	up.button_up.connect(func():game.planet.vertical=0.0)
	down.button_up.connect(func():game.planet.vertical=0.0)
	mine_action = _button("СКАНИРОВАТЬ", _mining_action)
	report_button = _button("ОТЧЁТ ДОБЫЧИ", show_report)
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
func modal() -> bool:return game.flight_ui.map_panel.visible or game.flight_ui.market_panel.visible or game.upgrades_panel.visible

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
	rect(launch,Rect2(360,296,336,48) if portrait else Rect2(990,204,264,48))
	rect(neighbor_launch,Rect2(24,296,320,48) if portrait else Rect2(24,278,264,48))
	rect(orbit,Rect2(360,296,336,48) if portrait else Rect2(990,204,264,48))
	rect(action_button,Rect2(230,730,260,56) if portrait else Rect2(510,445,260,56))
	rect(up,Rect2(500,1040,196,64) if portrait else Rect2(1080,478,174,64))
	rect(down,Rect2(500,1116,196,64) if portrait else Rect2(1080,550,174,64))
	rect(mine_action, Rect2(230,658,260,56) if portrait else Rect2(510,510,260,52))
	rect(report_button, Rect2(364,238,190,44) if portrait else Rect2(24,224,190,44))
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
	action_button.visible=active and stage in [game.planet.OUTBOUND, game.planet.INBOUND, "К ПЛАНЕТЕ","ПОВЕРХНОСТЬ","НА ПОВЕРХНОСТИ"] and not blocked
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
	var r:=Rect2(24,354,672,90) if portrait else Rect2(310,108,630,74)
	draw_style_box(game.flight_ui.style(Color(.025,.07,.11,.92),Color("285366")),r)
	var label: String
	var hint: String
	if stage in [game.planet.OUTBOUND, game.planet.INBOUND]:
		var destination: String = game.planet.generated.system_name if stage == game.planet.OUTBOUND else "СТАРТОВАЯ СИСТЕМА"
		label = "ПРЫЖОК → %s · %d м" % [destination, int(game.ship.position.distance_to(game.planet.nav_point()))]
		hint = "Подойдите до 35 м, скорость до 25 м/с · затем «ПРЫЖОК»"
	elif stage=="К ПЛАНЕТЕ":
		label="%s · ВХОД %d м" % [game.planet.region_title(), int(game.ship.position.distance_to(game.planet.entry_point()))]
		hint="Подойдите до 35 м, скорость до 25 м/с · затем «СПУСК»"
	else:
		label="%s · ВЫСОТА %d м · %s" % [game.planet.region_title(),int(game.planet.altitude()),stage]
		if stage=="НА ПОВЕРХНОСТИ":hint="Посадка выполнена · нажмите «ВЗЛЁТ» для продолжения"
		elif stage in ["ПОСАДКА","ВЗЛЁТ"]:hint="Посадочная автоматика · управление временно передано"
		else:hint="Посадка: до 25 м, до 8 м/с · орбита: от 100 м"
	text_at(r.position+Vector2(18,27),label,16,Color("64e3ff"))
	text_at(r.position+Vector2(18,53),hint,15)

	if stage in ["ПОВЕРХНОСТЬ", "НА ПОВЕРХНОСТИ"]:
		_draw_mining_status(portrait)

func _draw_mining_status(portrait: bool) -> void:
	var m = game.planet.mine()
	var r := Rect2(24,454,672,64) if portrait else Rect2(310,190,630,61)
	draw_style_box(game.flight_ui.style(Color(.025,.07,.11,.92),Color("285366")),r)
	var title := "СИГНАЛ РУДЫ · %d м" % roundi(game.planet.mining_distance(game.planet.signal_point()))
	var detail := "Сканирование · до 150 м, высота до 100 м, скорость до 20 м/с"
	if m.surveyed:
		title = "%s · ЗАПАС %d ЕД. · НИЗКИЙ РИСК" % [game.planet.site_title(), m.reserve]
		detail = "Сядьте у маркера · доступ к комплексу в пределах 40 м"
	if m.installed:
		title = "%s · СКЛАД %d/%d · ЗАПАС %d ЕД." % [game.planet.site_title(), m.stock, m.CAPACITY, m.reserve]
		detail = "%s · отсек %d/%d" % [m.production_status(), game.cargo_used(), game.Trade.CAPACITY]
	text_at(r.position + Vector2(18,24), title, 16, Color("ffc46a"))
	text_at(r.position + Vector2(18,48), detail, 15)
