class_name InventoryBar
extends Control

## Backpack button + 8x8 inventory grid for harvested / collected items.

signal feed_item_selected(item: InventoryData.Item)
signal feed_selection_cleared

const GRID_COLS: int = 8
const GRID_ROWS: int = 8
const SLOT_COUNT: int = GRID_COLS * GRID_ROWS
const SLOT_SIZE := Vector2(52, 52)

var _inventory: InventoryManager
var _backpack_btn: Button
var _panel: PanelContainer
var _grid: GridContainer
var _slots: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _slot_items: Array = []  # InventoryData.Item or null per slot
var _active_feed_item = null
var _open: bool = false


func setup(inventory: InventoryManager) -> void:
	_inventory = inventory
	_inventory.inventory_changed.connect(_refresh)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_backpack_btn = Button.new()
	_backpack_btn.tooltip_text = "Open backpack"
	_backpack_btn.custom_minimum_size = Vector2(64, 64)
	_backpack_btn.icon = _make_backpack_icon()
	_backpack_btn.expand_icon = true
	_backpack_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_backpack_btn.offset_left = -84.0
	_backpack_btn.offset_top = -100.0
	_backpack_btn.offset_right = -16.0
	_backpack_btn.offset_bottom = -36.0
	_backpack_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_backpack_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_backpack_btn.pressed.connect(_toggle_panel)
	_style_backpack_button(_backpack_btn)
	add_child(_backpack_btn)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -240.0
	_panel.offset_top = -260.0
	_panel.offset_right = 240.0
	_panel.offset_bottom = 260.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.08, 0.94)
	panel_style.border_color = Color(0.55, 0.42, 0.28, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Backpack"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_panel)
	header.add_child(close_btn)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)

	_slots.clear()
	_slot_icons.clear()
	_slot_counts.clear()
	_slot_items.clear()
	for i in range(SLOT_COUNT):
		var slot := _make_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)
		_slot_items.append(null)


func _style_backpack_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.3, 0.18, 0.95)
	normal.set_corner_radius_all(12)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.72, 0.55, 0.32)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.52, 0.38, 0.22, 0.98)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.22, 0.12, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed)


func _make_backpack_icon() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leather := Color(0.62, 0.42, 0.22)
	var dark := Color(0.38, 0.24, 0.12)
	var strap := Color(0.72, 0.52, 0.28)
	# Bag body
	for y in range(18, 54):
		for x in range(14, 50):
			img.set_pixel(x, y, leather)
	# Flap
	for y in range(14, 26):
		for x in range(16, 48):
			img.set_pixel(x, y, dark)
	# Strap loop
	for y in range(8, 18):
		for x in range(26, 38):
			if y < 12 or x < 28 or x > 35:
				img.set_pixel(x, y, strap)
	# Pocket line
	for x in range(20, 44):
		img.set_pixel(x, 36, dark)
	return ImageTexture.create_from_image(img)


func _make_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.17, 0.14, 0.9)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.34, 0.28)
	slot.add_theme_stylebox_override("panel", style)

	var root := Control.new()
	root.custom_minimum_size = SLOT_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_child(root)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 4
	icon.offset_right = -6
	icon.offset_bottom = -14
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_slot_icons.append(icon)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 12)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -4
	count.offset_bottom = -2
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(count)
	_slot_counts.append(count)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(index))
	root.add_child(btn)
	return slot


func _toggle_panel() -> void:
	if _open:
		_close_panel()
	else:
		_open = true
		_panel.visible = true
		_refresh()


func _close_panel() -> void:
	_open = false
	_panel.visible = false


func _refresh() -> void:
	for i in range(SLOT_COUNT):
		_slot_items[i] = null
		_slot_icons[i].texture = null
		_slot_counts[i].text = ""
		_slots[i].modulate = Color(1, 1, 1, 0.85)
		_slots[i].tooltip_text = ""

	for item in InventoryData.ITEMS:
		var slot_i: int = int(InventoryData.SLOT_INDEX.get(item, -1))
		if slot_i < 0 or slot_i >= SLOT_COUNT:
			continue
		var count: int = _inventory.get_count(item)
		_slot_items[slot_i] = item
		if count <= 0:
			_slot_icons[slot_i].modulate = Color(1, 1, 1, 0.2)
			_slot_icons[slot_i].texture = InventoryData.get_icon(item)
			_slot_counts[slot_i].text = ""
			_slots[slot_i].tooltip_text = InventoryData.get_item_name(item)
			continue
		_slot_icons[slot_i].modulate = Color.WHITE
		_slot_icons[slot_i].texture = InventoryData.get_icon(item)
		_slot_counts[slot_i].text = str(count)
		var tip := "%s x%d" % [InventoryData.get_item_name(item), count]
		if InventoryData.is_feedable(item):
			tip += "\nClick to feed animals"
		_slots[slot_i].tooltip_text = tip
		if _active_feed_item != null and item == _active_feed_item:
			_slots[slot_i].modulate = Color(1.15, 1.05, 0.75)


func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= _slot_items.size():
		return
	var item = _slot_items[index]
	if item == null:
		return
	if not _inventory.has_item(item):
		clear_feed_selection()
		return
	if not InventoryData.is_feedable(item):
		return
	if _active_feed_item == item:
		clear_feed_selection()
		return
	_active_feed_item = item
	_refresh()
	feed_item_selected.emit(item)


func clear_feed_selection() -> void:
	if _active_feed_item == null:
		return
	_active_feed_item = null
	_refresh()
	feed_selection_cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_panel()
		get_viewport().set_input_as_handled()
