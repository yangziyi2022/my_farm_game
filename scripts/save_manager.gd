class_name SaveManager
extends RefCounted

## Multi-world saves under user://worlds/{id}/
## Migrates legacy user://farm_save.json on first access.

const LEGACY_SAVE_PATH := "user://farm_save.json"
const WORLDS_DIR := "user://worlds"
const SETTINGS_PATH := "user://settings.json"
const SAVE_FILE := "farm_save.json"
const META_FILE := "meta.json"

static var _current_world_id: String = ""


static func ensure_ready() -> void:
	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	_migrate_legacy_if_needed()
	if _current_world_id.is_empty():
		_current_world_id = str(_load_settings().get("current_world_id", ""))


static func get_current_world_id() -> String:
	ensure_ready()
	return _current_world_id


static func set_current_world_id(world_id: String) -> void:
	ensure_ready()
	_current_world_id = world_id
	var settings := _load_settings()
	settings["current_world_id"] = world_id
	if not world_id.is_empty():
		settings["last_world_id"] = world_id
	_save_settings(settings)


static func get_last_world_id() -> String:
	ensure_ready()
	return str(_load_settings().get("last_world_id", ""))


static func world_exists(world_id: String) -> bool:
	if world_id.is_empty():
		return false
	return DirAccess.dir_exists_absolute(_world_dir(world_id))


static func world_has_save(world_id: String) -> bool:
	return FileAccess.file_exists(_save_path(world_id))


static func list_worlds() -> Array[Dictionary]:
	## Newest last_played first.
	ensure_ready()
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(WORLDS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var meta := load_meta(name)
			if meta.is_empty():
				meta = {
					"id": name,
					"display_name": name,
					"last_played": 0,
					"play_radius": GridManager.DEFAULT_PLAY_RADIUS,
					"created_at": 0,
				}
			else:
				meta["id"] = name
			result.append(meta)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_played", 0)) > int(b.get("last_played", 0))
	)
	return result


static func create_world(display_name: String = "") -> String:
	ensure_ready()
	var name := display_name.strip_edges()
	if name.is_empty():
		name = "My Farm %d" % (list_worlds().size() + 1)
	var id := _make_world_id()
	DirAccess.make_dir_recursive_absolute(_world_dir(id))
	var now := int(Time.get_unix_time_from_system())
	var meta := {
		"id": id,
		"display_name": name,
		"created_at": now,
		"last_played": now,
		"play_radius": GridManager.DEFAULT_PLAY_RADIUS,
	}
	_write_meta(id, meta)
	return id


static func rename_world(world_id: String, new_name: String) -> bool:
	ensure_ready()
	if not world_exists(world_id):
		return false
	var name := new_name.strip_edges()
	if name.is_empty():
		return false
	var meta := load_meta(world_id)
	if meta.is_empty():
		meta = {"id": world_id, "created_at": int(Time.get_unix_time_from_system())}
	meta["display_name"] = name
	meta["id"] = world_id
	_write_meta(world_id, meta)
	return true


static func delete_world(world_id: String) -> bool:
	ensure_ready()
	if not world_exists(world_id):
		return false
	_remove_dir_recursive(_world_dir(world_id))
	if _current_world_id == world_id:
		set_current_world_id("")
	var settings := _load_settings()
	if str(settings.get("last_world_id", "")) == world_id:
		settings["last_world_id"] = ""
		_save_settings(settings)
	return true


static func load_meta(world_id: String) -> Dictionary:
	var path := _meta_path(world_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func touch_last_played(world_id: String, play_radius: float = -1.0) -> void:
	if not world_exists(world_id):
		return
	var meta := load_meta(world_id)
	if meta.is_empty():
		meta = {"id": world_id, "display_name": world_id}
	meta["last_played"] = int(Time.get_unix_time_from_system())
	if play_radius > 0.0:
		meta["play_radius"] = play_radius
	_write_meta(world_id, meta)


static func save_farm(grid_manager: GridManager, inventory_manager: InventoryManager = null) -> bool:
	ensure_ready()
	var world_id := _current_world_id
	if world_id.is_empty() or not world_exists(world_id):
		world_id = create_world()
		set_current_world_id(world_id)

	var data := {
		"version": 5,
		"grid_width": GridManager.GRID_WIDTH,
		"grid_height": GridManager.GRID_HEIGHT,
		"play_radius": grid_manager.get_play_radius(),
		"objects": grid_manager.get_all_objects_data(),
	}
	if inventory_manager:
		data["inventory"] = inventory_manager.get_all_data()

	DirAccess.make_dir_recursive_absolute(_world_dir(world_id))
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(_save_path(world_id), FileAccess.WRITE)
	if file == null:
		push_error("Failed to save farm: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_str)
	file.close()

	var meta := load_meta(world_id)
	if meta.is_empty():
		meta = {
			"id": world_id,
			"display_name": "My Farm",
			"created_at": int(Time.get_unix_time_from_system()),
		}
	meta["last_played"] = int(Time.get_unix_time_from_system())
	meta["play_radius"] = grid_manager.get_play_radius()
	_write_meta(world_id, meta)
	return true


static func load_farm(grid_manager: GridManager, inventory_manager: InventoryManager = null) -> bool:
	ensure_ready()
	var world_id := _current_world_id
	if world_id.is_empty() or not world_has_save(world_id):
		push_warning("No save file for world '%s'" % world_id)
		return false

	var file := FileAccess.open(_save_path(world_id), FileAccess.READ)
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
		var objects: Array = data["objects"]
		var version := int(data.get("version", 1))
		if version < 4:
			for entry in objects:
				if entry is Dictionary:
					entry["grid_x"] = int(entry.get("grid_x", 0)) + GridManager.GRID_SHIFT
					entry["grid_y"] = int(entry.get("grid_y", 0)) + GridManager.GRID_SHIFT
		var radius := float(data.get("play_radius", GridManager.DEFAULT_PLAY_RADIUS))
		grid_manager.set_play_radius_silent(radius)
		grid_manager.load_objects_data(objects)
		if inventory_manager and data.has("inventory") and data["inventory"] is Dictionary:
			inventory_manager.load_data(data["inventory"])
		touch_last_played(world_id, radius)
		return true

	push_error("Invalid save file format")
	return false


static func has_any_world() -> bool:
	return not list_worlds().is_empty()


static func has_save() -> bool:
	## Backward-compatible: true if current world has a save, or legacy existed.
	ensure_ready()
	if not _current_world_id.is_empty() and world_has_save(_current_world_id):
		return true
	return FileAccess.file_exists(LEGACY_SAVE_PATH)


static func format_island_size(play_radius: float) -> String:
	var r := play_radius
	if r <= GridManager.DEFAULT_PLAY_RADIUS + 0.05:
		return "Island · starter"
	var steps := int(round((r - GridManager.DEFAULT_PLAY_RADIUS) / GridManager.EXPAND_STEP))
	return "Island · +%d expand" % maxi(steps, 1)


static func format_last_played(unix_ts: int) -> String:
	if unix_ts <= 0:
		return "Never played"
	var now := int(Time.get_unix_time_from_system())
	var delta := maxi(now - unix_ts, 0)
	if delta < 60:
		return "Just now"
	if delta < 3600:
		return "%d min ago" % int(delta / 60.0)
	if delta < 86400:
		return "%d hr ago" % int(delta / 3600.0)
	if delta < 86400 * 7:
		return "%d days ago" % int(delta / 86400.0)
	var dt := Time.get_datetime_dict_from_unix_time(unix_ts)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


# --- internals ----------------------------------------------------------------

static func _world_dir(world_id: String) -> String:
	return "%s/%s" % [WORLDS_DIR, world_id]


static func _save_path(world_id: String) -> String:
	return "%s/%s" % [_world_dir(world_id), SAVE_FILE]


static func _meta_path(world_id: String) -> String:
	return "%s/%s" % [_world_dir(world_id), META_FILE]


static func _make_world_id() -> String:
	var ts := int(Time.get_unix_time_from_system())
	var n := randi() % 10000
	return "world_%d_%04d" % [ts, n]


static func _write_meta(world_id: String, meta: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_world_dir(world_id))
	var file := FileAccess.open(_meta_path(world_id), FileAccess.WRITE)
	if file == null:
		push_error("Failed to write world meta: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()


static func _load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func _save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


static func _migrate_legacy_if_needed() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	# Already migrated?
	if DirAccess.dir_exists_absolute(WORLDS_DIR):
		var existing := DirAccess.open(WORLDS_DIR)
		if existing:
			existing.list_dir_begin()
			var n := existing.get_next()
			while n != "":
				if existing.current_is_dir() and not n.begins_with("."):
					existing.list_dir_end()
					# Keep legacy file but don't re-import.
					return
				n = existing.get_next()
			existing.list_dir_end()

	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	var id := "world_legacy"
	DirAccess.make_dir_recursive_absolute(_world_dir(id))
	var src := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	src.close()
	var dst := FileAccess.open(_save_path(id), FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(text)
	dst.close()

	var radius := GridManager.DEFAULT_PLAY_RADIUS
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		radius = float(json.data.get("play_radius", radius))
	var now := int(Time.get_unix_time_from_system())
	_write_meta(id, {
		"id": id,
		"display_name": "My Farm",
		"created_at": now,
		"last_played": now,
		"play_radius": radius,
	})
	var settings := _load_settings()
	if str(settings.get("last_world_id", "")).is_empty():
		settings["last_world_id"] = id
		_save_settings(settings)


static func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_remove_dir_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
