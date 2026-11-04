extends RefCounted
const CAPACITY := 10
const CONTRACT_SIZE := 2
const GOODS := ["ore","electronics","medicine"]
const NAMES := {"ore":"РУДА","electronics":"ЭЛЕКТРОНИКА","medicine":"МЕДИКАМЕНТЫ"}
const BUY := {"ore":[30,56],"electronics":[68,42],"medicine":[48,72]}
const SELL := {"ore":[24,50],"electronics":[62,36],"medicine":[42,66]}

static func empty_cargo() -> Dictionary:return {"ore":0,"electronics":0,"medicine":0}
static func price(good: String, station: int, buying: bool) -> int:
	if good not in GOODS:return 0
	return int((BUY if buying else SELL)[good][clampi(station,0,1)])
static func used(cargo: Dictionary) -> int:
	var total := 0
	for good in GOODS:total += int(cargo.get(good,0))
	return total
static func read_cargo(value) -> Dictionary:
	var result := empty_cargo()
	if typeof(value)!=TYPE_DICTIONARY:return result
	for good in GOODS:
		var count = value.get(good,0)
		if typeof(count) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(count)) or count<0 or count>CAPACITY or float(int(count))!=float(count):return empty_cargo()
		result[good] = int(count)
	return result if used(result)<=CAPACITY else empty_cargo()
