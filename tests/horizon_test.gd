extends SceneTree
var failures := 0
const PATH := "user://horizon_test.json"
const DT := 1.0 / 60.0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:failures += 1;push_error(message)
func heading(g) -> Vector3:
 var forward: Vector3 = -g.ship.global_basis.z
 return Vector3(forward.x,0,forward.z).normalized()
func reset_attitude(g, pitch: float = .45, roll: float = .65) -> void:
 g.clear_held_input();g.stabilized=true;g.velocity=Vector3.ZERO;g.throttle=0
 g.ship.position=Vector3(0,150,0)
 g.ship.basis=Basis(Vector3.UP,.7)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,roll)
func step(g, count: int) -> void:
 for i in range(count):g._physics_process(DT)
func run() -> void:
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(PATH+suffix)
 var g = load("res://main.tscn").instantiate();g.store.path=PATH;root.add_child(g)
 g.set_physics_process(false);await process_frame
 g.pending_snapshot.clear();g.start_planet_flight()
 g.planet._instantiate_region(load(g.planet.REGION_PATH));g.planet._set_surface(true);g.mission.stage="ПОВЕРХНОСТЬ"
 reset_attitude(g)
 var original_heading := heading(g)
 var initial: Basis = g.ship.global_basis
 step(g,1)
 check(g.ship.global_basis.get_rotation_quaternion().angle_to(initial.get_rotation_quaternion())>.0001,"leveling begins smoothly")
 check(g.ship.global_basis.get_rotation_quaternion().angle_to(initial.get_rotation_quaternion())<.1,"leveling never snaps")
 step(g,239)
 check(absf(g.ship.global_basis.z.y)<.002 and g.ship.global_basis.y.dot(Vector3.UP)>.999,"released controls level pitch and roll")
 check(heading(g).dot(original_heading)>.99999,"leveling preserves horizontal heading")
 reset_attitude(g)
 g.steer_touch=7;g.turn_input=Vector2(0,.6)
 var before_pitch: float = (-g.ship.global_basis.z).y
 step(g,20)
 check(absf((-g.ship.global_basis.z).y-before_pitch)>.1,"touch pitch remains effective during leveling")
 g.turn_input=Vector2(0,0.00001)
 var steered_forward: Vector3 = -g.ship.global_basis.z
 for i in range(180):g.planet.constrain_motion(DT)
 check((-g.ship.global_basis.z).dot(steered_forward)>.99999,"active pitch input is never pulled toward horizon")
 g.clear_held_input()
 reset_attitude(g,.4,0)
 Input.action_press("ui_up")
 var keyboard_pitch: float = (-g.ship.global_basis.z).y
 step(g,15)
 Input.action_release("ui_up")
 check((-g.ship.global_basis.z).y>keyboard_pitch+.1,"keyboard pitch remains effective")
 reset_attitude(g)
 g.stabilized=false
 var inertial_basis: Basis=g.ship.global_basis
 step(g,240)
 check(g.ship.global_basis.is_equal_approx(inertial_basis),"inertial flight preserves attitude")
 for pitch in [PI/2.0,-PI/2.0,PI/2.0-.000001,-PI/2.0+.000001]:
  reset_attitude(g,pitch,.9)
  step(g,240)
  check(g.ship.global_basis.is_finite() and absf(g.ship.global_basis.determinant()-1)<.0001,"vertical attitudes stay finite and orthonormal")
  check(absf(g.ship.global_basis.z.y)<.002,"vertical attitudes recover a horizontal heading")
 reset_attitude(g)
 g.planet.vertical=1
 var height: float=g.ship.position.y
 step(g,120)
 check(g.ship.position.y>height+15,"climb remains independent of pitch leveling")
 g.clear_held_input();step(g,120)
 check(absf(g.velocity.y)<.01,"released climb returns to hover")
 for stage in ["ПОСАДКА","ВЗЛЁТ","СПУСК","ВЫХОД НА ОРБИТУ","НА ПОВЕРХНОСТИ"]:
  reset_attitude(g);g.mission.stage=stage
  var transition_basis: Basis=g.ship.global_basis
  g.planet.constrain_motion(.5)
  check(g.ship.global_basis.is_equal_approx(transition_basis),"leveling excludes transition "+stage)
 g.mission.stage="ПОВЕРХНОСТЬ";reset_attitude(g);g.planet._set_surface(false)
 var space_basis: Basis=g.ship.global_basis
 g.planet.constrain_motion(1)
 check(g.ship.global_basis.is_equal_approx(space_basis),"space attitude is unchanged")
 g.queue_free();await process_frame
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(PATH+suffix)
 print("Horizon tests: %d failures" % failures);quit(1 if failures else 0)
