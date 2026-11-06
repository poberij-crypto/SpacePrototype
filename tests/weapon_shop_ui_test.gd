extends SceneTree

const SAVE := "user://weapon_shop_ui_test.json"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SAVE+suffix)

func run() -> void:
	clean()
	var game = load("res://main.tscn").instantiate()
	game.store.path = SAVE
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.credits = 10000
	var ui = game.flight_ui
	var shop = game.weapon_shop
	ui.weapon_shop_button.pressed.emit()
	await process_frame
	check(shop.visible,"Station arsenal opens through its HUD button")
	check(not ui.mission_panel.visible,"Shop replaces station mission panel")
	var purchase: int = game.armament.price("cannon",game.station_id,true)
	var before: int = game.credits
	shop.cards.cannon.buy.pressed.emit()
	check(game.credits == before-purchase and game.armament.warehouses[game.station_id].cannon == 1,"Buy button pays for station-local stock")
	shop.cards.cannon.left.pressed.emit()
	check(game.armament.loadout[0] == "cannon" and game.armament.warehouses[game.station_id].cannon == 0,"Fit button installs bought cannon")
	check(game.armament.warehouses[game.station_id].laser >= 1,"Replacing an equipped laser returns it to station storage")
	shop.remove_buttons[0].pressed.emit()
	check(game.armament.loadout[0].is_empty() and game.armament.warehouses[game.station_id].cannon == 1,"Remove button returns cannon to this station")
	before = game.credits
	var sale: int = game.armament.price("cannon",game.station_id,false)
	shop.cards.cannon.sell.pressed.emit()
	check(game.credits == before+sale and game.armament.warehouses[game.station_id].cannon == 0,"Sell button sells a stored cannon")
	game.armament.ammo = 290
	shop.refresh()
	check(shop.refill_buttons.ammo.text.contains("+10"),"Refill quote uses remaining ammunition capacity")
	shop.refill_buttons.ammo.pressed.emit()
	check(game.armament.ammo == 300,"Ammo refill button respects capacity")
	shop.refresh()
	check(shop.refill_buttons.ammo.disabled,"Full ammunition disables refill")
	for dimensions in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(720,1280),Vector2i(1080,2400),Vector2i(884,1104)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		var panel_rect: Rect2 = shop.panel.get_rect()
		check(ui.safe_bounds.encloses(panel_rect),"Arsenal stays within safe area %s" % dimensions)
		check(shop.scroll.size.y >= 160,"Weapon list has usable scroll space %s" % dimensions)
		var needs_scroll: bool = shop.cards_box.size.y > shop.scroll.size.y
		for control in [shop.close_button,shop.refill_buttons.ammo,shop.refill_buttons.rockets,shop.remove_buttons[0],shop.remove_buttons[1],shop.remove_buttons[2]]:
			var local_rect := Rect2(shop.panel.get_global_transform().affine_inverse()*control.global_position,control.size)
			check(Rect2(Vector2.ZERO,shop.panel.size).encloses(local_rect),"Fixed shop controls stay visible %s" % dimensions)
		shop.scroll.scroll_vertical = 100000
		await process_frame
		check(shop.scroll.scroll_vertical > 0 or not needs_scroll,"Launcher equipment is reachable %s" % dimensions)
	shop.close_button.pressed.emit()
	await process_frame
	check(not shop.visible,"Close button returns to station")
	game.selected_mission = "combat"
	game.start_selected_mission()
	game.toggle_weapon_shop()
	check(not shop.visible,"Arsenal cannot open during flight")
	var group: int = game.armament.group
	ui.group_button.pressed.emit()
	check(game.armament.group != group,"Flight group button cycles selected weapon mounts")
	game.queue_free()
	await process_frame
	clean()
	print("Weapon shop UI tests: %d failures" % failures)
	quit(1 if failures else 0)
