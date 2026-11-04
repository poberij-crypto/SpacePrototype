extends RefCounted
var path := "user://space_prototype.json"
var recovered := false

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):return {}
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null:return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK:return {}
	var value = parser.data
	if typeof(value) != TYPE_DICTIONARY:return {}
	if typeof(value.get("credits")) not in [TYPE_INT,TYPE_FLOAT] or typeof(value.get("upgrades")) != TYPE_DICTIONARY:return {}
	for key in ["engine","shield","weapon"]:
		if typeof(value.upgrades.get(key)) not in [TYPE_INT,TYPE_FLOAT]:return {}
	return value

func read_document() -> Dictionary:
	recovered = false
	var data := _read(path)
	if not data.is_empty():return data
	data = _read(path+".bak")
	recovered = not data.is_empty()
	return data

func write_document(data: Dictionary) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:return false
	# Never replace the usable backup with a corrupted main file.
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(path,path+".bak") != OK:return false
	return DirAccess.rename_absolute(path+".tmp",path) == OK
