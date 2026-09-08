extends RigidBody2D
const Art = preload("res://scripts/item_art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const LabTheme = preload("res://scripts/lab_theme.gd")
signal impact(at: Vector2, strength: float)
signal material_impact(material: String, intensity: float)
var uid := 0
var kind := "ball"
var props: Dictionary = {}
var home := Vector2.ZERO
var home_angle := 0.0
var art: Node2D
var held := false
var drag_target := Vector2.ZERO
var speed_limit := 1100.0
var restore_state: Dictionary = {}
var last_impact := 0
var previous_transform := Transform2D.IDENTITY
var current_transform := Transform2D.IDENTITY
var collider: CollisionShape2D

func _ready() -> void:
	props = Catalog.item(kind).merged(props, true)
	art = Art.new()
	art.kind = kind
	art.props = props
	add_child(art)
	collider = CollisionShape2D.new()
	if kind == "ball":
		var shape := CircleShape2D.new()
		shape.radius = props.radius
		collider.shape = shape
		mass = props.mass
		continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_contact)
		linear_damp = 0.1
		angular_damp = 0.15
		collision_layer = 1
		collision_mask = 3
	else:
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		collision_layer = 2
		collision_mask = 1
		if kind == "ramp":
			var shape := RectangleShape2D.new()
			shape.size = Vector2(props.length, props.get("thickness", 14))
			collider.shape = shape
		else:
			var shape := CircleShape2D.new()
			shape.radius = 25
			collider.shape = shape
	add_child(collider)
	var material := PhysicsMaterial.new()
	material.bounce = float(props.get("bounce", 0.12))
	material.friction = float(props.get("friction", 0.5))
	physics_material_override = material
	reset_physics_interpolation()
	previous_transform = global_transform
	current_transform = global_transform

func _physics_process(_delta: float) -> void:
	previous_transform = current_transform
	current_transform = global_transform

func visual_transform() -> Transform2D:
	return previous_transform.interpolate_with(current_transform, Engine.get_physics_interpolation_fraction())

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not restore_state.is_empty():
		state.transform = Transform2D(float(restore_state.get("angle", 0)), restore_state.position)
		state.linear_velocity = restore_state.get("velocity", Vector2.ZERO).limit_length(speed_limit)
		state.angular_velocity = clampf(float(restore_state.get("spin", 0)), -30, 30)
		restore_state.clear()
		reset_physics_interpolation()
	if held:
		# Stable, mass-aware servo. Never teleport an active dynamic ball.
		var acceleration := (drag_target - state.transform.origin) * 105.0 - state.linear_velocity * 20.5
		state.apply_central_force(acceleration.limit_length(9500) * mass)
	state.linear_velocity = state.linear_velocity.limit_length(speed_limit)
	state.angular_velocity = clampf(state.angular_velocity, -35, 35)

func _on_contact(other: Node) -> void:
	var now := Time.get_ticks_msec()
	var strength := linear_velocity.length()
	if strength > 95 and now - last_impact > 110:
		last_impact = now
		impact.emit(position, strength)
		var material := "wood"
		if other.get("kind") != null: material = LabTheme.material(other.kind)
		material_impact.emit(material, clampf(strength / 650.0 * sqrt(mass), 0.1, 1.0))

func configure(values: Dictionary) -> void:
	props = Catalog.item(kind).merged(values, true)
	if kind == "ball":
		mass = float(props.mass)
		inertia = 0.0
		var shape := CircleShape2D.new()
		shape.radius = float(props.radius)
		collider.shape = shape
	elif kind == "ramp":
		var shape := RectangleShape2D.new()
		shape.size = Vector2(props.length, props.get("thickness", 14))
		collider.shape = shape
	physics_material_override.friction = float(props.get("friction", 0.5))
	physics_material_override.bounce = float(props.get("bounce", 0.12))
	art.props = props
	art.queue_redraw()
	reset_physics_interpolation()
	previous_transform = global_transform
	current_transform = global_transform

func bounding_radius() -> float:
	if kind == "ball": return float(props.radius)
	if kind == "ramp": return Vector2(props.length / 2, props.get("thickness", 14) / 2).length()
	return 26.0

func serialize() -> Dictionary:
	var p: Vector2 = restore_state.get("position", position)
	var v: Vector2 = restore_state.get("velocity", linear_velocity)
	return {"id": uid, "kind": kind, "p": [p.x, p.y], "angle": restore_state.get("angle", rotation),
		"v": [v.x, v.y], "spin": restore_state.get("spin", angular_velocity),
		"home": [home.x, home.y], "home_angle": home_angle, "props": props.duplicate(true)}

