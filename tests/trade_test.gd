extends SceneTree
var failures := 0
const PATH := "user://trade_isolated.json"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func fresh():
	var g = load("res://main.tscn").instantiate()
	g.store.path = PATH
	root.add_child(g)
	g.set_physics_process(false)
	return g
func clean() -> void:
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(PATH+suffix)
func fly(g) -> void:
	for i in range(4000):
		var goal: Vector3 = g.mission.nav_position()
		var distance: float = g.ship.position.distance_to(goal)
		if distance>.1:g.ship.look_at(goal)
		g.throttle = .65 if distance>45 else (.2 if distance>12 else 0.0)
		g._physics_process(1.0/60.0)
		if g.mission.can_dock():break
func run() -> void:
	clean()
	var g = fresh()
	await process_frame
	if not g.has_method("trade_goods"):
		check(false,"Trade feature missing: purchases and sales must be available")
		g.queue_free()
		await process_frame
		quit(1)
		return
	g.credits = 1000
	check(g.trade_goods("ore",1,true),"buy ore at Poligon")
	check(g.credits==970 and g.cargo.ore==1,"purchase deducts 30 and adds one")
	check(g.trade_goods("ore",1,false),"sell ore at same station")
	check(g.credits==994 and g.cargo.ore==0,"same station sale loses spread")
	for quantity in [0,-1,11]:check(not g.trade_goods("ore",quantity,true),"invalid/overcapacity quantity rejected")
	check(not g.trade_goods("unknown",1,true),"unknown goods rejected")
	check(not g.trade_goods("medicine",1,false),"cannot sell absent goods")
	g.credits = 10
	check(not g.trade_goods("ore",1,true) and g.cargo.ore==0,"cannot spend missing credits")
	g.credits = 1000
	check(g.trade_goods("ore",10,true) and g.cargo_used()==10,"exact capacity allowed")
	check(not g.trade_goods("electronics",1,true),"mixed goods cannot overflow hold")
	g.choose_mission("delivery")
	g.start_selected_mission()
	check(g.at_station(),"contract needs two free slots")
	check(g.trade_goods("ore",2,false),"free contract space")
	g.start_selected_mission()
	check(g.mission.cargo_loaded and g.cargo_used()==10,"contract occupies two slots")
	check(not g.trade_goods("ore",1,false),"no trade in flight")
	g._save_progress()
	var pending = fresh()
	await process_frame
	check(not pending.trade_goods("ore",1,false),"no remote trade from pending flight menu")
	check(pending.cargo_used()==10,"pending flight menu counts reserved contract slots")
	check(pending.cargo.ore==8 and pending.resume_flight(),"restore delivery with merchandise")
	check(pending.cargo_used()==10,"restored contract capacity")
	pending.queue_free()
	fly(g)
	check(g.mission.can_dock(),"delivery route reachable")
	g.mission.dock()
	check(g.station_id==1 and g.cargo_used()==8,"arrival releases contract slots only")
	check(g.trade_goods("ore",8,false),"sell ore at Vector")
	check(g.cargo_used()==0,"sale empties merchandise hold")
	check(g.trade_goods("electronics",3,true),"purchase electronics at Vector")
	var saved_credits: int = g.credits
	var reloaded = fresh()
	await process_frame
	check(reloaded.station_id==1 and reloaded.cargo.electronics==3 and reloaded.credits==saved_credits,"cargo credits and station saved together")
	reloaded.queue_free()
	g.choose_mission("trade")
	g.start_selected_mission()
	check(g.mission.stage=="ПЕРЕЛЁТ" and not g.mission.cargo_loaded,"free transit without contract")
	g._save_progress()
	var resumed = fresh()
	await process_frame
	check(resumed.resume_flight() and resumed.mission.kind=="trade" and resumed.cargo.electronics==3,"free transit resume preserves cargo")
	resumed._toggle_market()
	var position: Vector3 = resumed.ship.position
	resumed.throttle = 1
	resumed._physics_process(1)
	check(resumed.ship.position==position and not resumed.firing,"cargo overlay pauses flight")
	resumed._toggle_market()
	fly(resumed)
	check(resumed.mission.can_dock(),"free transit reaches other station")
	resumed.mission.dock()
	check(resumed.station_id==0 and resumed.credits==saved_credits,"free transit pays no reward")
	resumed.mission.dock()
	check(resumed.credits==saved_credits,"repeated dock no reward")
	check(resumed.trade_goods("electronics",3,false),"sell transported goods")
	check(resumed.credits==saved_credits+186,"Poligon electronics sell price 62")
	var Trade = load("res://scripts/trade_data.gd")
	check(Trade.read_cargo({"ore":2.0}).ore==2,"JSON cargo quantities accepted")
	for bad in [{"ore":-1},{"ore":1.5},{"ore":11},{"ore":8,"medicine":3},{"ore":"2"}]:
		check(Trade.used(Trade.read_cargo(bad))==0,"malformed cargo safely rejected")
	resumed._toggle_market()
	for dimensions in [Vector2i(1280,720),Vector2i(720,1280)]:
		root.size = dimensions
		for i in range(4):await process_frame
		var ui = resumed.flight_ui
		var rect: Rect2 = ui.market_panel.panel.get_rect()
		check(Rect2(Vector2.ZERO,ui.design_size).encloses(rect),"market fits orientation")
		check(ui.market_panel.goods.ore.buy.size.y>=44,"touch action size")
		check(ui.market_panel.goods.ore.buy.text.contains("30"),"local buying price shown")
	resumed._toggle_market()
	var before: int = resumed.credits
	resumed.store.path = "user://missing_trade_directory/save.json"
	check(not resumed.trade_goods("medicine",1,true),"failed save rejects transaction")
	check(resumed.credits==before and resumed.cargo.medicine==0,"failed save rolls back funds and goods")
	resumed.store.path = PATH
	check(resumed.trade_goods("medicine",1,true),"purchase after save recovers")
	resumed.choose_mission("trade")
	resumed.start_selected_mission()
	resumed.destroyed = true
	resumed.mission.step()
	resumed._save_progress()
	var dead = fresh()
	await process_frame
	check(dead.cargo_used()==0,"destroyed cargo does not return after reload")
	var legacy: Dictionary = dead.store.read_document()
	legacy.erase("cargo")
	legacy.schema = 2
	check(dead.store.write_document(legacy),"write legacy profile")
	var migrated = fresh()
	await process_frame
	check(migrated.cargo_used()==0 and migrated.credits==dead.credits,"0.7 profile migrates without losing funds")
	migrated.queue_free()
	dead.queue_free()
	g.queue_free()
	resumed.queue_free()
	await process_frame
	clean()
	print("Trade tests: %d failures" % failures)
	quit(1 if failures else 0)
