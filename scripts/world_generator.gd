extends RefCounted

# Keep version 1 stable so an existing checkpoint always reconstructs the same site.
const START_SEED := 612047
const VERSION := 1
const HOME_GATE := Vector3(-145, 25, -220)
const ARRIVAL_GATE := Vector3(-115, 12, -75)
const STAR_NAMES := ["Кассиопея", "Эридан", "Лисса", "Альциона"]
const PLANET_NAMES := ["Ферра", "Терра Нова", "Борея", "Таласса"]
const GROUND_COLORS := [Color("b97851"), Color("9e9b72"), Color("9cb7c4"), Color("8574a1")]
const SKY_COLORS := [Color("c68662"), Color("a0ad85"), Color("a3bfd3"), Color("a097bf")]

static func neighbor() -> Dictionary:
	return generate_system(START_SEED, 1)

static func generate_system(galaxy_seed: int, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = galaxy_seed ^ (index * 104729) ^ VERSION
	var star_index := rng.randi_range(0, STAR_NAMES.size() - 1)
	var planet_index := rng.randi_range(0, PLANET_NAMES.size() - 1)
	var landing := Vector2(rng.randi_range(150, 290), rng.randi_range(-250, -150))
	var entry := Vector3(rng.randi_range(65, 135), rng.randi_range(12, 45), -310)
	return {
		"id": "system-%d" % index,
		"system_name": STAR_NAMES[star_index],
		"planet_name": PLANET_NAMES[planet_index],
		"entry": entry,
		"radius": rng.randf_range(46.0, 70.0),
		"rock_seed": rng.randi(),
		"offset": Vector2(rng.randf_range(200, 700), rng.randf_range(-700, -200)),
		"amplitude": rng.randf_range(0.8, 1.4),
		"landing": landing,
		"site": landing + Vector2(28, 0),
		"signal": landing + Vector2(-32, 36),
		"reserve": rng.randi_range(80, 120),
		"ground_color": GROUND_COLORS[planet_index],
		"sky_color": SKY_COLORS[planet_index],
	}
