extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scripts/app.gd").new()
	root.add_child(app)
	await process_frame
	app.world.clear()
	app.world.set_paused(true)
	var a = app.world.spawn("ball", Vector2(164, 379))
	app.world.spawn("ball", Vector2(231, 457))
	app.world.spawn("ball", Vector2(310, 575))
	app.world.spawn("ramp", Vector2(202, 514), 0.23)
	app.world.spawn("magnet", Vector2(102, 565))
	app.world.spawn("fan", Vector2(344, 577), -0.2)
	app.world.connect_points({"id": 0, "p": [126, 270]}, {"id": a.uid, "p": [0, 0]}, 90)
	app.toast_time = 0
	app.world.set_paused(false)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/preview-v3.png")
	app.world.select(a.uid)
	app.open_editor()
	app.draft_set("mass", 2.5)
	app.edit_tab = 1
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/properties-v3.png")
	app.close_editor(false)
	app.modal = "settings"
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/settings-v3.png")
	app.modal = ""
	root.size = Vector2i(450, 800)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/short-screen-v3.png")
	root.size = Vector2i(450, 1000)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tall-screen-v3.png")
	quit()
