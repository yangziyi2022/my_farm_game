class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://farm_save.json"


static func save_farm(grid_manager: GridManager, inventory_manager: InventoryManager = null) -> bool:
	var data := {
		"version": 3,
		"grid_width": GridManager.GRID_WIDTH,
		"grid_height": GridManager.GRID_HEIGHT,
		"objects": grid_manager.get_all_objects_data(),
	}
	if inventory_manager:
		data["inventory"] = inventory_manager.get_all_data()

	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save farm: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_str)
	file.close()
	return true


static func load_farm(grid_manager: GridManager, inventory_manager: InventoryManager = null) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("No save file found at %s" % SAVE_PATH)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load farm: %s" % FileAccess.get_open_error())
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		push_error("Failed to parse save JSON: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data
	if data.has("objects") and data["objects"] is Array:
		grid_manager.load_objects_data(data["objects"])
		if inventory_manager and data.has("inventory") and data["inventory"] is Dictionary:
			inventory_manager.load_data(data["inventory"])
		return true

	push_error("Invalid save file format")
	return false


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
