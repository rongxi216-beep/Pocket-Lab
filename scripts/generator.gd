extends RefCounted
## Templates establish meaningful structures; seeded variations preserve clearance.
static func generate(bounds: Rect2, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var items: Array = []
	var springs: Array = []
	var template := rng.randi_range(0, 4)
	var points: Array = []
	match template:
		0: points = [["ball", 0.34, 0.32], ["ramp", 0.52, 0.72], ["fan", 0.8, 0.86], ["ball", 0.7, 0.18]]
		1: points = [["ball", 0.5, 0.4], ["magnet", 0.26, 0.71], ["ramp", 0.68, 0.84]]
		2: points = [["ball", 0.32, 0.3], ["ball", 0.67, 0.42], ["fan", 0.65, 0.85], ["ramp", 0.27, 0.7]]
		3: points = [["ball", 0.28, 0.19], ["ball", 0.68, 0.16], ["ramp", 0.44, 0.46], ["fan", 0.79, 0.82]]
		4: points = [["magnet", 0.24, 0.62], ["ball", 0.4, 0.3], ["ball", 0.7, 0.24], ["ramp", 0.62, 0.8]]
	for entry in points:
		var p: Vector2 = bounds.position + Vector2(entry[1], entry[2]) * bounds.size + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var radius := 72.0 if entry[0] == "ramp" else 27.0
		p = p.clamp(bounds.position + Vector2.ONE * radius, bounds.end - Vector2.ONE * radius)
		# Deterministic bounded search for clearance, including short phone viewports.
		for attempt in 80:
			var overlapping := false
			for previous in items:
				var other_radius := 72.0 if previous.kind == "ramp" else 27.0
				if p.distance_to(Vector2(previous.p[0], previous.p[1])) < radius + other_radius + 4:
					overlapping = true
					break
			if not overlapping: break
			p = bounds.position + Vector2(rng.randf_range(radius, bounds.size.x - radius), rng.randf_range(radius, bounds.size.y - radius))
		var angle := rng.randf_range(-0.35, 0.35) if entry[0] == "ramp" else (rng.randf_range(-0.35, 0.1) if entry[0] == "fan" else 0.0)
		items.append({"id": items.size() + 1, "kind": entry[0], "p": [p.x, p.y], "home": [p.x, p.y],
			"angle": angle, "home_angle": angle, "v": [0, 0], "spin": 0, "props": {}})
	var anchor := bounds.position + Vector2(bounds.size.x * 0.35, 30)
	if template == 0 or template == 1:
		var p := Vector2(items[0].p[0], items[0].p[1])
		springs.append(link({"id": 0, "p": [anchor.x, anchor.y]}, {"id": 1, "p": [0, 0]}, anchor.distance_to(p) * 0.75))
		if template == 1:
			anchor.x = bounds.end.x - 60
			springs.append(link({"id": 0, "p": [anchor.x, anchor.y]}, {"id": 1, "p": [0, 0]}, anchor.distance_to(p) * 0.8))
	elif template == 2:
		springs.append(link({"id": 1, "p": [0, 0]}, {"id": 2, "p": [0, 0]}, 115))
	return {"version": 1, "scene": "desktop", "seed": seed_value, "template": template, "items": items,
		"springs": springs, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "paused": false}

static func link(a: Dictionary, b: Dictionary, rest: float) -> Dictionary:
	return {"a": a, "b": b, "rest": rest, "k": 34.0, "damp": 4.8}
