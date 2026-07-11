class_name ItemPalette
extends PanelContainer

signal item_selected(item_type: ItemData.ItemType)
signal select_tool_activated
signal hoe_tool_activated
signal harvest_tool_activated
signal rod_tool_activated

enum Tool { SELECT, HOE, HARVEST, ROD }

const SELECT_TOOL := -1

var _buttons: Dictionary = {}
var _select_btn: Button
var _hoe_btn: Button
var _harvest_btn: Button
var _rod_btn: Button
var _active_type: int = SELECT_TOOL
var _active_tool: Tool = Tool.SELECT


func _ready() -> void:
	_build_palette()
	activate_select_tool()


func _build_palette() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Tools"
	title.add_theme_font_size_override("font_size", 16)
	outer_vbox.add_child(title)

	_select_btn = _make_tool_button("Select")
	_select_btn.pressed.connect(_on_select_tool_pressed)
	outer_vbox.add_child(_select_btn)

	_hoe_btn = _make_tool_button("Hoe")
	_hoe_btn.pressed.connect(_on_hoe_tool_pressed)
	outer_vbox.add_child(_hoe_btn)

	_harvest_btn = _make_tool_button("Harvest")
	_harvest_btn.pressed.connect(_on_harvest_tool_pressed)
	outer_vbox.add_child(_harvest_btn)

	_rod_btn = _make_tool_button("Rod")
	_rod_btn.pressed.connect(_on_rod_tool_pressed)
	outer_vbox.add_child(_rod_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	for category in ItemData.CATEGORIES:
		var cat_label := Label.new()
		cat_label.text = ItemData.CATEGORIES[category]
		cat_label.add_theme_font_size_override("font_size", 13)
		content.add_child(cat_label)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		content.add_child(grid)

		for item_type in ItemData.get_items_by_category(category):
			var btn := Button.new()
			btn.text = ItemData.get_display_name(item_type)
			btn.custom_minimum_size = Vector2(100, 40)
			btn.toggle_mode = true
			var icon := ItemData.get_icon(item_type)
			if icon:
				btn.icon = icon
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			btn.pressed.connect(_on_item_pressed.bind(item_type))
			grid.add_child(btn)
			_buttons[item_type] = btn


func _make_tool_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(210, 34)
	btn.toggle_mode = true
	return btn


func _on_select_tool_pressed() -> void:
	activate_select_tool()
	select_tool_activated.emit()


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
	_update_button_styles()


func activate_hoe_tool() -> void:
	_active_tool = Tool.HOE
	_active_type = SELECT_TOOL
	_update_button_styles()


func activate_harvest_tool() -> void:
	_active_tool = Tool.HARVEST
	_active_type = SELECT_TOOL
	_update_button_styles()


func activate_rod_tool() -> void:
	_active_tool = Tool.ROD
	_active_type = SELECT_TOOL
	_update_button_styles()


func select_item(item_type: ItemData.ItemType) -> void:
	_active_tool = Tool.SELECT
	_active_type = item_type
	_update_button_styles()


func _update_button_styles() -> void:
	if _select_btn:
		_select_btn.button_pressed = _active_tool == Tool.SELECT and _active_type == SELECT_TOOL
	if _hoe_btn:
		_hoe_btn.button_pressed = _active_tool == Tool.HOE
	if _harvest_btn:
		_harvest_btn.button_pressed = _active_tool == Tool.HARVEST
	if _rod_btn:
		_rod_btn.button_pressed = _active_tool == Tool.ROD
	for type in _buttons:
		var btn: Button = _buttons[type]
		btn.button_pressed = _active_tool == Tool.SELECT and type == _active_type
