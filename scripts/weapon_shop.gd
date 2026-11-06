extends Control

const Sector = preload("res://scripts/sector_data.gd")
const CYAN := Color("64e3ff")
const DIM := Color("86a8bc")
var game: Node3D
var panel: PanelContainer
var title: Label
var summary: Label
var mounts: Label
var note: Label
var scroll: ScrollContainer
var cards_box: VBoxContainer
var close_button: Button
var cards: Dictionary = {}
var remove_buttons: Array[Button] = []
var refill_buttons: Dictionary = {}

func _label(value: String, font_size := 16, color := Color("e9f5fc")) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	return item

func _action(parent: Control, title_text: String, action: String, item: String, slot := -1) -> Button:
	var button := Button.new()
	button.text = title_text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.flight_ui.decorate(button)
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(func():
		game.weapon_transaction(action,item,slot)
		refresh())
	parent.add_child(button)
	return button

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",game.flight_ui.style(Color("0c1b2b"),CYAN))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	title = _label("АРСЕНАЛ",23,CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size = Vector2(132,48)
	game.flight_ui.decorate(close_button)
	close_button.add_theme_font_size_override("font_size",14)
	close_button.pressed.connect(game.toggle_weapon_shop)
	heading.add_child(close_button)
	summary = _label("",16,Color("ffc46a"))
	box.add_child(summary)
	mounts = _label("",14)
	box.add_child(mounts)
	var removes := HBoxContainer.new()
	removes.add_theme_constant_override("separation",8)
	box.add_child(removes)
	for slot in range(3):
		remove_buttons.append(_action(removes,["СНЯТЬ ЛЕВ.","СНЯТЬ ПРАВ.","СНЯТЬ ПУСК."][slot],"remove","",slot))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation",12)
	scroll.add_child(cards_box)
	for id in ["laser","cannon","plasma","launcher"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",game.flight_ui.button_style(Color("102534"),Color("285366")))
		cards_box.add_child(card)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation",6)
		card.add_child(lines)
		var heading_label := _label("",19,CYAN)
		lines.add_child(heading_label)
		var description := _label("",14,DIM)
		lines.add_child(description)
		var stats := _label("",14)
		lines.add_child(stats)
		var comparison := _label("",13,DIM)
		lines.add_child(comparison)
		var trading := HBoxContainer.new()
		trading.add_theme_constant_override("separation",8)
		lines.add_child(trading)
		var buy := _action(trading,"КУПИТЬ","buy",id)
		var sell := _action(trading,"ПРОДАТЬ","sell",id)
		var fitting := HBoxContainer.new()
		fitting.add_theme_constant_override("separation",8)
		lines.add_child(fitting)
		var left := _action(fitting,"УСТАНОВИТЬ В ПУСКОВУЮ" if id == "launcher" else "В ЛЕВЫЙ СЛОТ","equip",id,2 if id == "launcher" else 0)
		var right: Button
		if id != "launcher":
			right = _action(fitting,"В ПРАВЫЙ СЛОТ","equip",id,1)
		cards[id] = {"heading":heading_label,"description":description,"stats":stats,"comparison":comparison,"buy":buy,"sell":sell,"left":left,"right":right}
	var ammo_actions := HBoxContainer.new()
	ammo_actions.add_theme_constant_override("separation",8)
	box.add_child(ammo_actions)
	refill_buttons.ammo = _action(ammo_actions,"СНАРЯДЫ +60","refill","ammo")
	refill_buttons.rockets = _action(ammo_actions,"РАКЕТЫ +4","refill","rockets")
	note = _label("",14,DIM)
	note.custom_minimum_size.y = 38
	box.add_child(note)
	visible = false

func _mount_name(id: String) -> String:
	return "ПУСТО" if id.is_empty() else str(game.armament.CATALOG[id].name)

func _comparison(item: Dictionary, slot: int) -> String:
	var current: String = game.armament.loadout[slot]
	if current.is_empty():
		return "%s: пусто → %s" % ["Л" if slot == 0 else "П",item.name]
	var equipped: Dictionary = game.armament.CATALOG[current]
	return "%s: %s · Δ урон %+d / мощн. %+d / дальн. %+d / интервал %+.2f с" % ["Л" if slot == 0 else "П",equipped.name,int(item.damage)-int(equipped.damage),int(item.power)-int(equipped.power),int(item.range)-int(equipped.range),float(item.cooldown)-float(equipped.cooldown)]

func refresh() -> void:
	if game == null:
		return
	var a = game.armament
	var station: int = game.station_id
	title.text = "АРСЕНАЛ · «%s»" % Sector.title(station)
	summary.text = "%d кр. · Мощность %d / 70 · Снаряды %d/300 · Ракеты %d/12" % [game.credits,a.power_used(),a.ammo,a.rockets]
	mounts.text = "Л: %s · П: %s\nПусковая: %s · Склад оборудования: «%s»" % [_mount_name(a.loadout[0]),_mount_name(a.loadout[1]),_mount_name(a.launcher),Sector.title(station)]
	for slot in range(3):
		remove_buttons[slot].disabled = not game.can_weapon_transaction("remove","",slot)
	for id in cards:
		var row: Dictionary = cards[id]
		var item: Dictionary = a.CATALOG[id]
		row.heading.text = "%s · На складе: %d" % [item.name,int(a.warehouses[station].get(id,0))]
		row.description.text = item.description
		row.stats.text = "Урон %d · Мощность %d · Дальность %d м · Интервал %.2f с\nЭнергия %.0f · Нагрев %.0f · Совместимость: %s" % [item.damage,item.power,item.range,item.cooldown,item.energy,item.heat,"пусковая Скифа" if id == "launcher" else "левый / правый слот Скифа"]
		row.comparison.text = ("Пусковая: %s" % _mount_name(a.launcher)) if id == "launcher" else _comparison(item,0)+"\n"+_comparison(item,1)
		row.buy.text = "КУПИТЬ · %d кр." % a.price(id,station,true)
		row.sell.text = "ПРОДАТЬ · %d кр." % a.price(id,station,false)
		row.buy.disabled = not game.can_weapon_transaction("buy",id)
		row.sell.disabled = not game.can_weapon_transaction("sell",id)
		row.left.disabled = not game.can_weapon_transaction("equip",id,2 if id == "launcher" else 0)
		if row.right != null:
			row.right.disabled = not game.can_weapon_transaction("equip",id,1)
	for id in refill_buttons:
		var quantity := mini(60,300-a.ammo) if id == "ammo" else mini(4,12-a.rockets)
		refill_buttons[id].text = "%s +%d · %d кр." % ["БК" if id == "ammo" else "РАКЕТЫ",quantity,a.refill_cost(id,station)]
		refill_buttons[id].disabled = not game.can_weapon_transaction("refill",id)
	note.text = game.weapon_note if not game.weapon_note.is_empty() else "Покупка → склад этой станции → установка. Снятие возвращает модуль на этот склад. Оборудование не занимает грузовой отсек."
	note.add_theme_color_override("font_color",Color("ff7979") if not game.save_error.is_empty() else DIM)

func _process(_delta: float) -> void:
	if game == null or not visible:
		return
	size = game.flight_ui.design_size
	var safe: Rect2 = game.flight_ui.safe_bounds
	panel.position = Vector2(maxf(safe.position.x,(size.x-940)*.5),safe.position.y)
	panel.size = Vector2(minf(940,safe.size.x),safe.size.y)
	refresh()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.015,.03,.98))
