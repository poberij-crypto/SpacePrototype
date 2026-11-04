extends RefCounted

const SIGNAL_POINT := Vector2(180, 150)
const SITE := Vector2(244, 120)
const LANDING_POINT := Vector2(220, 120)
const RESERVE := 120
const CAPACITY := 20
const WORK_PER_ORE := 60.0
const REPAIR_SECONDS := 120.0
const SURVEY_SECONDS := 5.0
const SURVEY_RADIUS := 150.0
const SERVICE_RADIUS := 40.0

var surveyed := false
var installed := false
var initial_reserve := RESERVE
var reserve := RESERVE
var stock := 0
var work := 0.0
var saved_at := 0
var event_seed := 0
var event_index := 0
var offline_until_event := 0.0
var repair_left := 0.0
var report_produced := 0
var report_lost := 0
var report_breakdowns := 0
var report_raids := 0

func deploy(seed: int) -> void:
	installed = true
	reserve -= 1
	stock += 1
	event_seed = seed
	offline_until_event = _event_delay()

func advance(seconds: float, offline: bool) -> void:
	if not installed or (reserve == 0 and stock == 0) or seconds <= 0:
		return
	if not offline:
		_produce(seconds, 2.0)
		return

	# Resolve each incident after producing up to its timestamp.
	while seconds > 0 and (reserve > 0 or stock > 0):
		var span := minf(seconds, offline_until_event)
		_produce(span, 1.0)
		seconds -= span
		offline_until_event -= span
		if offline_until_event == 0:
			_resolve_event()
			event_index += 1
			offline_until_event = _event_delay()

func _produce(seconds: float, rate: float) -> void:
	var repair := minf(seconds, repair_left)
	repair_left -= repair
	if reserve == 0 or stock == CAPACITY:
		return
	work += (seconds - repair) * rate
	var units := mini(floori(work / WORK_PER_ORE), mini(reserve, CAPACITY - stock))
	reserve -= units
	stock += units
	work = 0.0 if reserve == 0 or stock == CAPACITY else work - units * WORK_PER_ORE
	if rate == 1.0:
		report_produced += units

func _event_delay() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = event_seed + 7919 * event_index
	if event_index == 0:
		return float(rng.randi_range(480, 960))
	return float(rng.randi_range(720, 1500))

func _resolve_event() -> void:
	if event_index % 2 == 0:
		if reserve > 0:
			repair_left = REPAIR_SECONDS
			report_breakdowns += 1
	else:
		var lost := ceili(stock * 0.25)
		stock -= lost
		report_lost += lost
		report_raids += 1

func has_report() -> bool:
	return report_produced + report_breakdowns + report_raids > 0

func clear_report() -> void:
	report_produced = 0
	report_lost = 0
	report_breakdowns = 0
	report_raids = 0

func production_status() -> String:
	if repair_left > 0:
		return "Авторемонт · %d с" % ceili(repair_left)
	if reserve == 0:
		return "Залежь исчерпана"
	if stock == CAPACITY:
		return "Склад заполнен"
	return "Следующая единица через %d с" % ceili((WORK_PER_ORE - work) / 2.0)

func capture() -> Dictionary:
	return {
		"surveyed": surveyed, "installed": installed, "reserve": reserve, "stock": stock,
		"work": work, "saved_at": saved_at, "event_seed": event_seed, "event_index": event_index,
		"offline_until_event": offline_until_event, "repair_left": repair_left,
		"report_produced": report_produced, "report_lost": report_lost,
		"report_breakdowns": report_breakdowns, "report_raids": report_raids,
	}

func restore(value) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var saved_survey = value.get("surveyed")
	var saved_installation = value.get("installed")
	surveyed = typeof(saved_survey) == TYPE_BOOL and saved_survey
	installed = surveyed and typeof(saved_installation) == TYPE_BOOL and saved_installation
	if not installed:
		value = {}
	reserve = int(_read(value, "reserve", initial_reserve - int(installed), initial_reserve - 1))
	stock = int(_read(value, "stock", 0, mini(CAPACITY, initial_reserve - reserve)))
	work = _read(value, "work", 0, WORK_PER_ORE - .000001)
	saved_at = int(_read(value, "saved_at", 0, 253402300799.0))
	event_seed = int(_read(value, "event_seed", 0, 2147483647.0))
	event_index = int(_read(value, "event_index", 0, 2147483647.0))
	offline_until_event = _read(value, "offline_until_event", _event_delay(), 1500.0) if installed else 0.0
	repair_left = _read(value, "repair_left", 0, REPAIR_SECONDS)
	report_produced = int(_read(value, "report_produced", 0, initial_reserve))
	report_lost = int(_read(value, "report_lost", 0, initial_reserve))
	report_breakdowns = int(_read(value, "report_breakdowns", 0, 2147483647.0))
	report_raids = int(_read(value, "report_raids", 0, 2147483647.0))

static func _read(data: Dictionary, key: String, fallback: float, maximum: float) -> float:
	var value = data.get(key)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, maximum)
