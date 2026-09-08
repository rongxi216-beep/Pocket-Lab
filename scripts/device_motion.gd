extends RefCounted
## Portrait device coordinates -> gentle world acceleration. Units: m/s² -> px/s².
var ready_sample := false
var filtered := Vector3.ZERO
var baseline := Vector3.ZERO
var cooldown := 1.0
var available := false

func reset() -> void:
	ready_sample = false
	cooldown = 1.0

func sample(gravity: Vector3, acceleration: Vector3, delta: float, suppressed: bool = false) -> Dictionary:
	var result := {"acceleration": Vector2.ZERO, "impulse": Vector2.ZERO}
	available = gravity.length() > 0.5 or acceleration.length() > 0.5
	if suppressed or not available or not gravity.is_finite() or not acceleration.is_finite():
		reset()
		return result
	var raw := gravity if gravity.length() > 0.5 else acceleration
	if not ready_sample:
		filtered = raw
		baseline = raw
		ready_sample = true
		return result
	var dt := clampf(delta, 0.0, 0.05)
	cooldown = maxf(0, cooldown - dt)
	filtered = filtered.lerp(raw, 1.0 - exp(-dt / 0.28))
	var tilt := Vector2(filtered.x - baseline.x, baseline.y - filtered.y)
	if tilt.length() > 0.45:
		result.acceleration = (tilt.normalized() * (tilt.length() - 0.45) * 24.0).limit_length(120)
	# Shake only with independent gravity: fallback cannot reliably separate tilt.
	if gravity.length() > 0.5 and acceleration.length() > 0.5:
		var linear := acceleration - gravity
		if linear.length() > 4.5 and cooldown <= 0:
			result.impulse = (Vector2(-linear.x, linear.y) * 5.0).limit_length(45)
			cooldown = 0.9
	return result
