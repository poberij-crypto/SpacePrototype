extends SceneTree
const Arms = preload("res://scripts/armament_state.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var arms := Arms.new()
	check(arms.power_used() == 40 and arms.loadout == ["laser","laser"], "Legacy ship begins with the two existing lasers")
	check(not arms.can_transact("buy","plasma",-1,0,0), "Purchase requires enough credits")
	var credits := arms.transact("buy","plasma",-1,0,1000)
	check(credits == 480 and arms.warehouses[0].plasma == 1 and arms.warehouses[1].plasma == 0, "Bought weapon belongs to the docking station")
	check(not arms.can_transact("equip","plasma",0,1,credits), "A weapon left on another station cannot be fitted")
	arms.transact("equip","plasma",0,0,credits)
	check(arms.loadout[0] == "plasma" and arms.warehouses[0].laser == 1, "Replacing an equipped gun retains the old one")
	arms.warehouses[0].plasma = 1
	arms.transact("equip","plasma",1,0,credits)
	arms.warehouses[0].launcher = 1
	check(not arms.can_transact("equip","launcher",2,0,credits), "Overpowered loadout is rejected")
	check(not arms.can_transact("equip","cannon",2,0,credits), "Main gun cannot use the missile mount")
	arms.ammo = 299
	check(arms.refill_quantity("ammo") == 1, "Partial ammunition refill fits the remaining capacity")
	arms.transact("refill","ammo",-1,0,credits)
	check(arms.ammo == 300 and not arms.can_transact("refill","ammo",-1,0,credits), "Full stock cannot charge another refill")
	arms.heat = [100.0,0.0]
	arms.overheated = [true,false]
	arms.tick(1)
	check(arms.overheated[0] and arms.heat[0] == 78.0, "Overheated gun must cool below the restart threshold")
	arms.tick(2)
	check(not arms.overheated[0], "Cooling restores weapon readiness")
	var copy := Arms.new()
	copy.restore(JSON.parse_string(JSON.stringify(arms.capture())))
	check(copy.capture() == arms.capture(), "Weapon profile survives JSON serialization")
	var game = load("res://main.tscn").instantiate()
	game.store.path = "user://armament_transaction_test.json"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.credits = 1000
	var before: Dictionary = game.armament.capture()
	game.store.path = "user://missing-armament-save-dir/save.json"
	check(not game.weapon_transaction("buy","cannon") and game.credits == 1000 and game.armament.capture() == before, "Failed purchase write rolls back funds and station storage")
	game.armament.warehouses[0].cannon = 1
	check(not game.weapon_transaction("equip","cannon",0) and game.armament.loadout[0] == "laser" and game.armament.warehouses[0].cannon == 1, "Failed fitting write preserves both weapons")
	game.store.path = "user://armament_transaction_test.json"
	check(game.weapon_transaction("equip","cannon",0), "Fit succeeds after save path recovery")
	game.start_selected_mission()
	check(not game.weapon_transaction("buy","plasma"), "The flight cannot buy or replace weapons remotely")
	game.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://armament_transaction_test.json"+suffix)
	print("Armament tests: %d failures" % failures)
	quit(1 if failures else 0)
