class_name ItemPalette
extends PanelContainer

signal item_selected(item_type: ItemData.ItemType)
signal select_tool_activated
signal multiselect_tool_activated
signal hoe_tool_activated
signal harvest_tool_activated
signal rod_tool_activated
## Emitted when active tool/item highlight changes (for top-right Select buttons).
signal tool_highlight_changed(tool: int, item_type: int)

enum Tool { SELECT, MULTISELECT, HOE, HARVEST, ROD }

const SELECT_TOOL := -1
const ICON_SIZE := Vector2(48, 48)
const CHILD_BTN_SIZE := Vector2(120, 34)
const CHILD_BTN_SIZE_TOUCH := Vector2(140, 48)
## Extra inset so content clears phone rounded corners / notch.
const SAFE_INSET_LEFT := 28.0
const SAFE_INSET_TOP := 52.0
const SCROLL_BAR_WIDTH := 32.0
const SCROLL_GUTTER := 8.0

var _buttons: Dictionary = {}
var _select_btn: Button
var _multiselect_btn: Button
var _hoe_btn: Button
var _harvest_btn: Button
var _rod_btn: Button
var _active_type: int = SELECT_TOOL
var _active_tool: Tool = Tool.SELECT

var _section_bodies: Dictionary = {}  # section_id -> Control
var _section_headers: Dictionary = {}  # section_id -> Button
var _open_section: String = ""
var _collapsed: bool = false
var _slide_tween: Tween
var _toggle_btn: Button
var _scroll: ScrollContainer
var _scroll_up_btn: Button
var _scroll_down_btn: Button
var _dock: Control
var _panel_width: float = 156.0
var _dock_left: float = 12.0
var _dock_top: float = 12.0
var _toggle_size := Vector2(30, 56)
var _touch_layout: bool = false
var _header_min_size := Vector2(140, 58)
var _child_btn_size := CHILD_BTN_SIZE
var _header_font_size: int = 16
var _child_font_size: int = 14
var _hoe_guide: Control = null
var _hoe_guide_tween: Tween
var _hoe_guide_token: int = 0
var _hoe_guide_active: bool = false


func _ready() -> void:
	_touch_layout = _prefer_touch_layout()
	if _touch_layout:
		_panel_width = 220.0
		_toggle_size = Vector2(48, 96)
		_header_min_size = Vector2(150, 70)
		_child_btn_size = CHILD_BTN_SIZE_TOUCH
		_header_font_size = 18
		_child_font_size = 16
	_install_dock_and_handle()
	_build_palette()
	activate_select_tool()


func _prefer_touch_layout() -> bool:
	# Farm UI is sized for phones; keep the larger layout everywhere.
	return true


func _install_dock_and_handle() -> void:
	## Wrap this PanelContainer in a side dock so the collapse handle can sit
	## beside the menu without being a PanelContainer child (those cover content).
	var ui := get_parent()
	if ui == null:
		return
	var base_w := maxf(offset_right - offset_left, 156.0)
	if _touch_layout:
		_panel_width = maxf(base_w, 220.0)
	else:
		_panel_width = base_w

	_dock = Control.new()
	_dock.name = "ItemPaletteDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.z_index = 30
	ui.add_child(_dock)
	# Keep above full-screen overlays (inventory bar / cursor) so the handle stays visible.
	ui.move_child(_dock, ui.get_child_count() - 1)

	reparent(_dock)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	offset_left = 0.0
	offset_top = 0.0

	_toggle_btn = Button.new()
	_toggle_btn.name = "PaletteSlideToggle"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.text = "«"
	_toggle_btn.tooltip_text = LocaleManager.t("Hide / show menu")
	_toggle_btn.custom_minimum_size = _toggle_size
	_toggle_btn.size = _toggle_size
	_toggle_btn.z_index = 20
	_toggle_btn.add_theme_font_size_override("font_size", 28 if _touch_layout else 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.26, 0.18, 0.98)
	style.set_corner_radius_all(10 if _touch_layout else 8)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.7, 0.4, 1.0)
	_toggle_btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.42, 0.34, 0.22, 1.0)
	_toggle_btn.add_theme_stylebox_override("hover", hover)
	_toggle_btn.pressed.connect(_toggle_slide)
	_dock.add_child(_toggle_btn)

	_scroll_up_btn = _make_scroll_chevron("▲", "Scroll up")
	_scroll_up_btn.pressed.connect(_on_scroll_up)
	_dock.add_child(_scroll_up_btn)
	_scroll_down_btn = _make_scroll_chevron("▼", "Scroll down")
	_scroll_down_btn.pressed.connect(_on_scroll_down)
	_dock.add_child(_scroll_down_btn)

	get_viewport().size_changed.connect(_layout_dock)
	_layout_dock()


func _layout_dock() -> void:
	if _dock == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# Vertically centered column; leave room for top toolbar + bottom status / island bar.
	var top_guard := 120.0
	var bottom_guard := 160.0
	var avail_h := maxf(vp.y - top_guard - bottom_guard, 280.0)
	var panel_h := mini(avail_h, 560.0 if _touch_layout else 520.0)
	_dock_left = SAFE_INSET_LEFT
	_dock_top = top_guard + (avail_h - panel_h) * 0.5
	if not _collapsed:
		_dock.position = Vector2(_dock_left, _dock_top)
	else:
		_dock.position = Vector2(-_panel_width - 4.0, _dock_top)
	_dock.size = Vector2(_panel_width + _toggle_size.x + 8.0, panel_h)
	size = Vector2(_panel_width, panel_h)
	offset_right = _panel_width
	offset_bottom = panel_h
	if _toggle_btn:
		_toggle_btn.position = Vector2(_panel_width + 4.0, panel_h * 0.5 - _toggle_size.y * 0.5)
	_layout_scroll_chevrons(panel_h)
	if _scroll and is_instance_valid(_scroll):
		_scroll.custom_minimum_size = Vector2(
			_panel_width - 20.0,
			maxf(panel_h - 24.0, 200.0)
		)


func _make_scroll_chevron(text: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(_toggle_size.x, 40.0)
	btn.size = Vector2(_toggle_size.x, 40.0)
	btn.z_index = 20
	btn.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.24, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.7, 0.4, 0.9)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.38, 0.32, 0.22, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _layout_scroll_chevrons(panel_h: float) -> void:
	var x := _panel_width + 4.0
	if _scroll_up_btn:
		_scroll_up_btn.position = Vector2(x, 8.0)
	if _scroll_down_btn:
		_scroll_down_btn.position = Vector2(x, panel_h - 48.0)


func _on_scroll_up() -> void:
	_nudge_scroll(-120.0)


func _on_scroll_down() -> void:
	_nudge_scroll(120.0)


func _nudge_scroll(delta: float) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	_scroll.scroll_vertical = maxi(0, int(_scroll.scroll_vertical + delta))


func _build_palette() -> void:
	var margin := MarginContainer.new()
	var m := 10 if _touch_layout else 8
	margin.add_theme_constant_override("margin_left", m)
	margin.add_theme_constant_override("margin_right", m)
	margin.add_theme_constant_override("margin_top", m)
	margin.add_theme_constant_override("margin_bottom", m)
	add_child(margin)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(_panel_width - float(m * 2), 320.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)
	if _touch_layout:
		_thicken_scroll_bar(scroll)
	_layout_dock()

	# Inset rows so the thick scrollbar sits to their right instead of covering text.
	var content_pad := MarginContainer.new()
	content_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gutter := int(SCROLL_BAR_WIDTH + SCROLL_GUTTER) if _touch_layout else 0
	content_pad.add_theme_constant_override("margin_right", gutter)
	scroll.add_child(content_pad)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12 if _touch_layout else 10)
	content_pad.add_child(outer)

	# Tools accordion: hammer -> hoe / harvest / rod
	var tools_body := VBoxContainer.new()
	tools_body.add_theme_constant_override("separation", 6 if _touch_layout else 4)
	_hoe_btn = _make_child_button(LocaleManager.t("Hoe"))
	_hoe_btn.pressed.connect(_on_hoe_tool_pressed)
	tools_body.add_child(_hoe_btn)
	_harvest_btn = _make_child_button(LocaleManager.t("Harvest"))
	_harvest_btn.pressed.connect(_on_harvest_tool_pressed)
	tools_body.add_child(_harvest_btn)
	_rod_btn = _make_child_button(LocaleManager.t("Rod"))
	_rod_btn.pressed.connect(_on_rod_tool_pressed)
	tools_body.add_child(_rod_btn)
	_add_section(outer, "tools", LocaleManager.t("Tool"), _icon_hammer(), Color(0.55, 0.45, 0.35), tools_body)

	# Category accordions
	var cat_meta := {
		ItemData.Category.TERRAIN: {"id": "terrain", "title": LocaleManager.t("Terrain"), "icon": _icon_dirt(), "color": Color(0.40, 0.26, 0.07)},
		ItemData.Category.STRUCTURE: {"id": "buildings", "title": LocaleManager.t("Building"), "icon": _icon_house(), "color": Color(0.7, 0.45, 0.35)},
		ItemData.Category.ANIMAL: {"id": "animals", "title": LocaleManager.t("Animal"), "icon": _icon_rabbit(), "color": Color(0.85, 0.75, 0.7)},
		ItemData.Category.PLANT: {"id": "crops", "title": LocaleManager.t("Seed"), "icon": _icon_pink_flower(), "color": Color(0.9, 0.55, 0.7)},
		ItemData.Category.DECOR: {"id": "decor", "title": LocaleManager.t("Decoration"), "icon": _icon_bulb(), "color": Color(0.95, 0.85, 0.35)},
	}

	for category in ItemData.CATEGORIES:
		var meta: Dictionary = cat_meta[category]
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 6 if _touch_layout else 4)
		for item_type in ItemData.get_items_by_category(category):
			# Text-only item rows — icons belong on category headers only.
			var btn := _make_child_button(ItemData.get_display_name(item_type))
			btn.toggle_mode = true
			btn.pressed.connect(_on_item_pressed.bind(item_type))
			body.add_child(btn)
			_buttons[item_type] = btn
		_add_section(
			outer,
			str(meta["id"]),
			str(meta["title"]),
			meta["icon"],
			meta["color"],
			body
		)


func _thicken_scroll_bar(scroll: ScrollContainer) -> void:
	## Wider vertical scrollbar / grabber for finger scrolling.
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.custom_minimum_size.x = SCROLL_BAR_WIDTH
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.85, 0.7, 0.4, 0.95)
	grabber.set_corner_radius_all(8)
	grabber.content_margin_left = 4
	grabber.content_margin_right = 4
	bar.add_theme_stylebox_override("grabber", grabber)
	var grabber_hl := grabber.duplicate() as StyleBoxFlat
	grabber_hl.bg_color = Color(0.95, 0.82, 0.5, 1.0)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hl)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.16, 0.12, 0.55)
	track.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("scroll", track)


func _toggle_slide() -> void:
	if _dock == null or _toggle_btn == null:
		return
	_collapsed = not _collapsed
	if _slide_tween and _slide_tween.is_running():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	var target_x: float
	if _collapsed:
		# Keep only the handle on-screen at the left edge.
		target_x = -_panel_width - 4.0
		_toggle_btn.text = "»"
		if _scroll_up_btn:
			_scroll_up_btn.visible = false
		if _scroll_down_btn:
			_scroll_down_btn.visible = false
	else:
		target_x = _dock_left
		_toggle_btn.text = "«"
		if _scroll_up_btn:
			_scroll_up_btn.visible = true
		if _scroll_down_btn:
			_scroll_down_btn.visible = true
	_slide_tween.tween_property(_dock, "position:x", target_x, 0.28)


func _add_section(
	parent: Control,
	section_id: String,
	title: String,
	icon: Texture2D,
	tint: Color,
	body: Control
) -> void:
	var header := _make_labeled_header(title, icon, tint)
	header.pressed.connect(_on_section_header_pressed.bind(section_id))
	parent.add_child(header)
	body.visible = false
	parent.add_child(body)
	_section_headers[section_id] = header
	_section_bodies[section_id] = body


func _make_labeled_header(title: String, icon: Texture2D, tint: Color) -> Button:
	## Icon + caption drawn together on the button (not a separate label above).
	var btn := Button.new()
	btn.text = title
	btn.tooltip_text = title
	btn.icon = icon
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = _header_min_size
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", _header_font_size)
	btn.add_theme_constant_override("h_separation", 10)
	btn.add_theme_constant_override("icon_max_width", 48 if _touch_layout else 40)
	btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.85))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.45)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8 if _touch_layout else 6
	style.content_margin_bottom = 8 if _touch_layout else 6
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _make_child_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = _child_btn_size
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", _child_font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	_apply_child_button_style(btn, false, false)
	return btn


func _apply_child_button_style(btn: Button, selected: bool, guide_pulse: bool = false) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if guide_pulse:
		style.bg_color = Color(0.95, 0.72, 0.2, 0.98)
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.95, 0.45, 1.0)
	elif selected:
		style.bg_color = Color(0.42, 0.55, 0.28, 0.98)
		style.set_border_width_all(3)
		style.border_color = Color(0.95, 0.88, 0.35, 1.0)
	else:
		style.bg_color = Color(0.22, 0.18, 0.14, 0.92)
		style.set_border_width_all(1)
		style.border_color = Color(0.45, 0.38, 0.3, 0.7)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	# Keep pressed looking like selected so toggle stays readable.
	pressed.bg_color = Color(0.42, 0.55, 0.28, 0.98) if selected or guide_pulse else style.bg_color.darkened(0.08)
	pressed.set_border_width_all(3 if selected or guide_pulse else 1)
	pressed.border_color = Color(0.95, 0.88, 0.35, 1.0) if selected or guide_pulse else style.border_color
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.modulate = Color(1.15, 1.1, 0.95) if selected or guide_pulse else Color.WHITE


func _on_section_header_pressed(section_id: String) -> void:
	if _open_section == section_id:
		_set_open_section("")
	else:
		_set_open_section(section_id)


func _set_open_section(section_id: String) -> void:
	_open_section = section_id
	for id in _section_bodies:
		var body: Control = _section_bodies[id]
		var open: bool = (str(id) == _open_section)
		body.visible = open
		var header: Button = _section_headers[id]
		header.modulate = Color(1.15, 1.1, 0.9) if open else Color.WHITE


func _on_select_tool_pressed() -> void:
	activate_select_tool()
	select_tool_activated.emit()


func _on_multiselect_tool_pressed() -> void:
	activate_multiselect_tool()
	multiselect_tool_activated.emit()


func _on_hoe_tool_pressed() -> void:
	activate_hoe_tool()
	hoe_tool_activated.emit()


func _on_harvest_tool_pressed() -> void:
	activate_harvest_tool()
	harvest_tool_activated.emit()


func _on_rod_tool_pressed() -> void:
	activate_rod_tool()
	rod_tool_activated.emit()


func _on_item_pressed(item_type: ItemData.ItemType) -> void:
	if _active_type == item_type and _active_tool == Tool.SELECT:
		activate_select_tool()
		select_tool_activated.emit()
		return
	select_item(item_type)
	item_selected.emit(item_type)


func activate_select_tool() -> void:
	_active_tool = Tool.SELECT
	_active_type = SELECT_TOOL
	_clear_hoe_guide()
	_update_button_styles()


func activate_multiselect_tool() -> void:
	_active_tool = Tool.MULTISELECT
	_active_type = SELECT_TOOL
	_clear_hoe_guide()
	_update_button_styles()


func activate_hoe_tool() -> void:
	_active_tool = Tool.HOE
	_active_type = SELECT_TOOL
	_set_open_section("tools")
	# Keep guide pulse if we're mid-hint; otherwise clear stale guides.
	if not _hoe_guide_active:
		_clear_hoe_guide()
	_update_button_styles()


## Expand the tool list, select Hoe, and pulse-highlight it.
func guide_to_hoe() -> void:
	if _collapsed:
		_toggle_slide()
	_hoe_guide_active = true
	activate_hoe_tool()
	hoe_tool_activated.emit()
	call_deferred("_finish_hoe_guide")


func _finish_hoe_guide() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_hoe_btn):
		return
	_scroll_control_into_view(_hoe_btn)
	_start_hoe_guide_pulse()


func _scroll_control_into_view(control: Control) -> void:
	if _scroll == null or control == null or not is_instance_valid(control):
		return
	var scroll_rect := _scroll.get_global_rect()
	var target_rect := control.get_global_rect()
	var delta := 0.0
	if target_rect.position.y < scroll_rect.position.y:
		delta = target_rect.position.y - scroll_rect.position.y - 12.0
	elif target_rect.end.y > scroll_rect.end.y:
		delta = target_rect.end.y - scroll_rect.end.y + 12.0
	if absf(delta) > 1.0:
		_scroll.scroll_vertical = maxi(0, int(_scroll.scroll_vertical + delta))


func _start_hoe_guide_pulse() -> void:
	_hoe_guide_active = true
	_hoe_guide_token += 1
	var token := _hoe_guide_token
	_update_button_styles()
	if _hoe_guide_tween and _hoe_guide_tween.is_running():
		_hoe_guide_tween.kill()
	if _hoe_btn == null:
		return
	_hoe_guide_tween = create_tween()
	_hoe_guide_tween.set_loops()
	_hoe_guide_tween.tween_property(_hoe_btn, "modulate", Color(1.35, 1.2, 0.75), 0.4).set_trans(Tween.TRANS_SINE)
	_hoe_guide_tween.tween_property(_hoe_btn, "modulate", Color(1.05, 1.0, 0.9), 0.4).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(5.5).timeout.connect(func() -> void:
		if token == _hoe_guide_token:
			_clear_hoe_guide()
	)


func _clear_hoe_guide() -> void:
	_hoe_guide_token += 1
	_hoe_guide_active = false
	if _hoe_guide_tween and _hoe_guide_tween.is_running():
		_hoe_guide_tween.kill()
	_hoe_guide_tween = null
	if _hoe_guide and is_instance_valid(_hoe_guide):
		_hoe_guide.queue_free()
	_hoe_guide = null
	if _hoe_btn and is_instance_valid(_hoe_btn) and _active_tool == Tool.HOE:
		_apply_child_button_style(_hoe_btn, true, false)
	elif _hoe_btn and is_instance_valid(_hoe_btn):
		_apply_child_button_style(_hoe_btn, false, false)


func activate_harvest_tool() -> void:
	_active_tool = Tool.HARVEST
	_active_type = SELECT_TOOL
	_clear_hoe_guide()
	_set_open_section("tools")
	_update_button_styles()


func activate_rod_tool() -> void:
	_active_tool = Tool.ROD
	_active_type = SELECT_TOOL
	_clear_hoe_guide()
	_set_open_section("tools")
	_update_button_styles()


func select_item(item_type: ItemData.ItemType) -> void:
	_active_tool = Tool.SELECT
	_active_type = item_type
	_clear_hoe_guide()
	var cat: ItemData.Category = ItemData.ITEMS[item_type]["category"]
	var section_map: Dictionary = {
		ItemData.Category.TERRAIN: "terrain",
		ItemData.Category.STRUCTURE: "buildings",
		ItemData.Category.ANIMAL: "animals",
		ItemData.Category.PLANT: "crops",
		ItemData.Category.DECOR: "decor",
	}
	var section: String = str(section_map.get(cat, ""))
	if section != "":
		_set_open_section(section)
	_update_button_styles()


func _update_button_styles() -> void:
	if _hoe_btn:
		var hoe_on := _active_tool == Tool.HOE
		_hoe_btn.button_pressed = hoe_on
		_apply_child_button_style(_hoe_btn, hoe_on, _hoe_guide_active and hoe_on)
	if _harvest_btn:
		var harvest_on := _active_tool == Tool.HARVEST
		_harvest_btn.button_pressed = harvest_on
		_apply_child_button_style(_harvest_btn, harvest_on, false)
	if _rod_btn:
		var rod_on := _active_tool == Tool.ROD
		_rod_btn.button_pressed = rod_on
		_apply_child_button_style(_rod_btn, rod_on, false)
	for type in _buttons:
		var btn: Button = _buttons[type]
		var on: bool = _active_tool == Tool.SELECT and int(type) == _active_type
		btn.button_pressed = on
		_apply_child_button_style(btn, on, false)
	tool_highlight_changed.emit(int(_active_tool), _active_type)


# --- Category / tool icons (procedural) ---------------------------------

func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, c)


func _icon_select() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	# Pointer triangle
	for y in range(12, 48):
		var w: int = int((y - 12) * 0.55)
		for x in range(18, 18 + maxi(w, 1)):
			img.set_pixel(x, y, c)
	_fill_rect(img, 18, 40, 28, 54, c)
	return ImageTexture.create_from_image(img)


func _icon_multiselect() -> Texture2D:
	## Two dashed selection boxes.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	_stroke_rect_dashed(img, 8, 10, 36, 38, c)
	_stroke_rect_dashed(img, 24, 24, 54, 54, c)
	return ImageTexture.create_from_image(img)


func _stroke_rect_dashed(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dash := 3
	var gap := 2
	var period := dash + gap
	for x in range(x0, x1 + 1):
		if (x - x0) % period < dash:
			img.set_pixel(x, y0, c)
			img.set_pixel(x, y1, c)
	for y in range(y0, y1 + 1):
		if (y - y0) % period < dash:
			img.set_pixel(x0, y, c)
			img.set_pixel(x1, y, c)


func _icon_hammer() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var head := Color(0.75, 0.75, 0.78)
	var handle := Color(0.55, 0.35, 0.18)
	# Handle diagonal
	for i in range(18, 52):
		for t in range(-3, 4):
			var x := i + t
			var y := i
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				img.set_pixel(x, y, handle)
	# Head
	_fill_rect(img, 10, 12, 34, 28, head)
	_fill_rect(img, 8, 16, 14, 24, head.darkened(0.15))
	return ImageTexture.create_from_image(img)


func _icon_dirt() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var soil := Color(0.40, 0.26, 0.07)
	var dark := Color(0.4, 0.28, 0.15)
	# Isometric-ish mound
	for y in range(20, 50):
		var span: int = 8 + (y - 20)
		_fill_rect(img, 32 - span, y, 32 + span, y + 1, soil if y % 3 != 0 else dark)
	return ImageTexture.create_from_image(img)


func _icon_house() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wall := Color(0.92, 0.88, 0.8)
	var roof := Color(0.75, 0.35, 0.28)
	var door := Color(0.45, 0.28, 0.15)
	# Walls
	_fill_rect(img, 16, 30, 48, 52, wall)
	# Roof triangle
	for y in range(12, 32):
		var w: int = (y - 12) * 2
		_fill_rect(img, 32 - w, y, 32 + w, y + 1, roof)
	# Door
	_fill_rect(img, 28, 38, 36, 52, door)
	return ImageTexture.create_from_image(img)


func _icon_rabbit() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fur := Color(0.95, 0.9, 0.88)
	var ear := Color(0.98, 0.8, 0.85)
	var eye := Color(0.15, 0.12, 0.12)
	# Body
	_fill_rect(img, 20, 28, 44, 50, fur)
	# Head
	_fill_rect(img, 24, 18, 40, 34, fur)
	# Ears
	_fill_rect(img, 24, 6, 30, 22, ear)
	_fill_rect(img, 34, 6, 40, 22, ear)
	# Eyes
	_fill_rect(img, 27, 24, 30, 27, eye)
	_fill_rect(img, 34, 24, 37, 27, eye)
	return ImageTexture.create_from_image(img)


func _icon_wheat() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stem := Color(0.35, 0.55, 0.2)
	var head := Color(0.92, 0.78, 0.25)
	_fill_rect(img, 30, 28, 34, 54, stem)
	for i in range(5):
		var y := 12 + i * 4
		_fill_rect(img, 24, y, 40, y + 3, head)
	return ImageTexture.create_from_image(img)


func _icon_pink_flower() -> Texture2D:
	## Soft pink blossom for the Seed category header.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var petal := Color(0.95, 0.55, 0.72)
	var petal_dark := Color(0.88, 0.4, 0.62)
	var center := Color(1.0, 0.88, 0.45)
	var stem := Color(0.35, 0.62, 0.32)
	_fill_rect(img, 30, 36, 34, 56, stem)
	# Five petals around center.
	for i in range(5):
		var ang := -PI * 0.5 + float(i) * TAU / 5.0
		var cx := 32.0 + cos(ang) * 12.0
		var cy := 26.0 + sin(ang) * 12.0
		for y in range(64):
			for x in range(64):
				var dx := float(x) - cx
				var dy := float(y) - cy
				if dx * dx + dy * dy <= 81.0:
					img.set_pixel(x, y, petal if (i % 2 == 0) else petal_dark)
	for y in range(64):
		for x in range(64):
			var dx := x - 32
			var dy := y - 26
			if dx * dx + dy * dy <= 49:
				img.set_pixel(x, y, center)
	return ImageTexture.create_from_image(img)


func _icon_bulb() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var glass := Color(1.0, 0.92, 0.45)
	var base := Color(0.55, 0.55, 0.58)
	# Bulb circle-ish
	for y in range(10, 42):
		for x in range(16, 48):
			var dx := x - 32
			var dy := y - 26
			if dx * dx + dy * dy <= 196:
				img.set_pixel(x, y, glass)
	_fill_rect(img, 26, 40, 38, 52, base)
	_fill_rect(img, 28, 52, 36, 56, base.darkened(0.2))
	return ImageTexture.create_from_image(img)
