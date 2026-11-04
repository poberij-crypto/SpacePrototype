extends Node
var enabled := true
var game: Node3D
var craft: Node3D
var state := "СБЛИЖЕНИЕ"
var state_time := 0.0
var cooldown := 0.0
var waypoint := Vector3.ZERO
var passes := 0

func setup(owner_game: Node3D, ship: Node3D) -> void:
	game = owner_game
	craft = ship
	craft.look_at(game.ship.global_position)

func _enter(next: String) -> void:
	state = next
	state_time = 0
	if next == "РАЗВОРОТ" or next == "УКЛОНЕНИЕ":
		var side := craft.global_basis.x * (1.0 if passes % 2 == 0 else -1.0)
		waypoint = craft.global_position - craft.global_basis.z * 65.0 + side * 50.0
	craft.set_meta("tactic", state)

func step(delta: float) -> void:
	if not enabled or game.destroyed: return
	cooldown = maxf(0, cooldown-delta)
	state_time += delta
	var offset: Vector3 = game.ship.global_position-craft.global_position
	var distance := offset.length()
	if state == "СБЛИЖЕНИЕ" and distance <= 108.0: _enter("АТАКА")
	elif state == "АТАКА" and (distance < 28.0 or state_time > 5.0): _enter("РАЗВОРОТ")
	elif state == "УКЛОНЕНИЕ" and state_time > 1.3: _enter("РАЗВОРОТ")
	elif state == "РАЗВОРОТ" and state_time > 3.0:
		passes += 1
		_enter("СБЛИЖЕНИЕ")
	var destination: Vector3 = game.ship.global_position if state == "СБЛИЖЕНИЕ" or state == "АТАКА" else waypoint
	var direction: Vector3 = destination-craft.global_position
	if direction.length() > .1:
		var up := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < .98 else Vector3.RIGHT
		var desired := Basis.looking_at(direction.normalized(),up).get_rotation_quaternion()
		var current := craft.global_basis.get_rotation_quaternion()
		var angle := current.angle_to(desired)
		var weight := minf(1.0,delta*(1.5 if state == "УКЛОНЕНИЕ" else 1.0)/maxf(angle,.001))
		craft.global_basis = Basis(current.slerp(desired,weight))
	var speed := 16.0 if state == "АТАКА" else 22.0
	craft.global_position -= craft.global_basis.z*speed*delta
	craft.set_meta("tactic",state)

func can_fire() -> bool:
	if not enabled or state != "АТАКА" or cooldown > 0 or game.destroyed:return false
	var offset: Vector3 = game.ship.global_position-craft.global_position
	return offset.length() > 1.0 and offset.length() < 110.0 and (-craft.global_basis.z).dot(offset.normalized()) > .985

func consume_shot() -> void:
	cooldown = 1.2

func on_hit() -> void:
	if state == "АТАКА" or state == "СБЛИЖЕНИЕ": _enter("УКЛОНЕНИЕ")
