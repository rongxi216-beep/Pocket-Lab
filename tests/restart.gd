extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests/restart")
	var app = load("res://scripts/app.gd").new()
	app.storage.root = "user://tests/restart"
	root.add_child(app)
	await process_frame
	if "--write" in OS.get_cmdline_user_args():
		app.world.clear()
		app.world.set_paused(true)
		var ball = app.world.spawn("ball", Vector2(220, 340))
		app.world.spawn("ramp", Vector2(240, 490), 0.3)
		app.world.connect_points({"id": 0, "p": [170, 220]}, {"id": ball.uid, "p": [0, 0]})
		app.feedback.sound = false
		app.feedback.haptics = false
		app.storage.write_record("settings", {"sound": false, "haptics": false, "fields": true})
		app.save_session()
		print("RESTART WRITE PASS")
		quit()
	else:
		var valid: bool = app.world.bodies.size() == 2 and app.world.springs.size() == 1 and app.world.paused and not app.feedback.sound and not app.feedback.haptics
		if valid:
			print("RESTART READ PASS: bodies, connection, paused state, preferences")
		else: printerr("RESTART READ FAIL")
		quit(0 if valid else 1)
