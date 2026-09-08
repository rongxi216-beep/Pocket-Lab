extends Control
const Art = preload("res://scripts/item_art.gd")
const LabTheme = preload("res://scripts/lab_theme.gd")
const Schema = preload("res://scripts/property_schema.gd")
const TEXT = LabTheme.INK
const MUTED = LabTheme.MUTED
const MINT = LabTheme.MINT
const BG = LabTheme.PAPER
var app: Node2D
var font: Font
var buttons: Dictionary = {}
var palette: Dictionary = {}
var sliders: Dictionary = {}
var active_slider := ""
var active_pointer := -99
var pressed_action := ""
var down_position := Vector2.ZERO
var pointer_position := Vector2.ZERO
var top := 0.0
var bottom := 0.0
var rotation_handle := Vector2.INF
var sheet_rect := Rect2()
var scene_gesture := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font = system
	if ResourceLoader.exists("res://assets/PocketLabUI-v3.ttf"): font = load("res://assets/PocketLabUI-v3.ttf")

func _process(_delta: float) -> void:
	queue_redraw()

func round_box(rect: Rect2, color: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> void:
	LabTheme.panel(self, rect, color, radius, border)

func label(text: String, p: Vector2, size_px: int = 14, color: Color = TEXT) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(text: String, rect: Rect2, size_px: int = 14, color: Color = TEXT) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	label(text, rect.get_center() + Vector2(-width / 2, size_px * 0.36), size_px, color)

func button(id: String, rect: Rect2, text: String, color: Color = Color("e5ecdc"), text_color: Color = TEXT) -> void:
	buttons[id] = rect
	round_box(rect, color.darkened(0.05) if pressed_action == id else color, 15)
	centered(text, rect, 13, text_color)

func glyph(id: String, rect: Rect2) -> void:
	buttons[id] = rect
	LabTheme.panel(self, rect, Color("dbebdc") if id == "pause" else Color("eeeedd"), 17, Color("d0ddc8"), true)
	var p := rect.get_center()
	match id:
		"pause":
			if app.world.paused:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -8), p + Vector2(8, 0), p + Vector2(-5, 8)]), TEXT)
			else:
				for x in [-4, 4]: draw_line(p + Vector2(x, -7), p + Vector2(x, 7), TEXT, 3, true)
		"library":
			round_box(Rect2(p - Vector2(10, 8), Vector2(20, 17)), Color.TRANSPARENT, 3, TEXT)
			draw_line(p + Vector2(-12, -8), p + Vector2(12, -8), TEXT, 2, true)
			draw_line(p + Vector2(-3, -2), p + Vector2(3, -2), TEXT, 2, true)
		"settings":
			for x in [-7, 0, 7]: draw_circle(p + Vector2(x, 0), 1.8, TEXT)

func _draw() -> void:
	if app == null or not is_instance_valid(app.world): return
	buttons.clear()
	palette.clear()
	sliders.clear()
	rotation_handle = Vector2.INF
	var w := size.x
	var h := size.y - bottom
	draw_rect(Rect2(0, 0, w, 72 + top), BG)
	label("口袋实验室", Vector2(24, 33 + top), 21)
	label("P O C K E T   L A B", Vector2(26, 54 + top), 10, MUTED)
	glyph("pause", Rect2(w - 180, 12 + top, 48, 48))
	glyph("library", Rect2(w - 122, 12 + top, 48, 48))
	glyph("settings", Rect2(w - 64, 12 + top, 48, 48))
	var arena: Rect2 = app.world.bounds
	var tray_y := h - (160 if app.tray_open else 72)
	draw_rect(Rect2(0, tray_y - 4, w, size.y - tray_y + 4), BG)
	LabTheme.panel(self, Rect2(14, tray_y, w - 28, 146 if app.tray_open else 58), Color("f1efdb"), 24, Color("cbd8bf"), true)
	label("工具抽屉", Vector2(32, tray_y + 33), 13)
	button("undo", Rect2(w - 214, tray_y + 4, 57, 48), "撤销", Color("e6ebd8"), MUTED if app.history.is_empty() else TEXT)
	button("shuffle", Rect2(w - 153, tray_y + 4, 72, 48), "重新组合", Color("e6ebd8"))
	button("tray", Rect2(w - 77, tray_y + 4, 54, 48), "收起" if app.tray_open else "展开", Color("f1efdb"), MUTED)
	if app.tray_open:
		var cell := (w - 44) / 5
		var types := ["ball", "spring", "ramp", "magnet", "fan"]
		var names := ["小球", "弹簧", "木板", "磁铁", "风扇"]
		for i in 5:
			var rect := Rect2(22 + cell * i, tray_y + 55, cell - 2, 82)
			palette[types[i]] = rect
			var selected: bool = app.palette_kind == types[i] or (app.spring_mode and i == 1)
			round_box(rect, Color("d9e7cf") if selected else Color("faf7e8"), 15)
			Art.paint(self, types[i], rect.get_center() - Vector2(0, 9), 0.4 if i == 2 else 0.75, app.elapsed if i == 4 and not app.world.paused else 0)
			centered(names[i], Rect2(rect.position + Vector2(0, 59), Vector2(rect.size.x, 22)), 12, TEXT)
	if app.spring_mode:
		var message := "先点小球或空白处" if app.spring_start.is_empty() else "再点另一个端点"
		round_box(Rect2(75, arena.position.y + 8, w - 150, 39), Color("e0ecd6"), 16)
		centered(message, Rect2(75, arena.position.y + 8, w - 150, 39), 12)
		if not app.spring_start.is_empty():
			var a: Vector2 = app.world_to_screen(app.world.endpoint_position(app.spring_start, true))
			draw_arc(a, 12, 0, TAU, 24, TEXT, 2, true)
			draw_dashed_line(a, pointer_position, Color(TEXT, 0.5), 1.5, 6, true)
	if app.palette_kind != "" and app.palette_kind != "spring":
		Art.paint(self, app.palette_kind, pointer_position)
	if app.press_time > 0.08 and not app.drag_started and app.modal in ["", "properties"]:
		var point: Vector2 = app.drag_origin
		var radius := 26.0
		if app.world.bodies.has(app.drag_id):
			var held = app.world.bodies[app.drag_id]
			point = held.position
			radius = minf(held.bounding_radius() + 10, 44)
		draw_arc(app.world_to_screen(point), radius, -PI / 2, -PI / 2 + TAU * clampf(app.press_time / 0.48, 0, 1), 48, TEXT, 2.5, true)
	if app.toast_time > 0 and app.modal == "":
		var toast_rect := Rect2(22, arena.position.y + 10, w - 44, 42)
		LabTheme.panel(self, toast_rect, Color("f8f4df"), 17, LabTheme.LINE, true)
		centered(app.toast_text, toast_rect, 11, TEXT)
	if app.debug:
		label("FPS %d · PHYS %d · BALL %d/48" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second, app.world.ball_count()], Vector2(34, arena.end.y - 12), 10, TEXT)
	if app.modal == "properties": draw_editor(w, h)
	elif app.modal != "": draw_modal(w, h)

func draw_editor(w: float, h: float) -> void:
	buttons.clear()
	palette.clear()
	sheet_rect = Rect2(0, h - 244, w, 244 + bottom)
	LabTheme.panel(self, sheet_rect, BG, 24, LabTheme.LINE, true)
	var y := sheet_rect.position.y
	draw_line(Vector2(w / 2 - 18, y + 8), Vector2(w / 2 + 18, y + 8), MUTED, 3, true)
	var names := {"ball": "小球", "ramp": "木板", "fan": "风扇", "magnet": "磁铁", "spring": "弹簧"}
	label(names[app.edit_kind], Vector2(22, y + 40), 19)
	button("pause", Rect2(w - 130, y + 12, 54, 44), "继续" if app.world.paused else "暂停")
	button("apply_properties", Rect2(w - 70, y + 12, 54, 44), "收起")
	var rows: Array = app.editor_rows()
	var cell := (w - 32) / rows.size()
	for i in rows.size():
		button("tab:" + str(i), Rect2(16 + cell * i, y + 59, cell - 4, 44), rows[i][1], Color("d3e6d8") if app.edit_tab == i else Color("f1f1e5"))
	var row: Array = rows[app.edit_tab]
	var value: float = app.draft.get(row[0], row[2])
	var value_text := "%d°" % value if row[0] == "angle" else Schema.format_value(row[0], value)
	centered(value_text, Rect2(w / 2 - 65, y + 103, 130, 26), 14)
	button("step:" + row[0] + ":-1", Rect2(16, y + 128, 44, 44), "−")
	button("step:" + row[0] + ":1", Rect2(w - 60, y + 128, 44, 44), "＋")
	var rect := Rect2(76, y + 128, w - 152, 44)
	sliders[row[0]] = {"rect": rect, "row": row}
	var start := Vector2(rect.position.x, rect.get_center().y)
	var end := Vector2(rect.end.x, rect.get_center().y)
	var knob := start.lerp(end, inverse_lerp(row[2], row[3], value))
	draw_line(start, end, Color("d1ddc7"), 7, true)
	draw_line(start, knob, MINT, 7, true)
	draw_circle(knob, 13, BG)
	draw_arc(knob, 13, 0, TAU, 32, MINT, 2, true)
	if app.edit_error != "": centered(app.edit_error, Rect2(10, y + 171, w - 20, 20), 11, Color("b17353"))
	var actions := ["cancel_properties", "delete"] if app.edit_kind == "spring" else ["cancel_properties", "duplicate", "reset", "delete"]
	var titles := ["还原本次", "解除连接"] if app.edit_kind == "spring" else ["还原本次", "复制", "复位", "收走"]
	var width := (w - 32) / actions.size()
	for i in actions.size(): button(actions[i], Rect2(16 + width * i, y + 192, width - 4, 44), titles[i], Color("edeedd"))

func draw_modal(w: float, h: float) -> void:
	buttons.clear()
	palette.clear()
	rotation_handle = Vector2.INF
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.19, 0.29, 0.23, 0.33))
	var panel := Rect2(22, maxf(top + 78, h - 578), w - 44, 550)
	LabTheme.panel(self, panel, BG, 26, LabTheme.LINE, true)
	label("本地作品" if app.modal == "library" else "实验室设置", panel.position + Vector2(22, 40), 22)
	button("close", Rect2(panel.end.x - 76, panel.position.y + 12, 56, 48), "关闭")
	var x := panel.position.x + 18
	var y := panel.position.y + 66
	var width := panel.size.x - 36
	if app.modal == "settings":
		var ids := ["sound", "haptics", "fields", "motion", "debug"]
		var names := ["交互声音", "轻触反馈", "显示磁场与风向", "随手机轻动", "性能信息"]
		var values := [app.feedback.sound, app.feedback.haptics, app.world.show_fields, app.motion_enabled, app.debug]
		for i in 5:
			button(ids[i], Rect2(x, y + i * 55, width, 48), names[i] + ("     开" if values[i] else "     关"), Color("dce9d4") if values[i] else Color("eeefdf"))
		button("previous", Rect2(x, y + 280, width, 48), "恢复重新组合前的场景")
		button("reset_all", Rect2(x, y + 335, width, 48), "所有道具回到放置位置")
		button("clear", Rect2(x, y + 390, width, 48), "清空实验台 · 可以撤销", Color("f0dfce"))
		label("自动保存在此设备 · 核心玩法无需网络", Vector2(x + 6, y + 468), 11, MUTED)
	else:
		button("save_work", Rect2(x, y, width, 52), "＋ 保存当前实验", Color("d6e7cf"))
		if app.works.is_empty(): centered("把喜欢的偶然，留在这里。", Rect2(x, y + 130, width, 50), 14, MUTED)
		for i in mini(4, maxi(0, app.works.size() - app.library_page * 4)):
			var index: int = app.library_page * 4 + i
			button("work:" + str(index), Rect2(x, y + 67 + i * 61, width, 53), str(app.works[index].get("title", "实验")))
		button("page_prev", Rect2(x, y + 321, 65, 48), "上一页")
		centered("%d / %d" % [app.library_page + 1, maxi(1, ceili(app.works.size() / 4.0))], Rect2(x + 70, y + 321, width - 140, 48), 12, MUTED)
		button("page_next", Rect2(x + width - 65, y + 321, 65, 48), "下一页")
		label("打开作品前，当前场景会加入撤销记录。", Vector2(x + 6, y + 468), 11, MUTED)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: pointer_down(event.position, event.index)
		elif event.index == active_pointer: pointer_up(event.position, event.canceled)
	elif event is InputEventScreenDrag and event.index == active_pointer: pointer_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position, -1)
		elif active_pointer == -1: pointer_up(event.position)
	elif event is InputEventMouseMotion and active_pointer == -1: pointer_move(event.position)
	accept_event()

func pointer_down(p: Vector2, index: int) -> void:
	if active_pointer != -99: return
	active_pointer = index
	scene_gesture = false
	down_position = p
	pointer_position = p
	for action in buttons:
		if buttons[action].has_point(p):
			pressed_action = action
			return
	if app.modal == "properties":
		for key in sliders:
			if sliders[key].rect.has_point(p):
				active_slider = key
				move_slider(p)
				return
		if sheet_rect.has_point(p): return
	if app.modal not in ["", "properties"]: return
	for kind in palette:
		if palette[kind].has_point(p):
			app.palette_kind = kind
			return
	scene_gesture = true
	app.scene_down(app.screen_to_world(p))

func pointer_move(p: Vector2) -> void:
	pointer_position = p
	if active_slider != "":
		move_slider(p)
		return
	if scene_gesture and pressed_action == "" and app.palette_kind == "" and app.modal in ["", "properties"]: app.scene_move(app.screen_to_world(p))

func move_slider(p: Vector2) -> void:
	if not sliders.has(active_slider): return
	var entry: Dictionary = sliders[active_slider]
	var t: float = clampf((p.x - entry.rect.position.x) / entry.rect.size.x, 0, 1)
	app.draft_set(active_slider, lerpf(entry.row[2], entry.row[3], t))

func pointer_up(p: Vector2, canceled: bool = false) -> void:
	if canceled:
		app.cancel_gesture()
	elif active_slider != "":
		move_slider(p)
	elif pressed_action != "":
		if buttons.has(pressed_action) and buttons[pressed_action].has_point(p): app.action(pressed_action)
	elif app.palette_kind != "":
		app.place_palette(app.screen_to_world(p), down_position.distance_to(p) < 16)
	elif app.modal == "properties" and sheet_rect.has_point(down_position) and p.y - down_position.y > 42:
		app.close_editor(true)
	elif scene_gesture and app.modal in ["", "properties"]: app.scene_up(app.screen_to_world(p))
	active_slider = ""
	pressed_action = ""
	app.palette_kind = ""
	active_pointer = -99
	scene_gesture = false

