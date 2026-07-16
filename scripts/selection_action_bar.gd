class_name SelectionActionBar
extends Control

## Floating Move / Rotate / Delete buttons above the current selection.

signal move_pressed
signal rotate_pressed
signal delete_pressed

const BTN_SIZE := Vector2(40, 40)

var camera: Camera3D
var _row: HBoxContainer
var _world_anchor: Vector3 = Vector3.ZERO
var _follow: bool = false


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide_bar()


func _build() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_row)

	_row.add_child(_make_action_button("Move", _make_move_icon(), Color(0.35, 0.65, 0.95), func() -> void: move_pressed.emit()))
	_row.add_child(_make_action_button("Rotate", _make_rotate_icon(), Color(0.45, 0.85, 0.55), func() -> void: rotate_pressed.emit()))
	_row.add_child(_make_action_button("Delete", _make_delete_icon(), Color(0.92, 0.4, 0.4), func() -> void: delete_pressed.emit()))


func _make_action_button(tip: String, icon: Texture2D, tint: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BTN_SIZE
	btn.tooltip_text = tip
	btn.icon = icon
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.55)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(on_press)
	return btn


func show_at_world(world_pos: Vector3) -> void:
	_world_anchor = world_pos
	_follow = true
	visible = true
	_update_screen_pos()


func hide_bar() -> void:
	_follow = false
	visible = false


func _process(_delta: float) -> void:
	if _follow and visible:
		_update_screen_pos()


func _update_screen_pos() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if camera.is_position_behind(_world_anchor):
		_row.visible = false
		return
	_row.visible = true
	var screen: Vector2 = camera.unproject_position(_world_anchor)
	var size: Vector2 = _row.get_combined_minimum_size()
	_row.position = screen - Vector2(size.x * 0.5, size.y + 12.0)


static func _make_move_icon() -> Texture2D:
	## Cross / 4-way arrow.
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	var mid := s / 2
	# Vertical shaft
	for y in range(10, 54):
		for x in range(mid - 3, mid + 4):
			img.set_pixel(x, y, c)
	# Horizontal shaft
	for x in range(10, 54):
		for y in range(mid - 3, mid + 4):
			img.set_pixel(x, y, c)
	# Arrow heads
	for i in range(10):
		for x in range(mid - i, mid + i + 1):
			img.set_pixel(x, 8 + i, c)          # up
			img.set_pixel(x, 55 - i, c)         # down
		for y in range(mid - i, mid + i + 1):
			img.set_pixel(8 + i, y, c)          # left
			img.set_pixel(55 - i, y, c)         # right
	return ImageTexture.create_from_image(img)


static func _make_rotate_icon() -> Texture2D:
	## Clear circular reload / rotate arrow (↻ style).
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	var cx := 31.5
	var cy := 31.5
	var r_mid := 20.0
	var thickness := 4.5
	# Draw a 270° arc (leave a gap for the arrow head).
	for y in range(s):
		for x in range(s):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			if absf(dist - r_mid) > thickness:
				continue
			var ang := atan2(dy, dx)  # -PI..PI, 0 = right
			# Keep arc from about 40° through 360°/0° to -50° (gap near top-right).
			var deg := rad_to_deg(ang)
			if deg < 0.0:
				deg += 360.0
			# Visible from 50° to 350° (gap 350→50 for arrow).
			if deg >= 50.0 and deg <= 350.0:
				img.set_pixel(x, y, c)
	# Arrow head at the gap (pointing clockwise near top-right).
	var tip := Vector2(48, 14)
	var left := Vector2(38, 10)
	var right := Vector2(42, 22)
	_fill_triangle(img, tip, left, right, c)
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
	## X / cross mark.
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
