extends SceneTree
const App = preload("res://scripts/app.gd")
var app: Node2D
var failures: Array[String] = []
var metrics: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	if not ok: failures.append(note); printerr(note)
func ticks(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func touch(p: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = p
	event.pressed = pressed
	root.push_input(event, true)
func drag(p: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = p
	root.push_input(event, true)
func run() -> void:
	app = App.new()
	root.add_child(app)
	await ticks(3)
	app.motion_enabled = false
	var world = app.world
	world.clear()
	world.set_paused(true)
	var ball = world.spawn("ball", Vector2(170, 350))
	var other = world.spawn("ball", Vector2(300, 450))
	world.select(ball.uid)
	app.open_editor()
	await ticks(3)
	var start: Vector2 = ball.position
	var count: int = app.history.size()
	app.draft_set("mass", 2.0)
	touch(app.world_to_screen(ball.position), true)
	drag(app.world_to_screen(ball.position + Vector2(40, -60)))
	await ticks(20)
	touch(app.world_to_screen(ball.position), false)
	check(ball.position.distance_to(start) > 40 and app.modal == "properties", "drag selected ball while sheet remains open")
	check(app.edit_id == ball.uid and ball.mass == 2, "editor target and live mass preserved")
	touch(app.world_to_screen(other.position), true)
	drag(app.world_to_screen(other.position + Vector2(-25, -60)))
	await ticks(20)
	touch(app.world_to_screen(other.position), false)
	check(app.edit_id == ball.uid and world.selected_id == ball.uid, "dragging another body never switches parameter target")
	app.close_editor(true)
	check(app.history.size() == count + 1, "all trial drags and parameter edits share one undo")
	app.action("undo")
	ball = world.bodies.values()[0]
	other = world.bodies.values()[1]
	check(ball.position == start and ball.mass == 1 and other.position == Vector2(300, 450), "undo restores whole experiment")
	world.select(ball.uid)
	app.open_editor()
	await ticks(3)
	touch(app.world_to_screen(other.position), true)
	await ticks(34)
	check(app.edit_id == other.uid and app.modal == "properties", "long press another object switches editor")
	world.set_paused(false)
	var moving_start: Vector2 = other.position
	touch(app.world_to_screen(other.position), true)
	drag(app.world_to_screen(other.position + Vector2(-60, -70)))
	await ticks(20)
	touch(app.world_to_screen(other.position), false)
	check(other.position.distance_to(moving_start) > 25 and not other.held and app.modal == "properties", "running simulation supports editor drag and release")
	app.close_editor(true)
	print(JSON.stringify({"failures": failures, "metrics": metrics}))
	var file := FileAccess.open("res://tests/editor-interaction-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "metrics": metrics}, "\t"))
	quit(0 if failures.is_empty() else 1)

