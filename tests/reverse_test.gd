extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:failures += 1;push_error(message)
func run() -> void:
 var g = load("res://main.tscn").instantiate()
 g.store.path = "user://reverse_test.json"
 root.add_child(g)
 g.set_physics_process(false)
 await process_frame
 g.pending_snapshot.clear()
 g.selected_mission = "combat"
 g.throttle = 0
 g.flight_ui.controls["−"].pressed.emit()
 check(is_equal_approx(g.throttle,-.2),"minus button must enable reverse")
 if not g.has_method("adjust_throttle"):
  g.queue_free();await process_frame;quit(1);return
 for i in range(10):g.adjust_throttle(-.2)
 check(is_equal_approx(g.throttle,-.3),"reverse capped at -30 percent")
 g.adjust_throttle(.2);g.adjust_throttle(.2)
 check(is_zero_approx(g.throttle),"zero crossing stops at neutral")
 g.start_selected_mission()
 g.throttle = -.3
 var forward: Vector3 = -g.ship.global_basis.z
 var start: Vector3 = g.ship.position
 for i in range(120):g._physics_process(1.0/60)
 check((g.ship.position-start).dot(forward)<-5,"reverse moves opposite ship nose")
 var snapshot: Dictionary = JSON.parse_string(JSON.stringify(g.snapshots.capture(g)))
 check(g.snapshots.valid(snapshot),"negative thrust survives JSON checkpoint")
 g.throttle = 1
 check(g.snapshots.restore(g,snapshot) and is_equal_approx(g.throttle,-.3),"reverse restored")
 snapshot.throttle = -.31
 check(not g.snapshots.valid(snapshot),"out-of-range reverse rejected")
 g.visuals.update_flight(-.3)
 for plume in g.visuals.plumes:check(plume.scale.y>0,"reverse never inverts engine flames")
 g.stabilized = false
 g.velocity = Vector3.ZERO
 g.throttle = -.3
 g._physics_process(1)
 check(g.velocity.dot(forward)<0,"reverse also works in inertia mode")
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(g.store.path+suffix)
 g.queue_free();await process_frame
 print("Reverse tests: %d failures" % failures);quit(1 if failures else 0)
