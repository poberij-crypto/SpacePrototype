extends Control

const Sector = preload("res://scripts/sector_data.gd")
var market_panel: Control
var market_button: Button
var planet_panel: Control
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
var contract_button: Button
var dock_button: Button
var portrait := false
var design_size := Vector2(1280,720)
var previous_size := Vector2.ZERO
var controls: Dictionary = {}
var game: Node3D
var content: Control
var group_button: Button
var missile_button: Button
var weapon_shop_button: Button
var fire_button: Button
var stable_button: Button
var camera_button: Button
var help_label: Label
var upgrades_panel: PanelContainer
var upgrade_info: Label
var factor := 1.0
var origin := Vector2.ZERO
# The full design surface follows the viewport; only touch target scale uses the baseline.
var safe_bounds := Rect2(24, 24, 1232, 672)

func setup(owner_game: Node3D) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	weapon_shop_button = button("АРСЕНАЛ", Rect2(990,264,126,48), game.toggle_weapon_shop)
	weapon_shop_button.add_theme_font_size_override("font_size", 14)
	group_button = button("ГРУППА · ОБА", Rect2(920,396,161,48), game.cycle_fire_group)
	group_button.add_theme_font_size_override("font_size", 13)
	missile_button = button("РАКЕТА", Rect2(1093,396,161,48), game.launch_missile, true)
	missile_button.add_theme_font_size_override("font_size", 13)
	camera_button = button("КАМЕРА · СНАРУЖИ", Rect2(990, 24, 264, 48), game._toggle_camera)
	button("МОДУЛИ", Rect2(990, 84, 126, 48), game._toggle_upgrades)
	button("МЕНЮ", Rect2(1128, 84, 126, 48), game.save_to_menu)
	button("+", Rect2(960, 458, 92, 76), func(): game.adjust_throttle(0.2))
	button("−", Rect2(960, 548, 92, 76), func(): game.adjust_throttle(-0.2))
	fire_button = button("ОГОНЬ\nУДЕРЖИВАТЬ", Rect2(1080, 478, 174, 146), func(): pass, true)
	fire_button.button_down.connect(func(): game.firing = true)
	fire_button.button_up.connect(func(): game.firing = false)
	stable_button = button("СТАБИЛИЗАЦИЯ · ВКЛ", Rect2(920, 642, 334, 52), game._toggle_stabilization)
	help_label = Label.new()
	help_label.position = Vector2(390, 505)
	help_label.size = Vector2(500, 36)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 15)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	for item in [["engine", "ДВИГАТЕЛЬ"], ["shield", "ЩИТ"], ["weapon", "УСИЛИТЕЛЬ ОРУЖИЯ"]]:
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
	planet_panel = preload("res://scripts/planet_ui.gd").new()
	content.add_child(planet_panel)
	planet_panel.setup(game)
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

func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var result := style(bg,border)
	result.content_margin_left = 12
	result.content_margin_right = 12
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result

func decorate(b: Button, primary := false) -> void:
	b.add_theme_stylebox_override("normal", button_style(Color("163845") if primary else Color(0.025, 0.07, 0.11, 0.92), CYAN if primary else Color("285366")))
	b.add_theme_stylebox_override("pressed", button_style(Color("20677b"), CYAN))
	b.add_theme_stylebox_override("hover", button_style(Color("17394b"), CYAN))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled",button_style(Color(.025,.07,.11,.80),Color("203847")))
	b.add_theme_color_override("font_disabled_color",Color("69818c"))
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
	var baseline := Vector2(720,1280) if portrait else Vector2(1280,720)
	if size != previous_size:
		game.clear_held_input()
		previous_size = size
	factor = maxf(.1,minf(size.x/baseline.x,size.y/baseline.y))
	design_size = size / factor
	safe_bounds = _safe_design_bounds()
	# Keep the complete corner layout usable when a display cutout consumes an edge.
	var safe_fit := minf(1.0,minf(safe_bounds.size.x/(baseline.x-48),safe_bounds.size.y/(baseline.y-48)))
	factor *= maxf(.1,safe_fit)
	design_size = size / factor
	origin = Vector2.ZERO
	content.scale = Vector2.ONE*factor
	content.position = origin
	content.size = design_size
	safe_bounds = _safe_design_bounds()
	var right := safe_bounds.end.x
	var bottom := safe_bounds.end.y
	var fire_width := 196.0 if portrait else 174.0
	var throttle_width := 110.0 if portrait else 92.0
	var stable_width := 408.0 if portrait else 334.0
	var throttle_x := right-(336 if portrait else 294)
	var rects: Array[Rect2] = [
		shortcut_rect(0),shortcut_rect(1),shortcut_rect(1),
		Rect2(throttle_x,bottom-236,throttle_width,76),
		Rect2(throttle_x,bottom-146,throttle_width,76),
		Rect2(right-fire_width,bottom-216,fire_width,144 if portrait else 146),
		Rect2(right-stable_width,bottom-52,stable_width,52),
	]
	var weapon_row := shortcut_rect(4)
	weapon_shop_button.position = weapon_row.position
	weapon_shop_button.size = Vector2((weapon_row.size.x-12)*.5,48)
	var combat_width := stable_width
	group_button.position = Vector2(right-combat_width,bottom-298)
	group_button.size = Vector2((combat_width-12)*.5,48)
	missile_button.position = group_button.position+Vector2(group_button.size.x+12,0)
	missile_button.size = group_button.size
	var row: Rect2 = shortcut_rect(1)
	rects[1] = Rect2(row.position,Vector2((row.size.x-12)*.5,48))
	rects[2] = Rect2(row.position+Vector2((row.size.x+12)*.5,0),Vector2((row.size.x-12)*.5,48))
	var buttons := [camera_button,controls["МОДУЛИ"],controls["МЕНЮ"],controls["+"],controls["−"],fire_button,stable_button]
	for i in range(buttons.size()):
		buttons[i].position = rects[i].position
		buttons[i].size = rects[i].size
	help_label.max_lines_visible = 1 if portrait else 2
	help_label.size = Vector2(minf(672 if portrait else 440, safe_bounds.size.x),24 if portrait else 36)
	help_label.position = Vector2((design_size.x-help_label.size.x)*.5,design_size.y*.5+(150 if portrait else 225))
	if not portrait:
		var left_clear := safe_bounds.position.x+400
		var right_clear := safe_bounds.end.x-310
		help_label.size.x = minf(help_label.size.x,right_clear-left_clear)
		help_label.position.x = clampf(help_label.position.x,left_clear,right_clear-help_label.size.x)
	upgrades_panel.position = (design_size-upgrades_panel.size)*.5
	mission_panel.position = Vector2((design_size.x-480)*.5,maxf(safe_bounds.position.y,(design_size.y-mission_panel.size.y)*.5))
	dock_button.position = context_position(90 if portrait else 85)
	market_panel.size = design_size
	map_panel.size = design_size
	row = shortcut_rect(2)
	market_button.position = row.position
	market_button.size = Vector2((row.size.x-12)*.5,44)
	map_button.position = row.position+Vector2((row.size.x+12)*.5,0)
	map_button.size = market_button.size

func _safe_design_bounds() -> Rect2:
	var insets := Vector4(24,24,24,24)
	if OS.get_name() == "Android":
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe.has_area():
			var ratio := design_size / screen
			insets.x = maxf(insets.x,safe.position.x*ratio.x)
			insets.y = maxf(insets.y,safe.position.y*ratio.y)
			insets.z = maxf(insets.z,(screen.x-safe.end.x)*ratio.x)
			insets.w = maxf(insets.w,(screen.y-safe.end.y)*ratio.y)
	return Rect2(Vector2(insets.x,insets.y),design_size-Vector2(insets.x+insets.z,insets.y+insets.w))

func shortcut_rect(row: int) -> Rect2:
	var width := 336.0 if portrait else 264.0
	return Rect2(safe_bounds.end.x-width,safe_bounds.position.y+row*60, width,48)

func context_position(y_offset: float) -> Vector2:
	return Vector2(design_size.x*.5-130,design_size.y*.5+y_offset)

func speed_rect() -> Rect2:
	return Rect2(safe_bounds.end-Vector2(416,432),Vector2(416,124)) if portrait else Rect2(safe_bounds.end-Vector2(334,380),Vector2(334,76))

func steering_rect() -> Rect2:
	return Rect2(Vector2(safe_bounds.position.x,safe_bounds.end.y-276),Vector2(260,276))

func planet_status_rect() -> Rect2:
	return Rect2(safe_bounds.position+Vector2(0,354 if portrait else 202),Vector2(300,86))

func mining_status_rect() -> Rect2:
	var r := planet_status_rect()
	r.position.y += 94
	return r

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
	group_button.text = "ГРУППА · " + game.armament.group_title()
	var armed: bool = game.armament.launcher == "launcher"
	missile_button.text = ("РАК%d · ЦЕЛЬ %d%%" % [game.armament.rockets, int(game.combat.lock_progress*100)]) if armed else "НЕТ ПУСКОВОЙ"
	missile_button.disabled = game.mission.flight_locked() or game.armament.rockets <= 0 or not armed or game.combat.lock_progress < 1.0 or game.armament.missile_cooldown > 0
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
	draw_set_transform((safe_bounds.position-Vector2(24,24))*factor,0,Vector2.ONE*factor)
	# Keep hull and systems together at the upper left.
	panel(Rect2(24, 24, 260, 48))
	draw_circle(Vector2(44, 48), 4, CYAN)
	txt(Vector2(58, 55), "СКИФ / %s" % (game.planet.generated.planet_name if game.planet.in_neighbor() else "АСТРА") if game.planet.on_surface() else ("СКИФ / %s" % game.planet.generated.system_name if game.planet.in_neighbor() else "СКИФ / УЧЕБНЫЙ ПОЛЁТ"), 17)
	panel(Rect2(24, 86, 260, 126))
	txt(Vector2(42, 113), "КОРПУС", 14, DIM)
	txt(Vector2(220, 113), "%d%%" % maxi(0, int(game.hull)), 16)
	bar(Vector2(42, 125), 224, game.hull / 100.0, CYAN if game.hull > 30 else RED)
	txt(Vector2(42, 159), "ЩИТ", 14, DIM)
	var max_shield: float = 100.0 + game.upgrades.shield * 25.0
	txt(Vector2(192, 159), "%d/%d" % [int(game.shield), int(max_shield)], 16)
	bar(Vector2(42, 172), 224, game.shield / max_shield, Color("8fa6ff"))
	txt(Vector2(42, 197), "СИСТЕМЫ · " + ("ОТКАЗ" if game.destroyed else "НОРМА"), 12, RED if game.destroyed else DIM)
	draw_set_transform(safe_bounds.position*factor,0,Vector2.ONE*factor)
	panel(Rect2(276,0,400,94))
	txt(Vector2(294,25), game.mission.objective(),13,DIM)
	var stage_title: String = "ОБРАТНЫЙ ПРЫЖОК" if game.mission.stage == game.planet.INBOUND else game.mission.stage
	txt(Vector2(294,53), "ЭТАП: " + stage_title,16)
	txt(Vector2(294,79), "%05d кр." % game.credits,17,AMBER)
	draw_set_transform(origin,0,Vector2.ONE*factor)
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
	var center := steering_rect().get_center()
	draw_circle(center, 87, Color(0.03, 0.10, 0.15, 0.8))
	draw_arc(center, 87, 0, TAU, 80, Color("3c6a80"), 1.5, true)
	draw_arc(center, 56, 0, TAU, 64, Color("234251"), 1.0, true)
	draw_line(center - Vector2(100, 0), center + Vector2(100, 0), Color("234251"))
	draw_line(center - Vector2(0, 100), center + Vector2(0, 100), Color("234251"))
	draw_circle(center + game.turn_input * 55, 30, Color(0.2, 0.65, 0.8, 0.55))
	txt(Vector2(center.x-63,safe_bounds.end.y-8), "ПОВОРОТ КОРАБЛЯ", 13, DIM)
	_draw_speed()
	_radar()
	if game.destroyed:
		panel(Rect2(design_size*.5-Vector2(252,70),Vector2(504,110)))
		txt(design_size*.5+Vector2(-180,-26), "КОРАБЛЬ ПОТЕРЯН", 28, RED)
		txt(design_size*.5+Vector2(-203,10), "Откройте «МЕНЮ» для новой попытки", 18)

func _targets(camera: Camera3D) -> void:
	if game.mission.stage != "БОЙ":return
	var selected: Node3D = null
	var best := -1.0
	for target in game.enemies:
		if not is_instance_valid(target) or not target.visible or camera.is_position_behind(target.global_position):
			continue
		var p := to_design(camera.unproject_position(target.global_position))
		if not (Rect2(Vector2(30,380)+(design_size-Vector2(720,1280))*.5,Vector2(660,400)) if portrait else Rect2(Vector2(304,130)+(design_size-Vector2(1280,720))*.5,Vector2(636,340))).has_point(p):
			continue
		var col := RED if target.get_meta("hostile") else AMBER
		if is_instance_valid(game.combat.lock_target) and target == game.combat.lock_target:
			draw_arc(p,27,-PI*.5,-PI*.5+TAU*game.combat.lock_progress,40,CYAN if game.combat.lock_progress>=1 else AMBER,2.5,true)
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
		var shift := (Vector2(-280,348)+(design_size-Vector2(720,1280))*.5) if portrait else Vector2(0,18)+(design_size-Vector2(1280,720))*.5
		panel(Rect2(Vector2(480,112)+shift,Vector2(320,70)))
		var target_shield := float(selected.get_meta("shield",0.0))
		txt(Vector2(498,138)+shift,("ПРОТИВНИК" if hostile else "МИШЕНЬ")+" · %d м · ЩИТ %d" % [distance,int(target_shield)],14,col)
		if hostile:
			bar(Vector2(498,143)+shift,284,target_shield/30.0,Color("8fa6ff"))
		var max_hp := 90.0 if hostile else 40.0
		bar(Vector2(498, 151)+shift, 284, float(selected.get_meta("health")) / max_hp, col)
		var selected_range := 0.0
		for slot in range(2):
			var weapon_id: String = game.armament.loadout[slot]
			if not weapon_id.is_empty() and game.armament.group in [0,slot+1]:
				selected_range = maxf(selected_range,float(game.armament.CATALOG[weapon_id].range))
		txt(Vector2(498,171)+shift,str(selected.get_meta("tactic","В РАДИУСЕ ОГНЯ")) if distance<=selected_range else "ВНЕ ДАЛЬНОСТИ ВЫБРАННОЙ ГРУППЫ",11,DIM)

func radar_center() -> Vector2:
	return Vector2(safe_bounds.position.x+96,safe_bounds.end.y-376) if portrait else Vector2(safe_bounds.position.x+326,safe_bounds.end.y-67)

func _radar() -> void:
	var c := radar_center()
	draw_circle(c, 61, Color(0.02, 0.07, 0.11, 0.9))
	for radius in [30, 60]:
		draw_arc(c, radius, 0, TAU, 64, Color("244355"), 1.0, true)
	draw_line(c - Vector2(60,0), c + Vector2(60,0), Color("244355"))
	draw_line(c - Vector2(0,60), c + Vector2(0,60), Color("244355"))
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-6), c+Vector2(-4,5), c+Vector2(4,5)]), CYAN)
	var radar_title := "РАДАР · 160 м"
	if game.planet.on_surface():
		var target_point := Vector3.ZERO
		radar_title = "ПЛОЩАДКА · 560 м"
		if game.planet.in_neighbor():
			target_point = game.planet.mining_target()
			if not game.planet.mine().surveyed:
				radar_title = "СИГНАЛ · 560 м"
		var relative: Vector3 = game.ship.global_basis.inverse() * (target_point - game.ship.global_position)
		draw_circle(c + Vector2(relative.x, relative.z).limit_length(560) * .1, 4, AMBER)
	for target in game.enemies:
		if not is_instance_valid(target) or not target.visible:
			continue
		var relative: Vector3 = game.ship.global_basis.inverse() * (target.global_position - game.ship.global_position)
		var point := Vector2(relative.x, relative.z) * 0.35
		point = point.limit_length(56)
		draw_circle(c + point, 3, RED if target.get_meta("hostile") else AMBER)
	txt(c+Vector2(-40,-77), radar_title, 12, DIM)

func _draw_portrait() -> void:
	draw_set_transform((safe_bounds.position-Vector2(24,24))*factor,0,Vector2.ONE*factor)
	panel(Rect2(24,24,300,48))
	txt(Vector2(42,55),"СКИФ / ПОЛЁТ",17)
	panel(Rect2(24,96,300,126))
	txt(Vector2(42,123),"КОРПУС  %d%%" % maxi(0,int(game.hull)),16)
	bar(Vector2(42,137),264,game.hull/100.0,CYAN)
	var max_shield: float = 100.0+game.upgrades.shield*25.0
	txt(Vector2(42,170),"ЩИТ  %d/%d" % [int(game.shield),int(max_shield)],16)
	bar(Vector2(42,184),264,game.shield/max_shield,Color("8fa6ff"))
	txt(Vector2(42,208),"СИСТЕМЫ · " + ("ОТКАЗ" if game.destroyed else "НОРМА"),12,DIM)
	panel(Rect2(24,238,300,126))
	txt(Vector2(42,264),game.mission.objective(),12)
	txt(Vector2(42,294),"ЭТАП: " + game.mission.stage,14,DIM)
	txt(Vector2(42,328),"КРЕДИТЫ: %d" % game.credits,16,AMBER)
	draw_set_transform(origin,0,Vector2.ONE*factor)
	var camera: Camera3D = game.cockpit_camera if game.cockpit else game.external_camera
	var aim := to_design(camera.unproject_position(game.ship.global_position-game.ship.global_basis.z*100.0))
	draw_arc(aim,20,0,TAU,48,CYAN,1.5,true)
	draw_circle(aim,2,CYAN)
	_targets(camera)
	_draw_navigation(camera)
	var center := steering_rect().get_center()
	draw_circle(center,87,Color(.03,.1,.15,.8))
	draw_arc(center,87,0,TAU,64,DIM,1.5,true)
	draw_arc(center,56,0,TAU,64,Color("234251"),1,true)
	draw_circle(center+game.turn_input*55,30,Color(.2,.65,.8,.55))
	txt(Vector2(center.x-71,safe_bounds.end.y-26),"ПОВОРОТ КОРАБЛЯ",13,DIM)
	_radar()
	_draw_speed()
	if game.destroyed:
		var p := design_size*.5-Vector2(290,160)
		panel(Rect2(p,Vector2(580,100)))
		txt(p+Vector2(135,41),"КОРАБЛЬ ПОТЕРЯН",24,RED)
		txt(p+Vector2(120,74),"Откройте «МЕНЮ»",18)

func _weapon_short(id: String) -> String:
	return {"laser":"ЛАЗ", "cannon":"АП", "plasma":"ПЛ", "":"—"}.get(id,"—")

func _draw_speed() -> void:
	var r := speed_rect()
	panel(r)
	var p := r.position
	if portrait:
		txt(p+Vector2(18,25),"СКОРОСТЬ",12,DIM)
		txt(p+Vector2(18,62),"%03d м/с" % int(game.velocity.length()),28)
	else:
		txt(p+Vector2(14,28),"%03d м/с" % int(game.velocity.length()),24)
	txt(p+Vector2(196,24),"ТЯГА %d%%" % int(game.throttle*100),14,CYAN)
	thrust_bar(p+Vector2(196,35),r.size.x-214)
	var status_y := 88.0 if portrait else 49.0
	txt(p+Vector2(14,status_y),"ЭН %d%% · БК %d · РАК %d" % [int(game.armament.energy),game.armament.ammo,game.armament.rockets],12,CYAN)
	txt(p+Vector2(14,status_y+18),"Л %s %d%% · П %s %d%%" % [_weapon_short(game.armament.loadout[0]),int(game.armament.heat[0]),_weapon_short(game.armament.loadout[1]),int(game.armament.heat[1])],12,AMBER if maxf(game.armament.heat[0],game.armament.heat[1])>=80 else DIM)

func _build_mission_panel() -> void:
	dock_button = button("СТЫКОВКА",Rect2(510,445,260,56),game.request_station_dock,true)
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
	contract_button = Button.new()
	contract_button.text = "КОНТРАКТЫ"
	contract_button.custom_minimum_size.y = 44
	decorate(contract_button)
	contract_button.pressed.connect(game.toggle_contract_board)
	box.add_child(contract_button)
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
	var shop_open: bool = (game.weapon_shop != null and game.weapon_shop.visible) or (game.contract_board != null and game.contract_board.visible)
	weapon_shop_button.visible = game.can_trade() and not map_panel.visible and not market_panel.visible and not upgrades_panel.visible and not shop_open
	market_button.visible = not map_panel.visible and not shop_open
	var m = game.mission
	var locked: bool = m.flight_locked()
	var pending: bool = not game.pending_snapshot.is_empty()
	var station: bool = game.at_station()
	mission_panel.visible = (station or m.stage=="ПРОВАЛ") and not upgrades_panel.visible and not market_panel.visible and not shop_open
	fire_button.disabled = locked or m.kind=="planet"
	fire_button.visible = m.kind!="planet" or station or m.stage=="ПРОВАЛ"
	group_button.visible = fire_button.visible and not shop_open
	missile_button.visible = fire_button.visible and not shop_open
	group_button.disabled = locked
	controls["+"].disabled = locked
	controls["−"].disabled = locked
	var contact: int = m.nearby_station()
	dock_button.visible = (contact >= 0 or m.stage in ["ВОЗВРАЩЕНИЕ","ДОСТАВКА","ПЕРЕЛЁТ"]) and not upgrades_panel.visible and not market_panel.visible and not map_panel.visible and not shop_open
	dock_button.disabled = not m.can_station_dock(contact)
	dock_button.add_theme_font_size_override("font_size", 14 if dock_button.disabled else 18)
	dock_button.text = "СТЫКОВКА" if contact < 0 else "СТЫКОВКА · %s" % Sector.title(contact)
	if contact >= 0 and dock_button.disabled:
		dock_button.text = "ПОДОЙДИТЕ ДО 40 м" if game.ship.position.distance_to(Sector.position(contact)) > Sector.DOCK_RADIUS else "СНИЗЬТЕ СКОРОСТЬ ДО 5 м/с"
	mission_choices.visible = station and not pending
	contract_button.visible = station and not pending
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
		mission_title.text = "ВЫЛЕТ ПРЕРВАН · СТАНЦИЯ" if m.interrupted else "МИССИЯ ВЫПОЛНЕНА" if m.stage=="ЗАВЕРШЕНО" else "СТАНЦИЯ «%s»" % Sector.title(game.station_id)
		var task := "Учебный бой: уничтожить противника.\nНаграда: 300 кр. + боевая награда."
		if game.selected_mission=="scout":task = "Разведка: сканировать маяк 3 секунды.\nДо 35 м, скорость до 8 м/с. Награда: 150 кр."
		if game.selected_mission=="delivery":task = "Контейнер оборудования → «%s».\nНаграда: 220 кр. Нужны 2 свободные ед." % Sector.title(1-game.station_id)
		if game.selected_mission=="planet":task = "Экспедиция на Астру: район Меридиан.\nРазведка, посадка и вывоз руды."
		if game.selected_mission=="trade":task = "Свободный перелёт → «%s».\nТовары продаются вручную через «ГРУЗ»." % Sector.title(1-game.station_id)
		mission_body.text = "Баланс: %d кр. · Корпус: %d%%\nСтанция «%s» · Вылетов: %d\n%s" % [game.credits,int(game.hull),Sector.title(game.station_id),game.training_runs,task]
		if m.contract_id > 0 and not game.contract_note.is_empty():mission_body.text += "\n" + game.contract_note
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
	var surface: bool = m.stage == "ПОВЕРХНОСТЬ" and game.planet.on_surface()
	if not surface and not game.has_orbital_target() and m.stage not in ["ВЫЛЕТ","ВОЗВРАЩЕНИЕ","СКАНИРОВАНИЕ","ДОСТАВКА","ПЕРЕЛЁТ","К ПЛАНЕТЕ",game.planet.OUTBOUND,game.planet.INBOUND]:return
	if m.can_dock():return
	var destination: Vector3 = game.planet.mining_target() if surface else game.flight_nav_position()
	var delta: Vector3 = destination-camera.global_position
	var zone := Rect2(60,550,600,140) if portrait else Rect2(330,205,570,265)
	if game.planet.active():
		zone = Rect2(60,590,600,60) if portrait else Rect2(400,400,500,20)
	zone.position += (design_size-(Vector2(720,1280) if portrait else Vector2(1280,720)))*.5
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
	var label: String = game.flight_nav_title()
	if surface:
		label = "ПЛОЩАДКА" if game.planet.mine().surveyed else "СИГНАЛ РУДЫ"
	if camera.is_position_behind(destination):label += " ПОЗАДИ"
	var label_y := p.y + 35
	if game.planet.active():
		label_y = p.y - 22
	var label_left := safe_bounds.position.x+320 if game.planet.active() and not portrait else 30.0
	var text_pos := Vector2(clampf(p.x-55,label_left,design_size.x-230),label_y)
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

func thrust_bar(p: Vector2, width: float) -> void:
	var zero := width*.3/1.3
	draw_rect(Rect2(p,Vector2(width,5)),Color("1d3444"))
	var endpoint: float = (game.throttle+.3)/1.3*width
	draw_rect(Rect2(p+Vector2(minf(zero,endpoint),0),Vector2(absf(endpoint-zero),5)),AMBER if game.throttle<0 else CYAN)
	draw_line(p+Vector2(zero,-4),p+Vector2(zero,9),WHITE,1)
