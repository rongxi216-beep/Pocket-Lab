extends RefCounted
## Content definitions are separate from simulation and storage.
const CONFIG = preload("res://content/desktop.json")

static func data() -> Dictionary:
	return CONFIG.data

static func item(kind: String) -> Dictionary:
	return data().items.get(kind, {})
