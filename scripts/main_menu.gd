extends Control

## Main menu: New Game / Load Game / Exit + worlds list with long-press rename/delete.

const FARM_SCENE := "res://scenes/main.tscn"
const LONG_PRESS_MS := 450

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


func _ready() -> void:
	SaveManager.ensure_ready()
	_build_ui()
	_refresh_worlds()
	var last := SaveManager.get_last_world_id()
	if SaveManager.world_exists(last):
		_select_world(last)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/icons/menu.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Content sits over the parchment panel in the art.
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 72)
	root.add_theme_constant_override("margin_right", 72)
	root.add_theme_constant_override("margin_top", 88)
	root.add_theme_constant_override("margin_bottom", 64)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	var brand := Label.new()
	brand.text = "Cozy Farm"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 48)
	brand.add_theme_color_override("font_color", Color(0.32, 0.22, 0.12, 1.0))
	brand.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	brand.add_theme_constant_override("shadow_offset_x", 1)
	brand.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(brand)

	var tag := Label.new()
	tag.text = "Build your island · grow your world"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(0.42, 0.34, 0.22, 0.95))
	col.add_child(tag)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	actions.add_child(_make_main_btn("New Game", Color(0.45, 0.62, 0.35), _on_new_game))
	actions.add_child(_make_main_btn("Load Game", Color(0.4, 0.55, 0.7), _on_load_game))
	actions.add_child(_make_main_btn("Exit", Color(0.7, 0.45, 0.38), _on_exit))

	var worlds_header := Label.new()
	worlds_header.text = "Worlds"
	worlds_header.add_theme_font_size_override("font_size", 22)
	worlds_header.add_theme_color_override("font_color", Color(0.3, 0.22, 0.12, 1.0))
	col.add_child(worlds_header)

	var hint := Label.new()
	hint.text = "Tap to select · Long-press to rename or delete"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28, 0.9))
	col.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_worlds_list = VBoxContainer.new()
	_worlds_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_worlds_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_worlds_list)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.38, 0.3, 0.18, 0.95))
	col.add_child(_status)

	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = LONG_PRESS_MS / 1000.0
	_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_press_timer)

	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename World"
	_rename_dialog.ok_button_text = "Rename"
	_rename_dialog.dialog_hide_on_ok = false
	var rename_wrap := MarginContainer.new()
	rename_wrap.add_theme_constant_override("margin_left", 8)
	rename_wrap.add_theme_constant_override("margin_right", 8)
	rename_wrap.add_theme_constant_override("margin_top", 8)
	rename_wrap.add_theme_constant_override("margin_bottom", 8)
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size = Vector2(300, 44)
	_rename_edit.placeholder_text = "World name"
	rename_wrap.add_child(_rename_edit)
	_rename_dialog.add_child(rename_wrap)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete World"
	_delete_dialog.dialog_text = "Delete this world? This cannot be undone."
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)


func _make_main_btn(text: String, tint: Color, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
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
		empty.text = "No worlds yet — tap New Game to start."
		empty.add_theme_font_size_override("font_size", 15)
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
	play_btn.text = "Play"
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
	dlg.ok_button_text = "Cancel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(260, 0)
	var rename_btn := Button.new()
	rename_btn.text = "Rename"
	rename_btn.custom_minimum_size = Vector2(0, 44)
	rename_btn.add_theme_font_size_override("font_size", 17)
	var delete_btn := Button.new()
	delete_btn.text = "Delete"
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
		_status.text = "Renamed"
		_rename_dialog.hide()
		_refresh_worlds()
	else:
		_status.text = "Enter a valid name"


func _open_delete(world_id: String) -> void:
	_delete_target = world_id
	var meta := SaveManager.load_meta(world_id)
	var name := str(meta.get("display_name", world_id))
	_delete_dialog.dialog_text = "Delete \"%s\"? This cannot be undone." % name
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _delete_target.is_empty():
		return
	var id := _delete_target
	_delete_target = ""
	if SaveManager.delete_world(id):
		if _selected_id == id:
			_selected_id = ""
		_status.text = "World deleted"
		_refresh_worlds()
	else:
		_status.text = "Delete failed"


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
	var id := SaveManager.create_world()
	_enter_world(id, true)


func _on_load_game() -> void:
	if _selected_id.is_empty() or not SaveManager.world_exists(_selected_id):
		var last := SaveManager.get_last_world_id()
		if SaveManager.world_exists(last):
			_enter_world(last)
			return
		var worlds := SaveManager.list_worlds()
		if worlds.is_empty():
			_status.text = "No worlds yet — tap New Game"
			return
		_enter_world(str(worlds[0].get("id", "")))
		return
	_enter_world(_selected_id)


func _enter_world(world_id: String, is_new: bool = false) -> void:
	if world_id.is_empty() or not SaveManager.world_exists(world_id):
		_status.text = "World not found"
		return
	SaveManager.set_current_world_id(world_id)
	# Signal farm scene whether to load save or start empty.
	get_tree().set_meta("boot_world_id", world_id)
	get_tree().set_meta("boot_is_new", is_new)
	SaveManager.touch_last_played(world_id)
	get_tree().change_scene_to_file(FARM_SCENE)


func _on_exit() -> void:
	get_tree().quit()
