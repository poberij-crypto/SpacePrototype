extends Control
const Trade = preload("res://scripts/trade_data.gd")
const Sector = preload("res://scripts/sector_data.gd")
var game: Node3D
var panel: PanelContainer
var title: Label
var balance: Label
var capacity: Label
var note: Label
var route: Button
var close_button: Button
var goods: Dictionary = {}

func label(text: String, font_size: int, color := Color("e9f5fc")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	return item

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",game.flight_ui.style(Color("0c1b2b"),Color("64e3ff")))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	title = label("ТОРГОВЫЙ ТЕРМИНАЛ",24,Color("64e3ff"))
	box.add_child(title)
	balance = label("",18)
	box.add_child(balance)
	capacity = label("",17,Color("ffc46a"))
	box.add_child(capacity)
	for good in Trade.GOODS:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",3)
		box.add_child(card)
		var name_label := label("",18)
		card.add_child(name_label)
		var peer := label("",15,Color("86a8bc"))
		card.add_child(peer)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation",12)
		card.add_child(actions)
		var buy := Button.new()
		var sell := Button.new()
		for b in [buy,sell]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 44
			game.flight_ui.decorate(b)
			b.add_theme_font_size_override("font_size",17)
			actions.add_child(b)
		buy.pressed.connect(func():game.trade_goods(good,1,true))
		sell.pressed.connect(func():game.trade_goods(good,1,false))
		goods[good] = {"name":name_label,"peer":peer,"buy":buy,"sell":sell}
	note = label("",16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 42
	box.add_child(note)
	route = Button.new()
	route.custom_minimum_size.y = 48
	game.flight_ui.decorate(route,true)
	route.pressed.connect(game.start_trade_flight)
	box.add_child(route)
	close_button = Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size.y = 44
	game.flight_ui.decorate(close_button)
	close_button.pressed.connect(game._toggle_market)
	box.add_child(close_button)
	visible = false

func _process(_delta: float) -> void:
	if game==null or not visible:return
	var portrait: bool = game.flight_ui.portrait
	panel.custom_minimum_size.x = 656 if portrait else 800
	panel.reset_size()
	panel.position = (size-panel.size)*.5
	var station: bool = game.can_trade()
	title.text = "РЫНОК · «%s»" % Sector.title(game.station_id) if station else "ГРУЗОВОЙ ОТСЕК"
	balance.text = "Баланс: %d кр. · %s" % [game.credits,"Торговля доступна" if station else "Торговля после стыковки"]
	capacity.text = "Груз: %d / %d ед. · Контейнер: %d ед." % [game.cargo_used(),Trade.CAPACITY,game.cargo_used()-Trade.used(game.cargo)]
	for good in Trade.GOODS:
		var row: Dictionary = goods[good]
		row["name"].text = "%s · В отсеке: %d" % [Trade.NAMES[good],game.cargo[good]]
		row.peer.text = "На «%s»: купить %d / продать %d кр." % [Sector.title(1-game.station_id),Trade.price(good,1-game.station_id,true),Trade.price(good,1-game.station_id,false)] if station else "«Полигон»: %d/%d · «Вектор»: %d/%d кр. (купить/продать)" % [Trade.price(good,0,true),Trade.price(good,0,false),Trade.price(good,1,true),Trade.price(good,1,false)]
		row.buy.text = "КУПИТЬ 1 · %d кр." % Trade.price(good,game.station_id,true)
		row.sell.text = "ПРОДАТЬ 1 · %d кр." % Trade.price(good,game.station_id,false)
		row.buy.disabled = not game.can_trade_goods(good,1,true)
		row.sell.disabled = not game.can_trade_goods(good,1,false)
	note.text = game.trade_note if not game.trade_note.is_empty() else ("Цены указаны за 1 ед. При потере корабля груз теряется." if station else "Полёт приостановлен. Торговать можно только после стыковки.")
	note.add_theme_color_override("font_color",Color("ff7979") if not game.save_error.is_empty() else Color("86a8bc"))
	route.text = "ПЕРЕЛЁТ → «%s» · БЕЗ КОНТРАКТА" % Sector.title(1-game.station_id)
	route.visible = station
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.015,.03,.97))
