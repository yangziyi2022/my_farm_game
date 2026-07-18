class_name TimeOfDayControls
extends VBoxContainer

## Right-side sun / moon; island expand/shrink sit bottom-center (clear of iPhone home bar).

signal expand_done(message: String)

var _expand_btn: Button
var _shrink_btn: Button
var _island_bar: HBoxContainer
var _grid_manager: GridManager


func setup(day_night: DayNightCycle, grid_manager: GridManager = null) -> void:
	_grid_manager = grid_manager
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Clear rounded corner / status-bar overlap; sit below Undo/Save/Load.
	offset_left = -84.0
	offset_top = 112.0
	offset_right = -28.0
	offset_bottom = 240.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 12)

	var sun_btn := _make_icon_button(_icon_sun(), "Morning — jump to sunrise")
	sun_btn.pressed.connect(func() -> void:
		if day_night:
			day_night.jump_to_sunrise()
	)
	add_child(sun_btn)

	var moon_btn := _make_icon_button(_icon_moon(), "Night — jump to moonrise")
	moon_btn.pressed.connect(func() -> void:
		if day_night:
			day_night.jump_to_moonrise()
	)
	add_child(moon_btn)

	if grid_manager:
		_install_island_size_bar()
		grid_manager.play_radius_changed.connect(_on_play_radius_changed)
		_refresh_island_buttons()


func _install_island_size_bar() -> void:
	## Bottom-center expand / shrink — above status bar, clear of home indicator.
	var ui := get_parent()
	if ui == null:
		return

	_island_bar = HBoxContainer.new()
	_island_bar.name = "IslandSizeBar"
	_island_bar.add_theme_constant_override("separation", 14)
	_island_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_island_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_island_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_island_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Centered pair above the status line / home indicator.
	_island_bar.offset_left = -70.0
	_island_bar.offset_right = 70.0
	_island_bar.offset_top = -148.0
	_island_bar.offset_bottom = -84.0
	ui.add_child(_island_bar)

	_shrink_btn = _make_icon_button(_icon_shrink(), "Shrink island — toward original size")
	_shrink_btn.pressed.connect(_on_shrink_pressed)
	_island_bar.add_child(_shrink_btn)

	_expand_btn = _make_icon_button(_icon_expand(), "Expand island — grow playable floor")
	_expand_btn.pressed.connect(_on_expand_pressed)
	_island_bar.add_child(_expand_btn)


func _on_expand_pressed() -> void:
	if _grid_manager == null:
		return
	var old_r := _grid_manager.get_play_radius()
	if _grid_manager.expand_island():
		var new_r := _grid_manager.get_play_radius()
		expand_done.emit(
			"Island expanded %.1f → %.1f (+%.1f)" % [old_r, new_r, new_r - old_r]
		)
	else:
		expand_done.emit("Island is already at max size.")


func _on_shrink_pressed() -> void:
	if _grid_manager == null:
		return
	if _grid_manager.shrink_blocked_by_content():
		expand_done.emit("Can't shrink — move or remove items near the edge first")
		return
	var old_r := _grid_manager.get_play_radius()
	if _grid_manager.shrink_island():
		var new_r := _grid_manager.get_play_radius()
		expand_done.emit(
			"Island shrunk %.1f → %.1f (−%.1f)" % [old_r, new_r, old_r - new_r]
		)
	else:
		expand_done.emit("Island is already at original size.")


func _on_play_radius_changed(_new_radius: float) -> void:
	_refresh_island_buttons()


func _refresh_island_buttons() -> void:
	if _grid_manager == null:
		return
	if _expand_btn:
		_expand_btn.disabled = not _grid_manager.can_expand()
	if _shrink_btn:
		_shrink_btn.disabled = not _grid_manager.can_shrink()


func _make_icon_button(icon: Texture2D, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.icon = icon
	btn.expand_icon = true
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.2, 0.88)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.75, 0.7, 0.55, 0.85)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.2, 0.28, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.12, 0.11, 0.14, 0.55)
	disabled.border_color = Color(0.45, 0.42, 0.38, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn


func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, c)


func _icon_sun() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var core := Color(1.0, 0.88, 0.35)
	var ray := Color(1.0, 0.75, 0.25)
	# Disc
	for y in range(64):
		for x in range(64):
			var dx := x - 32
			var dy := y - 32
			if dx * dx + dy * dy <= 196:
				img.set_pixel(x, y, core)
	# Rays
	for i in range(8):
		var ang := float(i) * TAU / 8.0
		for r in range(18, 30):
			var x := 32 + int(cos(ang) * r)
			var y := 32 + int(sin(ang) * r)
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				img.set_pixel(x, y, ray)
				if x + 1 < 64:
					img.set_pixel(x + 1, y, ray)
	return ImageTexture.create_from_image(img)


func _icon_moon() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var lit := Color(0.86, 0.9, 1.0)
	# Full disc then punch a dark circle for crescent
	for y in range(64):
		for x in range(64):
			var dx := x - 34
			var dy := y - 32
			if dx * dx + dy * dy <= 256:
				img.set_pixel(x, y, lit)
	for y in range(64):
		for x in range(64):
			var dx := x - 24
			var dy := y - 30
			if dx * dx + dy * dy <= 210:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _icon_expand() -> Texture2D:
	## Island disc with four outward arrows.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var land := Color(0.42, 0.62, 0.28)
	var rim := Color(0.95, 0.88, 0.45)
	var arrow := Color(0.95, 0.92, 0.8)
	for y in range(64):
		for x in range(64):
			var dx := x - 32
			var dy := y - 32
			var d2 := dx * dx + dy * dy
			if d2 <= 121:
				img.set_pixel(x, y, land)
			elif d2 <= 169:
				img.set_pixel(x, y, rim)
	# N / S / W / E arrows
	_draw_thick_line(img, Vector2i(32, 16), Vector2i(32, 4), arrow)
	_draw_thick_line(img, Vector2i(28, 8), Vector2i(32, 4), arrow)
	_draw_thick_line(img, Vector2i(36, 8), Vector2i(32, 4), arrow)
	_draw_thick_line(img, Vector2i(32, 48), Vector2i(32, 60), arrow)
	_draw_thick_line(img, Vector2i(28, 56), Vector2i(32, 60), arrow)
	_draw_thick_line(img, Vector2i(36, 56), Vector2i(32, 60), arrow)
	_draw_thick_line(img, Vector2i(16, 32), Vector2i(4, 32), arrow)
	_draw_thick_line(img, Vector2i(8, 28), Vector2i(4, 32), arrow)
	_draw_thick_line(img, Vector2i(8, 36), Vector2i(4, 32), arrow)
	_draw_thick_line(img, Vector2i(48, 32), Vector2i(60, 32), arrow)
	_draw_thick_line(img, Vector2i(56, 28), Vector2i(60, 32), arrow)
	_draw_thick_line(img, Vector2i(56, 36), Vector2i(60, 32), arrow)
	return ImageTexture.create_from_image(img)


func _icon_shrink() -> Texture2D:
	## Island disc with four inward arrows (toward original size).
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var land := Color(0.42, 0.62, 0.28)
	var rim := Color(0.95, 0.88, 0.45)
	var arrow := Color(0.95, 0.92, 0.8)
	for y in range(64):
		for x in range(64):
			var dx := x - 32
			var dy := y - 32
			var d2 := dx * dx + dy * dy
			if d2 <= 121:
				img.set_pixel(x, y, land)
			elif d2 <= 169:
				img.set_pixel(x, y, rim)
	# Inward N / S / W / E
	_draw_thick_line(img, Vector2i(32, 6), Vector2i(32, 18), arrow)
	_draw_thick_line(img, Vector2i(28, 14), Vector2i(32, 18), arrow)
	_draw_thick_line(img, Vector2i(36, 14), Vector2i(32, 18), arrow)
	_draw_thick_line(img, Vector2i(32, 58), Vector2i(32, 46), arrow)
	_draw_thick_line(img, Vector2i(28, 50), Vector2i(32, 46), arrow)
	_draw_thick_line(img, Vector2i(36, 50), Vector2i(32, 46), arrow)
	_draw_thick_line(img, Vector2i(6, 32), Vector2i(18, 32), arrow)
	_draw_thick_line(img, Vector2i(14, 28), Vector2i(18, 32), arrow)
	_draw_thick_line(img, Vector2i(14, 36), Vector2i(18, 32), arrow)
	_draw_thick_line(img, Vector2i(58, 32), Vector2i(46, 32), arrow)
	_draw_thick_line(img, Vector2i(50, 28), Vector2i(46, 32), arrow)
	_draw_thick_line(img, Vector2i(50, 36), Vector2i(46, 32), arrow)
	return ImageTexture.create_from_image(img)


func _draw_thick_line(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var x := int(round(lerpf(float(a.x), float(b.x), t)))
		var y := int(round(lerpf(float(a.y), float(b.y), t)))
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var px := x + ox
				var py := y + oy
				if px >= 0 and px < 64 and py >= 0 and py < 64:
					img.set_pixel(px, py, c)
