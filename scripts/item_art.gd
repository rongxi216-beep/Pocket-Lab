extends Node2D
## Original rounded laboratory toys; appearance follows real dimensions.
const LabTheme = preload("res://scripts/lab_theme.gd")
var kind := "ball"
var props: Dictionary = {}
var selected := false
var phase := 0.0
var active := true

func _process(delta: float) -> void:
	if kind == "fan" and active:
		phase += delta * 5.0 * float(props.get("strength", 1250)) / 1250.0
		queue_redraw()

func _draw() -> void:
	paint(self, kind, Vector2.ZERO, 1.0, phase, props)
	if selected:
		var radius := float(props.get("radius", 17)) + 9 if kind == "ball" else 34.0
		if kind == "ramp": radius = float(props.get("length", 132)) / 2 + 9
		draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color(LabTheme.INK, 0.42), 1.5, true)

static func paint(c: CanvasItem, type: String, p: Vector2, scale_factor: float = 1.0, t: float = 0.0, values: Dictionary = {}) -> void:
	c.draw_set_transform(p, 0, Vector2.ONE * scale_factor)
	match type:
		"ball":
			var r: float = values.get("radius", 17)
			c.draw_circle(Vector2(1, 3), r + 1, Color(0.30, 0.40, 0.34, 0.13))
			c.draw_circle(Vector2.ZERO, r, Color("779b9d"))
			c.draw_circle(Vector2(0, -1), r - 2, Color("aed6d9"))
			c.draw_arc(Vector2.ZERO, r - 5, -2.8, -1.4, 20, Color("ecf9f0"), 3, true)
			draw_mass_marks(c, r, float(values.get("mass", 1)))
			c.draw_arc(Vector2.ZERO, r - 4, 0.1, 1.4, 16, Color("8cb9bf"), 2, true)
			c.draw_circle(Vector2(r * 0.23, r * 0.18), maxf(2, r * 0.12), Color("759fa4"))
		"ramp":
			var length: float = values.get("length", 132)
			var thickness: float = values.get("thickness", 14)
			LabTheme.panel(c, Rect2(-length / 2, -thickness / 2, length, thickness), Color("e8bc85"), 5, Color("b88b61"), true)
			c.draw_line(Vector2(-length / 2 + 8, -thickness / 2 + 3), Vector2(length / 2 - 8, -thickness / 2 + 3), Color("ffe4b8"), 2, true)
			for side in [-1, 1]:
				c.draw_circle(Vector2(side * (length / 2 - 9), 0), 2, Color("af855e"))
			for i in 3:
				var x := -length * 0.23 + i * length * 0.23
				c.draw_line(Vector2(x - 4, 1), Vector2(x + 4, 1), Color("d5a370"), 1, true)
		"magnet":
			c.draw_arc(Vector2(0, 2), 15, 0, PI, 32, Color("b87860"), 15, true)
			c.draw_arc(Vector2.ZERO, 15, 0, PI, 32, Color("e5a084"), 12, true)
			for x in [-15, 15]:
				LabTheme.panel(c, Rect2(x - 7, -20, 14, 22), Color("e5a084"), 4)
				LabTheme.panel(c, Rect2(x - 7, -21, 14, 9), Color("faf0d3"), 3, Color("bda88b"))
				c.draw_line(Vector2(x - 3, -9), Vector2(x - 3, 1), Color("f7c2a1"), 2, true)
			c.draw_circle(Vector2(0, 16), 2.4, Color("fff0c6"))
		"fan":
			LabTheme.panel(c, Rect2(-12, 15, 24, 13), Color("bad1bf"), 5, Color("7fa999"))
			c.draw_circle(Vector2(0, 1), 25, Color("6d9b8d"))
			c.draw_circle(Vector2.ZERO, 23, Color("ecedd6"))
			c.draw_circle(Vector2.ZERO, 18, Color("c3ddd0"))
			for i in 3:
				var angle := t + i * TAU / 3.0
				var points := PackedVector2Array()
				for j in 20:
					var phi := j * TAU / 20
					points.append((Vector2(9, 0) + Vector2(cos(phi) * 8, sin(phi) * 5)).rotated(angle))
				c.draw_colored_polygon(points, Color("83b7a8"))
			c.draw_circle(Vector2.ZERO, 5, Color("fbebc9"))
			c.draw_arc(Vector2.ZERO, 20, -2.8, -1.2, 16, Color("fffcec"), 2, true)
			c.draw_circle(Vector2(0, 23), 1.7, Color("f5bd73"))
			c.draw_polyline(PackedVector2Array([Vector2(-4, -33), Vector2(0, -38), Vector2(4, -33)]), LabTheme.INK, 2, true)
		"spring":
			var points := PackedVector2Array([Vector2(0, -24)])
			for i in 10: points.append(Vector2(8 if i % 2 == 0 else -8, -20 + i * 4.4))
			points.append(Vector2(0, 24))
			c.draw_polyline(points, Color("668d7f"), 4, true)
			c.draw_polyline(points, Color("a9cbb0"), 2, true)
			for y in [-25, 25]:
				c.draw_circle(Vector2(0, y), 4, Color("6e9687"))
				c.draw_circle(Vector2(0, y), 2, LabTheme.PAPER)
	c.draw_set_transform(Vector2.ZERO)

static func draw_mass_marks(c: CanvasItem, r: float, mass_value: float) -> void:
	var dots := clampi(ceili(mass_value), 1, 5)
	for i in dots:
		c.draw_circle(Vector2((i - (dots - 1) * 0.5) * 3.5, r * 0.58), 1.2, Color("557f81"))

