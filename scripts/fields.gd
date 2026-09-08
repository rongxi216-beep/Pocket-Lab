extends RefCounted
## Stateless providers: new force types can join this registry without pair recipes.
static func magnetic(source: Node2D, ball: RigidBody2D) -> Vector2:
	var offset: Vector2 = source.position - ball.position
	var distance := offset.length()
	var radius: float = source.props.range
	if distance >= radius or distance < 1:
		return Vector2.ZERO
	var falloff := pow(1.0 - distance / radius, 1.35)
	return offset / distance * minf(source.props.strength * falloff, 2200)

static func wind(source: Node2D, ball: RigidBody2D) -> Vector2:
	var direction := Vector2.UP.rotated(source.rotation)
	var offset: Vector2 = ball.position - source.position
	var forward := offset.dot(direction)
	var side := absf(offset.cross(direction))
	var width: float = source.props.half_width + forward * 0.12
	if forward < 0 or forward > source.props.range or side > width:
		return Vector2.ZERO
	return direction * source.props.strength * (1.0 - forward / source.props.range) * (1.0 - side / width)
