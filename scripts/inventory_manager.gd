class_name InventoryManager
extends Node

signal inventory_changed
signal item_added(item: InventoryData.Item, amount: int)
signal item_removed(item: InventoryData.Item, amount: int)

var _counts: Dictionary = {}


func _ready() -> void:
	for item in InventoryData.ITEMS:
		_counts[item] = 0


func get_count(item: InventoryData.Item) -> int:
	return _counts.get(item, 0)


func has_item(item: InventoryData.Item, amount: int = 1) -> bool:
	return get_count(item) >= amount


func add_item(item: InventoryData.Item, amount: int = 1) -> void:
	if amount <= 0:
		return
	_counts[item] = get_count(item) + amount
	item_added.emit(item, amount)
	inventory_changed.emit()


func remove_item(item: InventoryData.Item, amount: int = 1) -> bool:
	if not has_item(item, amount):
		return false
	_counts[item] = get_count(item) - amount
	item_removed.emit(item, amount)
	inventory_changed.emit()
	return true


func get_all_data() -> Dictionary:
	var data: Dictionary = {}
	for item in InventoryData.ITEMS:
		var count: int = get_count(item)
		if count > 0:
			data[InventoryData.ITEMS[item]["id"]] = count
	return data


func load_data(data: Dictionary) -> void:
	for item in InventoryData.ITEMS:
		_counts[item] = 0
	for item_id in data:
		var item := InventoryData.get_by_id(item_id)
		_counts[item] = int(data[item_id])
	inventory_changed.emit()
