class_name TimeOfDayControls
extends VBoxContainer

## Right-side sun / moon; bottom bar: Select · Multi · Mute · Music · Shrink · Expand · Undo · Save

signal expand_done(message: String)
signal select_pressed
signal multiselect_pressed
signal undo_pressed
signal save_pressed

var _expand_btn: Button
var _shrink_btn: Button
var _mute_btn: Button
var _music_btn: Button
var _select_btn: Button
var _multiselect_btn: Button
var _undo_btn: Button
var _save_btn: Button
var _island_bar: HBoxContainer
var _grid_manager: GridManager


func setup(day_night: DayNightCycle, grid_manager: GridManager = null) -> void:
	_grid_manager = grid_manager
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Sit below Worlds button.
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

	_install_island_size_bar()
	if grid_manager:
		grid_manager.play_radius_changed.connect(_on_play_radius_changed)
		_refresh_island_buttons()


func _install_island_size_bar() -> void:
	## Bottom-center action strip above status / home indicator.
	var ui := get_parent()
	if ui == null:
		return

	_island_bar = HBoxContainer.new()
	_island_bar.name = "IslandSizeBar"
	_island_bar.add_theme_constant_override("separation", 10)
	_island_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_island_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_island_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_island_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_island_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Symmetric offsets — buttons center via alignment inside this strip.
	_island_bar.offset_left = -400.0
	_island_bar.offset_right = 400.0
	_island_bar.offset_top = -148.0
	_island_bar.offset_bottom = -84.0
	ui.add_child(_island_bar)

	# Select · Multi · Mute · Music · Shrink · Expand · Undo · Save
	_select_btn = _make_text_button("Select", Color(0.35, 0.55, 0.85))
	_select_btn.toggle_mode = true
	_select_btn.pressed.connect(func() -> void: select_pressed.emit())
	_island_bar.add_child(_select_btn)

	_multiselect_btn = _make_text_button("Multi", Color(0.4, 0.7, 0.75))
	_multiselect_btn.toggle_mode = true
	_multiselect_btn.pressed.connect(func() -> void: multiselect_pressed.emit())
	_island_bar.add_child(_multiselect_btn)

	_mute_btn = _make_icon_button(_icon_speaker(not AudioManager.is_muted()), "Mute all sound")
	_mute_btn.pressed.connect(_on_mute_pressed)
	_island_bar.add_child(_mute_btn)
	AudioManager.mute_changed.connect(_on_mute_changed)
	_refresh_mute_icon()

	_music_btn = _make_icon_button(
		_icon_music_note(not AudioManager.is_music_muted()),
		"Mute / unmute background music"
	)
	_music_btn.pressed.connect(_on_music_mute_pressed)
	_island_bar.add_child(_music_btn)
	AudioManager.music_mute_changed.connect(_on_music_mute_changed)
	_refresh_music_icon()

	_shrink_btn = _make_icon_button(_icon_shrink(), "Shrink island — toward original size")
	_shrink_btn.pressed.connect(_on_shrink_pressed)
	_island_bar.add_child(_shrink_btn)

	_expand_btn = _make_icon_button(_icon_expand(), "Expand island — grow playable floor")
	_expand_btn.pressed.connect(_on_expand_pressed)
	_island_bar.add_child(_expand_btn)
	if _grid_manager == null:
		_shrink_btn.visible = false
		_expand_btn.visible = false

	_undo_btn = _make_text_button("Undo", Color(0.78, 0.28, 0.28))
	_undo_btn.pressed.connect(func() -> void: undo_pressed.emit())
	_island_bar.add_child(_undo_btn)

	_save_btn = _make_text_button("Save", Color(0.18, 0.48, 0.28))
	_save_btn.pressed.connect(func() -> void: save_pressed.emit())
	_island_bar.add_child(_save_btn)


func set_undo_enabled(enabled: bool) -> void:
	if _undo_btn:
		_undo_btn.disabled = not enabled


func set_select_highlight(select_on: bool, multi_on: bool) -> void:
	if _select_btn:
		_select_btn.button_pressed = select_on
		_style_toggle_highlight(_select_btn, Color(0.35, 0.55, 0.85), select_on)
	if _multiselect_btn:
		_multiselect_btn.button_pressed = multi_on
		_style_toggle_highlight(_multiselect_btn, Color(0.4, 0.7, 0.75), multi_on)


func _style_toggle_highlight(btn: Button, tint: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	if selected:
		style.bg_color = Color(tint.r, tint.g, tint.b, 1.0).lightened(0.08)
		style.set_border_width_all(3)
		style.border_color = Color(0.95, 0.88, 0.35, 1.0)
	else:
		style.bg_color = Color(tint.r, tint.g, tint.b, 0.95)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.r, tint.g, tint.b, 1.0).lightened(0.05)
	pressed.set_border_width_all(3)
	pressed.border_color = Color(0.95, 0.88, 0.35, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.modulate = Color(1.12, 1.1, 0.95) if selected else Color.WHITE


func _on_mute_pressed() -> void:
	AudioManager.toggle_mute()
	# Soft click only when unmuting (so mute still gives feedback once).
	if not AudioManager.is_muted():
		AudioManager.play("ui_click")


func _on_music_mute_pressed() -> void:
	AudioManager.toggle_music_mute()
	if not AudioManager.is_muted():
		AudioManager.play("ui_click")


func _on_mute_changed(_muted: bool) -> void:
	_refresh_mute_icon()


func _on_music_mute_changed(_music_muted: bool) -> void:
	_refresh_music_icon()


func _refresh_mute_icon() -> void:
	if _mute_btn == null:
		return
	_mute_btn.icon = _icon_speaker(not AudioManager.is_muted())
	_mute_btn.tooltip_text = "Unmute all" if AudioManager.is_muted() else "Mute all"


func _refresh_music_icon() -> void:
	if _music_btn == null:
		return
	var on := not AudioManager.is_music_muted()
	_music_btn.icon = _icon_music_note(on)
	_music_btn.tooltip_text = "Unmute music" if AudioManager.is_music_muted() else "Mute music only"


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


func _make_text_button(text: String, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(72, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.96))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.88))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.95)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(tint.r, tint.g, tint.b, 0.4)
	disabled.border_color = Color(1, 1, 1, 0.15)
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


func _icon_speaker(on: bool) -> Texture2D:
	## Speaker cone + waves (on) or slash (muted).
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.95, 0.92, 0.8)
	# Cone body
	_fill_rect(img, 14, 24, 28, 40, c)
	for y in range(16, 48):
		var t := float(y - 16) / 32.0
		var tip := 28
		var edge := int(lerpf(28.0, 44.0, absf(t - 0.5) * 2.0))
		for x in range(tip, edge + 1):
			img.set_pixel(x, y, c)
	if on:
		# Sound waves
		for r in [8, 14, 20]:
			for a in range(-40, 41):
				var rad := deg_to_rad(float(a))
				var x := 44 + int(cos(rad) * float(r) * 0.35 + float(r) * 0.55)
				var y := 32 + int(sin(rad) * float(r))
				if x >= 0 and x < 64 and y >= 0 and y < 64:
					img.set_pixel(x, y, c)
					if x + 1 < 64:
						img.set_pixel(x + 1, y, c)
	else:
		# Mute slash
		_draw_thick_line(img, Vector2i(18, 46), Vector2i(48, 16), c)
	return ImageTexture.create_from_image(img)


func _icon_music_note(on: bool) -> Texture2D:
	## Eighth note; muted state draws a slash.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.95, 0.92, 0.8)
	# Note head (ellipse)
	for y in range(36, 52):
		for x in range(18, 36):
			var dx := (float(x) - 27.0) / 8.0
			var dy := (float(y) - 44.0) / 6.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
	# Stem
	_fill_rect(img, 32, 14, 36, 44, c)
	# Flag
	for y in range(14, 30):
		var t := float(y - 14) / 16.0
		var x0 := 36
		var x1 := 36 + int(lerpf(2.0, 16.0, t))
		for x in range(x0, mini(x1 + 1, 64)):
			img.set_pixel(x, y, c)
	if not on:
		_draw_thick_line(img, Vector2i(14, 50), Vector2i(50, 14), c)
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
