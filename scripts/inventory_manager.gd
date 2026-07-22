class_name InventoryManager
extends Node

signal inventory_changed
signal item_added(item: InventoryData.Item, amount: int)
signal item_removed(item: InventoryData.Item, amount: int)

const SLOT_COUNT: int = InventoryData.SLOT_COUNT
const HOTBAR_SIZE: int = InventoryData.HOTBAR_SIZE

## Each entry: {"item": InventoryData.Item, "count": int} or empty Dictionary {}.
var _slots: Array[Dictionary] = []


func _ready() -> void:
	_slots.clear()
	_slots.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		_slots[i] = {}
	ensure_default_tools()


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return _slots[index]


func is_slot_empty(index: int) -> bool:
	var slot := get_slot(index)
	return slot.is_empty() or int(slot.get("count", 0)) <= 0 or not slot.has("item")


func get_slot_item(index: int):
	if is_slot_empty(index):
		return null
	return _slots[index]["item"]


func get_slot_count(index: int) -> int:
	if is_slot_empty(index):
		return 0
	var item = _slots[index]["item"]
	if InventoryData.is_infinite(item):
		return 999
	return int(_slots[index].get("count", 0))


func get_count(item: InventoryData.Item) -> int:
	if InventoryData.is_infinite(item):
		return 999 if _find_item_slot(item) >= 0 else 0
	var total := 0
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			continue
		if _slots[i]["item"] == item:
			total += int(_slots[i]["count"])
	return total


func has_item(item: InventoryData.Item, amount: int = 1) -> bool:
	if InventoryData.is_infinite(item):
		return _find_item_slot(item) >= 0
	return get_count(item) >= amount


func add_item(item: InventoryData.Item, amount: int = 1) -> void:
	if amount <= 0:
		return
	if InventoryData.is_infinite(item):
		if _find_item_slot(item) < 0:
			_place_tool(item)
		item_added.emit(item, amount)
		inventory_changed.emit()
		return
	var remaining := amount
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			continue
		if _slots[i]["item"] == item:
			_slots[i]["count"] = int(_slots[i]["count"]) + remaining
			remaining = 0
			break
	if remaining > 0:
		for i in range(SLOT_COUNT):
			if is_slot_empty(i):
				_slots[i] = {"item": item, "count": remaining}
				remaining = 0
				break
	item_added.emit(item, amount)
	inventory_changed.emit()


func remove_item(item: InventoryData.Item, amount: int = 1) -> bool:
	if InventoryData.is_infinite(item):
		return has_item(item)
	if not has_item(item, amount):
		return false
	var remaining := amount
	for i in range(SLOT_COUNT - 1, -1, -1):
		if is_slot_empty(i):
			continue
		if _slots[i]["item"] != item:
			continue
		var have: int = int(_slots[i]["count"])
		var take: int = mini(have, remaining)
		have -= take
		remaining -= take
		if have <= 0:
			_slots[i] = {}
		else:
			_slots[i]["count"] = have
		if remaining <= 0:
			break
	item_removed.emit(item, amount)
	inventory_changed.emit()
	return true


func swap_slots(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	if from_index < 0 or from_index >= SLOT_COUNT:
		return
	if to_index < 0 or to_index >= SLOT_COUNT:
		return
	var tmp: Dictionary = _slots[from_index]
	_slots[from_index] = _slots[to_index]
	_slots[to_index] = tmp
	inventory_changed.emit()


func ensure_default_tools() -> void:
	## Seed infinite hoe / sickle / rod into bottom-right if missing.
	var changed := false
	for tool_item in InventoryData.DEFAULT_TOOL_SLOTS:
		if _find_item_slot(tool_item) >= 0:
			continue
		_place_tool(tool_item)
		changed = true
	if _ensure_starter_compost():
		changed = true
	if changed:
		inventory_changed.emit()


func _ensure_starter_compost() -> bool:
	## Compost is a backpack item (not a build-palette tool). Seed a starter stack
	## so fertilize is discoverable; harvest also drops more.
	if get_count(InventoryData.Item.COMPOST) > 0:
		return false
	const STARTER := 8
	var preferred: int = int(InventoryData.DEFAULT_SLOT.get(InventoryData.Item.COMPOST, 6))
	if preferred >= 0 and preferred < SLOT_COUNT and is_slot_empty(preferred):
		_slots[preferred] = {"item": InventoryData.Item.COMPOST, "count": STARTER}
		return true
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			_slots[i] = {"item": InventoryData.Item.COMPOST, "count": STARTER}
			return true
	return false


func get_all_data() -> Dictionary:
	var layout: Array = []
	layout.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			layout[i] = null
		else:
			var item: InventoryData.Item = _slots[i]["item"]
			layout[i] = {
				"id": InventoryData.ITEMS[item]["id"],
				"count": 1 if InventoryData.is_infinite(item) else int(_slots[i]["count"]),
			}
	return {"layout": layout}


func load_data(data: Dictionary) -> void:
	_clear_slots()
	if data.has("layout") and data["layout"] is Array:
		var layout: Array = data["layout"]
		for i in range(mini(layout.size(), SLOT_COUNT)):
			var entry = layout[i]
			if entry == null or not (entry is Dictionary):
				continue
			var item_id := str(entry.get("id", ""))
			var count := int(entry.get("count", 0))
			if item_id.is_empty() or count <= 0:
				continue
			var item := InventoryData.get_by_id(item_id)
			_slots[i] = {
				"item": item,
				"count": 1 if InventoryData.is_infinite(item) else count,
			}
	else:
		for item_id in data:
			var count := int(data[item_id])
			if count <= 0:
				continue
			var item := InventoryData.get_by_id(str(item_id))
			if InventoryData.is_infinite(item):
				continue
			var preferred: int = int(InventoryData.DEFAULT_SLOT.get(item, -1))
			if preferred >= 0 and preferred < SLOT_COUNT and is_slot_empty(preferred):
				_slots[preferred] = {"item": item, "count": count}
			else:
				for i in range(SLOT_COUNT):
					if is_slot_empty(i):
						_slots[i] = {"item": item, "count": count}
						break
	ensure_default_tools()
	inventory_changed.emit()


func _place_tool(tool_item: InventoryData.Item) -> void:
	var preferred: int = int(InventoryData.DEFAULT_TOOL_SLOTS.get(tool_item, -1))
	if preferred >= 0 and preferred < SLOT_COUNT and is_slot_empty(preferred):
		_slots[preferred] = {"item": tool_item, "count": 1}
		return
	for i in range(SLOT_COUNT - 1, -1, -1):
		if is_slot_empty(i):
			_slots[i] = {"item": tool_item, "count": 1}
			return


func _find_item_slot(item: InventoryData.Item) -> int:
	for i in range(SLOT_COUNT):
		if is_slot_empty(i):
			continue
		if _slots[i]["item"] == item:
			return i
	return -1


func _clear_slots() -> void:
	for i in range(SLOT_COUNT):
		_slots[i] = {}
