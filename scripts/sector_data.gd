extends RefCounted
const POSITIONS := [Vector3(35,0,-105),Vector3(-300,30,-490)]
const NAMES := ["Полигон","Вектор"]
static func position(id: int) -> Vector3:return POSITIONS[clampi(id,0,1)]
static func title(id: int) -> String:return NAMES[clampi(id,0,1)]
static func dock_point(id: int) -> Vector3:
	return position(id)+Vector3(0,0,-18 if id==0 else 18)
