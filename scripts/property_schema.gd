extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")

static func rows(kind: String) -> Array:
	match kind:
		"ball": return [["radius", "大小", 10.0, 30.0, 1.0], ["mass", "重量", 0.25, 5.0, 0.05], ["bounce", "弹性", 0.1, 0.9, 0.05]]
		"ramp": return [["length", "长度", 80.0, 200.0, 4.0], ["thickness", "厚度", 8.0, 30.0, 2.0], ["friction", "粗糙程度", 0.1, 1.0, 0.05]]
		"fan": return [["strength", "风力", 0.0, 2400.0, 50.0], ["range", "送风距离", 120.0, 320.0, 10.0]]
		"magnet": return [["strength", "吸力", 0.0, 2200.0, 50.0], ["range", "作用范围", 80.0, 220.0, 10.0]]
		"spring": return [["rest", "自然长度", 30.0, 400.0, 5.0], ["k", "松紧", 10.0, 65.0, 1.0], ["damp", "阻尼", 1.0, 12.0, 0.2]]
	return []

static func defaults(kind: String) -> Dictionary:
	if kind == "spring": return {"rest": 110.0, "k": 34.0, "damp": 4.8}
	return Catalog.item(kind).duplicate(true)

static func format_value(key: String, value: float) -> String:
	match key:
		"mass": return "%.2f kg" % value
		"radius": return "%.1f ×" % (value / 17.0)
		"length": return "%.1f ×" % (value / 132.0)
		"thickness": return "%.1f ×" % (value / 14.0)
		"strength": return "%d %%" % roundi(value / 1250.0 * 100)
		"range", "rest": return "%.1f ×" % (value / 150.0)
		"bounce", "friction": return "%d %%" % roundi(value * 100)
		"k": return "%.1f ×" % (value / 34.0)
		"damp": return "%.1f ×" % (value / 4.8)
	return str(value)

static func hint(kind: String) -> String:
	match kind:
		"ball": return "变重后，同样的风更难托起它。"
		"ramp": return "越粗糙，滑动越容易慢下来。"
		"fan": return "风力越大，小球越容易被托起。"
		"magnet": return "吸力越强，小球的轨迹越容易偏转。"
		"spring": return "越紧的弹簧，越不容易被拉长。"
	return ""
