extends Control

const Sector = preload("res://scripts/sector_data.gd")
const CYAN := Color("64e3ff")
const DIM := Color("86a8bc")
const BRIEF := {
	"delivery":"Доставьте груз (2 ед.) на другую станцию.",
	"scout":"Просканируйте маяк в указанном секторе и сдайте отчёт.",
	"combat":"Уничтожьте корабль в указанном секторе и сдайте отчёт.",
}

var game: Node3D
var panel: PanelContainer
var title: Label
var reputation: Label
var note: Label
var offers_button: Button
var journal_button: Button
var close_button: Button
var scroll: ScrollContainer
var cards: VBoxContainer
var confirmation: ConfirmationDialog
var journal := false
var cancel_id := 0
var grace_labels: Dictionary = {}
var displayed_at := -1

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", game.flight_ui.style(Color("0c1b2b"), CYAN))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	title = _label(heading, "", 23, CYAN)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	close_button = _button(heading, "ЗАКРЫТЬ", game.toggle_contract_board)
	close_button.size_flags_horizontal = SIZE_FILL
	close_button.custom_minimum_size.x = 132
	reputation = _label(box, "", 16, Color("ffc46a"))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	offers_button = _button(tabs, "ДОСТУПНЫЕ", _show_journal.bind(false))
	journal_button = _button(tabs, "ЖУРНАЛ", _show_journal.bind(true))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	cards = VBoxContainer.new()
	cards.size_flags_horizontal = SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 10)
	scroll.add_child(cards)
	note = _label(box, "", 14, DIM)
	note.custom_minimum_size.y = 32
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Отказ от контракта"
	confirmation.ok_button_text = "Отказаться"
	confirmation.cancel_button_text = "Оставить"
	confirmation.confirmed.connect(_cancel)
	add_child(confirmation)
	hide()

func _label(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func _button(parent: Control, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	game.flight_ui.decorate(button)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _show_journal(value: bool) -> void:
	journal = value
	scroll.scroll_vertical = 0
	refresh()

func _accept(key: String) -> void:
	if game.accept_contract(key) > 0:
		_show_journal(true)
	else:
		refresh()

func _launch(id: int) -> void:
	if not game.start_contract(id):
		refresh()

func _confirm_cancel(id: int) -> void:
	cancel_id = id
	_update_grace(int(Time.get_unix_time_from_system()))
	confirmation.popup_centered()

func _cancel() -> void:
	game.cancel_contract(cancel_id)
	cancel_id = 0
	refresh()

func refresh() -> void:
	var book = game.contracts
	title.text = "КОНТРАКТЫ · «%s»" % Sector.title(game.station_id)
	reputation.text = "%s %+d   ·   %s %+d" % [book.FACTIONS.guild, book.reputation.guild, book.FACTIONS.guard, book.reputation.guard]
	offers_button.disabled = not journal
	journal_button.disabled = journal
	journal_button.text = "ЖУРНАЛ · %d" % book.active.size()
	note.text = game.contract_note if not game.contract_note.is_empty() else "Оплата и репутация начисляются при сдаче на станции назначения."
	note.add_theme_color_override("font_color", DIM if game.save_error.is_empty() else Color("ff7979"))
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	grace_labels.clear()
	if journal:
		var ids := PackedInt32Array()
		for key in book.active:
			ids.append(int(key))
		ids.sort()
		ids.reverse()
		for id in ids:
			_card(book.order(id))
		if ids.is_empty():
			_label(cards, "Нет принятых контрактов.", 16, DIM)
	else:
		for key in book.OFFERS:
			_card(book.offer(key, game.station_id), key)
	_update_grace(int(Time.get_unix_time_from_system()))

func _card(order: Dictionary, key := "") -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", game.flight_ui.button_style(Color("102534"), Color("285366")))
	cards.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 5)
	card.add_child(lines)
	var heading: String = order.title if key != "" else "№%d · %s" % [order.id, order.title]
	_label(lines, heading, 19, CYAN)
	_label(lines, "%s · %s → %s" % [game.contracts.FACTIONS[order.faction], Sector.title(order.origin), Sector.title(order.destination)], 14, DIM)
	_label(lines, BRIEF[order.kind], 15, Color("e9f5fc"))
	if order.get("target_shield", 0.0) == 30.0:
		_label(lines, "Цель с усиленным щитом.", 14, DIM)
	_label(lines, "%d кр. · Репутация +%d" % [order.reward, order.trust], 15, Color("ffc46a"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	if key != "":
		var available: bool = game.contracts.can_accept(key, game.station_id)
		if not available:
			_label(lines, "Требуется репутация +%d" % order.required, 14, DIM)
		else:
			_label(lines, "Отказ без штрафа в первые 10 минут.", 14, DIM)
		lines.add_child(buttons)
		_button(buttons, "ПРИНЯТЬ", _accept.bind(key)).disabled = not available
		return
	grace_labels[order.id] = _label(lines, "", 14, DIM)
	var can_launch: bool = game.can_launch_contract(order.id)
	if not can_launch:
		var reason := "Вылет со станции «%s»." % Sector.title(order.origin) if order.origin != game.station_id else "Освободите 2 ед. в грузовом отсеке."
		_label(lines, reason, 14, DIM)
	lines.add_child(buttons)
	_button(buttons, "ВЫЛЕТ", _launch.bind(order.id)).disabled = not can_launch
	_button(buttons, "ОТКАЗ", _confirm_cancel.bind(order.id))

func _update_grace(now: int) -> void:
	displayed_at = now
	for id in grace_labels:
		var order: Dictionary = game.contracts.order(id)
		var remaining := clampi(int(order.accepted) + game.contracts.GRACE_SECONDS - now, 0, game.contracts.GRACE_SECONDS)
		grace_labels[id].text = "Отказ без штрафа ещё %d:%02d" % [floori(remaining / 60.0), remaining % 60] if remaining > 0 else "При отказе репутация −%d" % game.contracts.penalty(id, now)
	if cancel_id != 0:
		var order: Dictionary = game.contracts.order(cancel_id)
		if not order.is_empty():
			var loss: int = game.contracts.penalty(cancel_id, now)
			var effect: String = "Репутация сохранится." if loss == 0 else "%s · Репутация −%d." % [game.contracts.FACTIONS[order.faction], loss]
			confirmation.dialog_text = "Отказаться от контракта №%d?\n%s" % [cancel_id, effect]

func _process(_delta: float) -> void:
	if not visible:
		return
	size = game.flight_ui.design_size
	var safe: Rect2 = game.flight_ui.safe_bounds.grow(-2.0)
	panel.size = Vector2(minf(840, safe.size.x), safe.size.y)
	panel.position = Vector2(safe.get_center().x - panel.size.x * 0.5, safe.position.y)
	var now := int(Time.get_unix_time_from_system())
	if now != displayed_at:
		_update_grace(now)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(.005, .015, .03, .98))
