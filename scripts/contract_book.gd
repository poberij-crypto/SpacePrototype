extends RefCounted

const FACTIONS := {"guild":"Торговый союз", "guard":"Служба безопасности"}
const GRACE_SECONDS := 600
const CANCEL_PENALTY := 5
const MAX_ID := 2147483647
const OFFERS := {
	"delivery":{"kind":"delivery", "title":"Снабжение станции", "faction":"guild", "reward":240, "trust":5, "required":0},
	"survey":{"kind":"scout", "title":"Разведка сектора", "faction":"guard", "reward":180, "trust":5, "required":0},
	"pirate":{"kind":"combat", "title":"Перехват пиратов", "faction":"guard", "reward":380, "trust":8, "required":0, "target_shield":15.0, "pirates":2},
	"priority":{"kind":"delivery", "title":"Приоритетная доставка", "faction":"guild", "reward":410, "trust":7, "required":15},
	"raider":{"kind":"combat", "title":"Перехват рейдеров", "faction":"guard", "reward":540, "trust":10, "required":15, "target_shield":30.0, "pirates":3},
}
var reputation := {"guild":0, "guard":0}
var active: Dictionary = {}
var next_id := 1

func offer(key: String, station: int) -> Dictionary:
	var data: Dictionary = OFFERS.get(key, {}).duplicate()
	if not data.is_empty():
		data["origin"] = station
		data["destination"] = 1 - station
	return data

func can_accept(key: String, station: int) -> bool:
	if key not in OFFERS or station not in [0, 1] or next_id >= MAX_ID:
		return false
	var data: Dictionary = OFFERS[key]
	return data.required == 0 or int(reputation[data.faction]) >= data.required

func accept(key: String, station: int, now: int) -> int:
	if not can_accept(key, station):
		return 0
	var id := next_id
	next_id += 1
	active[str(id)] = {"offer":key, "origin":station, "accepted":now}
	return id

func order(id: int) -> Dictionary:
	var entry: Dictionary = active.get(str(id), {})
	if entry.is_empty():
		return {}
	var data := offer(entry.offer, entry.origin)
	data["id"] = id
	data["accepted"] = entry.accepted
	# Every signed contract has a reproducible destination marker.
	data["site"] = Vector3(-160 + (id % 9) * 15, (id % 5) * 8 - 16, -295 - (id % 7) * 14)
	return data

func penalty(id: int, now: int) -> int:
	var entry: Dictionary = active.get(str(id), {})
	if entry.is_empty() or now < int(entry.accepted) + GRACE_SECONDS:
		return 0
	var faction: String = OFFERS[entry.offer].faction
	return mini(CANCEL_PENALTY, int(reputation[faction]) + 100)

func cancel(id: int, now: int) -> int:
	var data := order(id)
	if data.is_empty():
		return -1
	var before: int = reputation[data.faction]
	change_reputation(data.faction, -penalty(id, now))
	active.erase(str(id))
	return before - int(reputation[data.faction])

func finish(id: int, station: int) -> Dictionary:
	var data := order(id)
	if data.is_empty() or data.destination != station:
		return {}
	var before: int = reputation[data.faction]
	change_reputation(data.faction, data.trust)
	data["trust"] = int(reputation[data.faction]) - before
	active.erase(str(id))
	return data

func change_reputation(faction: String, change: int) -> void:
	reputation[faction] = clampi(int(reputation[faction]) + change, -100, 100)

func capture() -> Dictionary:
	return {"next_id":next_id, "reputation":reputation.duplicate(), "active":active.duplicate(true)}

func restore(value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	for faction in FACTIONS:
		var score = value.get("reputation", {})
		if typeof(score) == TYPE_DICTIONARY and integer(score.get(faction), -100, 100):
			reputation[faction] = int(score[faction])
	active.clear()
	next_id = int(value.next_id) if integer(value.get("next_id"), 1, MAX_ID) else 1
	var orders = value.get("active")
	if typeof(orders) != TYPE_DICTIONARY:
		return
	for key in orders:
		var entry = orders[key]
		if typeof(key) != TYPE_STRING or not key.is_valid_int() or int(key) < 1 or int(key) >= MAX_ID or str(int(key)) != key:
			continue
		if typeof(entry) != TYPE_DICTIONARY or entry.get("offer") not in OFFERS:
			continue
		if not integer(entry.get("origin"), 0, 1) or not integer(entry.get("accepted"), 0, 253402300799):
			continue
		active[key] = {"offer":entry.offer, "origin":int(entry.origin), "accepted":int(entry.accepted)}
		next_id = maxi(next_id, int(key) + 1)

static func integer(value, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high and float(int(value)) == float(value)
