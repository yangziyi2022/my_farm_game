class_name InventoryBar
extends PanelContainer

signal feed_item_selected(item: InventoryData.Item)
signal feed_selection_cleared

var _inventory: InventoryManager
var _slots: Dictionary = {}
var _active_feed_item = null  # InventoryData.Item or null


func setup(inventory: InventoryManager) -> void:
	_inventory = inventory
	_inventory.inventory_changed.connect(_refresh)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for item in InventoryData.ITEMS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(88, 42)
		btn.toggle_mode = true
		btn.pressed.connect(_on_slot_pressed.bind(item))
		grid.add_child(btn)
		_slots[item] = btn


func _refresh() -> void:
	for item in _slots:
		var btn: Button = _slots[item]
		var count: int = _inventory.get_count(item)
		var label: String = InventoryData.get_item_name(item)
		btn.text = "%s\nx%d" % [label, count]
		btn.disabled = count <= 0
		if InventoryData.is_feedable(item):
			btn.tooltip_text = "Click to feed animals"
		btn.button_pressed = _active_feed_item != null and item == _active_feed_item


func _on_slot_pressed(item: InventoryData.Item) -> void:
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
