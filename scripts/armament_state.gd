extends RefCounted

const POWER_LIMIT := 70
const AMMO_CAPACITY := 300
const ROCKET_CAPACITY := 12
const CATALOG := {
	"laser": {"name":"Импульсный лазер Л-1", "description":"Точный луч. Эффективен против щитов, расходует энергию.", "price":[180,200], "power":20, "damage":10.0, "range":160.0, "cooldown":.35, "energy":5.0, "heat":10.0, "shield":1.6, "hull":.6},
	"cannon": {"name":"Автопушка АП-2", "description":"Быстрые снаряды против корпуса. Требуются боеприпасы и упреждение.", "price":[280,250], "power":12, "damage":8.0, "range":220.0, "cooldown":.12, "energy":0.0, "heat":4.0, "shield":.6, "hull":1.4},
	"plasma": {"name":"Плазменное орудие П-3", "description":"Мощный медленный сгусток. Высокие расход энергии и нагрев.", "price":[520,580], "power":35, "damage":28.0, "range":240.0, "cooldown":1.0, "energy":22.0, "heat":30.0, "shield":1.0, "hull":1.0},
	"launcher": {"name":"Ракетная установка РУ-1", "description":"Самонаведение после захвата цели. Нужны ракеты.", "price":[360,320], "power":15, "damage":45.0, "range":400.0, "cooldown":3.0, "energy":0.0, "heat":0.0, "shield":.8, "hull":1.8},
}
const MAIN_WEAPONS := ["laser", "cannon", "plasma"]
var loadout: Array = ["laser", "laser"]
var launcher := ""
var warehouses: Array = [{"laser":0,"cannon":0,"plasma":0,"launcher":0}, {"laser":0,"cannon":0,"plasma":0,"launcher":0}]
var ammo := 0
var rockets := 0
var energy := 100.0
var heat: Array = [0.0, 0.0]
var cooldowns: Array = [0.0, 0.0]
var overheated: Array = [false, false]
var missile_cooldown := 0.0
var group := 0

func price(item: String, station: int, buying := true) -> int:
	if item not in CATALOG or station < 0 or station > 1:
		return 0
	var cost: int = CATALOG[item].price[station]
	return cost if buying else floori(cost * .6)

func power_used() -> int:
	var total := 0
	for weapon in loadout + [launcher]:
		if weapon in CATALOG:
			total += int(CATALOG[weapon].power)
	return total

func group_title() -> String:
	return ["ОБА", "ЛЕВОЕ", "ПРАВОЕ"][group]

func refill_quantity(item: String) -> int:
	return mini(60, AMMO_CAPACITY - ammo) if item == "ammo" else (mini(4, ROCKET_CAPACITY - rockets) if item == "rockets" else 0)

func refill_cost(item: String, station: int) -> int:
	var quantity := refill_quantity(item)
	var unit_price := (30 if station == 0 else 36) / 60.0 if item == "ammo" else (100 if station == 0 else 90) / 4.0
	return ceili(quantity * unit_price)

func can_transact(action: String, item: String, slot: int, station: int, credits: int) -> bool:
	if station < 0 or station > 1:
		return false
	if action == "refill":
		return item in ["ammo", "rockets"] and refill_quantity(item) > 0 and credits >= refill_cost(item, station)
	if action == "remove":
		if slot < 0 or slot > 2: return false
		var old: String = launcher if slot == 2 else loadout[slot]
		return old != "" and int(warehouses[station].get(old, 0)) < 100
	if item not in CATALOG:
		return false
	var stock: int = warehouses[station].get(item, 0)
	match action:
		"buy": return stock < 100 and credits >= price(item, station)
		"sell": return stock > 0
		"equip":
			if stock == 0 or slot < 0 or slot > 2 or (slot == 2) != (item == "launcher"):
				return false
			var old: String = launcher if slot == 2 else loadout[slot]
			var old_power: int = CATALOG[old].power if old in CATALOG else 0
			return old != item and power_used() - old_power + int(CATALOG[item].power) <= POWER_LIMIT \
				and (old == "" or int(warehouses[station].get(old, 0)) < 100)
	return false

func transact(action: String, item: String, slot: int, station: int, credits: int) -> int:
	if not can_transact(action, item, slot, station, credits):
		return -1
	match action:
		"buy":
			warehouses[station][item] += 1
			return credits - price(item, station)
		"sell":
			warehouses[station][item] -= 1
			return credits + price(item, station, false)
		"refill":
			var cost := refill_cost(item, station)
			if item == "ammo": ammo += refill_quantity(item)
			else: rockets += refill_quantity(item)
			return credits - cost
		"equip", "remove":
			var old: String = launcher if slot == 2 else loadout[slot]
			if old != "": warehouses[station][old] += 1
			var next := item if action == "equip" else ""
			if next != "": warehouses[station][next] -= 1
			if slot == 2: launcher = next
			else: loadout[slot] = next
	return credits

func tick(delta: float) -> void:
	energy = minf(100, energy + 18.0 * delta)
	missile_cooldown = maxf(0, missile_cooldown - delta)
	for slot in range(2):
		heat[slot] = maxf(0, float(heat[slot]) - 22.0 * delta)
		cooldowns[slot] = maxf(0, float(cooldowns[slot]) - delta)
		if heat[slot] <= 55: overheated[slot] = false

func ready(slot: int) -> bool:
	var weapon: String = loadout[slot]
	return weapon in MAIN_WEAPONS and (group == 0 or group == slot + 1) and cooldowns[slot] <= 0 \
		and not overheated[slot] and energy >= float(CATALOG[weapon].energy) and (weapon != "cannon" or ammo > 0)

func consume_shot(slot: int) -> void:
	var weapon: Dictionary = CATALOG[loadout[slot]]
	energy -= float(weapon.energy)
	heat[slot] = minf(100, float(heat[slot]) + float(weapon.heat))
	cooldowns[slot] = float(weapon.cooldown)
	overheated[slot] = heat[slot] >= 100
	if loadout[slot] == "cannon": ammo -= 1

func runtime_capture() -> Dictionary:
	return {"ammo":ammo,"rockets":rockets,"energy":energy,"heat":heat.duplicate(),"cooldowns":cooldowns.duplicate(),"overheated":overheated.duplicate(),"missile_cooldown":missile_cooldown,"group":group}

static func number(value, minimum: float, maximum: float, integer := false) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= minimum and value <= maximum and (not integer or float(int(value)) == float(value))

static func valid_runtime(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	for pair in [["ammo",300],["rockets",12],["group",2]]:
		if not number(data.get(pair[0]),0,pair[1],true): return false
	if not number(data.get("energy"),0,100) or not number(data.get("missile_cooldown"),0,3): return false
	for key in ["heat", "cooldowns", "overheated"]:
		if typeof(data.get(key)) != TYPE_ARRAY or data[key].size() != 2: return false
	for slot in range(2):
		if not number(data.heat[slot],0,100) or not number(data.cooldowns[slot],0,1) or typeof(data.overheated[slot]) != TYPE_BOOL: return false
	return true

func restore_runtime(data) -> void:
	if not valid_runtime(data): return
	ammo = int(data.ammo)
	rockets = int(data.rockets)
	group = int(data.group)
	energy = float(data.energy)
	heat = data.heat.duplicate()
	cooldowns = data.cooldowns.duplicate()
	overheated = data.overheated.duplicate()
	missile_cooldown = float(data.missile_cooldown)

func capture() -> Dictionary:
	return {"version":1,"loadout":loadout.duplicate(),"launcher":launcher,"warehouses":warehouses.duplicate(true),"runtime":runtime_capture()}

func restore(data) -> void:
	if typeof(data) != TYPE_DICTIONARY or data.get("version") != 1: return
	if typeof(data.get("loadout")) != TYPE_ARRAY or data.loadout.size() != 2 or data.get("launcher") not in ["", "launcher"]: return
	for weapon in data.loadout:
		if weapon not in MAIN_WEAPONS + [""]: return
	if typeof(data.get("warehouses")) != TYPE_ARRAY or data.warehouses.size() != 2 or not valid_runtime(data.get("runtime")): return
	for stock in data.warehouses:
		if typeof(stock) != TYPE_DICTIONARY: return
		for weapon in CATALOG:
			if not number(stock.get(weapon),0,100,true): return
	var total := int(CATALOG.launcher.power) if data.launcher == "launcher" else 0
	for weapon in data.loadout:
		if weapon != "": total += int(CATALOG[weapon].power)
	if total > POWER_LIMIT: return
	loadout = data.loadout.duplicate()
	launcher = data.launcher
	warehouses = data.warehouses.duplicate(true)
	for stock in warehouses:
		for weapon in CATALOG:
			stock[weapon] = int(stock[weapon])
	restore_runtime(data.runtime)
