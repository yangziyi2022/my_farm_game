extends Control

## Main menu: New Game / Load Game / Exit + worlds list with long-press rename/delete.

const FARM_SCENE := "res://scenes/main.tscn"
const LONG_PRESS_MS := 450
## Keep content inside the parchment panel of menu.png (not the full-bleed art).
const PANEL_WIDTH_RATIO := 0.56
const PANEL_MAX_WIDTH := 460.0
const PANEL_SIDE_MIN := 56.0
const PANEL_TOP_RATIO := 0.12
const PANEL_BOTTOM_RATIO := 0.11

var _content_margin: MarginContainer
var _worlds_list: VBoxContainer
var _status: Label
var _selected_id: String = ""
var _rows: Dictionary = {}  # id -> PanelContainer

var _press_timer: Timer
var _press_world_id: String = ""
var _long_press_fired: bool = false

var _rename_dialog: AcceptDialog
var _rename_edit: LineEdit
var _rename_target: String = ""
var _delete_dialog: ConfirmationDialog
var _delete_target: String = ""

var _brand: Label
var _tag: Label
var _btn_new: Button
var _btn_load: Button
var _btn_exit: Button
var _worlds_header: Label
var _hint: Label
var _lang_label: Label
var _lang_en_btn: Button
var _lang_zh_btn: Button


func _ready() -> void:
	SaveManager.ensure_ready()
	AudioManager.play_music("day", true)
	_build_ui()
	_apply_locale_texts()
	_refresh_worlds()
	var last := SaveManager.get_last_world_id()
	if SaveManager.world_exists(last):
		_select_world(last)
	resized.connect(_update_content_margins)
	_update_content_margins()
	if not LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	_refresh_worlds()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/icons/menu.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Content sits over the parchment panel in the art — side margins are responsive.
	_content_margin = MarginContainer.new()
	_content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.add_child(center)

	var col := VBoxContainer.new()
	col.name = "MenuColumn"
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(col)

	_brand = Label.new()
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.add_theme_font_size_override("font_size", 42)
	_brand.add_theme_color_override("font_color", Color(0.32, 0.22, 0.12, 1.0))
	_brand.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	_brand.add_theme_constant_override("shadow_offset_x", 1)
	_brand.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_brand)

	_tag = Label.new()
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tag.add_theme_font_size_override("font_size", 14)
	_tag.add_theme_color_override("font_color", Color(0.42, 0.34, 0.22, 0.95))
	col.add_child(_tag)

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	col.add_child(lang_row)

	_lang_label = Label.new()
	_lang_label.add_theme_font_size_override("font_size", 13)
	_lang_label.add_theme_color_override("font_color", Color(0.38, 0.3, 0.18, 0.95))
	lang_row.add_child(_lang_label)

	_lang_en_btn = _make_lang_btn("English", LocaleManager.LOCALE_EN)
	_lang_zh_btn = _make_lang_btn("繁體中文", LocaleManager.LOCALE_ZH_TW)
	lang_row.add_child(_lang_en_btn)
	lang_row.add_child(_lang_zh_btn)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	col.add_child(actions)

	_btn_new = _make_main_btn("", Color(0.45, 0.62, 0.35), _on_new_game)
	_btn_load = _make_main_btn("", Color(0.4, 0.55, 0.7), _on_load_game)
	_btn_exit = _make_main_btn("", Color(0.7, 0.45, 0.38), _on_exit)
	actions.add_child(_btn_new)
	actions.add_child(_btn_load)
	actions.add_child(_btn_exit)

	_worlds_header = Label.new()
	_worlds_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_worlds_header.add_theme_font_size_override("font_size", 20)
	_worlds_header.add_theme_color_override("font_color", Color(0.3, 0.22, 0.12, 1.0))
	col.add_child(_worlds_header)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28, 0.9))
	col.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_worlds_list = VBoxContainer.new()
	_worlds_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_worlds_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_worlds_list)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.38, 0.3, 0.18, 0.95))
	col.add_child(_status)

	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = LONG_PRESS_MS / 1000.0
	_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_press_timer)

	_rename_dialog = AcceptDialog.new()
	_rename_dialog.dialog_hide_on_ok = false
	var rename_wrap := MarginContainer.new()
	rename_wrap.add_theme_constant_override("margin_left", 8)
	rename_wrap.add_theme_constant_override("margin_right", 8)
	rename_wrap.add_theme_constant_override("margin_top", 8)
	rename_wrap.add_theme_constant_override("margin_bottom", 8)
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size = Vector2(280, 44)
	rename_wrap.add_child(_rename_edit)
	_rename_dialog.add_child(rename_wrap)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)


func _make_lang_btn(label: String, locale: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(96, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		LocaleManager.set_locale(locale)
	)
	_style_lang_btn(btn, false)
	return btn


func _style_lang_btn(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.55, 0.42, 0.22, 0.95)
	else:
		style.bg_color = Color(0.86, 0.8, 0.68, 0.92)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.75, 0.55, 0.25, 0.95) if selected else Color(1, 1, 1, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override(
		"font_color",
		Color(1, 0.96, 0.88, 1.0) if selected else Color(0.28, 0.2, 0.12, 1.0)
	)


func _apply_locale_texts() -> void:
	_brand.text = LocaleManager.t("Cozy Farm")
	_tag.text = LocaleManager.t("Build your island · grow your world")
	_lang_label.text = LocaleManager.t("Language") + ":"
	_btn_new.text = LocaleManager.t("New Game")
	_btn_load.text = LocaleManager.t("Load Game")
	_btn_exit.text = LocaleManager.t("Exit")
	_worlds_header.text = LocaleManager.t("Worlds")
	_hint.text = LocaleManager.t("Tap to select · Long-press to rename or delete")
	_rename_dialog.title = LocaleManager.t("Rename World")
	_rename_dialog.ok_button_text = LocaleManager.t("Rename")
	_rename_edit.placeholder_text = LocaleManager.t("World name")
	_delete_dialog.title = LocaleManager.t("Delete World")
	_style_lang_btn(_lang_en_btn, LocaleManager.get_locale() == LocaleManager.LOCALE_EN)
	_style_lang_btn(_lang_zh_btn, LocaleManager.get_locale() == LocaleManager.LOCALE_ZH_TW)


func _update_content_margins() -> void:
	if _content_margin == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var panel_w := minf(vp.x * PANEL_WIDTH_RATIO, PANEL_MAX_WIDTH)
	var side := maxf((vp.x - panel_w) * 0.5, PANEL_SIDE_MIN)
	var top := maxf(vp.y * PANEL_TOP_RATIO, 52.0)
	var bottom := maxf(vp.y * PANEL_BOTTOM_RATIO, 40.0)
	_content_margin.add_theme_constant_override("margin_left", int(side))
	_content_margin.add_theme_constant_override("margin_right", int(side))
	_content_margin.add_theme_constant_override("margin_top", int(top))
	_content_margin.add_theme_constant_override("margin_bottom", int(bottom))

	var col := _content_margin.find_child("MenuColumn", true, false) as Control
	if col:
		col.custom_minimum_size = Vector2(panel_w, maxf(vp.y - top - bottom, 280.0))


func _make_main_btn(text: String, tint: Color, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(118, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.95)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(cb)
	return btn


func _refresh_worlds() -> void:
	for child in _worlds_list.get_children():
		child.queue_free()
	_rows.clear()
	var worlds := SaveManager.list_worlds()
	if worlds.is_empty():
		var empty := Label.new()
		empty.text = LocaleManager.t("No worlds yet — tap New Game to start.")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28, 0.9))
		_worlds_list.add_child(empty)
		_selected_id = ""
		return
	for meta in worlds:
		var id := str(meta.get("id", ""))
		var row := _make_world_row(meta)
		_worlds_list.add_child(row)
		_rows[id] = row
	if not _selected_id.is_empty() and _rows.has(_selected_id):
		_apply_row_styles()
	elif not worlds.is_empty():
		_select_world(str(worlds[0].get("id", "")))


func _make_world_row(meta: Dictionary) -> PanelContainer:
	var id := str(meta.get("id", ""))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("world_id", id)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.88, 0.75, 0.88)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.42, 0.25, 0.55)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var title := Label.new()
	title.text = str(meta.get("display_name", id))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.28, 0.2, 0.1, 1.0))
	text_col.add_child(title)

	var detail := Label.new()
	detail.text = "%s  ·  %s" % [
		SaveManager.format_last_played(int(meta.get("last_played", 0))),
		SaveManager.format_island_size(float(meta.get("play_radius", GridManager.DEFAULT_PLAY_RADIUS))),
	]
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color(0.42, 0.34, 0.22, 0.95))
	text_col.add_child(detail)

	var play_btn := Button.new()
	play_btn.text = LocaleManager.t("Play")
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.custom_minimum_size = Vector2(72, 40)
	play_btn.add_theme_font_size_override("font_size", 16)
	play_btn.pressed.connect(func() -> void:
		_select_world(id)
		_enter_world(id)
	)
	row.add_child(play_btn)

	panel.gui_input.connect(_on_row_gui_input.bind(id))
	return panel


func _on_row_gui_input(event: InputEvent, world_id: String) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_press(world_id)
		else:
			_end_press(world_id, true)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_press(world_id)
		else:
			_end_press(world_id, true)


func _begin_press(world_id: String) -> void:
	_press_world_id = world_id
	_long_press_fired = false
	_press_timer.start()


func _end_press(world_id: String, treat_as_tap: bool) -> void:
	_press_timer.stop()
	if _long_press_fired:
		return
	if treat_as_tap and world_id == _press_world_id:
		_select_world(world_id)


func _on_long_press_timeout() -> void:
	if _press_world_id.is_empty():
		return
	_long_press_fired = true
	_select_world(_press_world_id)
	_show_world_actions(_press_world_id)


func _show_world_actions(world_id: String) -> void:
	var meta := SaveManager.load_meta(world_id)
	var name := str(meta.get("display_name", world_id))

	var dlg := AcceptDialog.new()
	dlg.title = name
	dlg.dialog_text = ""
	dlg.ok_button_text = LocaleManager.t("Cancel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(260, 0)
	var rename_btn := Button.new()
	rename_btn.text = LocaleManager.t("Rename")
	rename_btn.custom_minimum_size = Vector2(0, 44)
	rename_btn.add_theme_font_size_override("font_size", 17)
	var delete_btn := Button.new()
	delete_btn.text = LocaleManager.t("Delete")
	delete_btn.custom_minimum_size = Vector2(0, 44)
	delete_btn.add_theme_font_size_override("font_size", 17)
	box.add_child(rename_btn)
	box.add_child(delete_btn)
	dlg.add_child(box)
	rename_btn.pressed.connect(func() -> void:
		dlg.hide()
		dlg.queue_free()
		_open_rename(world_id)
	)
	delete_btn.pressed.connect(func() -> void:
		dlg.hide()
		dlg.queue_free()
		_open_delete(world_id)
	)
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
	)
	dlg.close_requested.connect(func() -> void:
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _open_rename(world_id: String) -> void:
	_rename_target = world_id
	var meta := SaveManager.load_meta(world_id)
	_rename_edit.text = str(meta.get("display_name", ""))
	_rename_dialog.popup_centered(Vector2(360, 140))
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _on_rename_confirmed() -> void:
	if _rename_target.is_empty():
		_rename_dialog.hide()
		return
	if SaveManager.rename_world(_rename_target, _rename_edit.text):
		_status.text = LocaleManager.t("Renamed")
		_rename_dialog.hide()
		_refresh_worlds()
	else:
		_status.text = LocaleManager.t("Enter a valid name")


func _open_delete(world_id: String) -> void:
	_delete_target = world_id
	var meta := SaveManager.load_meta(world_id)
	var name := str(meta.get("display_name", world_id))
	_delete_dialog.dialog_text = LocaleManager.tf("Delete \"%s\"? This cannot be undone.", [name])
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _delete_target.is_empty():
		return
	var id := _delete_target
	_delete_target = ""
	if SaveManager.delete_world(id):
		if _selected_id == id:
			_selected_id = ""
		_status.text = LocaleManager.t("World deleted")
		_refresh_worlds()
	else:
		_status.text = LocaleManager.t("Delete failed")


func _select_world(world_id: String) -> void:
	_selected_id = world_id
	_apply_row_styles()


func _apply_row_styles() -> void:
	for id in _rows:
		var panel: PanelContainer = _rows[id]
		if not is_instance_valid(panel):
			continue
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		var selected: bool = str(id) == _selected_id
		style.border_color = Color(0.75, 0.5, 0.15, 0.95) if selected else Color(0.55, 0.42, 0.25, 0.55)
		style.bg_color = Color(1.0, 0.93, 0.7, 0.95) if selected else Color(0.93, 0.88, 0.75, 0.88)


func _on_new_game() -> void:
	AudioManager.play("ui_click")
	var id := SaveManager.create_world()
	_enter_world(id, true)


func _on_load_game() -> void:
	AudioManager.play("ui_click")
	if _selected_id.is_empty() or not SaveManager.world_exists(_selected_id):
		var last := SaveManager.get_last_world_id()
		if SaveManager.world_exists(last):
			_enter_world(last)
			return
		var worlds := SaveManager.list_worlds()
		if worlds.is_empty():
			_status.text = LocaleManager.t("No worlds yet — tap New Game")
			return
		_enter_world(str(worlds[0].get("id", "")))
		return
	_enter_world(_selected_id)


func _enter_world(world_id: String, is_new: bool = false) -> void:
	if world_id.is_empty() or not SaveManager.world_exists(world_id):
		_status.text = LocaleManager.t("World not found")
		return
	SaveManager.set_current_world_id(world_id)
	# Signal farm scene whether to load save or start empty.
	get_tree().set_meta("boot_world_id", world_id)
	get_tree().set_meta("boot_is_new", is_new)
	SaveManager.touch_last_played(world_id)
	get_tree().change_scene_to_file(FARM_SCENE)


func _on_exit() -> void:
	AudioManager.play("ui_click")
	get_tree().quit()
