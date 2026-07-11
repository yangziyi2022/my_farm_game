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
var _place_drag: bool = false
var _drag_object: Node3D = null
var _drag_origin: Vector2i = Vector2i.ZERO
var _drag_hover: Vector2i = Vector2i.ZERO
var _ghost: Node3D = null
var _footprint: FootprintOverlay = null
var _selection_footprint: FootprintOverlay = null
var _mouse_down_pos: Vector2 = Vector2.ZERO
var _last_click_obj: Node3D = null
var _last_click_msec: int = 0
const DRAG_THRESHOLD: float = 4.0
const DOUBLE_CLICK_MS: int = 400


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
	grid_manager.selection_changed.connect(_on_selection_changed)


func enter_select_mode() -> void:
	mode = Mode.SELECT
	if _dragging and _drag_object:
		_snap_drag_home()
	_end_object_drag()
	_place_drag = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	select_mode_requested.emit()
	status_message.emit("Select — hold and drag objects; release to place.")


func enter_hoe_mode() -> void:
	mode = Mode.HOE
	_dragging = false
	_place_drag = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	status_message.emit("Hoe — click grass to turn it into dirt paths.")


func enter_harvest_mode() -> void:
	mode = Mode.HARVEST
	_dragging = false
	_place_drag = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	feed_mode_cancelled.emit()
	_show_cursor_overlay("Harvest", Color(0.95, 0.75, 0.2))
	status_message.emit("Harvest — click mature plants to collect them.")


func enter_fish_mode() -> void:
	mode = Mode.FISH
	_dragging = false
	_place_drag = false
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
	_place_drag = false
	_drag_object = null
	grid_manager.select_object(null)
	_remove_ghost()
	_show_cursor_overlay(InventoryData.get_item_name(item), InventoryData.get_color(item))
	status_message.emit("Feed — click an animal with %s" % InventoryData.get_item_name(item))


func set_selected_item(item_type: ItemData.ItemType) -> void:
	selected_item = item_type
	mode = Mode.PLACE
	_dragging = false
	_place_drag = false
	_drag_object = null
	grid_manager.select_object(null)
	feed_mode_cancelled.emit()
	_update_ghost()
	_hide_cursor_overlay()
	status_message.emit("Place %s — hold, drag, release to place" % ItemData.get_item_name(item_type))


func perform_undo() -> void:
	if undo_manager and undo_manager.undo(grid_manager):
		enter_select_mode()
	else:
		status_message.emit("Nothing to undo")


func _process(_delta: float) -> void:
	if mode == Mode.PLACE and _ghost:
		_update_ghost_position()
	if _dragging and _drag_object and is_instance_valid(_drag_object):
		_update_drag_follow()


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
		_place_drag = false
		_register_click(null)
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	var hit_obj: Node3D = hit.get("object")
	var double_clicked := _register_click(hit_obj)

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
			if double_clicked and hit_obj and _is_movable_content(hit_obj):
				_select_placed_object(hit_obj)
				return
			if hit_obj and _is_movable_content(hit_obj):
				_select_placed_object(hit_obj)
				return
			# Hold-drag place: follow mouse, commit on release.
			_place_drag = true
			status_message.emit("Drag to position, release to place")
		Mode.SELECT:
			if hit_obj:
				_select_placed_object(hit_obj)
			else:
				grid_manager.select_object(null)
				status_message.emit("Deselected")


func _is_movable_content(obj: Node3D) -> bool:
	if obj == null or not obj.has_meta("item_type"):
		return false
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	return not ItemData.is_terrain(item_type)


func _register_click(obj: Node3D) -> bool:
	var now: int = Time.get_ticks_msec()
	var is_double := obj != null and obj == _last_click_obj and (now - _last_click_msec) <= DOUBLE_CLICK_MS
	_last_click_obj = obj
	_last_click_msec = now
	return is_double


func _select_placed_object(obj: Node3D) -> void:
	mode = Mode.SELECT
	_place_drag = false
	_remove_ghost()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	select_mode_requested.emit()
	var already_selected := grid_manager.get_selected() == obj
	if not already_selected:
		grid_manager.select_object(obj)
	_dragging = false
	_drag_object = obj
	_drag_origin = obj.get_meta("grid_pos")
	_drag_hover = _drag_origin
	# Keep world position stable on re-click (don't snap/rebuild unless needed).
	_drag_object.position = grid_manager.grid_to_world(_drag_origin)
	status_message.emit("Hold and drag to move — release to place. R to rotate")


func _on_selection_changed(obj: Node3D) -> void:
	_clear_selection_footprint()
	if obj == null or not is_instance_valid(obj):
		return
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	_selection_footprint = FootprintOverlay.create_for_item(item_type, grid_manager)
	_selection_footprint.name = "SelectionFootprint"
	_selection_footprint.set_valid(true)
	obj.add_child(_selection_footprint)


func _clear_selection_footprint() -> void:
	if _selection_footprint and is_instance_valid(_selection_footprint):
		_selection_footprint.queue_free()
	_selection_footprint = null


func _can_drop_drag_at(target: Vector2i) -> bool:
	if not grid_manager.is_in_bounds(target):
		return false
	if target == _drag_origin:
		return true
	return not grid_manager.has_content(target)


func _raycast_ground_cell(screen_pos: Vector2) -> Vector2i:
	# Always project onto the ground plane so dragging never hits the object's own collider.
	var from := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.001:
		return Vector2i(-9999, -9999)
	var t := -from.y / ray_dir.y
	if t < 0.0:
		return Vector2i(-9999, -9999)
	return grid_manager.world_to_grid_nearest(from + ray_dir * t)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x > -9000 and grid_manager.is_in_bounds(cell)


func _set_drag_pickable(enabled: bool) -> void:
	if _drag_object == null or not is_instance_valid(_drag_object):
		return
	var body := _drag_object.get_node_or_null("TileCollider") as CollisionObject3D
	if body:
		body.collision_layer = 1 if enabled else 0


func _update_drag_follow() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var target := _raycast_ground_cell(mouse_pos)
	if not _is_valid_cell(target):
		return
	# Only snap when the hovered cell changes — avoids per-frame jitter.
	if target == _drag_hover:
		return
	_drag_hover = target
	_drag_object.position = grid_manager.grid_to_world(target)
	if _selection_footprint:
		_selection_footprint.set_valid(_can_drop_drag_at(target))


func _snap_drag_home() -> void:
	if _drag_object and is_instance_valid(_drag_object):
		_drag_object.position = grid_manager.grid_to_world(_drag_origin)
		_drag_object.set_meta("grid_pos", _drag_origin)
	if _selection_footprint:
		_selection_footprint.set_valid(true)
	_drag_hover = _drag_origin


func _begin_object_drag(obj: Node3D) -> void:
	_dragging = true
	_place_drag = false
	mode = Mode.SELECT
	_drag_object = obj
	_drag_origin = obj.get_meta("grid_pos")
	_drag_hover = _drag_origin
	_set_drag_pickable(false)
	_update_drag_follow()


func _end_object_drag() -> void:
	_set_drag_pickable(true)
	_dragging = false


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
	# New item place-drag: commit on release.
	if _place_drag:
		_place_drag = false
		var place_pos := _raycast_ground_cell(screen_pos)
		if not _is_valid_cell(place_pos):
			status_message.emit("Cancelled place")
			return
		if grid_manager.can_place_at(place_pos, selected_item):
			grid_manager.place_object(selected_item, place_pos)
			status_message.emit("Placed %s at (%d, %d)" % [
				ItemData.get_item_name(selected_item), place_pos.x, place_pos.y
			])
		else:
			status_message.emit("Cannot place here")
		return

	# Move existing object: follow mouse while held, commit on release.
	if _dragging and _drag_object and is_instance_valid(_drag_object):
		var target := _raycast_ground_cell(screen_pos)
		if not _is_valid_cell(target):
			_snap_drag_home()
			status_message.emit("Move cancelled")
		elif target == _drag_origin:
			_snap_drag_home()
		elif _can_drop_drag_at(target) and grid_manager.move_object(_drag_origin, target):
			_drag_origin = target
			_drag_hover = target
			status_message.emit("Moved to (%d, %d)" % [target.x, target.y])
		else:
			_snap_drag_home()
			status_message.emit("Cannot move there")
		_end_object_drag()
		if grid_manager.get_selected() == _drag_object:
			_drag_origin = _drag_object.get_meta("grid_pos")
			_drag_hover = _drag_origin
		else:
			_drag_object = null
		return

	_end_object_drag()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag_object and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging and event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_begin_object_drag(_drag_object)
			elif _dragging:
				_update_drag_follow()


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
	if _dragging and _drag_object:
		_snap_drag_home()
		_end_object_drag()
	_place_drag = false
	_clear_selection_footprint()
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
	# Soften the model so the footprint tile is easier to read.
	_set_ghost_transparency(_ghost, 0.4)
	_footprint = FootprintOverlay.create_for_item(selected_item, grid_manager)
	_ghost.add_child(_footprint)
	grid_manager.objects_container.add_child(_ghost)


func _set_ghost_transparency(node: Node, alpha: float) -> void:
	if node is FootprintOverlay:
		return
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat == null and node.mesh:
			# GLB meshes often use surface materials — duplicate so we can fade them.
			var surface_count: int = node.mesh.get_surface_count()
			for i in range(surface_count):
				var src: Material = node.get_active_material(i)
				if src == null:
					continue
				var dup: Material = src.duplicate() as Material
				if dup is BaseMaterial3D:
					var bm: BaseMaterial3D = dup as BaseMaterial3D
					bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					bm.albedo_color.a = alpha
				node.set_surface_override_material(i, dup)
		elif mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = alpha
	for child in node.get_children():
		_set_ghost_transparency(child, alpha)


func _remove_ghost() -> void:
	_footprint = null
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
	if _footprint:
		_footprint.set_valid(valid)
	# Tint procedural placeholders only; footprint has its own colors.
	_set_ghost_tint(_ghost, Color(0.45, 1.0, 0.55, 0.4) if valid else Color(1.0, 0.45, 0.45, 0.4))


func _set_ghost_tint(node: Node, color: Color) -> void:
	if node is FootprintOverlay:
		return
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			var c := color
			c.a = mat.albedo_color.a
			mat.albedo_color = c
	for child in node.get_children():
		_set_ghost_tint(child, color)


func _set_ghost_color(node: Node, color: Color) -> void:
	_set_ghost_tint(node, color)
