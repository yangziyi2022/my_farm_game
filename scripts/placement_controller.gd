class_name PlacementController
extends Node

signal status_message(text: String)
signal select_mode_requested

enum Mode { PLACE, SELECT }

var grid_manager: GridManager
var camera: Camera3D
var selected_item: ItemData.ItemType = ItemData.ItemType.GRASS
var mode: Mode = Mode.SELECT

var _dragging: bool = false
var _drag_object: Node3D = null
var _drag_origin: Vector2i = Vector2i.ZERO
var _ghost: Node3D = null
var _mouse_down_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 8.0


func setup(p_grid_manager: GridManager, p_camera: Camera3D) -> void:
	grid_manager = p_grid_manager
	camera = p_camera


func enter_select_mode() -> void:
	mode = Mode.SELECT
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	select_mode_requested.emit()
	status_message.emit("Select mode — click objects to move, Esc to deselect")


func set_selected_item(item_type: ItemData.ItemType) -> void:
	selected_item = item_type
	mode = Mode.PLACE
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_update_ghost()
	status_message.emit("Place mode — %s (click Select or Esc to cancel)" % ItemData.get_item_name(item_type))


func _process(_delta: float) -> void:
	if mode == Mode.PLACE and _ghost:
		_update_ghost_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_rotate_selected()
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected()
			KEY_ESCAPE:
				_cancel_action()

	if event is InputEventMouseButton:
		_handle_mouse_button(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down_pos = event.position
			_on_left_press(event.position)
		else:
			_on_left_release(event.position)

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_right_click(event.position)


func _on_left_press(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		if mode == Mode.SELECT:
			grid_manager.select_object(null)
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	var hit_obj: Node3D = hit.get("object")

	if mode == Mode.PLACE:
		if hit_obj == null and grid_manager.is_in_bounds(grid_pos):
			grid_manager.place_object(selected_item, grid_pos)
			status_message.emit("Placed %s at (%d, %d)" % [
				ItemData.get_item_name(selected_item), grid_pos.x, grid_pos.y
			])
		elif hit_obj:
			mode = Mode.SELECT
			grid_manager.select_object(hit_obj)
			_remove_ghost()
			_dragging = false
			_drag_object = hit_obj
			_drag_origin = hit_obj.get_meta("grid_pos")
			status_message.emit("Selected — drag to move, R to rotate, Del to delete")
	else:
		if hit_obj:
			grid_manager.select_object(hit_obj)
			_dragging = false
			_drag_object = hit_obj
			_drag_origin = hit_obj.get_meta("grid_pos")
			status_message.emit("Selected — drag to move, R to rotate, Del to delete")
		else:
			grid_manager.select_object(null)
			status_message.emit("Deselected")


func _on_left_release(screen_pos: Vector2) -> void:
	if _dragging and _drag_object:
		var hit := _raycast(screen_pos)
		if not hit.is_empty():
			var target: Vector2i = hit["grid_pos"]
			if target != _drag_origin:
				if grid_manager.move_object(_drag_origin, target):
					status_message.emit("Moved object to (%d, %d)" % [target.x, target.y])
					_drag_origin = target
				else:
					status_message.emit("Cannot move there")
		_dragging = false
		_drag_object = null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag_object and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_dragging = true
				mode = Mode.SELECT


func _on_right_click(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	var hit_obj: Node3D = hit.get("object")

	if hit_obj:
		grid_manager.rotate_object(grid_pos, 1)
		status_message.emit("Rotated %s" % ItemData.get_item_name(hit_obj.get_meta("item_type")))
	elif mode == Mode.PLACE and grid_manager.is_occupied(grid_pos):
		grid_manager.remove_object(grid_pos)
		status_message.emit("Removed object at (%d, %d)" % [grid_pos.x, grid_pos.y])


func _rotate_selected() -> void:
	var selected := grid_manager.get_selected()
	if selected:
		var grid_pos: Vector2i = selected.get_meta("grid_pos")
		grid_manager.rotate_object(grid_pos, 1)
		status_message.emit("Rotated object")


func _delete_selected() -> void:
	var selected := grid_manager.get_selected()
	if selected:
		var grid_pos: Vector2i = selected.get_meta("grid_pos")
		grid_manager.remove_object(grid_pos)
		status_message.emit("Deleted object")
		enter_select_mode()


func _cancel_action() -> void:
	enter_select_mode()
	status_message.emit("Cancelled — Select mode")


func _raycast(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 200.0

	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space.intersect_ray(query)
	var grid_pos: Vector2i

	if result:
		grid_pos = grid_manager.world_to_grid(result.position)
	else:
		var ray_dir := camera.project_ray_normal(screen_pos)
		if absf(ray_dir.y) < 0.001:
			return {}
		var t := -from.y / ray_dir.y
		if t < 0:
			return {}
		var hit_point := from + ray_dir * t
		grid_pos = grid_manager.world_to_grid(hit_point)

	var hit_obj: Node3D = grid_manager.get_object_at(grid_pos)
	return {"grid_pos": grid_pos, "object": hit_obj}


func _update_ghost() -> void:
	_remove_ghost()
	if mode != Mode.PLACE:
		return
	_ghost = PlaceableObject.create(selected_item, Vector2i.ZERO, 0)
	_ghost.name = "Ghost"
	for child in _ghost.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.5
	grid_manager.objects_container.add_child(_ghost)


func _remove_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func _update_ghost_position() -> void:
	if not _ghost:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var hit := _raycast(mouse_pos)
	if hit.is_empty():
		_ghost.visible = false
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	_ghost.visible = grid_manager.is_in_bounds(grid_pos)
	_ghost.position = grid_manager.grid_to_world(grid_pos)

	var valid := grid_manager.is_in_bounds(grid_pos) and not grid_manager.is_occupied(grid_pos)
	for child in _ghost.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override
			if mat:
				mat.albedo_color = Color(0.3, 0.9, 0.3, 0.5) if valid else Color(0.9, 0.3, 0.3, 0.5)
