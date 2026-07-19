class_name PlacementController
extends Node

const ToolCursor3D = preload("res://scripts/tool_cursor_3d.gd")
const SelectionActionBarScript = preload("res://scripts/selection_action_bar.gd")

signal status_message(text: String)
signal select_mode_requested
signal feed_mode_cancelled

enum Mode { PLACE, SELECT, MULTISELECT, HOE, HARVEST, FISH, FEED }

var grid_manager: GridManager
var camera: Camera3D
var undo_manager: UndoManager
var inventory_manager: InventoryManager
var cursor_overlay: CursorOverlay
var tool_cursor: ToolCursor3D
var _action_bar: Control = null
var _menu_move_active: bool = false
## While Move mode: press+drag repositions; short tap drops at current cell.
var _menu_move_pressing: bool = false
var _menu_move_dragged: bool = false
const MENU_MOVE_TRANSPARENCY: float = 0.42
const MENU_MOVE_TINT := Color(1.0, 0.88, 0.2, 0.55)
var _copy_extend_active: bool = false
## True only while primary is held after a world press — not while tapping ✓/✕.
var _copy_dragging: bool = false
var _copy_source: Node3D = null
var _copy_item_type: ItemData.ItemType = ItemData.ItemType.FENCE
var _copy_origin: Vector2i = Vector2i.ZERO
var _copy_rotation: int = 0
var _copy_preview_rotation: int = -1
var _copy_cells: Array[Vector2i] = []
var _copy_all_valid: bool = false
var _copy_ghosts: Array[Node3D] = []
var _fish_phase: int = 0  # 0 idle, 1 waiting, 2 biting
var _fish_cell: Vector2i = Vector2i(-9999, -9999)
var _fish_water_pos: Vector3 = Vector3.ZERO
var _fish_wait_left: float = 0.0
## Hold-drag harvest: swipe across mature plants.
var _harvest_swiping: bool = false
var _harvest_last_cell: Vector2i = Vector2i(-9999, -9999)
var _harvest_swipe_count: int = 0
var selected_item: ItemData.ItemType = ItemData.ItemType.GRASS
var mode: Mode = Mode.SELECT
var feed_item: InventoryData.Item = InventoryData.Item.WHEAT
var _place_rotation: int = 0

var _dragging: bool = false
var _place_drag: bool = false
var _place_commit_pos: Vector2i = Vector2i(-9999, -9999)
var _ghost_grid_pos: Vector2i = Vector2i(-9999, -9999)
var _ghost_place_valid: bool = false
## Touch place: finger moved enough to reposition ghost (vs tap to confirm/cancel).
var _touch_place_moved: bool = false
var _drag_object: Node3D = null
var _drag_origin: Vector2i = Vector2i.ZERO
var _drag_hover: Vector2i = Vector2i.ZERO
var _ghost: Node3D = null
var _footprint: FootprintOverlay = null
var _tool_footprint: FootprintOverlay = null
var _selection_footprint: FootprintOverlay = null
var _mouse_down_pos: Vector2 = Vector2.ZERO
var _right_down_pos: Vector2 = Vector2.ZERO
var _right_held: bool = false
var _last_click_obj: Node3D = null
var _last_click_msec: int = 0
## Multi-select / marquee
var _selected_group: Array[Node3D] = []
var _group_origins: Dictionary = {}  # Node3D -> Vector2i
var _group_dragging: bool = false
var _marquee_active: bool = false
var _marquee_start: Vector2 = Vector2.ZERO
var _marquee_layer: CanvasLayer = null
var _marquee_fill: ColorRect = null
var _marquee_border: Panel = null
const DRAG_THRESHOLD: float = 4.0
const DOUBLE_CLICK_MS: int = 400
const MARQUEE_THRESHOLD: float = 8.0


func setup(
	p_grid_manager: GridManager,
	p_camera: Camera3D,
	p_undo_manager: UndoManager,
	p_inventory_manager: InventoryManager = null,
	p_cursor_overlay: CursorOverlay = null,
	p_tool_cursor: ToolCursor3D = null,
) -> void:
	grid_manager = p_grid_manager
	camera = p_camera
	undo_manager = p_undo_manager
	inventory_manager = p_inventory_manager
	cursor_overlay = p_cursor_overlay
	tool_cursor = p_tool_cursor
	if tool_cursor:
		tool_cursor.setup(camera)
	grid_manager.selection_changed.connect(_on_selection_changed)
	_ensure_marquee_ui()
	_ensure_action_bar()


func _ensure_marquee_ui() -> void:
	if _marquee_fill:
		return
	_marquee_layer = CanvasLayer.new()
	_marquee_layer.layer = 20
	add_child(_marquee_layer)

	_marquee_fill = ColorRect.new()
	_marquee_fill.color = Color(0.35, 0.75, 1.0, 0.18)
	_marquee_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee_fill.visible = false
	_marquee_layer.add_child(_marquee_fill)

	_marquee_border = Panel.new()
	_marquee_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee_border.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.35, 0.8, 1.0, 0.95)
	style.set_border_width_all(2)
	_marquee_border.add_theme_stylebox_override("panel", style)
	_marquee_layer.add_child(_marquee_border)


func enter_select_mode() -> void:
	mode = Mode.SELECT
	if _dragging and _drag_object:
		_snap_drag_home()
	if _group_dragging:
		_snap_group_home()
	_end_object_drag()
	_end_group_drag()
	_cancel_marquee()
	_place_drag = false
	_reset_selection_state()
	_remove_ghost()
	_hide_cursor_overlay()
	_hide_tool_cursor()
	_remove_tool_footprint()
	_clear_selection_footprint()
	feed_mode_cancelled.emit()
	# Heal desynced occupancy / unpickable colliders (e.g. stuck windmill).
	grid_manager.repair_content_registry()
	_restore_all_pickable()
	select_mode_requested.emit()
	status_message.emit("Select — drag empty ground to box-select, then drag selection to move.")


func enter_multiselect_mode() -> void:
	mode = Mode.MULTISELECT
	if _dragging and _drag_object:
		_snap_drag_home()
	if _group_dragging:
		_snap_group_home()
	_end_object_drag()
	_end_group_drag()
	_cancel_marquee()
	_place_drag = false
	_reset_selection_state()
	_remove_ghost()
	_hide_cursor_overlay()
	_hide_tool_cursor()
	_remove_tool_footprint()
	_clear_selection_footprint()
	feed_mode_cancelled.emit()
	grid_manager.repair_content_registry()
	_restore_all_pickable()
	status_message.emit("Multiselect — tap items to add/remove · use top Move / Rotate / Delete")


func enter_hoe_mode() -> void:
	mode = Mode.HOE
	_dragging = false
	_place_drag = false
	_group_dragging = false
	_cancel_marquee()
	_reset_selection_state()
	_remove_ghost()
	_hide_cursor_overlay()
	_reset_fishing_session()
	_show_hoe_cursor()
	_ensure_tool_footprint()
	feed_mode_cancelled.emit()
	status_message.emit("Hoe — click grass to turn it into dirt paths.")


func enter_harvest_mode() -> void:
	mode = Mode.HARVEST
	_dragging = false
	_place_drag = false
	_group_dragging = false
	_harvest_swiping = false
	_cancel_marquee()
	_reset_selection_state()
	_remove_ghost()
	_hide_cursor_overlay()
	_reset_fishing_session()
	_show_sickle_cursor()
	_ensure_tool_footprint()
	feed_mode_cancelled.emit()
	status_message.emit("Harvest — hold and slide over mature plants")


func enter_fish_mode() -> void:
	mode = Mode.FISH
	_dragging = false
	_place_drag = false
	_group_dragging = false
	_cancel_marquee()
	_reset_selection_state()
	_remove_ghost()
	_reset_fishing_session()
	_hide_cursor_overlay()
	feed_mode_cancelled.emit()
	_show_rod_cursor()
	_ensure_tool_footprint()
	status_message.emit("Rod — click water to cast, wait for a bite, click again to reel in")


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
	_group_dragging = false
	_cancel_marquee()
	_reset_selection_state()
	_remove_ghost()
	_hide_tool_cursor()
	_remove_tool_footprint()
	_show_cursor_overlay(InventoryData.get_item_name(item), InventoryData.get_color(item))
	status_message.emit("Feed — click an animal with %s" % InventoryData.get_item_name(item))


func set_selected_item(item_type: ItemData.ItemType) -> void:
	selected_item = item_type
	mode = Mode.PLACE
	_place_rotation = 0
	_dragging = false
	_place_drag = false
	_touch_place_moved = false
	_group_dragging = false
	_cancel_marquee()
	_reset_selection_state()
	_hide_tool_cursor()
	_remove_tool_footprint()
	feed_mode_cancelled.emit()
	_update_ghost()
	_hide_cursor_overlay()
	if PointerInput.is_touch_ui():
		status_message.emit("Place %s — tap a cell to place" % ItemData.get_item_name(item_type))
	else:
		status_message.emit("Place %s — hold/drag/release. R to rotate preview" % ItemData.get_item_name(item_type))


func perform_undo() -> void:
	if undo_manager and undo_manager.undo(grid_manager):
		enter_select_mode()
	else:
		status_message.emit("Nothing to undo")


func _process(_delta: float) -> void:
	# Capture primary while placing/dragging so CameraController won't steal one-finger orbit.
	# Touch: selection alone does not capture — Move button starts menu-move instead of drag.
	var selecting_held := (
		_drag_object != null
		and PointerInput.primary_down
		and not PointerInput.is_touch_ui()
	)
	var touch_placing := (
		mode == Mode.PLACE
		and PointerInput.is_touch_ui()
		and PointerInput.primary_down
	)
	PointerInput.gameplay_captures_primary = (
		_dragging and not _menu_move_active
		or _group_dragging and not _menu_move_active
		or _place_drag
		or _marquee_active
		or (_menu_move_active and PointerInput.primary_down)
		or (_copy_extend_active and _copy_dragging)
		or (_harvest_swiping and PointerInput.primary_down)
		or selecting_held
		or touch_placing
	)
	# Second finger = camera; abort in-progress one-finger place/marquee/move-drag.
	if PointerInput.touch_count() >= 2:
		if _place_drag:
			_place_drag = false
			_touch_place_moved = false
		if _menu_move_pressing:
			_menu_move_pressing = false
			_menu_move_dragged = false
		if _harvest_swiping:
			_end_harvest_swipe()
		if _marquee_active:
			_cancel_marquee()
	if mode == Mode.PLACE and _ghost:
		# Follow the finger/cursor so placement is always at the touch point.
		if PointerInput.is_touch_ui():
			if PointerInput.primary_down:
				_update_ghost_from_pointer()
			elif _is_valid_cell(_ghost_grid_pos):
				_apply_ghost_at_cell(_ghost_grid_pos)
		else:
			_update_ghost_from_pointer()
	if mode == Mode.HOE or mode == Mode.HARVEST or mode == Mode.FISH:
		_update_tool_footprint()
	if mode == Mode.FISH:
		_update_fishing(_delta)
	if mode == Mode.HARVEST and _harvest_swiping and PointerInput.primary_down:
		_update_harvest_swipe()
	if _copy_extend_active and _copy_dragging and PointerInput.primary_down:
		_update_copy_extend_from_pointer()
	if _menu_move_active and _menu_move_pressing and _menu_move_dragged:
		_update_menu_move_follow()
	if _dragging and _drag_object and is_instance_valid(_drag_object) and not _group_dragging and not _menu_move_active:
		_update_drag_follow()
	if _group_dragging and not _menu_move_active:
		_update_group_drag_follow()
	if _marquee_active:
		_update_marquee_visual(PointerInput.get_position())


func _unhandled_input(event: InputEvent) -> void:
	# Two-finger gestures belong to the camera — don't treat as clicks.
	if PointerInput.touch_count() >= 2:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			perform_undo()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_R:
				_rotate_selected()
				get_viewport().set_input_as_handled()
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cancel_action()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		_handle_mouse_button(event)


func _input(event: InputEvent) -> void:
	if PointerInput.touch_count() >= 2:
		return
	# Catch Delete even if a UI control has focus after box-select.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if (mode == Mode.SELECT or mode == Mode.MULTISELECT) and not _selected_group.is_empty():
				_delete_selected()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion:
		if _copy_extend_active:
			if _copy_dragging and PointerInput.primary_down:
				_update_copy_extend_from_pointer()
			return
		if _menu_move_active and _menu_move_pressing:
			if event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_menu_move_dragged = true
				_update_menu_move_follow()
			return
		if _marquee_active:
			_update_marquee_visual(event.position)
			return
		if _place_drag and mode == Mode.PLACE:
			# Only retarget after a real drag; tiny click jitter keeps the ghost cell.
			if event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_touch_place_moved = true
				if PointerInput.is_touch_ui():
					_update_ghost_from_pointer()
				else:
					_place_commit_pos = _ghost_grid_pos
			return
		# Touch: move via action-bar Move only — leave one-finger drag for camera orbit.
		if PointerInput.is_touch_ui():
			return
		if _selected_group.size() > 1 and _drag_object and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _group_dragging and event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_begin_group_drag()
			elif _group_dragging:
				_update_group_drag_follow()
			return
		if _drag_object and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging and event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
				_begin_object_drag(_drag_object)
			elif _dragging:
				_update_drag_follow()



func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down_pos = event.position
			_on_left_press(event.position)
		else:
			_on_left_release(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Short click rotates; drag is used by CameraController to orbit the island.
		if event.pressed:
			_right_held = true
			_right_down_pos = event.position
		else:
			if _right_held and event.position.distance_to(_right_down_pos) <= DRAG_THRESHOLD:
				_on_right_click(event.position)
			_right_held = false


func _on_left_press(screen_pos: Vector2) -> void:
	# Copy-extend: only world presses start a drag that updates the preview line.
	if _copy_extend_active:
		_copy_dragging = true
		_update_copy_extend_from_pointer()
		return

	# Menu-move: press starts drag; short tap on release drops.
	if _menu_move_active:
		_menu_move_pressing = true
		_menu_move_dragged = false
		return

	var hit := _raycast(screen_pos)

	# Place mode: always commit to the ghost cell — never steal into select on nearby hits.
	if mode == Mode.PLACE:
		if PointerInput.is_touch_ui():
			# Touch: place at the finger cell on release.
			_place_drag = true
			_touch_place_moved = false
			_update_ghost_from_pointer()
			_place_commit_pos = _ghost_grid_pos
			return
		var picked := _pick_selectable_at_screen(screen_pos)
		var double_clicked := _register_click(picked)
		if double_clicked and picked:
			_select_placed_object(picked)
			return
		_begin_place_drag()
		return

	# Select uses ground-cell picking — don't bail just because physics ray missed.
	if mode == Mode.SELECT:
		var picked := _pick_selectable_at_screen(screen_pos)
		_register_click(picked)
		if picked:
			if _selected_group.has(picked) and _selected_group.size() > 1:
				_prepare_group_drag(picked)
			else:
				_select_placed_object(picked)
		else:
			# Empty ground / sky — clear selection (action buttons handle their own clicks).
			_dragging = false
			_group_dragging = false
			_drag_object = null
			if not _selected_group.is_empty():
				_clear_selected_group()
				status_message.emit("Deselected")
			# Touch: skip marquee; Multiselect tool is for tap-to-add.
			if not PointerInput.is_touch_ui():
				_begin_marquee(screen_pos)
		return

	if mode == Mode.MULTISELECT:
		var picked := _pick_selectable_at_screen(screen_pos)
		_register_click(picked)
		_dragging = false
		_group_dragging = false
		_drag_object = null
		if picked:
			_toggle_multiselect(picked)
		else:
			if not _selected_group.is_empty():
				_clear_selected_group()
				status_message.emit("Deselected")
		return

	# Fishing uses ground cell + session state (cast → wait → reel).
	if mode == Mode.FISH:
		var fish_cell := _raycast_ground_cell(screen_pos)
		_register_click(null)
		if _fish_phase == 2:
			_reel_in_fish()
		elif _fish_phase == 1:
			status_message.emit("Patience — wait for the rod to shake")
		elif _is_valid_cell(fish_cell):
			_on_fish_click(fish_cell)
		else:
			status_message.emit("Cast only on water")
		return

	# Harvest: press starts a swipe path over mature plants.
	if mode == Mode.HARVEST:
		_register_click(null)
		_begin_harvest_swipe(screen_pos)
		return

	if hit.is_empty():
		_place_drag = false
		_register_click(null)
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	var hit_obj: Node3D = hit.get("object")
	_register_click(hit_obj)

	match mode:
		Mode.HOE:
			if grid_manager.hoe_grass(grid_pos):
				AudioManager.play("hoe")
				if tool_cursor:
					tool_cursor.play_hoe_dig()
				status_message.emit("Hoed grass at (%d, %d)" % [grid_pos.x, grid_pos.y])
			else:
				status_message.emit("Hoe only works on grass")
		Mode.FEED:
			_try_feed(grid_pos, hit_obj)


func _reset_selection_state() -> void:
	## Full clear used by Esc / mode switches so leftover highlights can't "stick".
	if _copy_extend_active:
		_clear_copy_ghosts()
		_copy_extend_active = false
		_copy_dragging = false
		_copy_source = null
		_copy_cells.clear()
		_copy_all_valid = false
	_cancel_menu_move()
	_hide_selection_actions()
	_restore_all_pickable()
	_clear_selected_group()
	_clear_selection_footprint()
	_drag_object = null
	_dragging = false
	_group_dragging = false
	_group_origins.clear()
	_last_click_obj = null
	_last_click_msec = 0
	grid_manager.select_object(null)


func _restore_all_pickable() -> void:
	for obj in grid_manager.get_all_selectable_objects():
		if not is_instance_valid(obj):
			continue
		grid_manager.set_object_pickable(obj, true)


func _pick_selectable_at_screen(screen_pos: Vector2) -> Node3D:
	## Hit whatever GLB / mesh is under the finger first (visible surface).
	var hit := _raycast_pick_object(screen_pos)
	if hit and _is_selectable(hit):
		return hit
	# Empty ground: only select terrain tiles (dirt / water / path), never steal via footprint.
	var ground_cell := _raycast_ground_cell(screen_pos)
	if _is_valid_cell(ground_cell):
		var terrain := grid_manager.get_terrain_at(ground_cell)
		if terrain and _is_selectable(terrain):
			return terrain
	return null


func _raycast_pick_object(screen_pos: Vector2) -> Node3D:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 200.0
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	return _resolve_object_from_collider(result.collider as Node)


func _begin_place_drag() -> void:
	# Desktop: lock to wherever the semi-transparent ghost currently sits.
	_update_ghost_from_pointer()
	_place_commit_pos = _ghost_grid_pos
	if not _is_valid_cell(_place_commit_pos):
		_place_drag = false
		status_message.emit("Cannot place here")
		return
	_place_drag = true
	status_message.emit("Release to place at ghost cell")


func _commit_place_at(place_pos: Vector2i) -> void:
	if not _is_valid_cell(place_pos):
		status_message.emit("Cancelled place")
		return
	if grid_manager.can_place_at(place_pos, selected_item, _place_rotation):
		var placed := grid_manager.place_object(selected_item, place_pos, _place_rotation)
		if placed != null or selected_item == ItemData.ItemType.GRASS:
			AudioManager.play("place")
		if selected_item == ItemData.ItemType.GRASS:
			status_message.emit("Cleared to grass floor at (%d, %d)" % [place_pos.x, place_pos.y])
		else:
			status_message.emit("Placed %s at (%d, %d)" % [
				ItemData.get_item_name(selected_item), place_pos.x, place_pos.y
			])
		if placed == null and selected_item != ItemData.ItemType.GRASS:
			pass
	else:
		status_message.emit("Cannot place here")


func _is_selectable(obj: Node3D) -> bool:
	if obj == null or not obj.has_meta("item_type"):
		return false
	# Grass is the default empty floor (no persistent selectable node).
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	return item_type != ItemData.ItemType.GRASS


func _is_movable_content(obj: Node3D) -> bool:
	# Kept as alias so older call sites stay readable.
	return _is_selectable(obj)


func _register_click(obj: Node3D) -> bool:
	var now: int = Time.get_ticks_msec()
	var is_double := obj != null and obj == _last_click_obj and (now - _last_click_msec) <= DOUBLE_CLICK_MS
	_last_click_obj = obj
	_last_click_msec = now
	return is_double


func _select_placed_object(obj: Node3D) -> void:
	mode = Mode.SELECT
	_place_drag = false
	_cancel_marquee()
	_remove_ghost()
	_hide_cursor_overlay()
	_hide_tool_cursor()
	_remove_tool_footprint()
	feed_mode_cancelled.emit()
	select_mode_requested.emit()
	_set_selected_group([obj])
	_dragging = false
	_group_dragging = false
	_drag_object = obj
	_drag_origin = obj.get_meta("grid_pos")
	_drag_hover = _drag_origin
	_drag_object.position = grid_manager.grid_to_world(_drag_origin)
	status_message.emit("Selected 1 — hold-drag to move, or box-select more on empty ground")


func _toggle_multiselect(obj: Node3D) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var next: Array = []
	for existing in _selected_group:
		if is_instance_valid(existing) and existing != obj:
			next.append(existing)
	var removing := _selected_group.has(obj)
	if not removing:
		next.append(obj)
	_set_selected_group(next)
	if next.is_empty():
		status_message.emit("Deselected")
	elif removing:
		status_message.emit("Selected %d — tap more or use top actions" % next.size())
	else:
		status_message.emit("Selected %d — tap more or use top actions" % next.size())


func _on_selection_changed(obj: Node3D) -> void:
	# Footprints for multi-select are managed by _refresh_group_footprints.
	if _selected_group.size() > 1:
		return
	_clear_selection_footprint()
	if obj == null or not is_instance_valid(obj):
		return
	if not _selected_group.has(obj):
		return
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	_selection_footprint = FootprintOverlay.create_for_item(item_type, grid_manager)
	_selection_footprint.name = "SelectionFootprint"
	_selection_footprint.set_valid(grid_manager.is_object_orientation_valid(obj))
	obj.add_child(_selection_footprint)


func _clear_selection_footprint() -> void:
	if _selection_footprint and is_instance_valid(_selection_footprint):
		_selection_footprint.queue_free()
	_selection_footprint = null
	for obj in _selected_group:
		_strip_object_footprints(obj)
	# Sweep leftovers — skip already-freed nodes (delete / mode switch races).
	if grid_manager:
		for obj in grid_manager.get_all_selectable_objects():
			_strip_object_footprints(obj)


func _strip_object_footprints(obj: Variant) -> void:
	## Use Variant so a freed Object doesn't fail typed Node3D arg coercion.
	if obj == null or not is_instance_valid(obj) or not (obj is Node3D):
		return
	var root := obj as Node3D
	for child in root.get_children():
		if not is_instance_valid(child):
			continue
		if child is FootprintOverlay \
				or child.name == "SelectionFootprint" \
				or child.name == "FootprintOverlay":
			child.queue_free()


func _set_selected_group(objs: Array) -> void:
	_clear_selection_footprint()
	_cancel_menu_move()
	for prev in _selected_group:
		if is_instance_valid(prev):
			SelectionFlash.reset(prev)
			grid_manager.set_object_highlighted(prev, false)
	_selected_group.clear()
	_group_origins.clear()
	for obj in objs:
		if obj == null or not is_instance_valid(obj):
			continue
		if not _is_selectable(obj):
			continue
		if _selected_group.has(obj):
			continue
		_selected_group.append(obj)
		_group_origins[obj] = obj.get_meta("grid_pos")
		grid_manager.set_object_highlighted(obj, true)
		SelectionFlash.play(obj)
	if _selected_group.is_empty():
		_drag_object = null
		_dragging = false
		_group_dragging = false
		grid_manager.select_object(null)
		_hide_selection_actions()
	else:
		if is_instance_valid(_selected_group[0]):
			grid_manager.select_object(_selected_group[0])
		_refresh_group_footprints()
		_show_selection_actions()


func _clear_selected_group() -> void:
	_set_selected_group([])
	# Same heal as entering Select — clears stuck occupancy / dead colliders.
	if grid_manager:
		grid_manager.repair_content_registry()
		_restore_all_pickable()


func _refresh_group_footprints() -> void:
	_clear_selection_footprint()
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		var item_type: ItemData.ItemType = obj.get_meta("item_type")
		var fp := FootprintOverlay.create_for_item(item_type, grid_manager)
		fp.name = "SelectionFootprint"
		fp.set_valid(grid_manager.is_object_orientation_valid(obj))
		obj.add_child(fp)
	if _selected_group.size() == 1:
		_selection_footprint = _selected_group[0].get_node_or_null("SelectionFootprint") as FootprintOverlay


func _refresh_selection_validity() -> void:
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		var fp := obj.get_node_or_null("SelectionFootprint") as FootprintOverlay
		if fp:
			fp.set_valid(grid_manager.is_object_orientation_valid(obj))


func _begin_marquee(screen_pos: Vector2) -> void:
	_marquee_active = true
	_marquee_start = screen_pos
	_ensure_marquee_ui()
	_update_marquee_visual(screen_pos)
	status_message.emit("Box select — drag to cover items, release to select")


func _cancel_marquee() -> void:
	_marquee_active = false
	if _marquee_fill:
		_marquee_fill.visible = false
	if _marquee_border:
		_marquee_border.visible = false


func _update_marquee_visual(screen_pos: Vector2) -> void:
	if not _marquee_fill or not _marquee_border:
		return
	var a := _marquee_start
	var b := screen_pos
	var rect := Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(a.x - b.x), absf(a.y - b.y))
	)
	_marquee_fill.visible = true
	_marquee_border.visible = true
	_marquee_fill.position = rect.position
	_marquee_fill.size = rect.size
	_marquee_border.position = rect.position
	_marquee_border.size = rect.size


func _finish_marquee(screen_pos: Vector2) -> void:
	if not _marquee_active:
		return
	var dragged := screen_pos.distance_to(_marquee_start) >= MARQUEE_THRESHOLD
	_cancel_marquee()
	if not dragged:
		_clear_selected_group()
		status_message.emit("Deselected")
		return

	var a := _marquee_start
	var b := screen_pos
	var rect := Rect2(
		Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(a.x - b.x), absf(a.y - b.y))
	)
	var picked: Array[Node3D] = []
	for obj in grid_manager.get_all_selectable_objects():
		if not _is_selectable(obj):
			continue
		var screen_pt := camera.unproject_position(obj.global_position + Vector3(0, 0.2, 0))
		if rect.has_point(screen_pt):
			picked.append(obj)

	_set_selected_group(picked)
	if picked.is_empty():
		status_message.emit("Nothing selected")
	else:
		status_message.emit("Selected %d — drag any selected item to move the group" % picked.size())


func _prepare_group_drag(anchor_obj: Node3D) -> void:
	_group_dragging = false
	_dragging = false
	_place_drag = false
	for obj in _selected_group:
		if is_instance_valid(obj):
			_group_origins[obj] = obj.get_meta("grid_pos")
	_drag_object = anchor_obj
	_drag_origin = anchor_obj.get_meta("grid_pos")
	_drag_hover = _drag_origin


func _begin_group_drag() -> void:
	if _copy_extend_active:
		return
	_hide_selection_actions()
	_group_dragging = true
	_dragging = true
	_place_drag = false
	mode = Mode.SELECT
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		_group_origins[obj] = obj.get_meta("grid_pos")
		grid_manager.set_object_pickable(obj, false)
		if _menu_move_active:
			_apply_menu_move_visual(obj, true)
			var origin: Vector2i = _group_origins[obj]
			obj.position = grid_manager.grid_to_world(origin)
	if _menu_move_active:
		_drag_hover = _drag_origin
		var valid := _can_drop_group_at(Vector2i.ZERO)
		for obj in _selected_group:
			if not is_instance_valid(obj):
				continue
			var fp := obj.get_node_or_null("SelectionFootprint") as FootprintOverlay
			if fp:
				fp.set_valid(valid)
	else:
		_update_group_drag_follow()


func _end_group_drag() -> void:
	_group_dragging = false
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		_clear_menu_move_visual(obj)
		grid_manager.set_object_pickable(obj, true)


func _update_group_drag_follow() -> void:
	if _selected_group.is_empty():
		return
	var mouse_pos := PointerInput.get_position()
	var target := _raycast_ground_cell(mouse_pos)
	if not _is_valid_cell(target):
		return
	if target == _drag_hover:
		return
	_drag_hover = target
	var delta := target - _drag_origin
	var valid := _can_drop_group_at(delta)
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		var origin: Vector2i = _group_origins[obj]
		obj.position = grid_manager.grid_to_world(origin + delta)
		var fp := obj.get_node_or_null("SelectionFootprint") as FootprintOverlay
		if fp:
			fp.set_valid(valid)


func _can_drop_group_at(delta: Vector2i) -> bool:
	var moving_content: Dictionary = {}
	var moving_terrain: Dictionary = {}
	for obj in _selected_group:
		if not is_instance_valid(obj):
			return false
		var from: Vector2i = _group_origins[obj]
		if grid_manager.is_terrain_object(obj):
			moving_terrain[obj] = from
		else:
			moving_content[obj] = from

	var content_targets: Dictionary = {}
	var terrain_targets: Dictionary = {}
	for obj in _selected_group:
		var from: Vector2i = _group_origins[obj]
		var to: Vector2i = from + delta
		if grid_manager.is_terrain_object(obj):
			if not grid_manager.is_in_bounds(to):
				return false
			if terrain_targets.has(to):
				return false
			terrain_targets[to] = true
			if grid_manager.has_terrain(to):
				var occupant: Node3D = grid_manager.get_terrain_at(to)
				if not moving_terrain.has(occupant):
					return false
		else:
			var footprint := grid_manager.get_object_footprint(obj)
			var rotation := grid_manager.get_object_rotation(obj)
			for cell in grid_manager.get_footprint_cells(to, footprint, rotation):
				if not grid_manager.is_in_bounds(cell):
					return false
				if content_targets.has(cell):
					return false
				content_targets[cell] = obj
				if grid_manager.has_content(cell):
					var occupant: Node3D = grid_manager.get_content_at(cell)
					if not moving_content.has(occupant):
						return false
	return true


func _snap_group_home() -> void:
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		var origin: Vector2i = _group_origins.get(obj, obj.get_meta("grid_pos"))
		_clear_menu_move_visual(obj)
		obj.position = grid_manager.grid_to_world(origin)
		obj.set_meta("grid_pos", origin)
		var fp := obj.get_node_or_null("SelectionFootprint") as FootprintOverlay
		if fp:
			fp.set_valid(true)
	if not _selected_group.is_empty():
		_drag_hover = _group_origins.get(_selected_group[0], _drag_origin)
		_drag_origin = _drag_hover


func _commit_group_drag(target: Vector2i) -> void:
	var delta := target - _drag_origin
	if delta == Vector2i.ZERO:
		_snap_group_home()
		return
	if not _can_drop_group_at(delta):
		_snap_group_home()
		status_message.emit("Cannot move selection there")
		return
	var moves: Array = []
	for obj in _selected_group:
		var from: Vector2i = _group_origins[obj]
		moves.append({"obj": obj, "from": from, "to": from + delta})
	if grid_manager.move_content_group(moves):
		for obj in _selected_group:
			_group_origins[obj] = obj.get_meta("grid_pos")
		_drag_origin = _group_origins[_selected_group[0]]
		_drag_hover = _drag_origin
		status_message.emit("Moved %d items" % _selected_group.size())
	else:
		_snap_group_home()
		status_message.emit("Cannot move selection there")


func _can_drop_drag_at(target: Vector2i) -> bool:
	if not grid_manager.is_in_bounds(target):
		return false
	if target == _drag_origin:
		return true
	if _drag_object and grid_manager.is_terrain_object(_drag_object):
		# Terrain may move under content; cannot overlap another terrain tile.
		return not grid_manager.has_terrain(target)
	if _drag_object:
		return grid_manager.can_move_content_to(_drag_object, target)
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
	grid_manager.set_object_pickable(_drag_object, enabled)


func _update_drag_follow() -> void:
	var mouse_pos := PointerInput.get_position()
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
		_clear_menu_move_visual(_drag_object)
		_drag_object.position = grid_manager.grid_to_world(_drag_origin)
		_drag_object.set_meta("grid_pos", _drag_origin)
	if _selection_footprint:
		_selection_footprint.set_valid(true)
	_drag_hover = _drag_origin


func _begin_object_drag(obj: Node3D) -> void:
	if _copy_extend_active:
		return
	_hide_selection_actions()
	_dragging = true
	_place_drag = false
	mode = Mode.SELECT
	_drag_object = obj
	_drag_origin = obj.get_meta("grid_pos")
	_drag_hover = _drag_origin
	_set_drag_pickable(false)
	if _menu_move_active:
		_apply_menu_move_visual(obj, true)
		_drag_object.position = grid_manager.grid_to_world(_drag_origin)
		if _selection_footprint:
			_selection_footprint.set_valid(_can_drop_drag_at(_drag_hover))
	else:
		_update_drag_follow()


func _end_object_drag() -> void:
	if _drag_object and is_instance_valid(_drag_object):
		_clear_menu_move_visual(_drag_object)
	_set_drag_pickable(true)
	_dragging = false


func _try_harvest(grid_pos: Vector2i, quiet: bool = false) -> bool:
	if not _is_valid_cell(grid_pos) or not grid_manager.is_plant_mature(grid_pos):
		if not quiet:
			status_message.emit("Nothing ready to harvest here")
		return false
	var plant := grid_manager.get_content_at(grid_pos)
	if plant:
		HarvestEffect.play(plant)
		AudioManager.play("harvest")
	var harvest_item = grid_manager.harvest_plant(grid_pos)
	if harvest_item == null:
		if not quiet:
			status_message.emit("Nothing ready to harvest here")
		return false
	if tool_cursor:
		tool_cursor.play_sickle_swing()
	if inventory_manager:
		inventory_manager.add_item(harvest_item)
	if not quiet:
		status_message.emit("Harvested %s!" % InventoryData.get_item_name(harvest_item))
	return true


func _begin_harvest_swipe(screen_pos: Vector2) -> void:
	_harvest_swiping = true
	_harvest_swipe_count = 0
	var cell := _raycast_ground_cell(screen_pos)
	_harvest_last_cell = cell if _is_valid_cell(cell) else Vector2i(-9999, -9999)
	if _try_harvest(cell, true):
		_harvest_swipe_count = 1
		status_message.emit("Harvested!")


func _update_harvest_swipe() -> void:
	if not _harvest_swiping:
		return
	var cell := _raycast_ground_cell(PointerInput.get_position())
	if not _is_valid_cell(cell):
		return
	if cell == _harvest_last_cell:
		return
	var from := _harvest_last_cell
	_harvest_last_cell = cell
	var path: Array[Vector2i] = []
	if _is_valid_cell(from):
		path = _cells_on_line(from, cell)
	else:
		path = [cell]
	var gained := 0
	for c in path:
		if c == from:
			continue
		if _try_harvest(c, true):
			gained += 1
	if gained > 0:
		_harvest_swipe_count += gained
		status_message.emit("Harvested %d" % _harvest_swipe_count)


func _end_harvest_swipe() -> void:
	if not _harvest_swiping:
		return
	_harvest_swiping = false
	if _harvest_swipe_count > 1:
		status_message.emit("Harvested %d plants" % _harvest_swipe_count)
	elif _harvest_swipe_count == 0:
		status_message.emit("Nothing ready along that path")
	_harvest_swipe_count = 0
	_harvest_last_cell = Vector2i(-9999, -9999)


func _cells_on_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## Inclusive grid line so fast swipes don't skip plants.
	var cells: Array[Vector2i] = []
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return cells


func _try_fish(grid_pos: Vector2i) -> void:
	## Kept for compatibility — fishing now uses the cast / bite / reel flow.
	_on_fish_click(grid_pos)


func _on_fish_click(grid_pos: Vector2i) -> void:
	match _fish_phase:
		0:
			if not grid_manager.try_fish(grid_pos):
				status_message.emit("Cast only on water")
				return
			_fish_cell = grid_pos
			_fish_water_pos = grid_manager.grid_to_world(grid_pos) + Vector3(0.0, 0.05, 0.0)
			_fish_phase = 1
			_fish_wait_left = 5.0
			AudioManager.play("fishing_drop")
			if tool_cursor:
				tool_cursor.play_rod_cast(_fish_water_pos)
			status_message.emit("Line cast — wait for a bite…")
		1:
			status_message.emit("Patience — wait for the rod to shake")
		2:
			_reel_in_fish()
		_:
			_reset_fishing_session()


func _update_fishing(delta: float) -> void:
	if _fish_phase != 1:
		return
	_fish_wait_left -= delta
	if _fish_wait_left > 0.0:
		return
	_fish_phase = 2
	if tool_cursor:
		tool_cursor.start_rod_bite_shake()
	status_message.emit("Bite! Click again to reel in the fish!")


func _reel_in_fish() -> void:
	if inventory_manager:
		inventory_manager.add_item(InventoryData.Item.FISH)
	FishCatchEffect.play(grid_manager.objects_container, _fish_water_pos)
	AudioManager.play("fish_catch")
	if tool_cursor:
		tool_cursor.stop_rod_session()
	_reset_fishing_session()
	status_message.emit("Caught a fish!")
	# Keep rod mode ready for another cast.
	if tool_cursor and mode == Mode.FISH:
		tool_cursor.show_rod()


func _reset_fishing_session() -> void:
	_fish_phase = 0
	_fish_cell = Vector2i(-9999, -9999)
	_fish_wait_left = 0.0
	if tool_cursor:
		tool_cursor.stop_rod_session()


func _try_feed(grid_pos: Vector2i, hit_obj: Node3D) -> void:
	if hit_obj == null or not ItemData.is_animal(hit_obj.get_meta("item_type")):
		status_message.emit("Click an animal to feed")
		return
	if inventory_manager and not inventory_manager.remove_item(feed_item):
		status_message.emit("No %s left" % InventoryData.get_item_name(feed_item))
		enter_select_mode()
		return
	AnimalFeedEffect.play(hit_obj)
	AudioManager.play("feed")
	status_message.emit("Fed %s to %s!" % [
		InventoryData.get_item_name(feed_item),
		ItemData.get_item_name(hit_obj.get_meta("item_type")),
	])


func _on_left_release(screen_pos: Vector2) -> void:
	if _marquee_active:
		_finish_marquee(screen_pos)
		return

	if _harvest_swiping:
		_end_harvest_swipe()
		return

	# Copy-extend: release freezes the preview so ✓/✕ can be pressed without re-aiming.
	if _copy_extend_active:
		_copy_dragging = false
		return

	# Menu-move: drag repositions floating item; tap nearby drops at current cell.
	if _menu_move_active and _menu_move_pressing:
		var moved := _menu_move_dragged or screen_pos.distance_to(_mouse_down_pos) > DRAG_THRESHOLD
		_menu_move_pressing = false
		_menu_move_dragged = false
		if moved:
			return
		_commit_menu_move(screen_pos)
		return

	# Touch place: release places at the cell under the finger.
	if mode == Mode.PLACE and PointerInput.is_touch_ui() and _place_drag:
		_update_ghost_from_pointer()
		_place_drag = false
		_touch_place_moved = false
		if _ghost_place_valid and _is_valid_cell(_ghost_grid_pos):
			_commit_place_at(_ghost_grid_pos)
		else:
			status_message.emit("Cannot place here")
		return

	# Desktop place-drag: commit on release at the locked / dragged ghost cell.
	if _place_drag:
		_place_drag = false
		# Prefer the cell we locked (or updated after a real drag), not a fresh raycast.
		var place_pos := _place_commit_pos
		if not _is_valid_cell(place_pos):
			place_pos = _ghost_grid_pos
		if not _is_valid_cell(place_pos):
			status_message.emit("Cancelled place")
			return
		_commit_place_at(place_pos)
		return

	# Multi-select group move (desktop hold-drag, not menu-move).
	if _group_dragging and not _selected_group.is_empty() and not _menu_move_active:
		var target := _raycast_ground_cell(screen_pos)
		if not _is_valid_cell(target):
			_snap_group_home()
			status_message.emit("Move cancelled")
		else:
			_commit_group_drag(target)
		_end_group_drag()
		_dragging = false
		_show_selection_actions()
		return

	# Move existing object: follow mouse while held, commit on release (desktop, not menu-move).
	if _dragging and _drag_object and is_instance_valid(_drag_object) and not _menu_move_active:
		var target := _raycast_ground_cell(screen_pos)
		if not _is_valid_cell(target):
			_snap_drag_home()
			status_message.emit("Move cancelled")
		elif target == _drag_origin:
			_snap_drag_home()
		elif _can_drop_drag_at(target) and grid_manager.move_object(_drag_origin, target):
			_drag_origin = target
			_drag_hover = target
			if _group_origins.has(_drag_object):
				_group_origins[_drag_object] = target
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
		_show_selection_actions()
		return

	_end_object_drag()


func _on_right_click(screen_pos: Vector2) -> void:
	# In place mode, right-click rotates the preview (stay in place mode).
	if mode == Mode.PLACE:
		_rotate_place_preview()
		return

	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return

	var grid_pos: Vector2i = hit["grid_pos"]
	var hit_obj: Node3D = hit.get("object")

	if hit_obj:
		var ok := grid_manager.rotate_object(grid_pos, 1)
		if _selected_group.has(hit_obj):
			_refresh_group_footprints()
		if ok:
			status_message.emit("Rotated %s" % ItemData.get_item_name(hit_obj.get_meta("item_type")))
		else:
			status_message.emit("Rotated — red means blocked, move or rotate again")


func _rotate_place_preview() -> void:
	_place_rotation = (_place_rotation + 1) % 4
	if _ghost:
		_ghost.set_meta("rotation", _place_rotation)
		GridManager.apply_placeable_yaw(_ghost, _place_rotation, ItemData.get_footprint(selected_item))
		_apply_ghost_at_cell(_ghost_grid_pos)
	status_message.emit("Facing %d° — still placing %s" % [
		_place_rotation * 90,
		ItemData.get_item_name(selected_item),
	])


func _rotate_selected() -> void:
	# While placing, R rotates the ghost and keeps the same item selected.
	if mode == Mode.PLACE:
		_rotate_place_preview()
		return
	if not _selected_group.is_empty():
		var batching := undo_manager != null and _selected_group.size() > 1
		if batching:
			undo_manager.begin_batch()
		var rotated := 0
		var any_blocked := false
		for obj in _selected_group:
			if not is_instance_valid(obj) or not obj.has_meta("grid_pos"):
				continue
			var item_type: ItemData.ItemType = obj.get_meta("item_type")
			if not ItemData.is_rotatable(item_type):
				continue
			var ok := grid_manager.rotate_object(obj.get_meta("grid_pos"), 1)
			rotated += 1
			if not ok:
				any_blocked = true
		if batching:
			undo_manager.end_batch()
		if rotated > 0:
			_refresh_group_footprints()
			_show_selection_actions()
			if any_blocked:
				status_message.emit("Rotated — red means blocked, move or rotate again")
			else:
				status_message.emit("Rotated %d item(s)" % rotated)
		else:
			status_message.emit("This item can't rotate")
		return
	var selected := grid_manager.get_selected()
	if selected:
		var grid_pos: Vector2i = selected.get_meta("grid_pos")
		var ok := grid_manager.rotate_object(grid_pos, 1)
		_refresh_group_footprints()
		_show_selection_actions()
		if ok:
			status_message.emit("Rotated object")
		else:
			status_message.emit("Rotated — red means blocked, move or rotate again")


func _delete_selected() -> void:
	_hide_selection_actions()
	_cancel_menu_move()
	if not _selected_group.is_empty():
		var to_delete: Array[Node3D] = _selected_group.duplicate()
		_clear_selected_group()
		var batching := undo_manager != null and to_delete.size() > 1
		if batching:
			undo_manager.begin_batch()
		var deleted := 0
		for obj in to_delete:
			if is_instance_valid(obj) and grid_manager.remove_node(obj):
				deleted += 1
		if batching:
			undo_manager.end_batch()
		if deleted > 0:
			AudioManager.play("delete")
		status_message.emit("Deleted %d items" % deleted)
		return
	var selected := grid_manager.get_selected()
	if selected:
		grid_manager.remove_node(selected)
		AudioManager.play("delete")
		status_message.emit("Deleted object")
		enter_select_mode()


func _cancel_action() -> void:
	if _marquee_active:
		_cancel_marquee()
	if _harvest_swiping:
		_end_harvest_swipe()
	if _copy_extend_active:
		_cancel_copy_extend()
	if _menu_move_active:
		_cancel_menu_move()
	_reset_fishing_session()
	if _group_dragging:
		_snap_group_home()
		_end_group_drag()
	if _dragging and _drag_object:
		_snap_drag_home()
		_end_object_drag()
	_place_drag = false
	_reset_selection_state()
	_remove_ghost()
	_hide_cursor_overlay()
	_hide_tool_cursor()
	_remove_tool_footprint()
	mode = Mode.SELECT
	select_mode_requested.emit()
	status_message.emit("Cancelled — selection cleared")


func _show_cursor_overlay(text: String, color: Color) -> void:
	if cursor_overlay:
		cursor_overlay.show_item(text, color)


func _hide_cursor_overlay() -> void:
	if cursor_overlay:
		cursor_overlay.hide_overlay()


func _show_hoe_cursor() -> void:
	if tool_cursor:
		tool_cursor.show_hoe()


func _show_rod_cursor() -> void:
	if tool_cursor:
		tool_cursor.show_rod()


func _show_sickle_cursor() -> void:
	if tool_cursor:
		tool_cursor.show_sickle()


func _hide_tool_cursor() -> void:
	_reset_fishing_session()
	if tool_cursor:
		tool_cursor.hide_tool()


func _ensure_tool_footprint() -> void:
	if _tool_footprint and is_instance_valid(_tool_footprint):
		_tool_footprint.visible = true
		_update_tool_footprint()
		return
	_tool_footprint = FootprintOverlay.create_for_item(ItemData.ItemType.DIRT, grid_manager)
	_tool_footprint.name = "ToolFootprint"
	grid_manager.objects_container.add_child(_tool_footprint)
	_update_tool_footprint()


func _tool_cell_valid(cell: Vector2i) -> bool:
	match mode:
		Mode.HOE:
			return grid_manager.can_hoe_at(cell)
		Mode.HARVEST:
			return grid_manager.is_plant_mature(cell)
		Mode.FISH:
			return grid_manager.try_fish(cell)
		_:
			return false


func _update_tool_footprint() -> void:
	if _tool_footprint == null or not is_instance_valid(_tool_footprint):
		return
	# While pinching/panning with two fingers, freeze the highlight.
	if PointerInput.touch_count() >= 2:
		return
	var cell := _raycast_ground_cell(PointerInput.get_position())
	if not _is_valid_cell(cell):
		_tool_footprint.visible = false
		if tool_cursor:
			tool_cursor.set_cell_anchor(Vector3.ZERO, false)
		return
	_tool_footprint.visible = true
	var world := grid_manager.grid_to_world(cell)
	_tool_footprint.position = world
	var valid := _tool_cell_valid(cell)
	_tool_footprint.set_valid(valid)
	if tool_cursor:
		tool_cursor.set_cell_anchor(world, true)


func _remove_tool_footprint() -> void:
	if _tool_footprint and is_instance_valid(_tool_footprint):
		_tool_footprint.queue_free()
	_tool_footprint = null


func _ensure_action_bar() -> void:
	if _action_bar and is_instance_valid(_action_bar):
		return
	var layer := CanvasLayer.new()
	layer.name = "SelectionActionLayer"
	layer.layer = 25
	add_child(layer)
	_action_bar = SelectionActionBarScript.new()
	_action_bar.name = "SelectionActionBar"
	layer.add_child(_action_bar)
	_action_bar.setup(camera)
	_action_bar.move_pressed.connect(_on_selection_move_pressed)
	_action_bar.copy_pressed.connect(_on_selection_copy_pressed)
	_action_bar.rotate_pressed.connect(_rotate_selected)
	_action_bar.delete_pressed.connect(_delete_selected)
	_action_bar.confirm_pressed.connect(_confirm_copy_extend)
	_action_bar.cancel_pressed.connect(_cancel_copy_extend)


func _selection_action_anchor() -> Vector3:
	if _selected_group.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	var count := 0
	var lift := 1.05
	for obj in _selected_group:
		if not is_instance_valid(obj):
			continue
		sum += obj.global_position
		count += 1
		var item_type: ItemData.ItemType = obj.get_meta("item_type")
		if ItemData.is_terrain(item_type):
			lift = maxf(lift, 0.55)
		else:
			lift = maxf(lift, 1.25)
	if count == 0:
		return Vector3.ZERO
	return sum / float(count) + Vector3(0.0, lift, 0.0)


func _show_selection_actions() -> void:
	if _action_bar == null:
		_ensure_action_bar()
	if _action_bar == null or _selected_group.is_empty():
		return
	if _menu_move_active or _dragging or _group_dragging or _marquee_active or _copy_extend_active:
		return
	if mode != Mode.SELECT and mode != Mode.MULTISELECT:
		_hide_selection_actions()
		return
	# Multiselect (or Select with a group) uses a top collective action bar.
	if mode == Mode.MULTISELECT or _selected_group.size() > 1:
		_action_bar.show_at_top()
	else:
		_action_bar.show_at_world(_selection_action_anchor())


func _hide_selection_actions() -> void:
	if _action_bar and is_instance_valid(_action_bar):
		_action_bar.hide_bar()


func _on_selection_move_pressed() -> void:
	if _selected_group.is_empty():
		return
	_hide_selection_actions()
	_menu_move_active = true
	_menu_move_pressing = false
	_menu_move_dragged = false
	if _selected_group.size() > 1:
		_prepare_group_drag(_selected_group[0])
		_begin_group_drag()
	else:
		_begin_object_drag(_selected_group[0])
	status_message.emit("Move — drag to position · tap nearby to drop")


func _on_selection_copy_pressed() -> void:
	if _selected_group.is_empty():
		return
	if _selected_group.size() != 1:
		status_message.emit("Copy works on one item at a time")
		return
	var src: Node3D = _selected_group[0]
	if not is_instance_valid(src) or not src.has_meta("item_type"):
		return
	_cancel_menu_move()
	_start_copy_extend(src)


func _start_copy_extend(src: Node3D) -> void:
	_clear_copy_ghosts()
	_copy_extend_active = true
	_copy_dragging = false
	_copy_source = src
	_copy_item_type = src.get_meta("item_type")
	_copy_origin = src.get_meta("grid_pos")
	_copy_rotation = int(src.get_meta("rotation", 0))
	_copy_preview_rotation = _copy_rotation
	_copy_cells.clear()
	_copy_all_valid = false
	# Cancel any object-drag so the original can't leave its cell during copy.
	if _dragging or _group_dragging:
		_snap_drag_home()
		_end_object_drag()
		_end_group_drag()
	_dragging = false
	_group_dragging = false
	_drag_object = null
	# Keep the original planted: never tint/move it during copy-extend.
	if is_instance_valid(src):
		_clear_menu_move_visual(src)
		src.position = grid_manager.grid_to_world(_copy_origin)
		src.set_meta("grid_pos", _copy_origin)
	_hide_selection_actions()
	_ensure_action_bar()
	_action_bar.show_confirm_at_top(false)
	status_message.emit("Copy — drag to extend · green ✓ to place · ✕ to cancel")


func _update_copy_extend_from_pointer() -> void:
	if not _copy_extend_active:
		return
	var cell := _raycast_ground_cell(PointerInput.get_position())
	if not _is_valid_cell(cell):
		return
	_set_copy_extend_target(cell)


func _set_copy_extend_target(target: Vector2i) -> void:
	## Keep the source object's rotation; only stamp axis-aligned copy cells.
	var dx := target.x - _copy_origin.x
	var dy := target.y - _copy_origin.y
	var along_x := absi(dx) >= absi(dy)

	var step := _copy_step_along_axis(along_x)
	var cells: Array[Vector2i] = []
	if along_x and dx != 0:
		var dir := 1 if dx > 0 else -1
		var dist := absi(dx)
		var i := step
		while i <= dist:
			cells.append(Vector2i(_copy_origin.x + dir * i, _copy_origin.y))
			i += step
	elif (not along_x) and dy != 0:
		var dir := 1 if dy > 0 else -1
		var dist := absi(dy)
		var i := step
		while i <= dist:
			cells.append(Vector2i(_copy_origin.x, _copy_origin.y + dir * i))
			i += step

	if _copy_cells_equal(cells):
		_refresh_copy_confirm_state()
		return
	_copy_cells = cells
	_copy_preview_rotation = _copy_rotation
	_rebuild_copy_ghosts()
	_refresh_copy_confirm_state()


func _copy_cells_equal(cells: Array[Vector2i]) -> bool:
	if cells.size() != _copy_cells.size():
		return false
	for i in range(cells.size()):
		if cells[i] != _copy_cells[i]:
			return false
	return true


func _copy_step_along_axis(along_x: bool) -> int:
	var fp := ItemData.get_footprint(_copy_item_type)
	var cells := grid_manager.get_footprint_cells(Vector2i.ZERO, fp, _copy_rotation)
	if cells.is_empty():
		return 1
	var min_v := 9999
	var max_v := -9999
	for c in cells:
		var v: int = c.x if along_x else c.y
		min_v = mini(min_v, v)
		max_v = maxi(max_v, v)
	return maxi(max_v - min_v + 1, 1)


func _rebuild_copy_ghosts() -> void:
	_clear_copy_ghosts()
	for cell in _copy_cells:
		var ghost := PlaceableObject.create(_copy_item_type, cell, _copy_rotation)
		ghost.name = "Ghost"
		ghost.set_meta("is_copy_ghost", true)
		grid_manager.objects_container.add_child(ghost)
		ghost.position = grid_manager.grid_to_world(cell)
		GridManager.apply_placeable_yaw(ghost, _copy_rotation, ItemData.get_footprint(_copy_item_type))
		_set_geometry_move_tint(ghost, true)
		var fp := FootprintOverlay.create_for_item(_copy_item_type, grid_manager)
		fp.name = "SelectionFootprint"
		ghost.add_child(fp)
		var valid := grid_manager.can_place_at(cell, _copy_item_type, _copy_rotation)
		fp.set_valid(valid)
		_copy_ghosts.append(ghost)


func _clear_copy_ghosts() -> void:
	for g in _copy_ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_copy_ghosts.clear()


func _refresh_copy_confirm_state() -> void:
	_copy_all_valid = not _copy_cells.is_empty()
	for cell in _copy_cells:
		if not grid_manager.can_place_at(cell, _copy_item_type, _copy_rotation):
			_copy_all_valid = false
			break
	# Footprints stay synced in rebuild; update confirm button.
	if _action_bar and is_instance_valid(_action_bar):
		_action_bar.show_confirm_at_top(_copy_all_valid)


func _confirm_copy_extend() -> void:
	if not _copy_extend_active:
		return
	if not _copy_all_valid or _copy_cells.is_empty():
		status_message.emit("Can't place — clear obstacles or cancel")
		return
	var cells: Array[Vector2i] = _copy_cells.duplicate()
	var item_type := _copy_item_type
	var rot := _copy_rotation
	_pin_copy_source_home()
	_clear_copy_ghosts()
	_copy_extend_active = false
	_copy_dragging = false
	_copy_source = null
	_copy_cells.clear()
	_copy_all_valid = false
	_hide_selection_actions()

	var batching := undo_manager != null and cells.size() > 1
	if batching:
		undo_manager.begin_batch()
	var placed := 0
	for cell in cells:
		if not grid_manager.can_place_at(cell, item_type, rot):
			continue
		var obj := grid_manager.place_object(item_type, cell, rot, true, 0)
		if obj != null or item_type == ItemData.ItemType.GRASS:
			placed += 1
	if batching:
		undo_manager.end_batch()

	if placed > 0:
		AudioManager.play("copy_confirm")
	_restore_selection_drag_anchor()
	if not _selected_group.is_empty():
		_show_selection_actions()
	status_message.emit("Copied %d item(s)" % placed)


func _cancel_copy_extend() -> void:
	if not _copy_extend_active:
		return
	_pin_copy_source_home()
	_clear_copy_ghosts()
	_copy_extend_active = false
	_copy_dragging = false
	_copy_source = null
	_copy_cells.clear()
	_copy_all_valid = false
	_hide_selection_actions()
	_restore_selection_drag_anchor()
	if not _selected_group.is_empty():
		_show_selection_actions()
	status_message.emit("Copy cancelled")


func _pin_copy_source_home() -> void:
	## Ensure the original never stays at a dragged world position after copy mode.
	if _copy_source != null and is_instance_valid(_copy_source):
		_clear_menu_move_visual(_copy_source)
		_copy_source.position = grid_manager.grid_to_world(_copy_origin)
		_copy_source.set_meta("grid_pos", _copy_origin)


func _restore_selection_drag_anchor() -> void:
	if _selected_group.size() == 1 and is_instance_valid(_selected_group[0]):
		_drag_object = _selected_group[0]
		_drag_origin = _drag_object.get_meta("grid_pos")
		_drag_hover = _drag_origin
	else:
		_drag_object = null


func _update_menu_move_follow() -> void:
	if _group_dragging:
		_update_group_drag_follow()
	elif _dragging and _drag_object and is_instance_valid(_drag_object):
		_update_drag_follow()


func _commit_menu_move(_screen_pos: Vector2) -> void:
	## Drop at the cell the floating item is currently over (tap nearby to confirm).
	var target := _drag_hover
	if _group_dragging and not _selected_group.is_empty():
		if not _is_valid_cell(target):
			_snap_group_home()
			status_message.emit("Move cancelled")
		elif not _can_drop_group_at(target - _drag_origin):
			_snap_group_home()
			status_message.emit("Cannot move there")
		else:
			_commit_group_drag(target)
		_end_group_drag()
		_dragging = false
	elif _dragging and _drag_object and is_instance_valid(_drag_object):
		if not _is_valid_cell(target):
			_snap_drag_home()
			status_message.emit("Move cancelled")
		elif target == _drag_origin:
			_snap_drag_home()
			status_message.emit("Stay put")
		elif _can_drop_drag_at(target) and grid_manager.move_object(_drag_origin, target):
			_clear_menu_move_visual(_drag_object)
			_drag_origin = target
			_drag_hover = target
			if _group_origins.has(_drag_object):
				_group_origins[_drag_object] = target
			status_message.emit("Moved to (%d, %d)" % [target.x, target.y])
		else:
			_snap_drag_home()
			status_message.emit("Cannot move there")
		_end_object_drag()
		if is_instance_valid(_drag_object):
			_drag_origin = _drag_object.get_meta("grid_pos")
			_drag_hover = _drag_origin
	_menu_move_active = false
	_menu_move_pressing = false
	_menu_move_dragged = false
	_show_selection_actions()


func _cancel_menu_move() -> void:
	if not _menu_move_active:
		return
	if _group_dragging:
		_snap_group_home()
		_end_group_drag()
		_dragging = false
	elif _dragging and _drag_object:
		_snap_drag_home()
		_end_object_drag()
	_menu_move_active = false
	_menu_move_pressing = false
	_menu_move_dragged = false


func _apply_menu_move_visual(obj: Node3D, active: bool) -> void:
	## Yellow translucent ghost while Move is active — no vertical lift.
	if obj == null or not is_instance_valid(obj):
		return
	_set_geometry_move_tint(obj, active)


func _clear_menu_move_visual(obj: Node3D) -> void:
	_apply_menu_move_visual(obj, false)


func _set_geometry_move_tint(node: Node, active: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is FootprintOverlay or str(node.name).begins_with("SelectionFootprint"):
		return
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		if active:
			if not gi.has_meta("_move_prev_transparency"):
				gi.set_meta("_move_prev_transparency", gi.transparency)
			gi.transparency = MENU_MOVE_TRANSPARENCY
			if not gi.has_meta("_move_overlay_on"):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = MENU_MOVE_TINT
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				gi.material_overlay = mat
				gi.set_meta("_move_overlay_on", true)
		else:
			if gi.has_meta("_move_prev_transparency"):
				gi.transparency = float(gi.get_meta("_move_prev_transparency"))
				gi.remove_meta("_move_prev_transparency")
			else:
				gi.transparency = 0.0
			if gi.has_meta("_move_overlay_on"):
				gi.material_overlay = null
				gi.remove_meta("_move_overlay_on")
	for child in node.get_children():
		_set_geometry_move_tint(child, active)


func _set_geometry_fade(node: Node, transparency: float) -> void:
	## Kept for any legacy call sites; prefer _set_geometry_move_tint for Move.
	if node == null or not is_instance_valid(node):
		return
	if node is FootprintOverlay or str(node.name).begins_with("SelectionFootprint"):
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = transparency
	for child in node.get_children():
		_set_geometry_fade(child, transparency)


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
	while current != null and is_instance_valid(current):
		if current is Node3D and current.has_meta("item_type") and current.has_meta("grid_pos"):
			var obj := current as Node3D
			# Identity match in the content registry (works for multi-cell + repaired anchors).
			if grid_manager.is_registered_content(obj):
				return obj
			if grid_manager.is_terrain_object(obj):
				return obj
			# Orphaned placeable (desynced occupancy) — still allow selecting it.
			if not grid_manager.is_terrain_object(obj):
				return obj
		current = current.get_parent()
	return null


func _update_ghost() -> void:
	_remove_ghost()
	if mode != Mode.PLACE:
		return
	# Mobile: footprint-only preview (instantiating full GLBs for ghosts is too slow on iPad).
	if OS.has_feature("mobile") or PointerInput.is_touch_ui():
		_ghost = Node3D.new()
		_ghost.name = "Ghost"
		grid_manager.objects_container.add_child(_ghost)
		_footprint = FootprintOverlay.create_for_item(selected_item, grid_manager)
		_footprint.name = "GhostFootprint"
		_ghost.add_child(_footprint)
		_ghost.visible = false
		return
	_ghost = PlaceableObject.create(selected_item, Vector2i.ZERO, _place_rotation)
	_ghost.name = "Ghost"
	GridManager.apply_placeable_yaw(_ghost, _place_rotation, ItemData.get_footprint(selected_item))
	_set_ghost_transparency(_ghost, 0.4)
	# Footprint under ghost so it rotates with the preview.
	_footprint = FootprintOverlay.create_for_item(selected_item, grid_manager)
	_footprint.name = "GhostFootprint"
	grid_manager.objects_container.add_child(_ghost)
	_ghost.add_child(_footprint)


func _set_ghost_transparency(node: Node, alpha: float) -> void:
	if node == null or not is_instance_valid(node):
		return
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
				var dup := src.duplicate()
				if dup is BaseMaterial3D:
					(dup as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					var c := (dup as BaseMaterial3D).albedo_color
					c.a = alpha
					(dup as BaseMaterial3D).albedo_color = c
				node.set_surface_override_material(i, dup)
		elif mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var c2 := mat.albedo_color
			c2.a = alpha
			mat.albedo_color = c2
	for child in node.get_children():
		if is_instance_valid(child):
			_set_ghost_transparency(child, alpha)


func _remove_ghost() -> void:
	if _footprint and is_instance_valid(_footprint):
		_footprint.queue_free()
	_footprint = null
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if grid_manager and grid_manager.objects_container:
		for child in grid_manager.objects_container.get_children():
			if child.name == "GhostFootprint" or child.name == "Ghost":
				child.queue_free()


func _update_ghost_from_pointer() -> void:
	if not _ghost:
		return
	var mouse_pos := PointerInput.get_position()
	var grid_pos := _raycast_ground_cell(mouse_pos)
	# While placing: keep the press-cell until the mouse really moves (avoids click jitter).
	if _place_drag and not PointerInput.is_touch_ui():
		if mouse_pos.distance_to(_mouse_down_pos) <= DRAG_THRESHOLD:
			grid_pos = _place_commit_pos
		else:
			_place_commit_pos = grid_pos
	elif _place_drag and PointerInput.is_touch_ui():
		_place_commit_pos = grid_pos
	_apply_ghost_at_cell(grid_pos)


func _apply_ghost_at_cell(grid_pos: Vector2i) -> void:
	if not _ghost:
		return
	_ghost_grid_pos = grid_pos
	if not _is_valid_cell(grid_pos):
		_ghost.visible = false
		_ghost_place_valid = false
		if _footprint:
			_footprint.visible = false
		return

	_ghost.visible = true
	_ghost.position = grid_manager.grid_to_world(grid_pos)
	GridManager.apply_placeable_yaw(_ghost, _place_rotation, ItemData.get_footprint(selected_item))
	if _footprint and is_instance_valid(_footprint):
		_footprint.visible = true

	var valid := grid_manager.can_place_at(grid_pos, selected_item, _place_rotation)
	_ghost_place_valid = valid
	if _footprint:
		_footprint.set_valid(valid)
	_set_ghost_tint(_ghost, Color(0.45, 1.0, 0.55, 0.4) if valid else Color(1.0, 0.45, 0.45, 0.4))


func _set_ghost_tint(node: Node, color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is FootprintOverlay:
		return
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			var c := color
			c.a = mat.albedo_color.a
			mat.albedo_color = c
	for child in node.get_children():
		if is_instance_valid(child):
			_set_ghost_tint(child, color)


func _set_ghost_color(node: Node, color: Color) -> void:
	_set_ghost_tint(node, color)
