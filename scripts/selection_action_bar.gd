class_name SelectionActionBar
extends Control

## Floating action buttons above selection, or confirm/cancel during copy-extend.

signal move_pressed
signal copy_pressed
signal rotate_pressed
signal delete_pressed
signal confirm_pressed
signal cancel_pressed

const BTN_SIZE := Vector2(56, 56)
const BTN_SIZE_TOP := Vector2(58, 58)
const TOP_INSET := 56.0
const SEP := 10
const SEP_TOP := 12

var camera: Camera3D
var _row: HBoxContainer
var _world_anchor: Vector3 = Vector3.ZERO
var _follow: bool = false
var _pin_top: bool = false
var _top_mode: bool = false
var _mode: String = "actions"  # "actions" | "confirm"
var _confirm_btn: Button
var _cancel_btn: Button


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide_bar()


func _build() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", SEP)
	_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	_rebuild_actions()


func _clear_row() -> void:
	for child in _row.get_children():
		child.queue_free()
	_confirm_btn = null
	_cancel_btn = null


func _rebuild_actions() -> void:
	_clear_row()
	_mode = "actions"
	_row.add_child(_make_action_button(LocaleManager.t("Move"), _make_move_icon(), Color(0.35, 0.65, 0.95), func() -> void: move_pressed.emit()))
	_row.add_child(_make_action_button(LocaleManager.t("Copy"), _make_copy_icon(), Color(0.95, 0.75, 0.3), func() -> void: copy_pressed.emit()))
	_row.add_child(_make_action_button(LocaleManager.t("Rotate"), _make_rotate_icon(), Color(0.45, 0.85, 0.55), func() -> void: rotate_pressed.emit()))
	_row.add_child(_make_action_button(LocaleManager.t("Delete"), _make_delete_icon(), Color(0.92, 0.4, 0.4), func() -> void: delete_pressed.emit()))
	_apply_current_sizes()


func _rebuild_confirm() -> void:
	_clear_row()
	_mode = "confirm"
	_confirm_btn = _make_action_button(LocaleManager.t("Confirm"), _make_check_icon(), Color(0.35, 0.78, 0.45), func() -> void: confirm_pressed.emit())
	_cancel_btn = _make_action_button(LocaleManager.t("Cancel"), _make_delete_icon(), Color(0.92, 0.4, 0.4), func() -> void: cancel_pressed.emit())
	_row.add_child(_confirm_btn)
	_row.add_child(_cancel_btn)
	_apply_current_sizes()


func _make_action_button(tip: String, icon: Texture2D, tint: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.tooltip_text = tip
	btn.icon = icon
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.94)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.55)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.45, 0.45, 0.45, 0.65)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.pressed.connect(on_press)
	return btn


func show_at_world(world_pos: Vector3) -> void:
	if _mode != "actions":
		_rebuild_actions()
	_world_anchor = world_pos
	_follow = true
	_pin_top = false
	_set_button_sizes(false)
	visible = true
	_update_screen_pos()


func show_at_top() -> void:
	if _mode != "actions":
		_rebuild_actions()
	_follow = false
	_pin_top = true
	_set_button_sizes(true)
	visible = true
	_row.visible = true
	_layout_top()


func show_confirm_at_top(can_confirm: bool) -> void:
	if _mode != "confirm":
		_rebuild_confirm()
	_follow = false
	_pin_top = true
	_set_button_sizes(true)
	if _confirm_btn:
		_confirm_btn.disabled = not can_confirm
		_confirm_btn.modulate = Color.WHITE if can_confirm else Color(1, 1, 1, 0.45)
	visible = true
	_row.visible = true
	_layout_top()


func set_confirm_enabled(can_confirm: bool) -> void:
	if _confirm_btn == null:
		return
	_confirm_btn.disabled = not can_confirm
	_confirm_btn.modulate = Color.WHITE if can_confirm else Color(1, 1, 1, 0.45)


func hide_bar() -> void:
	_follow = false
	_pin_top = false
	visible = false
	if _mode != "actions":
		_rebuild_actions()


func _apply_current_sizes() -> void:
	var size := BTN_SIZE_TOP if _top_mode else BTN_SIZE
	_row.add_theme_constant_override("separation", SEP_TOP if _top_mode else SEP)
	for child in _row.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = size


func _set_button_sizes(top: bool) -> void:
	_top_mode = top
	_apply_current_sizes()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _pin_top:
		_layout_top()
	elif _follow:
		_update_screen_pos()


func _layout_top() -> void:
	var vp := get_viewport().get_visible_rect().size
	var size: Vector2 = _row.get_combined_minimum_size()
	_row.position = Vector2((vp.x - size.x) * 0.5, TOP_INSET)


func _update_screen_pos() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if camera.is_position_behind(_world_anchor):
		_row.visible = false
		return
	_row.visible = true
	var screen: Vector2 = camera.unproject_position(_world_anchor)
	var size: Vector2 = _row.get_combined_minimum_size()
	_row.position = screen - Vector2(size.x * 0.5, size.y + 14.0)


static func _make_move_icon() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	var mid := s / 2
	for y in range(10, 54):
		for x in range(mid - 3, mid + 4):
			img.set_pixel(x, y, c)
	for x in range(10, 54):
		for y in range(mid - 3, mid + 4):
			img.set_pixel(x, y, c)
	for i in range(10):
		for x in range(mid - i, mid + i + 1):
			img.set_pixel(x, 8 + i, c)
			img.set_pixel(x, 55 - i, c)
		for y in range(mid - i, mid + i + 1):
			img.set_pixel(8 + i, y, c)
			img.set_pixel(55 - i, y, c)
	return ImageTexture.create_from_image(img)


static func _make_copy_icon() -> Texture2D:
	## Two overlapping pages.
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	_stroke_rect(img, 18, 10, 50, 42, c, 3)
	_stroke_rect(img, 12, 20, 44, 52, c, 3)
	return ImageTexture.create_from_image(img)


static func _stroke_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, t: int) -> void:
	for x in range(x0, x1 + 1):
		for k in range(t):
			img.set_pixel(x, y0 + k, c)
			img.set_pixel(x, y1 - k, c)
	for y in range(y0, y1 + 1):
		for k in range(t):
			img.set_pixel(x0 + k, y, c)
			img.set_pixel(x1 - k, y, c)


static func _make_rotate_icon() -> Texture2D:
	## Single clockwise rotate arrow (↻) with a large arrowhead.
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	var cx := 31.5
	var cy := 34.0
	var r_mid := 18.0
	var thickness := 4.5
	# Arc from ~85° clockwise around to ~35° (gap for the head at top-right).
	for y in range(s):
		for x in range(s):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			if absf(dist - r_mid) > thickness:
				continue
			var ang := atan2(dy, dx)
			var deg := rad_to_deg(ang)
			if deg < 0.0:
				deg += 360.0
			if deg >= 85.0 or deg <= 35.0:
				img.set_pixel(x, y, c)
	# Arrowhead: tip points roughly along the arc (clockwise / down-right).
	var tip := Vector2(50, 18)
	var base_in := Vector2(36, 8)
	var base_out := Vector2(40, 28)
	_fill_triangle(img, tip, base_in, base_out, c)
	return ImageTexture.create_from_image(img)


static func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(floor(minf(a.x, minf(b.x, c.x))))
	var max_x := int(ceil(maxf(a.x, maxf(b.x, c.x))))
	var min_y := int(floor(minf(a.y, minf(b.y, c.y))))
	var max_y := int(ceil(maxf(a.y, maxf(b.y, c.y))))
	for y in range(mini(max_y + 1, img.get_height())):
		if y < maxi(min_y, 0):
			continue
		for x in range(mini(max_x + 1, img.get_width())):
			if x < maxi(min_x, 0):
				continue
			if _point_in_triangle(Vector2(x, y), a, b, c):
				img.set_pixel(x, y, color)


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var inv := 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) <= 1.0


static func _make_delete_icon() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	for i in range(14, 50):
		for t in range(-3, 4):
			var a := i
			var b := i + t
			var c1 := (s - 1 - i) + t
			if b >= 0 and b < s:
				img.set_pixel(a, b, c)
			if c1 >= 0 and c1 < s:
				img.set_pixel(a, c1, c)
	return ImageTexture.create_from_image(img)


static func _make_check_icon() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	# Thick check mark.
	for i in range(0, 18):
		for t in range(-3, 4):
			var x := 14 + i
			var y := 34 + int(i * 0.55) + t
			if x >= 0 and x < s and y >= 0 and y < s:
				img.set_pixel(x, y, c)
	for i in range(0, 28):
		for t in range(-3, 4):
			var x := 30 + i
			var y := 44 - int(i * 0.9) + t
			if x >= 0 and x < s and y >= 0 and y < s:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
