extends SceneTree
var failures := 0
const PATH := "user://planet_test.json"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:failures += 1;push_error(message)
func fresh():
 var g = load("res://main.tscn").instantiate();g.store.path = PATH;root.add_child(g);g.set_physics_process(false);return g
func transition(g, stage: String) -> void:
 for i in range(300):
  if g.mission.stage!=stage:return
  g._physics_process(.05)
  await process_frame
 check(false,"transition timeout: "+stage)
func fly_to(g, goal: Vector3, stop_distance := 12.0) -> void:
 for i in range(5000):
  var distance: float = g.ship.position.distance_to(goal)
  if distance>.1:g.ship.look_at(goal)
  g.throttle = .65 if distance>45 else (.2 if distance>stop_distance else 0.0)
  g._physics_process(1.0/60)
  if distance<=stop_distance and g.velocity.length()<5:return
 check(false,"flight failed to reach destination")
func roundtrip(g) -> void:
 var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(g.snapshots.capture(g)))
 var position: Vector3 = g.ship.position
 check(g.snapshots.valid(checkpoint) and g.snapshots.restore(g,checkpoint),"transition snapshot roundtrip: "+g.mission.stage)
 check(g.ship.position.distance_to(position)<.01,"transition position preserved")
func cleanup() -> void:
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(PATH+suffix)
func run() -> void:
 cleanup()
 var g = fresh();await process_frame
 if not g.has_method("start_planet_flight"):
  check(false,"Planet expedition is missing");g.queue_free();await process_frame;quit(1);return
 g.credits = 1000;g.trade_goods("ore",2,true)
 var before: int = g.credits
 g.start_planet_flight()
 check(g.mission.stage=="К ПЛАНЕТЕ","planet expedition launch")
 check(not g.planet.can_enter(),"entry gate rejects far ship")
 fly_to(g,g.planet.ENTRY)
 check(g.planet.can_enter(),"entry reachable by actual flight")
 g.planet.action()
 check(g.mission.stage=="СПУСК","descent starts")
 g._physics_process(.5)
 g._save_progress()
 var resumed = fresh();await process_frame
 check(resumed.resume_flight() and resumed.mission.stage=="СПУСК","resume descent")
 await transition(resumed,"СПУСК")
 check(resumed.mission.stage=="ПОВЕРХНОСТЬ" and resumed.planet.on_surface(),"surface district loaded")
 check(resumed.cargo.ore==2 and resumed.credits==before,"cargo and funds survive transfer")
 check(not resumed.planet.can_land(),"landing rejects high altitude")
 for dimensions in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(884,1104)]:
  root.size=dimensions
  for i in range(4):await process_frame
  var ui=resumed.flight_ui
  check(Rect2(Vector2.ZERO,ui.design_size).encloses(ui.planet_panel.up.get_rect()),"surface controls fit orientation")
  check(not ui.mission_panel.visible,"surface does not show station panel")
 check(not resumed.can_trade(),"no remote market on surface")
 resumed.ship.position = Vector3(0,12,0);resumed.velocity = Vector3(10,0,0)
 check(not resumed.planet.can_land(),"landing rejects high speed")
 resumed.velocity = Vector3.ZERO
 resumed.ship.position=Vector3(39,12,4)
 check(not resumed.planet.can_land(),"landing rejects occupied outpost footprint")
 resumed.ship.position=Vector3(0,12,0)
 check(resumed.planet.can_land(),"flat low slow area permits landing")
 resumed.planet.action();resumed._physics_process(.8);roundtrip(resumed);await transition(resumed,"ПОСАДКА")
 check(resumed.mission.stage=="НА ПОВЕРХНОСТИ","landing completes")
 var parked: Vector3 = resumed.ship.position
 resumed.throttle = 1;resumed.firing = true;resumed._physics_process(1)
 check(resumed.ship.position==parked and not resumed.firing,"landed ship stays parked")
 resumed._save_progress()
 var landed = fresh();await process_frame
 check(landed.resume_flight() and landed.mission.stage=="НА ПОВЕРХНОСТИ" and landed.planet.on_surface(),"landed district resume")
 check(landed.ship.position.distance_to(parked)<.01 and landed.cargo.ore==2,"landed position cargo restored")
 landed.planet.action();landed._physics_process(.8);roundtrip(landed);await transition(landed,"ВЗЛЁТ")
 check(landed.mission.stage=="ПОВЕРХНОСТЬ" and landed.planet.altitude()>15,"takeoff to hover")
 check(not landed.planet.can_exit(),"orbit exit blocked near ground")
 landed.planet.vertical = 1
 for i in range(500):landed._physics_process(1.0/60)
 check(landed.planet.altitude()>100,"held climb changes altitude")
 landed.clear_held_input();check(landed.planet.vertical==0,"held climb clears with input reset")
 check(landed.planet.can_exit(),"orbit gate opens above 100m")
 landed.planet.exit_orbit()
 landed._physics_process(.6);landed._save_progress()
 var ascent = fresh();await process_frame
 check(ascent.resume_flight() and ascent.mission.stage=="ВЫХОД НА ОРБИТУ","ascent resume")
 ascent._physics_process(2.3);roundtrip(ascent)
 await transition(ascent,"ВЫХОД НА ОРБИТУ")
 check(ascent.mission.stage=="ВОЗВРАЩЕНИЕ" and not ascent.planet.on_surface(),"orbit scene restored")
 fly_to(ascent,ascent.mission.nav_position())
 check(ascent.mission.can_dock(),"return station reachable")
 ascent.mission.dock()
 check(ascent.station_id==0 and ascent.credits==before and ascent.cargo.ore==2,"docked exploration pays zero and preserves goods")
 ascent.station_id=1;ascent.mission.stage="ЗАВЕРШЕНО";ascent.start_planet_flight()
 check(ascent.mission.origin==1,"expedition from second station")
 ascent.ship.position=ascent.planet.ENTRY;ascent.velocity=Vector3.ZERO;ascent.planet.action()
 await transition(ascent,"СПУСК")
 ascent.ship.position=Vector3(0,3,0);ascent.velocity=Vector3(0,-20,0)
 var hull_before: float = ascent.hull
 ascent._physics_process(.2)
 check(ascent.ship.position.y>=ascent.planet.region.height_at(0,0)+1.5 and ascent.hull<hull_before,"ground clamp and impact damage")
 ascent.ship.position=Vector3(2000,200,2000);ascent._physics_process(.1)
 check(absf(ascent.ship.position.x)<=900 and absf(ascent.ship.position.z)<=900,"district edge constrained")
 ascent.planet.vertical=1
 ascent._toggle_upgrades()
 check(ascent.planet.vertical==0,"module overlay clears held climb")
 ascent._toggle_upgrades()
 ascent._toggle_map()
 for i in range(2):await process_frame
 check(not ascent.flight_ui.market_button.visible,"map hides market button over title")
 ascent.planet.vertical=1
 var held: Vector3=ascent.ship.position;ascent._physics_process(1)
 check(ascent.ship.position==held,"surface map pauses flight")
 ascent._toggle_map();ascent.clear_held_input()
 var snapshot: Dictionary = JSON.parse_string(JSON.stringify(ascent.snapshots.capture(ascent)))
 check(ascent.snapshots.valid(snapshot),"surface snapshot JSON valid")
 snapshot.planet.surface=false
 check(not ascent.snapshots.valid(snapshot),"inconsistent scene checkpoint rejected")
 for game in [g,resumed,landed,ascent]:game.queue_free()
 await process_frame;cleanup()
 print("Planet tests: %d failures" % failures);quit(1 if failures else 0)
