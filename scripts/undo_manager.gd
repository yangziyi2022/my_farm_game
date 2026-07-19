class_name UndoManager
extends Node

signal undo_applied(description: String)
signal stack_changed(can_undo: bool)

const MAX_STACK_SIZE: int = 50

enum ActionType {
	PLACE,
	REMOVE,
	REPLACE,
	MOVE,
	ROTATE,
	EXPAND,
	BATCH,
}

var _stack: Array[Dictionary] = []
var _applying_undo: bool = false
var _batch_depth: int = 0
var _pending_batch: Array = []


func can_undo() -> bool:
	return not _stack.is_empty()


func stack_depth() -> int:
	return _stack.size()


func clear() -> void:
	_stack.clear()
	_pending_batch.clear()
	_batch_depth = 0
	stack_changed.emit(false)


func is_applying_undo() -> bool:
	return _applying_undo


func begin_batch() -> void:
	if _applying_undo:
		return
	_batch_depth += 1
	if _batch_depth == 1:
		_pending_batch.clear()


func end_batch() -> void:
	if _applying_undo:
		return
	if _batch_depth <= 0:
		return
	_batch_depth -= 1
	if _batch_depth > 0:
		return
	if _pending_batch.is_empty():
		return
	if _pending_batch.size() == 1:
		_stack.append(_pending_batch[0])
	else:
		_stack.append({"type": ActionType.BATCH, "actions": _pending_batch.duplicate()})
	_pending_batch.clear()
	while _stack.size() > MAX_STACK_SIZE:
		_stack.pop_front()
	stack_changed.emit(true)


func record_place(grid_pos: Vector2i, item_type: ItemData.ItemType, rotation: int, growth_stage: int = 0) -> void:
	_push({
		"type": ActionType.PLACE,
		"grid_pos": grid_pos,
		"item_type": item_type,
		"rotation": rotation,
		"growth_stage": growth_stage,
	})


func record_remove(grid_pos: Vector2i, item_type: ItemData.ItemType, rotation: int, growth_stage: int = 0) -> void:
	_push({
		"type": ActionType.REMOVE,
		"grid_pos": grid_pos,
		"item_type": item_type,
		"rotation": rotation,
		"growth_stage": growth_stage,
	})


func record_replace(
	grid_pos: Vector2i,
	before_type: ItemData.ItemType,
	before_rotation: int,
	before_growth: int,
	after_type: ItemData.ItemType,
	after_rotation: int,
	after_growth: int
) -> void:
	_push({
		"type": ActionType.REPLACE,
		"grid_pos": grid_pos,
		"before_type": before_type,
		"before_rotation": before_rotation,
		"before_growth": before_growth,
		"after_type": after_type,
		"after_rotation": after_rotation,
		"after_growth": after_growth,
	})


func record_move(from: Vector2i, to: Vector2i) -> void:
	_push({
		"type": ActionType.MOVE,
		"from": from,
		"to": to,
	})


func record_rotate(grid_pos: Vector2i, old_rotation: int, new_rotation: int) -> void:
	_push({
		"type": ActionType.ROTATE,
		"grid_pos": grid_pos,
		"old_rotation": old_rotation,
		"new_rotation": new_rotation,
	})


func record_expand(old_radius: float, new_radius: float) -> void:
	_push({
		"type": ActionType.EXPAND,
		"old_radius": old_radius,
		"new_radius": new_radius,
	})


func undo(grid_manager: GridManager) -> bool:
	if _stack.is_empty():
		return false

	var action: Dictionary = _stack.pop_back()
	_applying_undo = true
	_apply_action(action, grid_manager)
	_applying_undo = false
	stack_changed.emit(can_undo())
	undo_applied.emit(_describe_action(action))
	return true


func _apply_action(action: Dictionary, grid_manager: GridManager) -> void:
	match action["type"]:
		ActionType.PLACE:
			# Dirt/path/water live on the terrain layer — content remove alone can't undo hoe.
			if ItemData.is_terrain(action["item_type"]):
				grid_manager.restore_default_grass_at(action["grid_pos"])
			else:
				grid_manager.remove_object_silent(action["grid_pos"])
		ActionType.REMOVE:
			grid_manager.place_object_silent(
				action["item_type"],
				action["grid_pos"],
				action["rotation"],
				action.get("growth_stage", 0)
			)
		ActionType.REPLACE:
			grid_manager.replace_object_silent(
				action["grid_pos"],
				action["before_type"],
				action["before_rotation"],
				action.get("before_growth", 0)
			)
		ActionType.MOVE:
			grid_manager.move_object_silent(action["to"], action["from"])
		ActionType.ROTATE:
			grid_manager.set_rotation_silent(action["grid_pos"], action["old_rotation"])
		ActionType.EXPAND:
			grid_manager.set_play_radius_silent(float(action["old_radius"]))
		ActionType.BATCH:
			var actions: Array = action.get("actions", [])
			for i in range(actions.size() - 1, -1, -1):
				_apply_action(actions[i], grid_manager)


func _push(action: Dictionary) -> void:
	if _applying_undo:
		return
	if _batch_depth > 0:
		_pending_batch.append(action)
		return
	_stack.append(action)
	while _stack.size() > MAX_STACK_SIZE:
		_stack.pop_front()
	stack_changed.emit(true)


func _describe_action(action: Dictionary) -> String:
	match action["type"]:
		ActionType.PLACE:
			return "Undid place %s" % ItemData.get_item_name(action["item_type"])
		ActionType.REMOVE:
			return "Undid remove %s" % ItemData.get_item_name(action["item_type"])
		ActionType.REPLACE:
			return "Undid change to %s" % ItemData.get_item_name(action["after_type"])
		ActionType.MOVE:
			return "Undid move"
		ActionType.ROTATE:
			return "Undid rotate"
		ActionType.EXPAND:
			var old_r := float(action["old_radius"])
			var new_r := float(action["new_radius"])
			if new_r < old_r:
				return "Undid shrink (%.1f → %.1f)" % [new_r, old_r]
			return "Undid expand (%.1f → %.1f)" % [new_r, old_r]
		ActionType.BATCH:
			var n: int = action.get("actions", []).size()
			return "Undid group action (%d)" % n
	return "Undid action"
