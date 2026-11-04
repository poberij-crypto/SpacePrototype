extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := "user://isolated_save_test.json"
	var store = load("res://scripts/checkpoint_store.gd").new()
	store.path = path
	assert(store.write_document({"credits":50,"upgrades":{"engine":0,"shield":0,"weapon":0}}),"first save")
	assert(store.write_document({"credits":80,"upgrades":{"engine":1,"shield":0,"weapon":0}}),"second save")
	assert(store.read_document().credits == 80,"latest version")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert(store.read_document().credits == 50,"fallback to previous valid backup")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	print("Save storage tests PASS")
	quit()
