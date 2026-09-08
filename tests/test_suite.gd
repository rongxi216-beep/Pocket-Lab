extends SceneTree
const App = preload("res://scripts/app.gd")
const Generator = preload("res://scripts/generator.gd")
const Storage = preload("res://scripts/storage.gd")
const Fields = preload("res://scripts/fields.gd")
var app: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	app = App.new()
	root.add_child(app)
	await process_frame
	app.feedback.haptics = false
	var world = app.world
	# Use the original canonical test arena so physics assertions are layout-independent.
	world.set_bounds(Rect2(24, 158, 402, 502))
	print("TEST generator: determinism, validity, clearance, bounded counts")
	for height in [300.0, 502.0, 680.0]:
		var bounds := Rect2(24, 158, 402, height)
		for seed_value in 150:
			var scene := Generator.generate(bounds, seed_value)
			check(scene == Generator.generate(bounds, seed_value), "deterministic seed %d" % seed_value)
			check(Storage.valid_scene(scene), "valid generated schema")
			for i in scene.items.size():
				var item: Dictionary = scene.items[i]
				var p := Vector2(item.p[0], item.p[1])
				var radius := 72.0 if item.kind == "ramp" else 27.0
				check(bounds.grow(-radius + 0.01).has_point(p), "generated object inside bounds")
				for j in i:
					var other: Dictionary = scene.items[j]
					var radius_other := 72.0 if other.kind == "ramp" else 27.0
					check(p.distance_to(Vector2(other.p[0], other.p[1])) >= radius + radius_other + 3.9, "generated clearance")
	print("TEST gravity, floor, ramp and ball collision")
	world.clear()
	world.set_paused(false)
	var ball = world.spawn("ball", Vector2(210, 220))
	await ticks(20)
	check(ball.position.y > 225 and ball.linear_velocity.y > 100, "gravity moves ball")
	await ticks(360)
	check(ball.position.y < world.bounds.end.y and ball.position.y > world.bounds.end.y - 65, "floor contains and settles ball")
	world.clear()
	world.spawn("ramp", Vector2(220, 460), 0.3)
	ball = world.spawn("ball", Vector2(200, 350))
	await ticks(65)
	check(ball.position.x > 220, "ramp changes ball horizontal trajectory")
	world.clear()
	var left = world.spawn("ball", Vector2(175, 300))
	var right = world.spawn("ball", Vector2(275, 300))
	left.gravity_scale = 0
	right.gravity_scale = 0
	left.linear_velocity = Vector2(250, 0)
	await ticks(30)
	check(right.linear_velocity.x > 30, "ball transfers momentum through engine collision")
	print("TEST magnet, wind rotation and force superposition")
	world.clear()
	ball = world.spawn("ball", Vector2(240, 300))
	ball.gravity_scale = 0
	var magnet = world.spawn("magnet", Vector2(330, 300))
	await ticks(15)
	check(ball.linear_velocity.x > 30, "magnet accelerates ball through force")
	world.clear()
	ball = world.spawn("ball", Vector2(220, 370))
	var fan = world.spawn("fan", Vector2(220, 460))
	await ticks(30)
	check(ball.linear_velocity.y < 0, "fan lifts ball against gravity")
	fan.rotation = PI / 2
	ball.position = Vector2(310, 460)
	var wind := Fields.wind(fan, ball)
	check(wind.x > 0 and absf(wind.y) < 1, "rotated fan matches visual direction")
	world.clear()
	ball = world.spawn("ball", Vector2(225, 300))
	ball.gravity_scale = 0
	world.spawn("magnet", Vector2(140, 300))
	world.spawn("magnet", Vector2(310, 300))
	await ticks(25)
	check(absf(ball.linear_velocity.x) < 2, "equal opposing magnets cancel")
	print("TEST spring oscillation, invalid endpoints and cascade deletion")
	world.clear()
	ball = world.spawn("ball", Vector2(225, 380))
	check(world.connect_points({"id": 0, "p": [225, 200]}, {"id": ball.uid, "p": [0, 0]}, 100), "fixed anchor connects")
	var max_y: float = ball.position.y
	var min_y: float = ball.position.y
	var sign_changes := 0
	var previous_v := 0.0
	for i in 150:
		await ticks(1)
		max_y = maxf(max_y, ball.position.y)
		min_y = minf(min_y, ball.position.y)
		if ball.linear_velocity.y * previous_v < 0: sign_changes += 1
		previous_v = ball.linear_velocity.y
	check(max_y - min_y > 35 and sign_changes >= 2, "spring produces physical damped oscillation")
	check(not world.connect_points({"id": ball.uid, "p": [0, 0]}, {"id": ball.uid, "p": [0, 0]}), "self link rejected")
	check(not world.connect_points({"id": 999, "p": [0, 0]}, {"id": ball.uid, "p": [0, 0]}), "dangling link rejected")
	var saved: Dictionary = world.snapshot()
	world.remove_body(ball.uid)
	check(world.springs.is_empty(), "delete removes connected springs")
	world.restore(saved)
	check(world.bodies.size() == 1 and world.springs.size() == 1, "restore connection graph")
	world.set_paused(true)
	ball = world.bodies.values()[0]
	var frozen: Vector2 = ball.position
	await ticks(30)
	check(ball.position.distance_to(frozen) < 0.01, "pause freezes physics")
	world.set_paused(false)
	await ticks(30)
	check(ball.position.distance_to(frozen) > 0.1, "resume restores simulation")
	print("TEST touch palette, dragging, multitouch ownership, actions and undo")
	app.tray_open = true
	world.clear()
	world.set_paused(true)
	await process_frame
	await process_frame
	# Real InputEventScreenTouch through the same GUI entry point as mobile.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = app.hud.palette.ball.get_center()
	app.hud._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = app.world_to_screen(Vector2(180, 300))
	app.hud._gui_input(drag)
	touch.pressed = false
	touch.position = drag.position
	app.hud._gui_input(touch)
	check(world.ball_count() == 1, "touch drag adds ball")
	ball = world.bodies.values()[0]
	var original_id: int = ball.uid
	app.action("duplicate")
	check(world.ball_count() == 2, "duplicate body")
	app.action("delete")
	check(world.ball_count() == 1, "delete body")
	app.action("undo")
	check(world.ball_count() == 2, "undo delete")
	app.action("clear")
	check(world.bodies.is_empty(), "clear scene")
	app.action("undo")
	check(world.ball_count() == 2, "undo clear")
	ball = world.bodies[original_id]
	app.hud.pointer_down(app.world_to_screen(ball.position), 0)
	app.hud.pointer_down(Vector2(340, 350), 1)
	check(app.hud.active_pointer == 0, "second finger cannot steal gesture")
	app.hud.pointer_move(app.world_to_screen(ball.position + Vector2(70, 10)))
	await ticks(20)
	app.hud.pointer_up(app.world_to_screen(ball.position))
	check(ball.position.x > 210, "paused touch drag repositions ball")
	world.set_paused(false)
	app.scene_down(ball.position)
	app.scene_move(Vector2(10000, -10000))
	await ticks(40)
	app.scene_up(Vector2(10000, -10000))
	await ticks(2)
	check(ball.linear_velocity.length() <= 1101 and ball.position.is_finite(), "abnormal touch samples have bounded throw")
	print("TEST persistence, backup recovery, local works and lifecycle")
	var store = Storage.new()
	store.root = "user://tests/suite_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(store.root)
	check(store.write_record("session", {"world": saved}), "write session")
	check(store.write_record("session", {"world": world.snapshot()}), "replace session")
	var corrupt := FileAccess.open(store.root.path_join("session.json"), FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(store.read_record("session").world == JSON.parse_string(JSON.stringify(saved)), "corrupt primary uses valid backup")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.items[0].props = {"mass": "bad"}
	check(not Storage.valid_scene(invalid), "invalid property rejected")
	invalid = saved.duplicate(true)
	invalid.version = 99
	check(not Storage.valid_scene(invalid), "future schema rejected safely")
	app.storage = store
	app.action("shuffle")
	var prior: Dictionary = app.previous.world
	check(store.read_record("previous").has("world"), "shuffle persists prior snapshot")
	app.action("previous")
	check(world.bodies.size() == prior.items.size(), "previous snapshot restored")
	app.works.clear()
	app.action("save_work")
	check(app.works.size() == 1 and store.read_record("works").works.size() == 1, "work saved locally")
	world.clear()
	app.action("work:0")
	check(world.bodies.size() > 0, "saved work opens")
	world.set_paused(false)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(world.paused and app.backgrounded, "background pauses simulation")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not world.paused and not app.backgrounded, "foreground resumes prior state")
	print("TEST maximum load, combined forces, bounds and finite states: 1800 steps")
	world.clear()
	world.set_paused(false)
	world.spawn("fan", Vector2(110, 560), 0.1)
	world.spawn("fan", Vector2(340, 560), -0.3)
	world.spawn("magnet", Vector2(100, 320))
	world.spawn("magnet", Vector2(350, 320))
	world.spawn("ramp", Vector2(225, 450), 0.2)
	for i in 48:
		var body = world.spawn("ball", Vector2(55 + i % 10 * 36, 190 + i / 10 * 38))
		if i < 8: world.connect_points({"id": 0, "p": [body.position.x, 168]}, {"id": body.uid, "p": [0, 0]}, 100)
	check(world.spawn("ball", Vector2(200, 200)) == null, "49th ball rejected")
	var max_speed := 0.0
	for step in 1800:
		await ticks(1)
		if step % 60 == 0:
			for body in world.bodies.values():
				check(body.position.is_finite() and body.linear_velocity.is_finite(), "stress finite state")
				check(world.bounds.grow(20).has_point(body.position), "stress containment")
				max_speed = maxf(max_speed, body.linear_velocity.length())
	check(max_speed <= 1101, "stress speed cap")
	var report := {"engine": Engine.get_version_info().string, "checks": checks, "failures": failures,
		"max_speed": max_speed, "stress_physics_steps": 1800, "mobile_device_tested": false}
	var report_file := FileAccess.open("res://tests/results.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	print("RESULT: %d checks, %d failures; max speed %.2f" % [checks, failures.size(), max_speed])
	quit(0 if failures.is_empty() else 1)
