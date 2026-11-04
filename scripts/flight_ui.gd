extends Control

const Sector = preload("res://scripts/sector_data.gd")
var market_panel: Control
var market_button: Button
var map_panel: Control
var map_button: Button
var delivery_choice: Button
const CYAN := Color("64e3ff")
const DIM := Color("6991a7")
const WHITE := Color("e9f5fc")
const AMBER := Color("ffc46a")
const RED := Color("ff7979")
var resume_button: Button
var repair_button: Button
var discard_button: Button
var mission_choices: HBoxContainer
var combat_choice: Button
var scout_choice: Button
var discard_dialog: ConfirmationDialog
var upgrade_buttons: Array[Button] = []
var previous_mission_stage := ""
var mission_panel: PanelContainer
var mission_title: Label
var mission_body: Label
var mission_button: Button
var dock_button: Button
var portrait := false
var design_size := Vector2(1280,720)
var previous_size := Vector2.ZERO
var controls: Dictionary = {}
var game: Node3D
var content: Control
var fire_button: Button
var stable_button: Button
var camera_button: Button
var help_label: Label
var upgrades_panel: PanelContainer
var upgrade_info: Label
var factor := 1.0
var origin := Vector2.ZERO

func setup(owner_game: Node3D) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	camera_button = button("КАМЕРА · СНАРУЖИ", Rect2(990, 24, 264, 48), game._toggle_camera)
	button("МОДУЛИ", Rect2(990, 84, 126, 48), game._toggle_upgrades)
	button("МЕНЮ", Rect2(1128, 84, 126, 48), game.save_to_menu)
	button("+", Rect2(960, 458, 92, 76), func(): game.throttle = minf(1.0, game.throttle + 0.2))
	button("−", Rect2(960, 548, 92, 76), func(): game.throttle = maxf(0.0, game.throttle - 0.2))
	fire_button = button("ОГОНЬ\nУДЕРЖИВАТЬ", Rect2(1080, 478, 174, 146), func(): pass, true)
	fire_button.button_down.connect(func(): game.firing = true)
	fire_button.button_up.connect(func(): game.firing = false)
	stable_button = button("СТАБИЛИЗАЦИЯ · ВКЛ", Rect2(920, 642, 334, 52), game._toggle_stabilization)
	help_label = Label.new()
	help_label.position = Vector2(390, 505)
	help_label.size = Vector2(500, 36)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 17)
	help_label.add_theme_color_override("font_color", CYAN)
	help_label.text = "Наведите нос корабля на оранжевую цель"
	content.add_child(help_label)
	upgrades_panel = PanelContainer.new()
	upgrades_panel.position = Vector2(420, 154)
	upgrades_panel.size = Vector2(440, 430)
	upgrades_panel.add_theme_stylebox_override("panel", style(Color("0c1b2b"), CYAN))
	content.add_child(upgrades_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	upgrades_panel.add_child(menu)
	upgrade_info = Label.new()
	upgrade_info.add_theme_color_override("font_color", WHITE)
	upgrade_info.add_theme_font_size_override("font_size", 21)
	menu.add_child(upgrade_info)
	for item in [["engine", "ДВИГАТЕЛЬ"], ["shield", "ЩИТ"], ["weapon", "ОРУЖИЕ"]]:
		var key: String = item[0]
		var b := Button.new()
		b.text = item[1] + "  +  /  100 кр."
		b.set_meta("kind",key)
		upgrade_buttons.append(b)
		b.custom_minimum_size = Vector2(400, 56)
		decorate(b)
		b.pressed.connect(func(): game._buy(key))
		menu.add_child(b)
	var close := Button.new()
	close.text = "ВЕРНУТЬСЯ В ПОЛЁТ"
	close.custom_minimum_size = Vector2(400, 56)
	decorate(close)
	close.pressed.connect(game._toggle_upgrades)
	menu.add_child(close)
	upgrades_panel.visible = false
	_build_mission_panel()
	_build_sector_map()
	_build_market()
	_layout()

func style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

func decorate(b: Button, primary := false) -> void:
	b.add_theme_stylebox_override("normal", style(Color("163845") if primary else Color(0.025, 0.07, 0.11, 0.92), CYAN if primary else Color("285366")))
	b.add_theme_stylebox_override("pressed", style(Color("20677b"), CYAN))
	b.add_theme_stylebox_override("hover", style(Color("17394b"), CYAN))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE

func button(text: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	decorate(b, primary)
	b.pressed.connect(action)
	content.add_child(b)
	controls[text] = b
	return b

func _layout() -> void:
	portrait = size.y > size.x
	design_size = Vector2(720,1280) if portrait else Vector2(1280,720)
	if size != previous_size:
		game.clear_held_input()
		previous_size = size
	factor = maxf(.1,minf(size.x/design_size.x,size.y/design_size.y))
	origin = (size-design_size*factor)*.5
	content.scale = Vector2.ONE*factor
	content.position = origin
	var rects: Array = [Rect2(990,24,264,48),Rect2(990,84,126,48),Rect2(1128,84,126,48),Rect2(960,458,92,76),Rect2(960,548,92,76),Rect2(1080,478,174,146),Rect2(920,642,334,52)]
	if portrait:
		rects = [Rect2(360,24,336,48),Rect2(344,178,166,48),Rect2(530,178,166,48),Rect2(360,1020,110,76),Rect2(360,1110,110,76),Rect2(500,1040,196,144),Rect2(288,1208,408,52)]
	var buttons := [camera_button,controls["МОДУЛИ"],controls["МЕНЮ"],controls["+"],controls["−"],fire_button,stable_button]
	for i in range(buttons.size()):
		buttons[i].position = rects[i].position
		buttons[i].size = rects[i].size
	help_label.position = Vector2(24,962) if portrait else Vector2(390,505)
	help_label.size.x = 672 if portrait else 500
	upgrades_panel.position = Vector2(140,380) if portrait else Vector2(420,154)
	mission_panel.position = Vector2((design_size.x-480)*.5,maxf(105,(design_size.y-mission_panel.size.y)*.5))
	dock_button.position = Vector2(230,730) if portrait else Vector2(510,445)
	market_panel.size = design_size
	market_button.position = Vector2(194,238) if portrait else Vector2(990,144)
	market_button.size = Vector2(150,44) if portrait else Vector2(126,44)
	map_panel.size = design_size
	map_button.position = Vector2(24,238) if portrait else Vector2(1128,144)
	map_button.size = Vector2(150,44) if portrait else Vector2(126,44)

func steering_rect() -> Rect2:
	return Rect2(20,1000,270,260) if portrait else Rect2(20,420,260,280)

func to_design(point: Vector2) -> Vector2:
	return (point - origin) / factor

func from_design(point: Vector2) -> Vector2:
	return origin + point * factor

func _process(_delta: float) -> void:
	if game == null:
		return
	_layout()
	fire_button.text = "ОГОНЬ\nАКТИВЕН" if game.firing else "ОГОНЬ\nУДЕРЖИВАТЬ"
	camera_button.text = "КАМЕРА · КАБИНА" if game.cockpit else "КАМЕРА · СНАРУЖИ"
	stable_button.text = "СТАБИЛИЗАЦИЯ · ВКЛ" if game.stabilized else "СТАБИЛИЗАЦИЯ · ВЫКЛ"
	_update_mission_panel()
	queue_redraw()

func txt(p: Vector2, value: String, size_px := 18, color := WHITE) -> void:
	draw_string(get_theme_default_font(), p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func panel(rect: Rect2) -> void:
	draw_style_box(style(Color(0.02, 0.045, 0.075, 0.87), Color("244355")), rect)

func bar(p: Vector2, width: float, fraction: float, color: Color) -> void:
	draw_rect(Rect2(p, Vector2(width, 5)), Color("1d3444"))
	draw_rect(Rect2(p, Vector2(width * clampf(fraction, 0, 1), 5)), color)

func _draw() -> void:
	if game == null or content == null:
		return
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	if portrait:
		_draw_portrait()
		return
	panel(Rect2(24, 24, 260, 48))
	draw_circle(Vector2(44, 48), 4, CYAN)
	txt(Vector2(58, 55), "СКИФ / УЧЕБНЫЙ ПОЛЁТ", 17)
	panel(Rect2(24, 86, 260, 126))
	txt(Vector2(42, 113), "КОРПУС", 14, DIM)
	txt(Vector2(220, 113), "%d%%" % maxi(0, int(game.hull)), 16)
	bar(Vector2(42, 125), 224, game.hull / 100.0, CYAN if game.hull > 30 else RED)
	txt(Vector2(42, 159), "ЩИТ", 14, DIM)
	var max_shield: float = 100.0 + game.upgrades.shield * 25.0
	txt(Vector2(192, 159), "%d/%d" % [int(game.shield), int(max_shield)], 16)
	bar(Vector2(42, 172), 224, game.shield / max_shield, Color("8fa6ff"))
	txt(Vector2(42, 197), "СИСТЕМЫ · " + ("ОТКАЗ" if game.destroyed else "НОРМА"), 12, RED if game.destroyed else DIM)
	panel(Rect2(440, 24, 400, 70))
	txt(Vector2(460, 49), game.mission.objective(), 13, DIM)
	txt(Vector2(460, 77), "ЭТАП: " + game.mission.stage, 18)
	txt(Vector2(700, 77), "%05d кр." % game.credits, 17, AMBER)
	# Aim indicator follows the actual forward line of the ship.
	var camera: Camera3D = game.cockpit_camera if game.cockpit else game.external_camera
	var aim_world: Vector3 = game.ship.global_position - game.ship.global_basis.z * 100.0
	var aim := to_design(camera.unproject_position(aim_world))
	draw_arc(aim, 20, 0.3, 1.25, 12, CYAN, 1.5, true)
	draw_arc(aim, 20, 1.88, 2.84, 12, CYAN, 1.5, true)
	draw_arc(aim, 20, 3.45, 4.40, 12, CYAN, 1.5, true)
	draw_arc(aim, 20, 5.02, 5.97, 12, CYAN, 1.5, true)
	draw_circle(aim, 2, CYAN)
	_targets(camera)
	_draw_navigation(camera)
	# Joystick and instructions.
	var center := Vector2(154, 564)
	draw_circle(center, 87, Color(0.03, 0.10, 0.15, 0.8))
	draw_arc(center, 87, 0, TAU, 80, Color("3c6a80"), 1.5, true)
	draw_arc(center, 56, 0, TAU, 64, Color("234251"), 1.0, true)
	draw_line(center - Vector2(100, 0), center + Vector2(100, 0), Color("234251"))
	draw_line(center - Vector2(0, 100), center + Vector2(0, 100), Color("234251"))
	draw_circle(center + game.turn_input * 55, 30, Color(0.2, 0.65, 0.8, 0.55))
	txt(Vector2(91, 688), "ПОВОРОТ КОРАБЛЯ", 13, DIM)
	panel(Rect2(448, 570, 412, 124))
	txt(Vector2(468, 597), "СКОРОСТЬ", 13, DIM)
	txt(Vector2(468, 647), "%03d" % int(game.velocity.length()), 43)
	txt(Vector2(556, 648), "м/с", 16, DIM)
	txt(Vector2(650, 597), "ТЯГА  %d%%" % int(game.throttle * 100), 16, CYAN)
	bar(Vector2(650, 624), 186, game.throttle, CYAN)
	txt(Vector2(468, 677), "СТАБИЛИЗИРОВАННЫЙ ПОЛЁТ" if game.stabilized else "ИНЕРЦИЯ · ДВИЖЕНИЕ СОХРАНЯЕТСЯ", 13, DIM if game.stabilized else AMBER)
	txt(Vector2(966, 440), "ТЯГА", 14, DIM)
	_radar()
	if game.destroyed:
		panel(Rect2(388, 290, 504, 110))
		txt(Vector2(460, 334), "КОРАБЛЬ ПОТЕРЯН", 28, RED)
		txt(Vector2(437, 370), "Откройте «МЕНЮ» для новой попытки", 18)

func _targets(camera: Camera3D) -> void:
	if game.mission.stage != "БОЙ":return
	var selected: Node3D = null
	var best := -1.0
	for target in game.enemies:
		if not is_instance_valid(target) or not target.visible or camera.is_position_behind(target.global_position):
			continue
		var p := to_design(camera.unproject_position(target.global_position))
		if not (Rect2(30,326,660,470) if portrait else Rect2(304,118,636,360)).has_point(p):
			continue
		var col := RED if target.get_meta("hostile") else AMBER
		for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
			var c: Vector2 = p + corner * 19
			draw_line(c, c - Vector2(corner.x * 9, 0), col, 1.5, true)
			draw_line(c, c - Vector2(0, corner.y * 9), col, 1.5, true)
		var delta: Vector3 = target.global_position - game.ship.global_position
		var alignment: float = (-game.ship.global_basis.z).dot(delta.normalized())
		if alignment > best:
			best = alignment
			selected = target
	if selected != null:
		var distance: int = int(game.ship.global_position.distance_to(selected.global_position))
		var hostile: bool = selected.get_meta("hostile")
		var col := RED if hostile else AMBER
		var shift := Vector2(-280,132) if portrait else Vector2.ZERO
		panel(Rect2(Vector2(480,112)+shift,Vector2(320,70)))
		txt(Vector2(498, 138)+shift, ("ПРОТИВНИК" if hostile else "МИШЕНЬ") + "  /  %d м" % distance, 17, col)
		var max_hp := 90.0 if hostile else 40.0
		bar(Vector2(498, 151)+shift, 284, float(selected.get_meta("health")) / max_hp, col)
		txt(Vector2(498, 171)+shift, str(selected.get_meta("tactic", "В РАДИУСЕ ОГНЯ")) if distance <= 160 else "ВНЕ ДАЛЬНОСТИ ОРУЖИЯ", 11, DIM)

func _radar() -> void:
	var c := Vector2(120,880) if portrait else Vector2(350,627)
	draw_circle(c, 61, Color(0.02, 0.07, 0.11, 0.9))
	for radius in [30, 60]:
		draw_arc(c, radius, 0, TAU, 64, Color("244355"), 1.0, true)
	draw_line(c - Vector2(60,0), c + Vector2(60,0), Color("244355"))
	draw_line(c - Vector2(0,60), c + Vector2(0,60), Color("244355"))
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-6), c+Vector2(-4,5), c+Vector2(4,5)]), CYAN)
	for target in game.enemies:
		if not is_instance_valid(target) or not target.visible:
			continue
		var relative: Vector3 = game.ship.global_basis.inverse() * (target.global_position - game.ship.global_position)
		var point := Vector2(relative.x, relative.z) * 0.35
		point = point.limit_length(56)
		draw_circle(c + point, 3, RED if target.get_meta("hostile") else AMBER)
	txt(Vector2(80,803) if portrait else Vector2(310,550), "РАДАР · 160 м", 12, DIM)

func _draw_portrait() -> void:
	panel(Rect2(24,24,300,48))
	txt(Vector2(42,55),"СКИФ / ПОЛЁТ",17)
	panel(Rect2(24,96,300,126))
	txt(Vector2(42,123),"КОРПУС  %d%%" % maxi(0,int(game.hull)),16)
	bar(Vector2(42,137),264,game.hull/100.0,CYAN)
	var max_shield: float = 100.0+game.upgrades.shield*25.0
	txt(Vector2(42,170),"ЩИТ  %d/%d" % [int(game.shield),int(max_shield)],16)
	bar(Vector2(42,184),264,game.shield/max_shield,Color("8fa6ff"))
	txt(Vector2(42,208),"СИСТЕМЫ · " + ("ОТКАЗ" if game.destroyed else "НОРМА"),12,DIM)
	panel(Rect2(344,96,352,70))
	txt(Vector2(362,122),game.mission.objective(),14)
	txt(Vector2(362,151),"КРЕДИТЫ: %d" % game.credits,16,AMBER)
	var camera: Camera3D = game.cockpit_camera if game.cockpit else game.external_camera
	var aim := to_design(camera.unproject_position(game.ship.global_position-game.ship.global_basis.z*100.0))
	draw_arc(aim,20,0,TAU,48,CYAN,1.5,true)
	draw_circle(aim,2,CYAN)
	_targets(camera)
	_draw_navigation(camera)
	var center := Vector2(145,1110)
	draw_circle(center,87,Color(.03,.1,.15,.8))
	draw_arc(center,87,0,TAU,64,DIM,1.5,true)
	draw_arc(center,56,0,TAU,64,Color("234251"),1,true)
	draw_circle(center+game.turn_input*55,30,Color(.2,.65,.8,.55))
	txt(Vector2(74,1230),"ПОВОРОТ КОРАБЛЯ",13,DIM)
	_radar()
	panel(Rect2(280,824,416,124))
	txt(Vector2(298,850),"СКОРОСТЬ",13,DIM)
	txt(Vector2(298,900),"%03d" % int(game.velocity.length()),43)
	txt(Vector2(386,900),"м/с",16,DIM)
	txt(Vector2(486,850),"ТЯГА %d%%" % int(game.throttle*100),16,CYAN)
	bar(Vector2(486,878),192,game.throttle,CYAN)
	txt(Vector2(298,930),"СТАБИЛИЗАЦИЯ" if game.stabilized else "ИНЕРЦИОННЫЙ ПОЛЁТ",13,DIM)
	txt(Vector2(380,1002),"ТЯГА",14,DIM)
	if game.destroyed:
		panel(Rect2(70,480,580,100))
		txt(Vector2(205,521),"КОРАБЛЬ ПОТЕРЯН",24,RED)
		txt(Vector2(190,554),"Откройте «МЕНЮ»",18)

func _build_mission_panel() -> void:
	dock_button = button("СТЫКОВКА",Rect2(510,445,260,56),game.mission.dock,true)
	dock_button.visible = false
	mission_panel = PanelContainer.new()
	mission_panel.size = Vector2(480,290)
	mission_panel.add_theme_stylebox_override("panel",style(Color("0c1b2b"),CYAN))
	content.add_child(mission_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	mission_panel.add_child(box)
	mission_title = Label.new()
	mission_title.add_theme_font_size_override("font_size",24)
	mission_title.add_theme_color_override("font_color",CYAN)
	box.add_child(mission_title)
	mission_body = Label.new()
	mission_body.custom_minimum_size = Vector2(430,100)
	mission_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_body.add_theme_font_size_override("font_size",18)
	box.add_child(mission_body)
	mission_button = Button.new()
	mission_button.custom_minimum_size = Vector2(430,60)
	decorate(mission_button,true)
	mission_button.pressed.connect(func():
		if game.mission.stage == "ПРОВАЛ":game.save_to_menu()
		else:game.start_selected_mission())
	mission_choices = HBoxContainer.new()
	mission_choices.add_theme_constant_override("separation",8)
	box.add_child(mission_choices)
	combat_choice = Button.new()
	combat_choice.text = "БОЙ"
	combat_choice.custom_minimum_size = Vector2(138,44)
	decorate(combat_choice)
	combat_choice.pressed.connect(func():game.choose_mission("combat"))
	mission_choices.add_child(combat_choice)
	scout_choice = Button.new()
	scout_choice.text = "РАЗВЕДКА"
	scout_choice.custom_minimum_size = Vector2(138,44)
	decorate(scout_choice)
	scout_choice.pressed.connect(func():game.choose_mission("scout"))
	mission_choices.add_child(scout_choice)
	delivery_choice = Button.new()
	delivery_choice.text = "ДОСТАВКА"
	delivery_choice.custom_minimum_size = Vector2(138,44)
	decorate(delivery_choice)
	delivery_choice.pressed.connect(func():game.choose_mission("delivery"))
	mission_choices.add_child(delivery_choice)
	box.add_child(mission_button)
	resume_button = Button.new()
	resume_button.text = "ПРОДОЛЖИТЬ ВЫЛЕТ"
	resume_button.custom_minimum_size = Vector2(430,56)
	decorate(resume_button,true)
	resume_button.pressed.connect(game.resume_flight)
	box.add_child(resume_button)
	repair_button = Button.new()
	repair_button.custom_minimum_size = Vector2(430,48)
	decorate(repair_button)
	repair_button.pressed.connect(game.repair_at_station)
	box.add_child(repair_button)
	discard_button = Button.new()
	discard_button.text = "ОТМЕНИТЬ СОХРАНЁННЫЙ ВЫЛЕТ"
	discard_button.custom_minimum_size = Vector2(430,46)
	decorate(discard_button)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.dialog_text = "Отменить текущий вылет? Награда за миссию не будет начислена."
	discard_dialog.title = "Отмена вылета"
	discard_dialog.ok_button_text = "Отменить вылет"
	discard_dialog.cancel_button_text = "Вернуться"
	add_child(discard_dialog)
	discard_dialog.confirmed.connect(game.discard_flight)
	discard_button.pressed.connect(func():discard_dialog.popup_centered(Vector2i(460,160)))
	box.add_child(discard_button)

func _update_mission_panel() -> void:
	var m = game.mission
	var locked: bool = m.flight_locked()
	var pending: bool = not game.pending_snapshot.is_empty()
	var station: bool = game.at_station()
	mission_panel.visible = locked and not upgrades_panel.visible and not market_panel.visible
	fire_button.disabled = locked
	controls["+"].disabled = locked
	controls["−"].disabled = locked
	dock_button.visible = m.stage in ["ВОЗВРАЩЕНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"] and not upgrades_panel.visible and not market_panel.visible
	dock_button.disabled = not m.can_dock()
	mission_choices.visible = station and not pending
	mission_button.disabled = station and game.selected_mission=="delivery" and game.cargo_used()+game.Trade.CONTRACT_SIZE>game.Trade.CAPACITY
	mission_button.visible = not pending
	resume_button.visible = station and pending
	discard_button.visible = station and pending
	repair_button.visible = station and not pending
	var cost: int = game.repair_cost()
	repair_button.text = "КОРПУС ИСПРАВЕН" if cost==0 else "РЕМОНТ КОРПУСА · %d кр." % cost
	repair_button.disabled = cost==0 or game.credits<cost
	combat_choice.disabled = game.selected_mission == "combat"
	scout_choice.disabled = game.selected_mission == "scout"
	delivery_choice.disabled = game.selected_mission == "delivery"
	for b in upgrade_buttons:
		b.disabled = not station or pending or game.credits<100 or game.upgrades[b.get_meta("kind")]>=3
	if pending:
		mission_title.text = "ВЫЛЕТ СОХРАНЁН"
		mission_body.text = "Продолжите полёт с последнего сохранения.\nЭтап: %s\nБаланс: %d кредитов.\nНовое задание и услуги доступны после\nвозвращения или отмены вылета." % [str(game.pending_snapshot.get("stage","неизвестен")),game.credits]
	elif station:
		mission_title.text = "МИССИЯ ВЫПОЛНЕНА" if m.stage=="ЗАВЕРШЕНО" else "СТАНЦИЯ «%s»" % Sector.title(game.station_id)
		var task := "Учебный бой: уничтожить противника.\nНаграда: 300 кр. + боевая награда."
		if game.selected_mission=="scout":task = "Разведка: сканировать маяк 3 секунды.\nДо 35 м, скорость до 8 м/с. Награда: 150 кр."
		if game.selected_mission=="delivery":task = "Контейнер оборудования → «%s».\nНаграда: 220 кр. Нужны 2 свободные ед." % Sector.title(1-game.station_id)
		if game.selected_mission=="trade":task = "Свободный перелёт → «%s».\nТовары продаются вручную через «ГРУЗ»." % Sector.title(1-game.station_id)
		mission_body.text = "Баланс: %d кр. · Корпус: %d%%\nСтанция «%s» · Вылетов: %d\n%s" % [game.credits,int(game.hull),Sector.title(game.station_id),game.training_runs,task]
		if mission_button.disabled:mission_body.text += "\nОсвободите 2 ед. отсека через «ГРУЗ»."
		mission_button.text = "НАЧАТЬ ВЫЛЕТ"
	else:
		mission_title.text = "ВЫЛЕТ ПРЕРВАН"
		mission_body.text = "Корабль и груз потеряны. Награды нет.\nНовая попытка начнётся на станции\nс восстановленным учебным кораблём."
		mission_button.text = "НА СТАНЦИЮ"
	if not game.profile_note.is_empty():mission_body.text += "\n"+game.profile_note
	mission_panel.reset_size()
	if m.stage in ["ВЫЛЕТ","ВОЗВРАЩЕНИЕ","СКАНИРОВАНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"]:help_label.text = m.hint()
	elif locked:help_label.text = ""
	elif m.stage == "БОЙ" and previous_mission_stage != m.stage:help_label.text = "Противник активен · держите его в прицеле"
	if not game.save_error.is_empty():help_label.text = game.save_error
	previous_mission_stage = m.stage

func _draw_navigation(camera: Camera3D) -> void:
	var m = game.mission
	if m.stage not in ["ВЫЛЕТ","ВОЗВРАЩЕНИЕ","СКАНИРОВАНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"]:return
	if m.can_dock():return
	var destination: Vector3 = m.nav_position()
	var delta: Vector3 = destination-camera.global_position
	var zone := Rect2(60,340,600,400) if portrait else Rect2(330,205,570,265)
	var p := to_design(camera.unproject_position(destination))
	var offscreen := camera.is_position_behind(destination) or not zone.has_point(p)
	if offscreen:
		var local: Vector3 = camera.global_basis.inverse()*delta
		var dir := Vector2(local.x,-local.y)
		if dir.length()<.01:dir = Vector2.RIGHT
		dir = dir.normalized()
		var half := zone.size*.5
		var travel := minf(half.x/maxf(absf(dir.x),.001),half.y/maxf(absf(dir.y),.001))
		p = zone.get_center()+dir*travel
		var tangent := Vector2(-dir.y,dir.x)
		draw_colored_polygon(PackedVector2Array([p+dir*16,p-dir*12+tangent*9,p-dir*12-tangent*9]),CYAN)
	else:
		draw_polyline(PackedVector2Array([p+Vector2(0,-16),p+Vector2(16,0),p+Vector2(0,16),p+Vector2(-16,0),p+Vector2(0,-16)]),CYAN,2,true)
	var label := Sector.title(m.destination if m.stage in ["ДОСТАВКА","ПЕРЕЛЁТ"] else m.origin) if m.stage in ["ВОЗВРАЩЕНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"] else "МАЯК"
	if camera.is_position_behind(destination):label += " ПОЗАДИ"
	var text_pos := Vector2(clampf(p.x-55,30,design_size.x-230),p.y+35)
	txt(text_pos,label+" %d м" % int(game.ship.position.distance_to(destination)),14,CYAN)

func _build_sector_map() -> void:
	map_button = button("КАРТА",Rect2(1128,144,126,44),game._toggle_map)
	map_panel = preload("res://scripts/sector_map.gd").new()
	content.add_child(map_panel)
	map_panel.setup(game)

func _build_market() -> void:
	market_button = button("ГРУЗ / РЫНОК",Rect2(990,144,126,44),game._toggle_market)
	market_button.add_theme_font_size_override("font_size",14)
	market_panel = preload("res://scripts/market_panel.gd").new()
	content.add_child(market_panel)
	market_panel.setup(game)
