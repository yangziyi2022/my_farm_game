class_name PlacementController
extends Node

signal status_message(text: String)
signal select_mode_requested
signal feed_mode_cancelled

enum Mode { PLACE, SELECT, HOE, HARVEST, FISH, FEED }

var grid_manager: GridManager
var camera: Camera3D
var undo_manager: UndoManager
var inventory_manager: InventoryManager
var cursor_overlay: CursorOverlay
var selected_item: ItemData.ItemType = ItemData.ItemType.GRASS
var mode: Mode = Mode.SELECT
var feed_item: InventoryData.Item = InventoryData.Item.WHEAT

var _dragging: bool = false
var _drag_object: Node3D = null
var _drag_origin: Vector2i = Vector2i.ZERO
var _ghost: Node3D = null
var _mouse_down_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 8.0


func setup(
	p_grid_manager: GridManager,
	p_camera: Camera3D,
	p_undo_manager: UndoManager,
	p_inventory_manager: InventoryManager = null,
	p_cursor_overlay: CursorOverlay = null,
) -> void:
	grid_manager = p_grid_manager
	camera = p_camera
	undo_manager = p_undo_manager
	inventory_manager = p_inventory_manager
	cursor_overlay = p_cursor_overlay


func enter_select_mode() -> void:
	mode = Mode.SELECT
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	select_mode_requested.emit()
	status_message.emit("Select — click objects to move. Hoe dirt for seeds and wheat.")


func enter_hoe_mode() -> void:
	mode = Mode.HOE
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	status_message.emit("Hoe — click grass to turn it into dirt paths.")


func enter_harvest_mode() -> void:
	mode = Mode.HARVEST
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	feed_mode_cancelled.emit()
	_show_cursor_overlay("Harvest", Color(0.95, 0.75, 0.2))
	status_message.emit("Harvest — click mature plants to collect them.")


func enter_fish_mode() -> void:
	mode = Mode.FISH
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	feed_mode_cancelled.emit()
	_show_cursor_overlay("Rod", Color(0.45, 0.35, 0.2))
	status_message.emit("Rod — click water tiles to catch fish.")


func enter_feed_mode(item: InventoryData.Item) -> void:
	if not InventoryData.is_feedable(item):
		return
	if inventory_manager and not inventory_manager.has_item(item):
		status_message.emit("No %s left to feed" % InventoryData.get_item_name(item))
		return
	mode = Mode.FEED
	feed_item = item
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_show_cursor_overlay(InventoryData.get_item_name(item), InventoryData.get_color(item))
	status_message.emit("Feed — click an animal with %s" % InventoryData.get_item_name(item))


func set_selected_item(item_type: ItemData.ItemType) -> void:
	selected_item = item_type
	mode = Mode.PLACE
	_dragging = false
	_drag_object = null
	grid_manager.select_object(null)
	feed_mode_cancelled.emit()
	_update_ghost()
	_hide_cursor_overlay()
	if ItemData.is_growable_plant(item_type):
		status_message.emit("Plant %s on dirt — it will grow over time" % ItemData.get_item_name(item_type))
	else:
		status_message.emit("Place — %s" % ItemData.get_item_name(item_type))


func perform_undo() -> void:
	if undo_manager and undo_manager.undo(grid_manager):
		enter_select_mode()
	else:
		status_message.emit("Nothing to undo")


func _process(_delta: float) -> void:
	if mode == Mode.PLACE and _ghost:
		_update_ghost_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			perform_undo()
			get_viewport().set_input_as_handled()
			return
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

	match mode:
		Mode.HOE:
			if grid_manager.hoe_grass(grid_pos):
				status_message.emit("Hoed grass at (%d, %d)" % [grid_pos.x, grid_pos.y])
			else:
				status_message.emit("Hoe only works on grass")
		Mode.HARVEST:
			_try_harvest(grid_pos)
		Mode.FISH:
			_try_fish(grid_pos)
		Mode.FEED:
			_try_feed(grid_pos, hit_obj)
		Mode.PLACE:
			if grid_manager.can_place_at(grid_pos, selected_item):
				grid_manager.place_object(selected_item, grid_pos)
				status_message.emit("Placed %s at (%d, %d)" % [
					ItemData.get_item_name(selected_item), grid_pos.x, grid_pos.y
				])
			elif hit_obj:
				mode = Mode.SELECT
				grid_manager.select_object(hit_obj)
				_remove_ghost()
				_hide_cursor_overlay()
				_dragging = false
				_drag_object = hit_obj
				_drag_origin = hit_obj.get_meta("grid_pos")
				status_message.emit("Selected — drag to move, R to rotate")
		Mode.SELECT:
			if hit_obj:
				grid_manager.select_object(hit_obj)
				_dragging = false
				_drag_object = hit_obj
				_drag_origin = hit_obj.get_meta("grid_pos")
				status_message.emit("Selected — drag to move, R to rotate")
			else:
				grid_manager.select_object(null)
				status_message.emit("Deselected")


func _try_harvest(grid_pos: Vector2i) -> void:
	if not grid_manager.is_plant_mature(grid_pos):
		status_message.emit("Nothing ready to harvest here")
		return
	var harvest_item = grid_manager.harvest_plant(grid_pos)
	if harvest_item == null:
		status_message.emit("Nothing ready to harvest here")
		return
	if inventory_manager:
		inventory_manager.add_item(harvest_item)
	status_message.emit("Harvested %s!" % InventoryData.get_item_name(harvest_item))


func _try_fish(grid_pos: Vector2i) -> void:
	if not grid_manager.try_fish(grid_pos):
		status_message.emit("Cast the rod on water")
		return
	if inventory_manager:
		inventory_manager.add_item(InventoryData.Item.FISH)
	status_message.emit("Caught a fish!")


func _try_feed(grid_pos: Vector2i, hit_obj: Node3D) -> void:
	if hit_obj == null or not ItemData.is_animal(hit_obj.get_meta("item_type")):
		status_message.emit("Click an animal to feed")
		return
	if inventory_manager and not inventory_manager.remove_item(feed_item):
		status_message.emit("No %s left" % InventoryData.get_item_name(feed_item))
		enter_select_mode()
		return
	AnimalFeedEffect.play(hit_obj)
	status_message.emit("Fed %s to %s!" % [
		InventoryData.get_item_name(feed_item),
		ItemData.get_item_name(hit_obj.get_meta("item_type")),
	])


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
	status_message.emit("Cancelled")


func _show_cursor_overlay(text: String, color: Color) -> void:
	if cursor_overlay:
		cursor_overlay.show_item(text, color)


func _hide_cursor_overlay() -> void:
	if cursor_overlay:
		cursor_overlay.hide_overlay()


func _raycast(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 200.0

	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space.intersect_ray(query)
	var grid_pos: Vector2i
	var hit_obj: Node3D = null

	if result:
		hit_obj = _resolve_object_from_collider(result.collider as Node)
		if hit_obj:
			grid_pos = hit_obj.get_meta("grid_pos")
		else:
			grid_pos = grid_manager.world_to_grid_nearest(result.position)
			hit_obj = grid_manager.get_object_at(grid_pos)
	else:
		var ray_dir := camera.project_ray_normal(screen_pos)
		if absf(ray_dir.y) < 0.001:
			return {}
		var t := -from.y / ray_dir.y
		if t < 0:
			return {}
		var hit_point := from + ray_dir * t
		grid_pos = grid_manager.world_to_grid_nearest(hit_point)
		hit_obj = grid_manager.get_object_at(grid_pos)

	return {"grid_pos": grid_pos, "object": hit_obj}


func _resolve_object_from_collider(node: Node) -> Node3D:
	var current: Node = node
	while current:
		if current is Node3D and current.has_meta("grid_pos"):
			var grid_pos: Vector2i = current.get_meta("grid_pos")
			if grid_manager.get_object_at(grid_pos) == current:
				return current
		current = current.get_parent()
	return null


func _update_ghost() -> void:
	_remove_ghost()
	if mode != Mode.PLACE:
		return
	_ghost = PlaceableObject.create(selected_item, Vector2i.ZERO, 0)
	_ghost.name = "Ghost"
	_set_ghost_transparency(_ghost, 0.5)
	grid_manager.objects_container.add_child(_ghost)


func _set_ghost_transparency(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = alpha
	for child in node.get_children():
		_set_ghost_transparency(child, alpha)


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

	var valid := grid_manager.can_place_at(grid_pos, selected_item)
	_set_ghost_color(_ghost, Color(0.3, 0.9, 0.3, 0.5) if valid else Color(0.9, 0.3, 0.3, 0.5))


func _set_ghost_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			mat.albedo_color = color
	for child in node.get_children():
		_set_ghost_color(child, color)
