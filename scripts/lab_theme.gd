extends RefCounted
const CONFIG = preload("res://content/desktop_theme.json")
const PAPER = Color("f8f5e9")
const INK = Color("3e645d")
const MUTED = Color("7e968a")
const MINT = Color("81b6a2")
const LINE = Color("cad7c4")
const PEACH = Color("edba93")
const BLUE = Color("a5cbd2")

static func material(kind: String) -> String:
	return CONFIG.data.materials.get(kind, "wood")

static func panel(c: CanvasItem, rect: Rect2, color: Color, radius: int = 16, border: Color = Color.TRANSPARENT, shadow: bool = false) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border.a > 0:
		box.set_border_width_all(2)
		box.border_color = border
	if shadow:
		box.shadow_color = Color(0.25, 0.36, 0.29, 0.12)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 4)
	c.draw_style_box(box, rect)
