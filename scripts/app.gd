extends Node2D
const World = preload("res://scripts/world.gd")
const HUD = preload("res://scripts/hud.gd")
const Storage = preload("res://scripts/storage.gd")
const Generator = preload("res://scripts/generator.gd")
const Feedback = preload("res://scripts/feedback.gd")
const LabTheme = preload("res://scripts/lab_theme.gd")
const Schema = preload("res://scripts/property_schema.gd")
const ROOM = preload("res://assets/lab-room-v2.png")
var world: Node2D
var hud: Control
var feedback: Node
var storage = Storage.new()
var history: Array = []
var works: Array = []
var previous: Dictionary = {}
var seed_value := 17
var tray_open := false
var spring_mode := false
var spring_start: Dictionary = {}
var palette_kind := ""
var modal := ""
var library_page := 0
var debug := false
var toast_text := ""
var toast_time := 0.0
var elapsed := 0.0
var autosave := 0.0
var drag_id := 0
var drag_started := false
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
var pointer := Vector2.ZERO
var pre_drag: Dictionary = {}
var backgrounded := false
var paused_before_background := false
var test_mode := false
var press_time := 0.0
var press_spring := -1
var rotating := false
var rotate_offset := 0.0
var edit_kind := ""
var edit_id := 0
var edit_spring := -1
var draft: Dictionary = {}
var edit_before: Dictionary = {}
var edit_was_paused := false
var link_mass := true
var edit_error := ""
var draft_position := Vector2.ZERO
var edit_tab := 0
var edit_changed := false
var motion_enabled := true
var motion = preload("res://scripts/device_motion.gd").new()

func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().canvas_transform.affine_inverse() * p

func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().canvas_transform * p

func update_view() -> void:
	var bounds: Rect2 = world.bounds
	var bottom_y: float = hud.size.y - hud.bottom - (252 if modal == "properties" else (170 if tray_open else 76))
	var available := Rect2(18, 76 + hud.top, hud.size.x - 36, maxf(200, bottom_y - 76 - hud.top))
	var zoom := minf(1.0, minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y))
	get_viewport().canvas_transform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), available.get_center() - bounds.get_center() * zoom)


func _ready() -> void:
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	if test_mode:
		DirAccess.make_dir_recursive_absolute("user://tests")
		storage.root = "user://tests"
	Engine.max_fps = 60
	world = World.new()
	add_child(world)
	feedback = Feedback.new()
	add_child(feedback)
	world.material_impact.connect(func(material: String, intensity: float): feedback.play("impact_" + material, intensity))
	world.physical_event.connect(func(kind: String, intensity: float): feedback.play(kind, intensity))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.app = self
	layer.add_child(hud)
	get_viewport().size_changed.connect(layout)
	layout()
	var record: Dictionary = {} if test_mode else storage.read_record("session")
	if not record.is_empty():
		world.restore(record.world)
		seed_value = int(record.get("seed", 17))
	else:
		world.clear()
		var center: Vector2 = world.bounds.get_center()
		var ball = world.spawn("ball", center - Vector2(35, 90), 0, {"radius": 24.0, "mass": 1.2})
		world.spawn("ramp", center + Vector2(20, 130), 0.18)
		world.connect_points({"id": 0, "p": [center.x, center.y - 235]}, {"id": ball.uid, "p": [0, 0]})
		ball.linear_velocity = Vector2(35, 0)
	var preferences := storage.read_record("settings")
	feedback.sound = bool(preferences.get("sound", false))
	feedback.haptics = bool(preferences.get("haptics", true))
	world.show_fields = bool(preferences.get("fields", true))
	motion_enabled = bool(preferences.get("motion", true))
	var saved = storage.read_record("works").get("works", [])
	if saved is Array:
		for work in saved:
			if work is Dictionary and Storage.valid_scene(work.get("world", {})):
				works.append(work)
	previous = storage.read_record("previous")
	get_tree().auto_accept_quit = false

func layout() -> void:
	var size := get_viewport_rect().size
	hud.size = size
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.y > 0 and safe.size.y > 0:
			top = safe.position.y * size.y / screen.y
			bottom = (screen.y - safe.end.y) * size.y / screen.y
	hud.top = top
	hud.bottom = bottom
	var floor_y := size.y - bottom - 76
	var ceiling := 76 + top
	var rect := Rect2(18, ceiling, size.x - 36, maxf(250, floor_y - ceiling))
	if modal == "properties": close_editor(true)
	if world.bodies.is_empty(): world.set_bounds(rect)
	elif world.bounds != rect:
		cancel_gesture()
		var snapshot: Dictionary = world.snapshot()
		world.set_bounds(rect)
		world.restore(snapshot)
	update_view()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	var room_y: float = 76 + hud.top
	var room_height: float = (world.bounds.end.y - room_y) / 0.782
	draw_texture_rect(ROOM, Rect2(0, room_y, get_viewport_rect().size.x, room_height), false)
	# The visible frame is the collision boundary; shelves are decoration only.
	LabTheme.panel(self, world.bounds, Color(1, 1, 1, 0.035), 10, Color(0.40, 0.58, 0.47, 0.17))
	draw_line(Vector2(world.bounds.position.x, world.bounds.end.y), Vector2(world.bounds.end.x, world.bounds.end.y), Color("c69b70"), 2, true)

func _process(delta: float) -> void:
	if backgrounded: return
	elapsed += delta
	update_view()
	if hud.active_pointer != -99 and not drag_started and not rotating and modal in ["", "properties"] and (drag_id != 0 or press_spring >= 0):
		press_time += delta
		if press_time >= 0.48:
			if modal == "properties":
				var next_id := drag_id
				var next_spring := press_spring
				if next_id != edit_id or next_spring != edit_spring:
					close_editor(true)
					world.select(next_id, next_spring)
					open_editor()
				else: press_time = 0
			else: open_editor()
	toast_time = maxf(0, toast_time - delta)
	autosave += delta
	if autosave > 2.0 and drag_id == 0:
		save_session()
		autosave = 0

func _physics_process(delta: float) -> void:
	var response: Dictionary = motion.sample(Input.get_gravity(), Input.get_accelerometer(), delta, not motion_enabled or backgrounded or world.paused or modal != "" or drag_id != 0 or palette_kind != "")
	if not world.paused:
		for moving in world.bodies.values():
			if moving.kind == "ball":
				if response.acceleration.length() > 0.1:
					moving.sleeping = false
					moving.apply_central_force(response.acceleration * moving.mass)
				if response.impulse.length() > 0.1:
					moving.apply_central_impulse(response.impulse * moving.mass)
	if rotating and world.bodies.has(world.selected_id):
		var body = world.bodies[world.selected_id]
		var target: float = (pointer - body.position).angle() + rotate_offset
		# Small physics-step increments avoid sweeping a whole board in one event.
		var next_angle: float = rotate_toward(body.rotation, target, 4.0 * delta)
		if world.rotation_in_bounds(body, next_angle): body.rotation = next_angle
		return
	if drag_id == 0 or not drag_started or not world.bodies.has(drag_id): return
	var body = world.bodies[drag_id]
	var margin: float = body.bounding_radius() + 2
	var target: Vector2 = world.clamp_position(pointer + drag_offset, margin)
	if body.kind == "ball" and not world.paused:
		body.drag_target = target
		body.held = true
		body.sleeping = false
	else:
		body.position = body.position.move_toward(target, 650 * delta)
		if body.kind == "ball":
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0

func toast(text: String) -> void:
	toast_text = text
	toast_time = 2.8

func push_history(snapshot: Dictionary = {}) -> void:
	var state: Dictionary = world.snapshot() if snapshot.is_empty() else snapshot
	state["seed"] = seed_value
	history.append(state.duplicate(true))
	if history.size() > 24: history.pop_front()

func changed(kind: String = "place") -> void:
	feedback.play(kind)
	save_session()

func save_session() -> void:
	if test_mode or not is_instance_valid(world): return
	var state: Dictionary = world.snapshot()
	if backgrounded: state.paused = paused_before_background
	if not storage.write_record("session", {"world": state, "seed": seed_value}): toast(storage.last_error)

func scene_down(p: Vector2) -> void:
	if not world.bounds.has_point(p): return
	pointer = p
	drag_origin = p
	press_time = 0
	press_spring = -1
	if spring_mode: return
	var id: int = world.hit_body(p)
	press_spring = world.hit_spring(p) if id == 0 else -1
	if modal != "properties": world.select(id, press_spring)
	if id != 0:
		drag_id = id
		drag_offset = world.bodies[id].position - p
		pre_drag = world.snapshot()

func scene_move(p: Vector2) -> void:
	pointer = p
	if p.distance_to(drag_origin) > 7:
		press_spring = -1
		press_time = 0
	if drag_id != 0 and p.distance_to(drag_origin) > 7 and not drag_started:
		drag_started = true
		if modal == "properties": edit_changed = true
		else: push_history(pre_drag)

func scene_up(p: Vector2) -> void:
	if rotating:
		rotating = false
		changed()
		return
	if spring_mode and world.bounds.has_point(p):
		var end: Dictionary = world.endpoint(p)
		if spring_start.is_empty():
			spring_start = end
			feedback.play("place", 0.2)
		else:
			var before: Dictionary = world.snapshot()
			if world.connect_points(spring_start, end):
				push_history(before)
				spring_start.clear()
				spring_mode = false
				world.select(0, world.springs.size() - 1)
				changed("spring")
				toast("连接好了，轻轻拉一下")
			else: toast("至少连接一个小球，并选择不同端点")
	if drag_id != 0 and world.bodies.has(drag_id):
		var body = world.bodies[drag_id]
		body.held = false
		# Release retains servo velocity, bounded independently of touch event rate.
		body.linear_velocity = body.linear_velocity.limit_length(850)
		if drag_started: changed()
	drag_id = 0
	drag_started = false
	press_spring = -1
	press_time = 0

func cancel_gesture() -> void:
	if drag_id != 0 and world.bodies.has(drag_id): world.bodies[drag_id].held = false
	drag_id = 0
	drag_started = false
	rotating = false
	press_spring = -1
	press_time = 0
	palette_kind = ""
	if is_instance_valid(hud):
		hud.active_pointer = -99
		hud.pressed_action = ""
		hud.active_slider = ""
		hud.scene_gesture = false

func place_palette(p: Vector2, tapped: bool) -> void:
	if palette_kind == "spring":
		spring_mode = not spring_mode
		spring_start.clear()
		if spring_mode and not tapped and world.bounds.has_point(p): spring_start = world.endpoint(p)
		world.select(0)
		return
	if not tapped and not world.bounds.has_point(p): return
	var target: Vector2 = world.bounds.get_center() - Vector2(0, world.bounds.size.y * 0.2) if tapped else p
	var point: Vector2 = world.free_position(target, palette_kind)
	if not point.is_finite():
		toast("这里有点挤，先腾一点空间")
		return
	var before: Dictionary = world.snapshot()
	var body = world.spawn(palette_kind, point, 0.2 if palette_kind == "ramp" else 0.0)
	if body == null:
		toast("工具箱已满 · 最多 48 个小球、28 个固定道具")
		return
	push_history(before)
	world.select(body.uid)
	spring_mode = false
	spring_start.clear()
	changed(palette_kind if palette_kind in ["magnet", "fan"] else "place")
	if world.ball_count() >= 40: toast("小球有点多了 · 上限 48 个")

func action(id: String) -> void:
	if id.begins_with("tab:"):
		edit_tab = int(id.split(":")[1])
		return
	if modal == "properties" and id in ["duplicate", "delete", "reset"]:
		close_editor(true)
	if modal == "properties" and id == "pause":
		world.set_paused(not world.paused)
		return
	if id.begins_with("step:") and modal == "properties":
		var parts := id.split(":")
		for row in editor_rows():
			if row[0] == parts[1]: draft_set(row[0], float(draft[row[0]]) + row[4] * int(parts[2]))
		return
	if id == "properties":
		open_editor()
		return
	if id == "apply_properties":
		apply_editor()
		return
	if id == "cancel_properties":
		close_editor(false)
		return
	if id == "default_properties":
		draft = Schema.defaults(edit_kind)
		link_mass = true
		edit_error = ""
		return
	if id == "link_mass":
		link_mass = not link_mass
		return
	if modal == "properties": return
	if id in ["clear", "undo", "shuffle", "previous", "reset_all"] or id.begins_with("work:"):
		spring_mode = false
		spring_start.clear()
	if id.begins_with("work:"):
		push_history()
		var work: Dictionary = works[int(id.split(":")[1])]
		world.restore(work.world)
		seed_value = int(work.get("seed", 17))
		modal = ""
		changed()
		toast("作品已打开 · 撤销可回到刚才")
		return
	match id:
		"pause":
			world.set_paused(not world.paused)
			changed()
		"tray":
			tray_open = not tray_open
			layout()
		"settings", "library":
			modal = id
			world.select(0)
			spring_mode = false
			spring_start.clear()
		"close": modal = ""
		"sound", "haptics", "fields", "debug", "motion":
			match id:
				"sound":
					feedback.sound = not feedback.sound
					if not feedback.sound: feedback.stop_audio()
				"haptics": feedback.haptics = not feedback.haptics
				"fields": world.show_fields = not world.show_fields
				"debug": debug = not debug
				"motion":
					motion_enabled = not motion_enabled
					motion.reset()
			if not storage.write_record("settings", {"sound": feedback.sound, "haptics": feedback.haptics, "fields": world.show_fields, "motion": motion_enabled}): toast(storage.last_error)
		"undo":
			if not history.is_empty():
				var state: Dictionary = history.pop_back()
				world.restore(state)
				seed_value = int(state.get("seed", seed_value))
				changed()
				toast("已回到上一步")
			else: toast("还没有需要撤销的操作")
		"clear":
			modal = ""
			push_history()
			world.clear()
			changed("delete")
			toast("空白也很好 · 可以撤销")
		"shuffle":
			previous = {"world": world.snapshot(), "seed": seed_value}
			if not storage.write_record("previous", previous):
				toast("未能保留当前场景，请稍后重试")
				return
			push_history()
			seed_value = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
			world.restore(Generator.generate(world.bounds, seed_value))
			changed()
			toast("新的偶然 · 撤销可以回到刚才")
		"previous":
			if Storage.valid_scene(previous.get("world", {})):
				push_history()
				world.restore(previous.world)
				seed_value = int(previous.get("seed", 17))
				modal = ""
				changed()
				toast("重新组合前的场景已恢复")
			else:
				modal = ""
				toast("还没有重新组合前的快照")
		"save_work":
			if works.size() >= 40:
				modal = ""
				toast("已保存 40 件作品，暂时达到本地作品上限")
				return
			var title := "实验 %02d · " % (works.size() + 1) + Time.get_datetime_string_from_system().replace("T", " ").substr(5, 11)
			works.push_front({"title": title, "world": world.snapshot(), "seed": seed_value})
			if not storage.write_record("works", {"version": 1, "works": works}):
				works.pop_front()
				modal = ""
				toast(storage.last_error)
				return
			library_page = 0
			feedback.play()
		"page_prev": library_page = maxi(0, library_page - 1)
		"page_next": library_page = mini(maxi(0, ceili(works.size() / 4.0) - 1), library_page + 1)
		"reset_all":
			push_history()
			for body in world.bodies.values(): reset_body(body)
			modal = ""
			changed()
		"delete":
			push_history()
			if world.selected_id != 0: world.remove_body(world.selected_id)
			elif world.selected_spring >= 0:
				world.springs.remove_at(world.selected_spring)
				world.select(0)
			changed("delete")
			toast("已移除 · 可以撤销")
		"duplicate", "reset", "rotate_left", "rotate_right": modify_selected(id)

func modify_selected(action_id: String) -> void:
	var body = world.bodies.get(world.selected_id)
	if body == null: return
	if action_id == "duplicate":
		var p: Vector2 = world.free_position(body.position + Vector2(42, -42), body.kind, body.props)
		if not p.is_finite():
			toast("这里有点挤，先腾一点空间")
			return
		var before: Dictionary = world.snapshot()
		var copy = world.spawn(body.kind, p, body.rotation, body.props)
		if copy == null:
			toast("道具数量已达上限")
			return
		push_history(before)
		world.select(copy.uid)
	else:
		push_history()
		if action_id == "reset": reset_body(body)
		else:
			var angle: float = body.rotation + deg_to_rad(-15 if action_id == "rotate_left" else 15)
			if body.kind == "ball" and not world.paused:
				body.restore_state = {"position": body.position, "angle": angle, "velocity": body.linear_velocity, "spin": body.angular_velocity}
				body.sleeping = false
			else: body.rotation = angle
	changed()

func reset_body(body: Node2D) -> void:
	var reset_position: Vector2 = world.clamp_position(body.home, body.bounding_radius() + 2)
	if body.kind == "ball" and not world.paused:
		body.restore_state = {"position": reset_position, "angle": body.home_angle, "velocity": Vector2.ZERO, "spin": 0}
		body.sleeping = false
	else:
		body.position = reset_position
		body.rotation = body.home_angle
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0
		body.reset_physics_interpolation()

func _notification(what: int) -> void:
	if not is_instance_valid(world): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if backgrounded: return
		cancel_gesture()
		save_session()
		motion.reset()
		paused_before_background = world.paused
		world.set_paused(true)
		feedback.stop_audio()
		backgrounded = true
		Engine.max_fps = 10
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not backgrounded: return
		motion.reset()
		backgrounded = false
		world.set_paused(paused_before_background)
		Engine.max_fps = 60
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal == "properties":
			close_editor(true)
			return
		if modal != "":
			modal = ""
			return
		if backgrounded: world.set_paused(paused_before_background)
		save_session()
		get_tree().quit()

func editor_rows() -> Array:
	var rows := Schema.rows(edit_kind)
	if edit_kind in ["ramp", "fan", "magnet"]: rows.append(["angle", "方向", -180.0, 180.0, 1.0])
	return rows

func open_editor() -> void:
	if modal != "": return
	edit_id = world.selected_id
	edit_spring = world.selected_spring
	if edit_id == 0 and edit_spring < 0: return
	edit_before = world.snapshot()
	edit_was_paused = world.paused
	if edit_id != 0:
		var body = world.bodies.get(edit_id)
		if body == null: return
		edit_kind = body.kind
		draft = body.props.duplicate(true)
		draft.angle = rad_to_deg(wrapf(body.rotation, -PI, PI))
	else:
		edit_kind = "spring"
		draft = world.springs[edit_spring].duplicate(true)
	link_mass = false
	edit_changed = false
	edit_tab = 0
	edit_error = ""
	cancel_gesture()
	motion.reset()
	modal = "properties"
	update_view()

func draft_set(key: String, value: float) -> void:
	if modal != "properties" or not is_finite(value): return
	for row in editor_rows():
		if row[0] != key: continue
		value = clampf(snappedf(value, row[4]), row[2], row[3])
		var next := draft.duplicate(true)
		next[key] = value
		if edit_id != 0:
			var body = world.bodies.get(edit_id)
			if body == null: return
			var angle: float = deg_to_rad(value) if key == "angle" else body.rotation
			if key in ["radius", "length", "thickness", "angle"] and not world.fits(edit_id, body.position, next, angle):
				edit_error = "这里放不下了，先留一点空间。"
				return
			if key == "angle": body.rotation = angle
			else: body.configure(next)
			body.sleeping = false
		else:
			world.springs[edit_spring][key] = value
		draft = next
		edit_changed = true
		edit_error = ""
		return

func apply_editor() -> bool:
	if modal != "properties": return false
	close_editor(true)
	return true

func close_editor(keep: bool) -> void:
	if modal != "properties": return
	if keep:
		if edit_changed: push_history(edit_before)
	else:
		world.restore(edit_before)
	modal = ""
	cancel_gesture()
	motion.reset()
	edit_error = ""
	update_view()
	save_session()
