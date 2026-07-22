class_name InventoryBar
extends Control

## Backpack button + 8x8 inventory grid for harvested / collected items.
## Top row (hotbar) uses a distinct tint — those 8 slots drive walk-mode hands.

signal feed_item_selected(item: InventoryData.Item)
signal feed_selection_cleared
signal walk_mode_pressed

const GRID_COLS: int = InventoryData.GRID_COLS
const GRID_ROWS: int = InventoryData.GRID_ROWS
const SLOT_COUNT: int = InventoryData.SLOT_COUNT
const HOTBAR_SIZE: int = InventoryData.HOTBAR_SIZE
const ICON_SIZE := Vector2(48, 48)
const HOTBAR_BG := Color(0.18, 0.32, 0.38, 0.92)
const NORMAL_BG := Color(0, 0, 0, 0)
const SLOT_FRAME := Color(0.2, 0.17, 0.14, 0.9)
const HOTBAR_FRAME := Color(0.22, 0.4, 0.48, 0.95)

var _inventory: InventoryManager
var _backpack_btn: Button
var _walk_btn: Button
var _panel_layer: CanvasLayer
var _panel: PanelContainer
var _grid: GridContainer
var _slot_cells: Array[PanelContainer] = []
var _slots: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _slot_labels: Array[Label] = []
var _slot_roots: Array[Control] = []
var _active_feed_item = null
var _open: bool = false
var _drag_from: int = -1


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
	var pack_size := 76.0
	_backpack_btn.custom_minimum_size = Vector2(pack_size, pack_size)
	_backpack_btn.icon = _make_backpack_icon()
	_backpack_btn.expand_icon = true
	_backpack_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var inset_r := 28.0
	var inset_b := 48.0
	_backpack_btn.offset_left = -(pack_size + inset_r + 4.0)
	_backpack_btn.offset_top = -(pack_size + inset_b)
	_backpack_btn.offset_right = -inset_r
	_backpack_btn.offset_bottom = -inset_b
	_backpack_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_backpack_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_backpack_btn.pressed.connect(_toggle_panel)
	_style_backpack_button(_backpack_btn)
	add_child(_backpack_btn)

	_walk_btn = Button.new()
	_walk_btn.tooltip_text = "Walk on your island"
	_walk_btn.custom_minimum_size = Vector2(pack_size, pack_size)
	_walk_btn.icon = _make_walk_icon()
	_walk_btn.expand_icon = true
	_walk_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var walk_gap := 12.0
	_walk_btn.offset_left = -(pack_size * 2.0 + walk_gap + inset_r + 4.0)
	_walk_btn.offset_top = -(pack_size + inset_b)
	_walk_btn.offset_right = -(pack_size + walk_gap + inset_r)
	_walk_btn.offset_bottom = -inset_b
	_walk_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_walk_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_walk_btn.pressed.connect(func() -> void: walk_mode_pressed.emit())
	_style_walk_button(_walk_btn)
	add_child(_walk_btn)

	# Own canvas layer so the open bag always sits above palette / island bar / walk HUD.
	_panel_layer = CanvasLayer.new()
	_panel_layer.name = "BackpackLayer"
	_panel_layer.layer = 60
	add_child(_panel_layer)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300.0
	_panel.offset_top = -320.0
	_panel.offset_right = 300.0
	_panel.offset_bottom = 320.0
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
	_panel_layer.add_child(_panel)

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

	var hotbar_hint := Label.new()
	hotbar_hint.text = "Top row = walk hotbar (1–8) · Bottom-right = tools (∞)"
	hotbar_hint.add_theme_font_size_override("font_size", 12)
	hotbar_hint.add_theme_color_override("font_color", Color(0.55, 0.78, 0.85))
	vbox.add_child(hotbar_hint)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_grid)

	_slot_cells.clear()
	_slots.clear()
	_slot_icons.clear()
	_slot_counts.clear()
	_slot_labels.clear()
	_slot_roots.clear()
	for i in range(SLOT_COUNT):
		_grid.add_child(_make_slot(i))


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


func _style_walk_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.28, 0.48, 0.38, 0.95)
	normal.set_corner_radius_all(12)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.55, 0.78, 0.55)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.34, 0.58, 0.44, 0.98)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.36, 0.28, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed)


func set_walk_button_visible(visible: bool) -> void:
	if _walk_btn:
		_walk_btn.visible = visible


func _make_backpack_icon() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leather := Color(0.62, 0.42, 0.22)
	var dark := Color(0.38, 0.24, 0.12)
	var strap := Color(0.72, 0.52, 0.28)
	for y in range(18, 54):
		for x in range(14, 50):
			img.set_pixel(x, y, leather)
	for y in range(14, 26):
		for x in range(16, 48):
			img.set_pixel(x, y, dark)
	for y in range(8, 18):
		for x in range(26, 38):
			if y < 12 or x < 28 or x > 35:
				img.set_pixel(x, y, strap)
	for x in range(20, 44):
		img.set_pixel(x, 36, dark)
	return ImageTexture.create_from_image(img)


func _make_walk_icon() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.95, 0.95, 0.9)
	for y in range(10, 24):
		for x in range(26, 38):
			var dx := x - 32
			var dy := y - 17
			if dx * dx + dy * dy <= 36:
				img.set_pixel(x, y, c)
	for y in range(24, 42):
		for x in range(27, 37):
			img.set_pixel(x, y, c)
	for y in range(42, 56):
		for x in range(27, 31):
			img.set_pixel(x, y, c)
		for x in range(33, 37):
			img.set_pixel(x, y, c)
	for y in range(26, 30):
		for x in range(18, 46):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_slot(index: int) -> PanelContainer:
	var is_hotbar := index < HOTBAR_SIZE
	var is_tool_corner := index >= SLOT_COUNT - 3
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(64, 78)
	var cell_style := StyleBoxFlat.new()
	if is_hotbar:
		cell_style.bg_color = HOTBAR_BG
		cell_style.set_corner_radius_all(8)
		cell_style.content_margin_left = 2
		cell_style.content_margin_right = 2
		cell_style.content_margin_top = 2
		cell_style.content_margin_bottom = 2
		cell_style.set_border_width_all(1)
		cell_style.border_color = Color(0.45, 0.72, 0.8, 0.7)
	elif is_tool_corner:
		cell_style.bg_color = Color(0.28, 0.22, 0.16, 0.85)
		cell_style.set_corner_radius_all(8)
		cell_style.set_border_width_all(1)
		cell_style.border_color = Color(0.7, 0.55, 0.3, 0.65)
	else:
		cell_style.bg_color = NORMAL_BG
	cell.add_theme_stylebox_override("panel", cell_style)
	_slot_cells.append(cell)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(col)

	if is_hotbar:
		var key_lbl := Label.new()
		key_lbl.text = str(index + 1)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.95))
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(key_lbl)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = ICON_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = HOTBAR_FRAME if is_hotbar else SLOT_FRAME
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.78, 0.85) if is_hotbar else Color(0.4, 0.34, 0.28)
	slot.add_theme_stylebox_override("panel", style)
	col.add_child(slot)

	var root := Control.new()
	root.custom_minimum_size = ICON_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_drag_forwarding(
		Callable(self, "_slot_get_drag_data").bind(index),
		Callable(self, "_slot_can_drop_data").bind(index),
		Callable(self, "_slot_drop_data").bind(index)
	)
	root.gui_input.connect(_on_slot_gui_input.bind(index))
	slot.add_child(root)
	_slot_roots.append(root)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 4
	icon.offset_right = -5
	icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_slot_icons.append(icon)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 11)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -3
	count.offset_bottom = -1
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(count)
	_slot_counts.append(count)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(64, 22)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	name_lbl.text = ""
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)
	_slot_labels.append(name_lbl)

	_slots.append(slot)
	return cell


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		# Release after a drag from this slot — ignore as click.
		if _drag_from == index:
			_drag_from = -1
			return
		if _drag_from >= 0:
			return
		_on_slot_pressed(index)


func _slot_get_drag_data(_at_position: Vector2, index: int) -> Variant:
	if _inventory == null or _inventory.is_slot_empty(index):
		return null
	_drag_from = index
	var item = _inventory.get_slot_item(index)
	var preview := TextureRect.new()
	preview.texture = InventoryData.get_icon(item)
	preview.custom_minimum_size = ICON_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"type": "inv_slot", "index": index}


func _slot_can_drop_data(_at_position: Vector2, data: Variant, _index: int) -> bool:
	return data is Dictionary and str(data.get("type", "")) == "inv_slot"


func _slot_drop_data(_at_position: Vector2, data: Variant, index: int) -> void:
	if not (data is Dictionary):
		return
	var from_i := int(data.get("index", -1))
	if from_i < 0 or _inventory == null:
		return
	_inventory.swap_slots(from_i, index)
	_drag_from = -1


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
	if _inventory == null:
		return
	for i in range(SLOT_COUNT):
		_slot_icons[i].texture = null
		_slot_counts[i].text = ""
		_slot_labels[i].text = ""
		_slots[i].modulate = Color(1, 1, 1, 0.85)
		_slots[i].tooltip_text = ""
		if _inventory.is_slot_empty(i):
			continue
		var item = _inventory.get_slot_item(i)
		var count: int = _inventory.get_slot_count(i)
		var item_name := InventoryData.get_item_name(item)
		_slot_icons[i].modulate = Color.WHITE
		_slot_icons[i].texture = InventoryData.get_icon(item)
		if InventoryData.is_infinite(item):
			_slot_counts[i].text = "∞"
		else:
			_slot_counts[i].text = str(count)
		_slot_labels[i].text = item_name
		_slot_labels[i].modulate = Color.WHITE
		var tip := item_name if InventoryData.is_infinite(item) else "%s x%d" % [item_name, count]
		if InventoryData.is_hand_tool(item):
			tip += "\nDrag to hotbar · Use while walking"
		elif InventoryData.is_feedable(item):
			tip += "\nFeed (species diet) · Click animal / Walk Use"
		if i < HOTBAR_SIZE:
			tip += "\nWalk hotbar slot %d" % (i + 1)
		tip += "\nDrag to rearrange"
		_slots[i].tooltip_text = tip
		if _active_feed_item != null and item == _active_feed_item:
			_slots[i].modulate = Color(1.15, 1.05, 0.75)


func _on_slot_pressed(index: int) -> void:
	if _inventory == null or _inventory.is_slot_empty(index):
		return
	var item = _inventory.get_slot_item(index)
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
