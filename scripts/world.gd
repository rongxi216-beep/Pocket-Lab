extends Node2D
const Body = preload("res://scripts/lab_body.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Fields = preload("res://scripts/fields.gd")
signal impact(at: Vector2, strength: float)
signal physical_event(kind: String, intensity: float)
signal material_impact(material: String, intensity: float)
var bodies: Dictionary = {}
var springs: Array = []
var next_id := 1
var bounds := Rect2(24, 166, 402, 508)
var walls: StaticBody2D
var paused := false
var show_fields := true
var selected_id := 0
var selected_spring := -1
var pulses: Array = []
var providers: Dictionary = {"magnet": Fields.magnetic, "fan": Fields.wind}
var event_times: Dictionary = {}

func _ready() -> void:
	walls = StaticBody2D.new()
	walls.collision_layer = 2
	walls.collision_mask = 1
	add_child(walls)
	set_bounds(bounds)

func set_bounds(rect: Rect2) -> void:
	bounds = rect
	if not is_instance_valid(walls):
		return
	for child in walls.get_children():
		walls.remove_child(child)
		child.queue_free()
	var boxes := [Rect2(rect.position - Vector2(12, 12), Vector2(rect.size.x + 24, 12)),
		Rect2(rect.position + Vector2(-12, 0), Vector2(12, rect.size.y)),
		Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(12, rect.size.y)),
		Rect2(rect.position + Vector2(0, rect.size.y), Vector2(rect.size.x, 16))]
	for box in boxes:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = box.size
		collision.shape = shape
		collision.position = box.get_center()
		walls.add_child(collision)

func ball_count() -> int:
	var count := 0
	for body in bodies.values():
		if body.kind == "ball": count += 1
	return count

func clamp_position(p: Vector2, margin: float = 26) -> Vector2:
	return p.clamp(bounds.position + Vector2.ONE * margin, bounds.end - Vector2.ONE * margin)

func free_position(p: Vector2, kind: String, props: Dictionary = {}) -> Vector2:
	# Conservative circles also protect long rotated fixtures during placement.
	var radius := Vector2(props.get("length", 132) / 2.0, props.get("thickness", 14) / 2.0).length() + 3 if kind == "ramp" else (float(props.get("radius", 17)) + 1 if kind == "ball" else 27.0)
	for attempt in 90:
		var offset := Vector2.from_angle(attempt * 2.4) * sqrt(float(attempt)) * 15
		var candidate := clamp_position(p + offset, radius)
		var valid := true
		for body in bodies.values():
			var other: float = body.bounding_radius() + 1
			if candidate.distance_to(body.position) < radius + other + 3:
				valid = false
				break
		if valid: return candidate
	return Vector2.INF

func spawn(kind: String, p: Vector2, angle: float = 0, properties: Dictionary = {}, uid: int = 0) -> Node2D:
	if kind not in ["ball", "ramp", "magnet", "fan"]: return null
	var balls := ball_count()
	if (kind == "ball" and balls >= Catalog.data().max_balls) or (kind != "ball" and bodies.size() - balls >= Catalog.data().max_fixtures):
		return null
	var body := Body.new()
	body.kind = kind
	body.uid = next_id if uid == 0 else uid
	next_id = maxi(next_id, body.uid + 1)
	body.props = properties.duplicate(true)
	body.position = clamp_position(p, float(properties.get("radius", 17)) + 1 if kind == "ball" else 28)
	body.rotation = angle
	body.home = body.position
	body.home_angle = angle
	add_child(body)
	bodies[body.uid] = body
	body.impact.connect(func(at: Vector2, strength: float):
		if not paused:
			if pulses.size() < 16: pulses.append({"p": at, "life": 0.0, "strength": strength})
			impact.emit(at, strength))
	body.material_impact.connect(func(material: String, intensity: float):
		if not paused: material_impact.emit(material, intensity))
	if paused: body.freeze = true
	return body

func fits(id: int, p: Vector2, values: Dictionary, angle: float) -> bool:
	if not bodies.has(id): return false
	var body = bodies[id]
	var shape: Shape2D
	var extents := Vector2.ONE * 25
	if body.kind == "ramp":
		shape = RectangleShape2D.new()
		shape.size = Vector2(values.length, values.get("thickness", 14))
		var half: Vector2 = shape.size / 2
		extents = Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y, absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	else:
		shape = CircleShape2D.new()
		shape.radius = float(values.get("radius", 17)) if body.kind == "ball" else 25.0
		extents = Vector2.ONE * shape.radius
	if p.x - extents.x < bounds.position.x or p.x + extents.x > bounds.end.x or p.y - extents.y < bounds.position.y or p.y + extents.y > bounds.end.y: return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(angle, p)
	query.collision_mask = 3
	query.exclude = [body.get_rid()]
	query.margin = 0.1
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func rotation_in_bounds(body: Node2D, angle: float) -> bool:
	var extents := Vector2.ONE * 26
	if body.kind == "ramp":
		var half := Vector2(body.props.length / 2, body.props.get("thickness", 14) / 2)
		extents = Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y, absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	return body.position.x - extents.x >= bounds.position.x and body.position.x + extents.x <= bounds.end.x and body.position.y - extents.y >= bounds.position.y and body.position.y + extents.y <= bounds.end.y

func find_edit_position(id: int, values: Dictionary) -> Vector2:
	if not bodies.has(id): return Vector2.INF
	var body = bodies[id]
	if fits(id, body.position, values, body.rotation): return body.position
	# Keep resized objects near the original place, never silently across the room.
	for attempt in 64:
		var p: Vector2 = body.position + Vector2.from_angle(attempt * 2.4) * sqrt(float(attempt + 1)) * 5
		if fits(id, p, values, body.rotation): return p
	return Vector2.INF

func endpoint(p: Vector2) -> Dictionary:
	var id := hit_body(p)
	if id != 0: return {"id": id, "p": [0.0, 0.0]}
	var point := clamp_position(p, 8)
	return {"id": 0, "p": [point.x, point.y]}

func endpoint_position(point: Dictionary, interpolated: bool = false) -> Vector2:
	var offset := Vector2(point.p[0], point.p[1])
	if int(point.id) == 0: return offset
	if not bodies.has(int(point.id)): return offset
	var body: Node2D = bodies[int(point.id)]
	return body.visual_transform() * offset if interpolated else body.to_global(offset)

func endpoint_velocity(point: Dictionary) -> Vector2:
	if int(point.id) == 0 or not bodies.has(int(point.id)): return Vector2.ZERO
	return bodies[int(point.id)].linear_velocity

func connect_points(a: Dictionary, b: Dictionary, rest: float = -1, restoring: bool = false) -> bool:
	if springs.size() >= Catalog.data().max_springs: return false
	if int(a.id) == int(b.id): return false
	if int(a.id) != 0 and not bodies.has(int(a.id)): return false
	if int(b.id) != 0 and not bodies.has(int(b.id)): return false
	var dynamic_end := false
	for point in [a, b]:
		if int(point.id) != 0 and bodies[int(point.id)].kind == "ball": dynamic_end = true
	if not dynamic_end: return false
	var distance := endpoint_position(a).distance_to(endpoint_position(b))
	if not restoring and (distance < 20 or distance > 550): return false
	for spring in springs:
		if (spring.a == a and spring.b == b) or (spring.a == b and spring.b == a): return false
	springs.append({"a": a.duplicate(true), "b": b.duplicate(true),
		"rest": clampf(distance if rest < 0 else rest, 30, 400), "k": 34.0, "damp": 4.8})
	return true

func remove_body(id: int) -> void:
	if not bodies.has(id): return
	for index in range(springs.size() - 1, -1, -1):
		if int(springs[index].a.id) == id or int(springs[index].b.id) == id: springs.remove_at(index)
	var body: Node = bodies[id]
	bodies.erase(id)
	remove_child(body)
	body.queue_free()
	selected_id = 0
	selected_spring = -1

func clear() -> void:
	for id in bodies.keys(): remove_body(id)
	springs.clear()
	pulses.clear()
	event_times.clear()
	next_id = 1

func set_paused(value: bool) -> void:
	paused = value
	for body in bodies.values():
		body.freeze = value or body.kind != "ball"
		body.art.active = not value
		if body.kind == "ball" and not value: body.sleeping = false

func select(id: int, spring_index: int = -1) -> void:
	selected_id = id
	selected_spring = spring_index
	for body in bodies.values():
		body.art.selected = body.uid == id
		body.art.queue_redraw()

func hit_body(p: Vector2) -> int:
	var ids := bodies.keys()
	ids.reverse()
	for id in ids:
		var body: Node2D = bodies[id]
		var local := body.to_local(p)
		if body.kind == "ramp":
			var dimensions := Vector2(body.props.length + 14, maxf(body.props.get("thickness", 14) + 14, 42))
			if Rect2(-dimensions / 2, dimensions).has_point(local): return id
		elif local.length() < maxf(28, body.bounding_radius() + 7): return id
	return 0

func hit_spring(p: Vector2) -> int:
	for i in springs.size():
		var a := endpoint_position(springs[i].a)
		var b := endpoint_position(springs[i].b)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 17: return i
	return -1

func _physics_process(_delta: float) -> void:
	if paused: return
	var balls: Array = []
	var fields: Array = []
	for body in bodies.values():
		if body.kind == "ball": balls.append(body)
		elif providers.has(body.kind): fields.append(body)
	for ball in balls:
		var total := Vector2.ZERO
		for field in fields:
			total += providers[field.kind].call(field, ball)
			if field.kind == "magnet" and field.position.distance_to(ball.position) < 48 and ball.linear_velocity.length() > 70:
				emit_physical_event("magnet", 0.25)
		if total.length_squared() > 1:
			ball.sleeping = false
			ball.apply_central_force(total.limit_length(5000))
	for spring in springs:
		var a := endpoint_position(spring.a)
		var b := endpoint_position(spring.b)
		var offset := b - a
		var distance := offset.length()
		if distance < 0.01: continue
		var direction := offset / distance
		var relative := (endpoint_velocity(spring.b) - endpoint_velocity(spring.a)).dot(direction)
		# Hooke + axial damping + capped progressive resistance beyond 2.5x rest.
		var extension: float = distance - spring.rest
		var extra := maxf(distance - spring.rest * 2.5, 0) * 40.0
		var force := direction * clampf(spring.k * extension + spring.damp * relative + extra, -4500, 4500)
		if distance > spring.rest * 1.6 and absf(relative) > 90: emit_physical_event("spring", 0.2)
		apply_endpoint_force(spring.a, force)
		apply_endpoint_force(spring.b, -force)

func emit_physical_event(kind: String, intensity: float) -> void:
	var now := Time.get_ticks_msec()
	if now - int(event_times.get(kind, -2000)) > 1200:
		event_times[kind] = now
		physical_event.emit(kind, intensity)

func apply_endpoint_force(point: Dictionary, force: Vector2) -> void:
	if int(point.id) == 0 or not bodies.has(int(point.id)): return
	var body: RigidBody2D = bodies[int(point.id)]
	if body.kind == "ball":
		if force.length_squared() > 4: body.sleeping = false
		body.apply_central_force(force)

func snapshot() -> Dictionary:
	var items: Array = []
	for body in bodies.values(): items.append(body.serialize())
	return {"version": 1, "scene": "desktop", "items": items, "springs": springs.duplicate(true),
		"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "paused": paused}

func restore(data: Dictionary) -> void:
	clear()
	var old_rect: Array = data.get("bounds", [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y])
	var origin := Vector2(old_rect[0], old_rect[1])
	var size_before := Vector2(maxf(old_rect[2], 1), maxf(old_rect[3], 1))
	for item in data.get("items", []):
		var point := Vector2(item.p[0], item.p[1])
		point = bounds.position + (point - origin) / size_before * bounds.size
		var body = spawn(item.kind, point, float(item.get("angle", 0)), item.get("props", {}), int(item.id))
		if body == null: continue
		var home_data: Array = item.get("home", item.p)
		body.home = clamp_position(bounds.position + (Vector2(home_data[0], home_data[1]) - origin) / size_before * bounds.size)
		body.home_angle = float(item.get("home_angle", body.rotation))
		var velocity: Array = item.get("v", [0, 0])
		body.linear_velocity = Vector2(velocity[0], velocity[1]).limit_length(1100)
		body.angular_velocity = clampf(float(item.get("spin", 0)), -35, 35)
		body.reset_physics_interpolation()
	for source in data.get("springs", []):
		var spring: Dictionary = source.duplicate(true)
		for point in [spring.a, spring.b]:
			if int(point.id) == 0:
				var position_new := clamp_position(bounds.position + (Vector2(point.p[0], point.p[1]) - origin) / size_before * bounds.size, 8)
				point.p = [position_new.x, position_new.y]
		if connect_points(spring.a, spring.b, float(spring.rest), true):
			springs[-1].k = clampf(float(spring.get("k", 34)), 5, 70)
			springs[-1].damp = clampf(float(spring.get("damp", 4.8)), 1, 15)
	set_paused(bool(data.get("paused", false)))

func _process(delta: float) -> void:
	for i in range(pulses.size() - 1, -1, -1):
		pulses[i].life += delta
		if pulses[i].life > 0.35: pulses.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if show_fields:
		for body in bodies.values():
			if body.kind == "magnet":
				for fraction in [0.45, 0.75, 1.0]:
					draw_arc(body.position, body.props.range * fraction, 0, TAU, 64, Color(0.79, 0.5, 0.48, 0.07 if body.uid != selected_id else 0.16), 1, true)
			elif body.kind == "fan" and body.props.strength > 0:
				var direction := Vector2.UP.rotated(body.rotation)
				var side := direction.orthogonal()
				var distance: float = body.props.range
				var width: float = body.props.half_width
				draw_colored_polygon(PackedVector2Array([body.position - side * width, body.position + side * width,
					body.position + direction * distance + side * (width + distance * 0.12), body.position + direction * distance - side * (width + distance * 0.12)]), Color(0.5, 0.75, 0.76, 0.035))
				for lane in [-1, 0, 1]:
					var travel := fmod(Time.get_ticks_msec() * 0.045 * body.props.strength / 1250.0 + lane * 53, distance - 50) + 32 if not paused else 85.0
					var p: Vector2 = body.position + side * lane * 21 + direction * travel
					draw_line(p, p + direction * 16, Color(0.35, 0.57, 0.53, 0.35), 1.5, true)
	for index in springs.size():
		var spring: Dictionary = springs[index]
		var a := endpoint_position(spring.a, true)
		var b := endpoint_position(spring.b, true)
		var direction := (b - a).normalized()
		var side := direction.orthogonal()
		var points := PackedVector2Array([a, a + direction * 10])
		for i in 17:
			points.append(a.lerp(b, 0.09 + i * 0.82 / 16) + side * (6 if i % 2 == 0 else -6))
		points.append(b - direction * 10)
		points.append(b)
		draw_polyline(points, Color("486f61") if index == selected_spring else Color("6a9581"), 3.5, true)
		draw_polyline(points, Color("c7dfb7"), 1.3, true)
		for p in [a, b]:
			draw_circle(p, 5.5, Color("6e9687"))
			draw_circle(p, 2.6, Color("faf0d3"))
	for pulse in pulses:
		var progress: float = pulse.life / 0.35
		draw_arc(pulse.p, 18 + progress * 19, 0, TAU, 32, Color(0.8, 0.89, 0.82, (1 - progress) * 0.3), 1, true)
