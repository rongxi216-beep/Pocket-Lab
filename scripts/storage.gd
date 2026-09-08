extends RefCounted
## Versioned, bounded local records. temp -> backup -> primary; corrupt primary falls back.
var root := "user://"
var last_error := ""

func _path(name: String) -> String:
	return root.path_join(name + ".json")

func write_record(name: String, data: Dictionary) -> bool:
	last_error = ""
	var path := _path(name)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "无法写入本地存储"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "存储空间不足或写入失败"
		return false
	if FileAccess.file_exists(path):
		# Retain the old primary until the complete temp has been flushed.
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			last_error = "无法更新存档备份"
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "无法替换存档"
		return false
	return true

func read_record(name: String) -> Dictionary:
	for suffix in ["", ".bak"]:
		var path: String = _path(name) + suffix
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 4000000: continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK: continue
		var parsed = parser.data
		if parsed is Dictionary:
			if name in ["session", "previous"] and not valid_scene(parsed.get("world", {})): continue
			return parsed
	return {}

static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and absf(float(value)) < 10000000

static func pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and finite_number(value[0]) and finite_number(value[1])

static func valid_scene(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("scene") != "desktop": return false
	if not data.get("items") is Array or not data.get("springs") is Array: return false
	if data.items.size() > 76 or data.springs.size() > 48: return false
	var rect = data.get("bounds")
	if not rect is Array or rect.size() != 4: return false
	for number in rect:
		if not finite_number(number): return false
	if rect[2] < 100 or rect[3] < 100: return false
	var ids := {}
	for item in data.items:
		if not item is Dictionary or not finite_number(item.get("id")): return false
		if int(item.id) <= 0 or ids.has(int(item.id)): return false
		ids[int(item.id)] = true
		if item.get("kind") not in ["ball", "ramp", "magnet", "fan"]: return false
		if not pair(item.get("p")) or not pair(item.get("v")) or not pair(item.get("home")): return false
		for key in ["angle", "spin", "home_angle"]:
			if not finite_number(item.get(key)): return false
		if not item.get("props", {}) is Dictionary: return false
		# Only bounded numeric properties enter physics; names are display-only.
		for key in item.get("props", {}):
			if key == "name": continue
			var value = item.props[key]
			if not finite_number(value) or value < 0 or value > 5000: return false
		if float(item.get("props", {}).get("mass", 1)) < 0.1: return false
		if float(item.get("props", {}).get("mass", 1)) > 5: return false
		if float(item.get("props", {}).get("radius", 17)) < 8 or float(item.get("props", {}).get("radius", 17)) > 30: return false
		var limits := {"length": [40, 220], "thickness": [6, 36], "friction": [0, 1], "bounce": [0, 1], "range": [30, 400], "strength": [0, 2400], "half_width": [20, 100]}
		for key in limits:
			if item.get("props", {}).has(key) and (item.props[key] < limits[key][0] or item.props[key] > limits[key][1]): return false
	for spring in data.springs:
		if not spring is Dictionary: return false
		for key in ["a", "b"]:
			var end = spring.get(key)
			if not end is Dictionary or not finite_number(end.get("id")) or not pair(end.get("p")): return false
			if int(end.id) != 0 and not ids.has(int(end.id)): return false
		for key in ["rest", "k", "damp"]:
			if not finite_number(spring.get(key)): return false
	return true
