class_name WalkModeController
extends Node

## Build ↔ Walk explore mode.
## 1) Place a yellow ghost avatar on a free cell
## 2) Drop in → third-person follow + circular joystick (diagonal ok)
##    Bridges walkable, benches hop-on, fences vault-over.

signal status_message(text: String)
signal walk_started
signal walk_ended

enum State { OFF, PLACING, WALKING }

const LOOK_SENSITIVITY: float = 0.0042
const LOOK_PITCH_MIN: float = deg_to_rad(8.0)
const LOOK_PITCH_MAX: float = deg_to_rad(55.0)
const FOLLOW_DISTANCE: float = 5.5
const FOLLOW_HEIGHT: float = 2.4
const GHOST_HOVER_Y: float = 0.55
const PLACE_TAP_THRESHOLD: float = 14.0
const MOVE_SPEED: float = 3.6
const HEIGHT_LERP: float = 10.0
const JOYSTICK_RADIUS: float = 64.0
const JOYSTICK_DEADZONE: float = 0.18
const VAULT_DURATION: float = 0.38
const VAULT_HEIGHT: float = 0.75
## Soft aim: pick nearest interactable near screen center (not only a hard ray).
const AIM_SCREEN_RADIUS: float = 110.0
const AIM_CELL_RADIUS: int = 3
const AIM_STICKY_BONUS: float = 28.0
const COMPOST_DROP_CHANCE: float = 0.28

var grid_manager: GridManager
var camera: Camera3D
var camera_controller: CameraController
var placement_controller: PlacementController
var inventory_manager: InventoryManager

var animal_info_card: AnimalInfoCard = null
var plant_info_card: PlantInfoCard = null
var _soft_aim_target: Node3D = null

var state: State = State.OFF
var _avatar: PlayerAvatar
var _ghost_cell: Vector2i = Vector2i(-9999, -9999)
var _busy: bool = false  # vault / hop tween lock
var _sitting: bool = false
var _sit_bench: Node3D = null

## Saved build-camera state.
var _saved_projection: int = Camera3D.PROJECTION_ORTHOGONAL
var _saved_size: float = 16.0
var _saved_near: float = 0.05
var _saved_far: float = 4000.0
var _saved_pos: Vector3 = Vector3.ZERO
var _saved_basis: Basis = Basis.IDENTITY

var _look_yaw: float = 0.0
var _look_pitch: float = deg_to_rad(28.0)
var _look_dragging: bool = false
var _look_last: Vector2 = Vector2.ZERO
var _place_pressing: bool = false
var _place_press_pos: Vector2 = Vector2.ZERO
var _place_dragged: bool = false

## Movement input (−1..1). y negative = forward (camera-relative).
var _stick_vec: Vector2 = Vector2.ZERO
var _key_vec: Vector2 = Vector2.ZERO

## UI
var _ui_layer: CanvasLayer
var _place_hint: Label
var _walk_hud: Control
var _exit_btn: Button
var _joystick: Control
var _hotbar: HBoxContainer
var _hotbar_btns: Array[Button] = []
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_counts: Array[Label] = []
var _hotbar_selected: int = -1
var _use_btn: Button
var _rename_btn: Button
var _collect_btn: Button
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _rename_target: Node3D = null
var _hotbar_name_lbl: Label
var _day_night_kept: CanvasItem = null
var _use_highlight: MeshInstance3D
var _stick_active: bool = false
var _stick_pointer_id: int = -1  # -1 mouse, >=0 touch index
var _build_ui_hidden: Array[CanvasItem] = []
var _fish_phase: int = 0  # 0 idle, 1 waiting, 2 bite
var _fish_cell: Vector2i = Vector2i(-9999, -9999)
var _fish_wait_left: float = 0.0
var _fish_water_pos: Vector3 = Vector3.ZERO


func setup(
	p_grid: GridManager,
	p_camera: Camera3D,
	p_cam_ctrl: CameraController,
	p_placement: PlacementController,
	p_inventory: InventoryManager = null
) -> void:
	grid_manager = p_grid
	camera = p_camera
	camera_controller = p_cam_ctrl
	placement_controller = p_placement
	inventory_manager = p_inventory
	if inventory_manager and not inventory_manager.inventory_changed.is_connected(_refresh_hotbar):
		inventory_manager.inventory_changed.connect(_refresh_hotbar)
	_build_ui()


func is_active() -> bool:
	return state != State.OFF


func begin_place_avatar() -> void:
	if state == State.WALKING:
		return
	if state == State.PLACING:
		_try_confirm_place()
		return
	_enter_placing()


func exit_walk() -> void:
	if state == State.OFF:
		return
	_busy = false
	_stick_vec = Vector2.ZERO
	_key_vec = Vector2.ZERO
	_stick_active = false
	_reset_walk_fish()
	_stand_up(false)
	_teardown_avatar()
	_hide_walk_hud()
	_hide_place_hint()
	_restore_build_camera()
	_restore_build_ui()
	if camera_controller:
		camera_controller.set_build_orbit_enabled(true)
	if placement_controller:
		placement_controller.set_walk_mode_blocked(false)
	if grid_manager:
		grid_manager.set_feed_attract(false)
	if animal_info_card:
		animal_info_card.clear()
	if plant_info_card:
		plant_info_card.clear()
	_soft_aim_target = null
	state = State.OFF
	walk_ended.emit()
	status_message.emit(LocaleManager.t("Back to build view"))


func _enter_placing() -> void:
	state = State.PLACING
	if placement_controller:
		placement_controller.set_walk_mode_blocked(true)
	if camera_controller:
		camera_controller.set_build_orbit_enabled(true)
	_ensure_avatar()
	_avatar.set_ghost_look(true)
	_avatar.visible = true
	var start := _default_place_cell()
	_set_ghost_cell(start)
	_show_place_hint()
	_hide_walk_hud()
	status_message.emit(LocaleManager.t("Walk — drag yellow figure · tap again to drop in"))


func _try_confirm_place() -> void:
	if state != State.PLACING:
		return
	if not grid_manager.player_can_stand_at(_ghost_cell):
		status_message.emit(LocaleManager.t("Can't stand here — try grass, path, bridge, or bench"))
		return
	_start_walking(_ghost_cell)


func _start_walking(cell: Vector2i) -> void:
	state = State.WALKING
	_busy = false
	_stick_vec = Vector2.ZERO
	_key_vec = Vector2.ZERO
	_ensure_avatar()
	_avatar.set_ghost_look(false)
	_avatar.grid_pos = cell
	_avatar.position = _world_stand_pos(cell)
	_avatar.set_facing_yaw(_look_yaw)
	_hide_place_hint()
	_hide_build_ui()
	_show_walk_hud()
	_snapshot_build_camera()
	if camera_controller:
		camera_controller.set_build_orbit_enabled(false)
	if camera:
		var focus := _avatar.global_position + Vector3(0.0, 1.0, 0.0)
		var to_cam := camera.global_position - focus
		if to_cam.length_squared() > 0.01:
			_look_yaw = atan2(to_cam.x, to_cam.z)
			_look_pitch = asin(clampf(to_cam.y / to_cam.length(), -1.0, 1.0))
			_look_pitch = clampf(_look_pitch, LOOK_PITCH_MIN, LOOK_PITCH_MAX)
	_apply_follow_camera(true)
	walk_started.emit()
	status_message.emit(LocaleManager.t("Exploring — joystick to move · swipe to look · Exit to leave"))


func _world_stand_pos(cell: Vector2i) -> Vector3:
	var p := grid_manager.grid_to_world(cell)
	p.y = grid_manager.player_surface_height(cell)
	return p


func _default_place_cell() -> Vector2i:
	var center_world := grid_manager.get_map_center()
	var cell := grid_manager.world_to_grid_nearest(center_world)
	if grid_manager.player_can_stand_at(cell):
		return cell
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if grid_manager.player_can_stand_at(c):
					return c
	return cell


func _ensure_avatar() -> void:
	if _avatar != null and is_instance_valid(_avatar):
		return
	_avatar = PlayerAvatar.new()
	_avatar.name = "PlayerAvatar"
	grid_manager.objects_container.add_child(_avatar)


func _teardown_avatar() -> void:
	_clear_use_highlight()
	if _avatar != null and is_instance_valid(_avatar):
		_avatar.clear_fishing_line()
		_avatar.queue_free()
	_avatar = null
	_ghost_cell = Vector2i(-9999, -9999)


func _set_ghost_cell(cell: Vector2i) -> void:
	_ghost_cell = cell
	if _avatar == null or not is_instance_valid(_avatar):
		return
	var world := grid_manager.grid_to_world(cell)
	world.y = grid_manager.player_surface_height(cell) + GHOST_HOVER_Y
	_avatar.position = world
	if grid_manager.player_can_stand_at(cell):
		_avatar.set_ghost_look(true)
	else:
		_apply_invalid_ghost_tint()


func _apply_invalid_ghost_tint() -> void:
	if _avatar == null:
		return
	for child in _avatar.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.35, 0.3, 0.5)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(child as MeshInstance3D).material_override = mat


func _process(delta: float) -> void:
	if state == State.PLACING:
		if PointerInput.primary_down:
			PointerInput.gameplay_captures_primary = true
			_update_ghost_from_pointer()
			if _place_pressing and PointerInput.get_position().distance_to(_place_press_pos) > PLACE_TAP_THRESHOLD:
				_place_dragged = true
		_update_ghost_from_pointer()
	elif state == State.WALKING:
		PointerInput.gameplay_captures_primary = _look_dragging or _stick_active
		_update_key_vec()
		if not _busy:
			_apply_move(delta)
		_update_walk_fishing(delta)
		_update_use_highlight()
		_apply_follow_camera(false)
		_update_use_button_label()
		_update_hotbar_name_label()
		_update_feed_attract()
		_update_aim_cards()


func _update_key_vec() -> void:
	_key_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		_key_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		_key_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		_key_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		_key_vec.x += 1.0
	if _key_vec.length_squared() > 1.0:
		_key_vec = _key_vec.normalized()


func _move_input() -> Vector2:
	if _stick_vec.length() >= JOYSTICK_DEADZONE:
		return _stick_vec
	return _key_vec


func _apply_move(delta: float) -> void:
	if _avatar == null or not is_instance_valid(_avatar):
		return
	var input := _move_input()
	if _sitting:
		if input.length() >= JOYSTICK_DEADZONE:
			_stand_up(true)
		else:
			return
	if input.length() < JOYSTICK_DEADZONE:
		_sync_height(delta)
		return
	var forward := Vector3(-sin(_look_yaw), 0.0, -cos(_look_yaw))
	var right := Vector3(cos(_look_yaw), 0.0, -sin(_look_yaw))
	# input.y negative = forward
	var wish := (-forward * input.y + right * input.x)
	if wish.length_squared() < 0.0001:
		_sync_height(delta)
		return
	wish = wish.normalized()
	var speed := MOVE_SPEED * clampf(input.length(), 0.0, 1.0)
	var delta_pos := wish * speed * delta

	# Face movement direction.
	var look_target := _avatar.position + wish
	look_target.y = _avatar.position.y
	_avatar.look_at(look_target, Vector3.UP)
	_avatar.facing_yaw = _avatar.rotation.y

	# Slide on X then Z so diagonals can glance along walls / fences.
	_try_axis_move(Vector3(delta_pos.x, 0.0, 0.0))
	_try_axis_move(Vector3(0.0, 0.0, delta_pos.z))
	_sync_height(delta)
	_avatar.grid_pos = grid_manager.world_to_grid_nearest(_avatar.position)


func _try_axis_move(delta_pos: Vector3) -> void:
	if delta_pos.length_squared() < 0.0000001:
		return
	var next := _avatar.position + delta_pos
	var cell := grid_manager.world_to_grid_nearest(next)
	if grid_manager.player_can_stand_at(cell):
		_avatar.position = next
		return
	# Vault fence: hop to the cell beyond if free.
	if grid_manager.player_is_fence(cell):
		var beyond := _vault_landing(cell, delta_pos)
		if beyond.x > -9000 and grid_manager.player_can_stand_at(beyond):
			_start_vault(beyond)
			return
	# Blocked — leave position unchanged on this axis.


func _vault_landing(fence_cell: Vector2i, delta_pos: Vector3) -> Vector2i:
	var step := Vector2i.ZERO
	if absf(delta_pos.x) >= absf(delta_pos.z):
		step.x = 1 if delta_pos.x > 0.0 else -1
	else:
		step.y = 1 if delta_pos.z > 0.0 else -1
	if step == Vector2i.ZERO:
		return Vector2i(-9999, -9999)
	return fence_cell + step


func _start_vault(landing: Vector2i) -> void:
	if _busy or _avatar == null:
		return
	_busy = true
	_stick_vec = Vector2.ZERO
	var from := _avatar.position
	var to := _world_stand_pos(landing)
	var mid := (from + to) * 0.5
	mid.y = maxf(from.y, to.y) + VAULT_HEIGHT
	var look := to
	look.y = from.y
	if look.distance_squared_to(from) > 0.0001:
		_avatar.look_at(look, Vector3.UP)
	_avatar.grid_pos = landing
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_avatar, "position", mid, VAULT_DURATION * 0.45)
	tw.tween_property(_avatar, "position", to, VAULT_DURATION * 0.55)
	tw.finished.connect(func() -> void:
		_busy = false
		if _avatar and is_instance_valid(_avatar):
			_avatar.position = to
			_avatar.grid_pos = landing
	)


func _sync_height(delta: float) -> void:
	if _avatar == null or not is_instance_valid(_avatar):
		return
	if _sitting:
		return
	var cell := grid_manager.world_to_grid_nearest(_avatar.position)
	var target_y := grid_manager.player_surface_height(cell)
	# Small hop onto / off bench when height changes a lot.
	var dy := target_y - _avatar.position.y
	if absf(dy) > 0.28 and not _busy and _move_input().length() >= JOYSTICK_DEADZONE:
		_busy = true
		var to := _avatar.position
		to.y = target_y
		var mid := _avatar.position.lerp(to, 0.5)
		mid.y = maxf(_avatar.position.y, target_y) + 0.35
		var tw := create_tween()
		tw.tween_property(_avatar, "position", mid, 0.12)
		tw.tween_property(_avatar, "position", to, 0.14)
		tw.finished.connect(func() -> void:
			_busy = false
		)
		return
	_avatar.position.y = lerpf(_avatar.position.y, target_y, clampf(HEIGHT_LERP * delta, 0.0, 1.0))


func _update_ghost_from_pointer() -> void:
	if grid_manager == null or camera == null:
		return
	var screen := PointerInput.get_position()
	var cell := _raycast_ground_cell(screen)
	if cell.x < -9000:
		return
	if cell != _ghost_cell:
		_set_ghost_cell(cell)


func _raycast_ground_cell(screen_pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-9999, -9999)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-9999, -9999)
	var hit := from + dir * t
	return grid_manager.world_to_grid_nearest(hit)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLACING:
		_handle_placing_input(event)
	elif state == State.WALKING:
		_handle_walking_input(event)


func _handle_placing_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _is_pointer_over_walk_ui(st.position):
				return
			_place_pressing = true
			_place_dragged = false
			_place_press_pos = st.position
			_update_ghost_from_pointer()
			get_viewport().set_input_as_handled()
		else:
			if _place_pressing and not _place_dragged:
				_try_confirm_place()
			_place_pressing = false
			_place_dragged = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _is_pointer_over_walk_ui(mb.position):
				return
			_place_pressing = true
			_place_dragged = false
			_place_press_pos = mb.position
			_update_ghost_from_pointer()
			get_viewport().set_input_as_handled()
		else:
			if _place_pressing and not _place_dragged:
				_try_confirm_place()
			_place_pressing = false
			_place_dragged = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _place_pressing:
		if event.position.distance_to(_place_press_pos) > PLACE_TAP_THRESHOLD:
			_place_dragged = true
		_update_ghost_from_pointer()


func _handle_walking_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			exit_walk()
			get_viewport().set_input_as_handled()
			return
		var hot_i := _hotbar_index_from_key(event.keycode)
		if hot_i >= 0:
			_select_hotbar_slot(hot_i)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			_on_use_pressed()
			get_viewport().set_input_as_handled()
			return
	# Look drag — ignore when over joystick / exit / hotbar.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if _is_pointer_over_walk_ui(st.position):
			_look_dragging = false
			return
		if st.pressed:
			_look_dragging = true
			_look_last = st.position
		else:
			_look_dragging = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and _look_dragging:
		var sd := event as InputEventScreenDrag
		_apply_look_delta(sd.relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _is_pointer_over_walk_ui(mb.position):
				_look_dragging = false
				return
			_look_dragging = mb.pressed
			_look_last = mb.position
			if mb.pressed:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _look_dragging:
		var mm := event as InputEventMouseMotion
		_apply_look_delta(mm.relative)
		get_viewport().set_input_as_handled()


func _hotbar_index_from_key(keycode: int) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		KEY_7, KEY_KP_7:
			return 6
		KEY_8, KEY_KP_8:
			return 7
		_:
			return -1


func _select_hotbar_slot(index: int) -> void:
	if index < 0 or index >= InventoryData.HOTBAR_SIZE:
		return
	if index != _hotbar_selected:
		_reset_walk_fish()
	_hotbar_selected = index
	_apply_held_from_hotbar()
	_refresh_hotbar_selection_style()
	_update_use_button_label()


func _apply_held_from_hotbar() -> void:
	if _avatar == null or not is_instance_valid(_avatar):
		return
	if inventory_manager == null or _hotbar_selected < 0:
		_avatar.set_held_inventory_item(null)
		_update_hotbar_name_label()
		return
	if inventory_manager.is_slot_empty(_hotbar_selected):
		_avatar.set_held_inventory_item(null)
		_update_hotbar_name_label()
		return
	_avatar.set_held_inventory_item(inventory_manager.get_slot_item(_hotbar_selected))
	_update_hotbar_name_label()


func _refresh_hotbar() -> void:
	if _hotbar_icons.is_empty():
		return
	for i in range(InventoryData.HOTBAR_SIZE):
		var icon: TextureRect = _hotbar_icons[i]
		var count_lbl: Label = _hotbar_counts[i]
		var btn: Button = _hotbar_btns[i]
		if inventory_manager == null or inventory_manager.is_slot_empty(i):
			icon.texture = null
			count_lbl.text = ""
			btn.tooltip_text = "Hotbar %d (empty)" % (i + 1)
			continue
		var item = inventory_manager.get_slot_item(i)
		var count: int = inventory_manager.get_slot_count(i)
		icon.texture = InventoryData.get_icon(item)
		count_lbl.text = "∞" if InventoryData.is_infinite(item) else str(count)
		btn.tooltip_text = "%s  [%d]" % [InventoryData.get_item_name(item), i + 1]
	_apply_held_from_hotbar()
	_refresh_hotbar_selection_style()
	_update_use_button_label()
	_update_hotbar_name_label()


func _on_use_pressed() -> void:
	if state != State.WALKING or _busy:
		return
	if _avatar == null or not is_instance_valid(_avatar):
		return
	if _avatar.is_swinging():
		return
	if _sitting:
		_stand_up(true)
		return
	var item = _avatar.get_held_inventory_item()
	if item == null:
		if _aimed_animal() != null:
			_avatar.play_use_swing(Callable(self, "_try_pet"))
			return
		var bench := _aimed_bench()
		if bench != null:
			_sit_on_bench(bench)
			return
		_avatar.play_use_swing(Callable(self, "_try_pet"))
		return
	# Fishing reel / cast uses the same Use button without always swinging twice.
	if item == InventoryData.Item.TOOL_ROD and _fish_phase == 2:
		_avatar.play_use_swing(Callable(self, "_reel_walk_fish"))
		return
	if InventoryData.is_fertilizer(item):
		var ground := Vector3.ZERO
		var plant := _aimed_plant()
		if plant and is_instance_valid(plant):
			ground = plant.global_position
			if grid_manager:
				ground.y = grid_manager.player_surface_height(
					grid_manager.world_to_grid_nearest(plant.global_position)
				)
		_avatar.play_compost_sprinkle(Callable(self, "_use_fertilizer").bind(item), ground)
		return
	_avatar.play_use_swing(Callable(self, "_apply_use_impact").bind(item))


func _apply_use_impact(item: InventoryData.Item) -> void:
	match item:
		InventoryData.Item.TOOL_HOE:
			_use_hoe()
		InventoryData.Item.TOOL_HARVEST:
			_use_harvest()
		InventoryData.Item.TOOL_ROD:
			_use_rod()
		_:
			if InventoryData.is_feedable(item):
				_use_feed(item)
			elif InventoryData.is_fertilizer(item):
				_use_fertilizer(item)
			elif _aimed_animal() != null:
				_try_pet()
			else:
				status_message.emit(LocaleManager.t("Waved %s") % InventoryData.get_item_name(item))


func _aimed_animal() -> Node3D:
	var soft := _soft_aim_interactable()
	if soft and ItemData.is_animal(soft.get_meta("item_type")):
		return soft
	for cell in _use_target_cells():
		var animal := grid_manager.get_animal_at(cell)
		if animal:
			return animal
	return null


func _aimed_bench() -> Node3D:
	## Prefer facing / view cell, then the tile the player is already standing on.
	for cell in _use_target_cells():
		var obj := grid_manager.get_content_at(cell)
		if obj and obj.has_meta("item_type") and obj.get_meta("item_type") == ItemData.ItemType.BENCH:
			return obj
	return null


func _sit_on_bench(bench: Node3D) -> void:
	if _avatar == null or bench == null or not is_instance_valid(bench):
		return
	if not bench.has_meta("grid_pos"):
		return
	var anchor: Vector2i = bench.get_meta("grid_pos")
	var footprint := grid_manager.get_object_footprint(bench)
	var rotation := grid_manager.get_object_rotation(bench)
	var seat := grid_manager.footprint_center_world(anchor, footprint, rotation)
	seat.y = grid_manager.player_surface_height(anchor)
	_sitting = true
	_sit_bench = bench
	_avatar.position = seat
	_avatar.grid_pos = grid_manager.world_to_grid_nearest(seat)
	_avatar.set_sitting(true)
	status_message.emit(LocaleManager.t("Resting on the bench"))
	_update_use_button_label()


func _stand_up(announce: bool = true) -> void:
	if not _sitting:
		return
	_sitting = false
	_sit_bench = null
	if _avatar and is_instance_valid(_avatar):
		_avatar.set_sitting(false)
		var cell := grid_manager.world_to_grid_nearest(_avatar.position)
		_avatar.position.y = grid_manager.player_surface_height(cell)
		_avatar.grid_pos = cell
	if announce:
		status_message.emit(LocaleManager.t("Stood up"))
	_update_use_button_label()


func _aimed_plant() -> Node3D:
	var soft := _soft_aim_interactable()
	if soft and ItemData.is_growable_plant(soft.get_meta("item_type")):
		return soft
	for cell in _use_target_cells():
		var obj := grid_manager.get_content_at(cell)
		if obj and ItemData.is_growable_plant(obj.get_meta("item_type")):
			return obj
	return null


func _try_pet() -> void:
	var animal := _aimed_animal()
	if animal == null:
		status_message.emit(LocaleManager.t("Look at / face an animal to pet"))
		return
	var result := AnimalInteraction.try_pet(animal)
	status_message.emit(str(result.get("message", "")))
	if result.get("ok", false):
		var ctrl := animal.get_node_or_null("AnimalController") as AnimalController
		if ctrl:
			var from := _avatar.global_position if _avatar else Vector3.ZERO
			ctrl.play_pet_react(from)


func _use_fertilizer(item: InventoryData.Item) -> bool:
	if inventory_manager == null or not inventory_manager.has_item(item):
		status_message.emit(LocaleManager.t("No %s left") % InventoryData.get_item_name(item))
		return false
	var plant := _aimed_plant()
	if plant == null:
		status_message.emit(LocaleManager.t("Aim at a growing plant to fertilize"))
		return false
	var growth := plant.get_node_or_null("CropGrowth") as CropGrowth
	if growth == null:
		status_message.emit(LocaleManager.t("Can't fertilize that"))
		return false
	var result := growth.try_fertilize()
	status_message.emit(str(result.get("message", "")))
	if result.get("ok", false):
		inventory_manager.remove_item(item, 1)
		AudioManager.play("hoe")
		return true
	return false


func _update_feed_attract() -> void:
	if grid_manager == null or _avatar == null or not is_instance_valid(_avatar):
		return
	var item = _avatar.get_held_inventory_item()
	if item != null and InventoryData.is_feedable(item):
		grid_manager.set_feed_attract(true, _avatar.global_position, item)
	else:
		grid_manager.set_feed_attract(false)


func _update_aim_cards() -> void:
	## Soft-lock nearest animal or plant near the reticle; sticky so cards don't flicker.
	var target := _soft_aim_interactable()
	var animal: Node3D = null
	var plant: Node3D = null
	if target:
		var item_type: ItemData.ItemType = target.get_meta("item_type")
		if ItemData.is_animal(item_type):
			animal = target
		elif ItemData.is_growable_plant(item_type):
			plant = target
	if animal_info_card:
		if animal:
			animal_info_card.show_animal(animal)
		else:
			animal_info_card.clear()
	if plant_info_card:
		if plant:
			plant_info_card.show_plant(plant)
		else:
			plant_info_card.clear()
	_update_rename_button(animal)
	_update_collect_button(animal)


func _soft_aim_interactable() -> Node3D:
	## Prefer animals slightly over plants when scores are close.
	if camera == null or grid_manager == null or _avatar == null:
		return null
	var vp := camera.get_viewport()
	if vp == null:
		return null
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	var best: Node3D = null
	var best_score := INF
	var origin := _avatar.grid_pos
	for dx in range(-AIM_CELL_RADIUS, AIM_CELL_RADIUS + 1):
		for dy in range(-AIM_CELL_RADIUS, AIM_CELL_RADIUS + 1):
			var cell := Vector2i(origin.x + dx, origin.y + dy)
			if not grid_manager.is_in_bounds(cell):
				continue
			var obj := grid_manager.get_content_at(cell)
			if obj == null or not is_instance_valid(obj):
				continue
			var item_type: ItemData.ItemType = obj.get_meta("item_type")
			var is_animal := ItemData.is_animal(item_type)
			var is_plant := ItemData.is_growable_plant(item_type)
			if not is_animal and not is_plant:
				continue
			if camera.is_position_behind(obj.global_position):
				continue
			var screen: Vector2 = camera.unproject_position(obj.global_position + Vector3(0, 0.6, 0))
			var screen_dist := screen.distance_to(center)
			if screen_dist > AIM_SCREEN_RADIUS:
				continue
			var world_dist := _avatar.global_position.distance_to(obj.global_position)
			var score := screen_dist + world_dist * 14.0
			if is_plant:
				score += 10.0  # prefer animals when tied
			if obj == _soft_aim_target:
				score -= AIM_STICKY_BONUS
			if score < best_score:
				best_score = score
				best = obj
	if best == null:
		best = _raycast_view_animal()
	_soft_aim_target = best
	return best


func _raycast_view_animal() -> Node3D:
	if camera == null or grid_manager == null or _avatar == null:
		return null
	var vp := camera.get_viewport()
	if vp == null:
		return null
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(center)
	var to := from + camera.project_ray_normal(center) * 40.0
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var node: Node = result.collider as Node
	while node != null and is_instance_valid(node):
		if node is Node3D and node.has_meta("item_type") and ItemData.is_animal(node.get_meta("item_type")):
			return node as Node3D
		node = node.get_parent()
	return null


func _facing_cell() -> Vector2i:
	if _avatar == null:
		return Vector2i.ZERO
	var yaw := _avatar.rotation.y
	var fx := -sin(yaw)
	var fz := -cos(yaw)
	var step := Vector2i.ZERO
	if absf(fx) >= absf(fz):
		step.x = 1 if fx > 0.0 else -1
	else:
		step.y = 1 if fz > 0.0 else -1
	return _avatar.grid_pos + step


func _raycast_view_cell() -> Vector2i:
	## Camera look ray → ground cell, clamped near the avatar.
	if camera == null or _avatar == null or grid_manager == null:
		return _facing_cell()
	var vp := camera.get_viewport()
	if vp == null:
		return _facing_cell()
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(center)
	var dir := camera.project_ray_normal(center)
	if absf(dir.y) < 0.001:
		return _facing_cell()
	var ground_y := grid_manager.player_surface_height(_avatar.grid_pos)
	var t := (ground_y - from.y) / dir.y
	if t < 0.2 or t > 40.0:
		return _facing_cell()
	var hit := from + dir * t
	var cell := grid_manager.world_to_grid_nearest(hit)
	if not grid_manager.is_in_bounds(cell):
		return _facing_cell()
	var dx := absi(cell.x - _avatar.grid_pos.x)
	var dy := absi(cell.y - _avatar.grid_pos.y)
	if maxi(dx, dy) > 4:
		return _facing_cell()
	return cell


func _resolve_use_cell() -> Vector2i:
	## Prefer view-ray cell when it is a useful target; else face-forward cell.
	var view_cell := _raycast_view_cell()
	var face_cell := _facing_cell()
	var item = null
	if _avatar:
		item = _avatar.get_held_inventory_item()
	if item != null and _cell_is_useful_for(item, view_cell):
		return view_cell
	if item != null and _cell_is_useful_for(item, face_cell):
		return face_cell
	if _avatar and view_cell != _avatar.grid_pos:
		return view_cell
	return face_cell


func _cell_is_useful_for(item: InventoryData.Item, cell: Vector2i) -> bool:
	if grid_manager == null or not grid_manager.is_in_bounds(cell):
		return false
	match item:
		InventoryData.Item.TOOL_HOE:
			return grid_manager.can_hoe_at(cell)
		InventoryData.Item.TOOL_HARVEST:
			return grid_manager.is_plant_mature(cell)
		InventoryData.Item.TOOL_ROD:
			return grid_manager.try_fish(cell)
		_:
			if InventoryData.is_feedable(item):
				return grid_manager.get_animal_at(cell) != null
			if InventoryData.is_fertilizer(item):
				var obj := grid_manager.get_content_at(cell)
				if obj == null:
					return false
				var growth := obj.get_node_or_null("CropGrowth") as CropGrowth
				return growth != null and not growth.is_mature() and not growth.is_fertilized()
	return false


func _use_target_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _avatar == null:
		return cells
	var primary := _resolve_use_cell()
	cells.append(primary)
	var face := _facing_cell()
	if face != primary:
		cells.append(face)
	if _avatar.grid_pos != primary and _avatar.grid_pos != face:
		cells.append(_avatar.grid_pos)
	return cells


func _use_hoe() -> void:
	var cell := _resolve_use_cell()
	if grid_manager.hoe_grass(cell):
		AudioManager.play("hoe")
		status_message.emit(LocaleManager.t("Tilled dirt"))
	else:
		status_message.emit(LocaleManager.t("Can't hoe here"))


func _use_harvest() -> void:
	for cell in _use_target_cells():
		if not grid_manager.is_plant_mature(cell):
			continue
		var plant := grid_manager.get_content_at(cell)
		var plant_type = null
		if plant:
			plant_type = plant.get_meta("item_type")
			HarvestEffect.play(plant)
		AudioManager.play("harvest")
		var harvest_item = grid_manager.harvest_plant(cell)
		if harvest_item != null and inventory_manager:
			inventory_manager.add_item(harvest_item)
			# Occasional compost from non-tree crops fuels the fertilize loop.
			if (
				plant_type != null
				and plant_type != ItemData.ItemType.TREE
				and randf() < COMPOST_DROP_CHANCE
			):
				inventory_manager.add_item(InventoryData.Item.COMPOST, 1)
				status_message.emit(
					LocaleManager.tf("Harvested %s! (+compost)", [
						InventoryData.get_item_name(harvest_item),
					])
				)
			else:
				status_message.emit(
					LocaleManager.t("Harvested %s!") % InventoryData.get_item_name(harvest_item)
				)
			return
	status_message.emit(LocaleManager.t("Nothing ready to harvest"))


func _use_rod() -> void:
	if _fish_phase == 1:
		status_message.emit(LocaleManager.t("Wait for a bite…"))
		return
	var cell := _resolve_use_cell()
	if not grid_manager.try_fish(cell):
		status_message.emit(LocaleManager.t("Need water or a pond ahead"))
		return
	_fish_phase = 1
	_fish_cell = cell
	_fish_water_pos = grid_manager.grid_to_world(cell) + Vector3(0.0, 0.06, 0.0)
	_fish_wait_left = randf_range(1.2, 2.4)
	AudioManager.play("fishing_drop")
	if _avatar:
		_avatar.set_fishing_line_target(_fish_water_pos, false)
	status_message.emit(LocaleManager.t("Line cast — wait, then Use again"))
	_update_use_button_label()


func _update_walk_fishing(delta: float) -> void:
	if _fish_phase == 1:
		_fish_wait_left -= delta
		if _avatar:
			_avatar.set_fishing_line_target(_fish_water_pos, false)
		if _fish_wait_left > 0.0:
			return
		_fish_phase = 2
		AudioManager.play("ui_click")
		if _avatar:
			_avatar.set_fishing_line_target(_fish_water_pos, true)
		status_message.emit(LocaleManager.t("Bite! Press Use to reel in"))
		_update_use_button_label()
	elif _fish_phase == 2:
		if _avatar:
			_avatar.set_fishing_line_target(_fish_water_pos, true)


func _reel_walk_fish() -> void:
	if _fish_phase != 2:
		return
	if inventory_manager:
		inventory_manager.add_item(InventoryData.Item.FISH)
	AudioManager.play("fish_catch")
	if grid_manager:
		FishCatchEffect.play(grid_manager.objects_container, _fish_water_pos)
	_reset_walk_fish()
	status_message.emit(LocaleManager.t("Caught a fish!"))


func _reset_walk_fish() -> void:
	_fish_phase = 0
	_fish_cell = Vector2i(-9999, -9999)
	_fish_wait_left = 0.0
	_fish_water_pos = Vector3.ZERO
	if _avatar and is_instance_valid(_avatar):
		_avatar.clear_fishing_line()
	_update_use_button_label()


func _use_feed(item: InventoryData.Item) -> void:
	for cell in _use_target_cells():
		var animal := grid_manager.get_animal_at(cell)
		if animal == null:
			continue
		var result := AnimalInteraction.try_feed(animal, item, inventory_manager)
		status_message.emit(str(result.get("message", "")))
		if result.get("ok", false):
			_apply_held_from_hotbar()
		return
	status_message.emit(LocaleManager.t("Look at / face an animal to feed"))


func _update_use_button_label() -> void:
	if _use_btn == null:
		return
	if _sitting:
		_use_btn.text = LocaleManager.t("Stand")
		return
	if _fish_phase == 2:
		_use_btn.text = LocaleManager.t("Reel")
		return
	if _fish_phase == 1:
		_use_btn.text = LocaleManager.t("Wait…")
		return
	var item = null
	if _avatar:
		item = _avatar.get_held_inventory_item()
	if item == null:
		if _aimed_animal() != null:
			_use_btn.text = LocaleManager.t("Pet")
		elif _aimed_bench() != null:
			_use_btn.text = LocaleManager.t("Rest")
		else:
			_use_btn.text = LocaleManager.t("Use")
	elif InventoryData.is_fertilizer(item):
		_use_btn.text = LocaleManager.t("Fertilize")
	else:
		_use_btn.text = LocaleManager.t("Use")


func _update_hotbar_name_label() -> void:
	if _hotbar_name_lbl == null:
		return
	if inventory_manager == null or _hotbar_selected < 0 or inventory_manager.is_slot_empty(_hotbar_selected):
		_hotbar_name_lbl.text = ""
		return
	var item = inventory_manager.get_slot_item(_hotbar_selected)
	_hotbar_name_lbl.text = InventoryData.get_item_name(item)


func _ensure_use_highlight() -> void:
	if _use_highlight and is_instance_valid(_use_highlight):
		return
	_use_highlight = MeshInstance3D.new()
	_use_highlight.name = "WalkUseHighlight"
	var box := BoxMesh.new()
	box.size = Vector3(GridManager.TILE_WIDTH * 0.92, 0.06, GridManager.TILE_HEIGHT * 0.92)
	_use_highlight.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.25, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_use_highlight.material_override = mat
	if grid_manager and grid_manager.objects_container:
		grid_manager.objects_container.add_child(_use_highlight)
	else:
		add_child(_use_highlight)


func _clear_use_highlight() -> void:
	if _use_highlight and is_instance_valid(_use_highlight):
		_use_highlight.queue_free()
	_use_highlight = null


func _update_use_highlight() -> void:
	if state != State.WALKING or _avatar == null or not is_instance_valid(_avatar):
		if _use_highlight:
			_use_highlight.visible = false
		return
	var item = _avatar.get_held_inventory_item()
	if item == null:
		if _use_highlight:
			_use_highlight.visible = false
		return
	_ensure_use_highlight()
	var cell := _resolve_use_cell()
	var useful := _cell_is_useful_for(item, cell)
	var world := grid_manager.grid_to_world(cell)
	world.y = grid_manager.player_surface_height(cell) + 0.08
	_use_highlight.global_position = world
	_use_highlight.visible = true
	var mat := _use_highlight.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(1.0, 0.88, 0.25, 0.42) if useful else Color(1.0, 0.88, 0.25, 0.18)


func _refresh_hotbar_selection_style() -> void:
	for i in range(_hotbar_btns.size()):
		var btn: Button = _hotbar_btns[i]
		var selected := i == _hotbar_selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.4, 0.42, 0.98) if selected else Color(0.14, 0.22, 0.26, 0.92)
		style.set_corner_radius_all(10)
		style.set_border_width_all(3 if selected else 2)
		style.border_color = Color(0.95, 0.85, 0.35, 1.0) if selected else Color(0.45, 0.7, 0.78, 0.65)
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = style.bg_color.lightened(0.08)
		btn.add_theme_stylebox_override("hover", hover)


func _apply_look_delta(relative: Vector2) -> void:
	_look_yaw -= relative.x * LOOK_SENSITIVITY
	_look_pitch += relative.y * LOOK_SENSITIVITY
	_look_pitch = clampf(_look_pitch, LOOK_PITCH_MIN, LOOK_PITCH_MAX)
	_apply_follow_camera(false)


func _apply_follow_camera(force_projection: bool) -> void:
	if camera == null or _avatar == null or not is_instance_valid(_avatar):
		return
	if force_projection or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 55.0
		camera.near = 0.1
		camera.far = 200.0
	var focus := _avatar.global_position + Vector3(0.0, 1.0, 0.0)
	var cos_p := cos(_look_pitch)
	var offset := Vector3(
		sin(_look_yaw) * cos_p,
		sin(_look_pitch),
		cos(_look_yaw) * cos_p
	) * FOLLOW_DISTANCE
	offset.y += FOLLOW_HEIGHT * 0.15
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)


func _snapshot_build_camera() -> void:
	if camera == null:
		return
	_saved_projection = camera.projection
	_saved_size = camera.size
	_saved_near = camera.near
	_saved_far = camera.far
	_saved_pos = camera.global_position
	_saved_basis = camera.global_transform.basis


func _restore_build_camera() -> void:
	if camera == null:
		return
	camera.projection = _saved_projection
	camera.size = _saved_size
	camera.near = _saved_near
	camera.far = _saved_far
	camera.global_position = _saved_pos
	camera.global_transform.basis = _saved_basis
	if camera_controller:
		camera_controller.refresh_from_camera()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "WalkModeUI"
	_ui_layer.layer = 40
	add_child(_ui_layer)

	_place_hint = Label.new()
	_place_hint.visible = false
	_place_hint.text = LocaleManager.t("Drag figure · tap to enter")
	_place_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_hint.add_theme_font_size_override("font_size", 18)
	_place_hint.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_place_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_place_hint.offset_top = 72.0
	_place_hint.offset_bottom = 110.0
	_place_hint.offset_left = -200.0
	_place_hint.offset_right = 200.0
	_ui_layer.add_child(_place_hint)

	_walk_hud = Control.new()
	_walk_hud.visible = false
	_walk_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_walk_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_walk_hud)

	_exit_btn = _make_hud_button(LocaleManager.t("Exit"), Color(0.75, 0.3, 0.28))
	_exit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Top-left so it never overlaps day/night controls (top-right).
	_exit_btn.offset_left = 28.0
	_exit_btn.offset_top = 56.0
	_exit_btn.offset_right = 140.0
	_exit_btn.offset_bottom = 112.0
	_exit_btn.pressed.connect(exit_walk)
	_walk_hud.add_child(_exit_btn)

	_joystick = Control.new()
	_joystick.name = "MoveJoystick"
	_joystick.custom_minimum_size = Vector2(JOYSTICK_RADIUS * 2.0 + 24.0, JOYSTICK_RADIUS * 2.0 + 24.0)
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.offset_left = 28.0
	_joystick.offset_top = -(JOYSTICK_RADIUS * 2.0 + 72.0)
	_joystick.offset_right = 28.0 + JOYSTICK_RADIUS * 2.0 + 24.0
	_joystick.offset_bottom = -36.0
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick.gui_input.connect(_on_joystick_gui_input)
	_joystick.draw.connect(_on_joystick_draw)
	_walk_hud.add_child(_joystick)

	_hotbar = HBoxContainer.new()
	_hotbar.name = "WalkHotbar"
	_hotbar.add_theme_constant_override("separation", 8)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.offset_left = -292.0
	_hotbar.offset_right = 292.0
	_hotbar.offset_top = -138.0
	_hotbar.offset_bottom = -56.0
	_hotbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_walk_hud.add_child(_hotbar)

	_hotbar_btns.clear()
	_hotbar_icons.clear()
	_hotbar_counts.clear()
	for i in range(InventoryData.HOTBAR_SIZE):
		_hotbar.add_child(_make_hotbar_slot(i))

	_hotbar_name_lbl = Label.new()
	_hotbar_name_lbl.name = "HotbarItemName"
	_hotbar_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_name_lbl.add_theme_font_size_override("font_size", 14)
	_hotbar_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 0.95))
	_hotbar_name_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.85))
	_hotbar_name_lbl.add_theme_constant_override("outline_size", 4)
	_hotbar_name_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_name_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar_name_lbl.offset_left = -180.0
	_hotbar_name_lbl.offset_right = 180.0
	_hotbar_name_lbl.offset_top = -52.0
	_hotbar_name_lbl.offset_bottom = -28.0
	_hotbar_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_name_lbl.text = ""
	_walk_hud.add_child(_hotbar_name_lbl)

	_use_btn = _make_hud_button(LocaleManager.t("Use"), Color(0.35, 0.55, 0.75))
	_use_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# Keep clear of phone Dynamic Island / rounded right edge.
	_use_btn.offset_left = -220.0
	_use_btn.offset_right = -100.0
	_use_btn.offset_top = -36.0
	_use_btn.offset_bottom = 36.0
	_use_btn.pressed.connect(_on_use_pressed)
	_walk_hud.add_child(_use_btn)

	_rename_btn = _make_hud_button(LocaleManager.t("Rename"), Color(0.55, 0.48, 0.32))
	_rename_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_rename_btn.offset_left = -220.0
	_rename_btn.offset_right = -100.0
	_rename_btn.offset_top = 48.0
	_rename_btn.offset_bottom = 108.0
	_rename_btn.visible = false
	_rename_btn.pressed.connect(_on_rename_pressed)
	_walk_hud.add_child(_rename_btn)

	_collect_btn = _make_hud_button(LocaleManager.t("Collect"), Color(0.55, 0.62, 0.4))
	_collect_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_collect_btn.offset_left = -220.0
	_collect_btn.offset_right = -100.0
	_collect_btn.offset_top = 120.0
	_collect_btn.offset_bottom = 180.0
	_collect_btn.visible = false
	_collect_btn.pressed.connect(_on_collect_pressed)
	_walk_hud.add_child(_collect_btn)

	_build_rename_dialog()


func _build_rename_dialog() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = LocaleManager.t("Rename animal")
	_rename_dialog.ok_button_text = LocaleManager.t("Save")
	_rename_dialog.cancel_button_text = LocaleManager.t("Cancel")
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.exclusive = true
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	_rename_dialog.close_requested.connect(func() -> void:
		_rename_dialog.hide()
		_rename_target = null
	)
	_rename_dialog.canceled.connect(func() -> void:
		_rename_target = null
	)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.custom_minimum_size = Vector2(280, 0)

	var hint := Label.new()
	hint.text = LocaleManager.t("Enter a name (leave blank to reset)")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	body.add_child(hint)

	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = LocaleManager.t("Animal name")
	_rename_edit.max_length = 20
	_rename_edit.clear_button_enabled = true
	_rename_edit.virtual_keyboard_enabled = true
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.text_submitted.connect(func(_t: String) -> void:
		_on_rename_confirmed()
	)
	body.add_child(_rename_edit)

	_rename_dialog.add_child(body)
	# Keep dialog above walk HUD.
	_ui_layer.add_child(_rename_dialog)


func _update_rename_button(animal: Node3D) -> void:
	if _rename_btn == null:
		return
	_rename_btn.visible = animal != null and is_instance_valid(animal)


func _update_collect_button(animal: Node3D) -> void:
	if _collect_btn == null:
		return
	# Empty-hand only so Collect never replaces Pet on Use.
	var hands_empty := _avatar != null and _avatar.get_held_inventory_item() == null
	var life := AnimalInteraction.get_life(animal) if animal else null
	var ready := hands_empty and life != null and life.can_collect_produce()
	_collect_btn.visible = ready
	if ready:
		_collect_btn.text = life.get_collect_button_label()


func _on_collect_pressed() -> void:
	if state != State.WALKING or _busy:
		return
	if _avatar and _avatar.get_held_inventory_item() != null:
		status_message.emit(LocaleManager.t("Empty hands to collect"))
		return
	var animal := _aimed_animal()
	if animal == null:
		status_message.emit(LocaleManager.t("Look at / face an animal to collect"))
		return
	var result := AnimalInteraction.try_collect_produce(animal, inventory_manager)
	status_message.emit(str(result.get("message", "")))
	_update_collect_button(animal)
	if animal_info_card and result.get("ok", false):
		animal_info_card.show_animal(animal)


func _on_rename_pressed() -> void:
	var animal := _aimed_animal()
	if animal == null:
		status_message.emit(LocaleManager.t("Aim at an animal to rename"))
		return
	_rename_target = animal
	_rename_dialog.title = LocaleManager.tf("Rename %s", [AnimalInteraction.get_display_name(animal)])
	var current := ""
	if animal.has_meta("custom_name"):
		current = str(animal.get_meta("custom_name"))
	_rename_edit.text = current
	_rename_dialog.popup_centered(Vector2(340, 160))
	_rename_edit.grab_focus()
	_rename_edit.caret_column = _rename_edit.text.length()
	# Mobile / tablet: force virtual keyboard.
	_rename_edit.edit()


func _on_rename_confirmed() -> void:
	if _rename_dialog == null:
		return
	if _rename_target == null or not is_instance_valid(_rename_target):
		_rename_dialog.hide()
		_rename_target = null
		return
	var result := AnimalInteraction.set_custom_name(_rename_target, _rename_edit.text)
	status_message.emit(str(result.get("message", "")))
	if result.get("ok", false):
		_rename_dialog.hide()
		# Refresh card name immediately if still aimed.
		if animal_info_card and animal_info_card.visible:
			animal_info_card.show_animal(_rename_target)
		_rename_target = null
	else:
		# Keep dialog open on failure.
		_rename_edit.grab_focus()


func _make_hotbar_slot(index: int) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(68, 72)
	btn.tooltip_text = "Hotbar %d" % (index + 1)
	btn.pressed.connect(_select_hotbar_slot.bind(index))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.22, 0.26, 0.92)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.7, 0.78, 0.65)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.3, 0.34, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.4, 0.42, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(root)

	var key := Label.new()
	key.text = str(index + 1)
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", Color(0.75, 0.9, 0.95))
	key.set_anchors_preset(Control.PRESET_TOP_LEFT)
	key.offset_left = 5
	key.offset_top = 2
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 14
	icon.offset_right = -12
	icon.offset_bottom = -18
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_hotbar_icons.append(icon)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -6
	count.offset_bottom = -4
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(count)
	_hotbar_counts.append(count)

	_hotbar_btns.append(btn)
	return btn


func _on_joystick_gui_input(event: InputEvent) -> void:
	if state != State.WALKING:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_stick_active = true
			_stick_pointer_id = st.index
			_update_stick_from_local(st.position)
			_joystick.accept_event()
		elif st.index == _stick_pointer_id:
			_stick_active = false
			_stick_pointer_id = -1
			_stick_vec = Vector2.ZERO
			_joystick.queue_redraw()
			_joystick.accept_event()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _stick_active and sd.index == _stick_pointer_id:
			_update_stick_from_local(sd.position)
			_joystick.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_stick_active = true
			_stick_pointer_id = -1
			_update_stick_from_local(mb.position)
			_joystick.accept_event()
		else:
			_stick_active = false
			_stick_vec = Vector2.ZERO
			_joystick.queue_redraw()
			_joystick.accept_event()
		return
	if event is InputEventMouseMotion and _stick_active and _stick_pointer_id < 0:
		_update_stick_from_local(event.position)
		_joystick.accept_event()


func _update_stick_from_local(local_pos: Vector2) -> void:
	var center := _joystick.size * 0.5
	var offset := local_pos - center
	var max_r := JOYSTICK_RADIUS
	if offset.length() > max_r:
		offset = offset.normalized() * max_r
	# UI y+ is down; invert so up on stick = forward (negative move.y).
	_stick_vec = Vector2(offset.x / max_r, offset.y / max_r)
	_joystick.queue_redraw()


func _on_joystick_draw() -> void:
	if _joystick == null:
		return
	var center := _joystick.size * 0.5
	var base_r := JOYSTICK_RADIUS
	_joystick.draw_circle(center, base_r + 6.0, Color(0.1, 0.12, 0.1, 0.45))
	_joystick.draw_arc(center, base_r, 0.0, TAU, 48, Color(0.85, 0.9, 0.75, 0.55), 3.0, true)
	var knob_offset := Vector2(_stick_vec.x, _stick_vec.y) * base_r
	_joystick.draw_circle(center + knob_offset, 28.0, Color(0.35, 0.7, 0.45, 0.92))
	_joystick.draw_arc(center + knob_offset, 28.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0, true)


func _make_hud_button(text: String, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(100, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _show_place_hint() -> void:
	if _place_hint:
		_place_hint.visible = true


func _hide_place_hint() -> void:
	if _place_hint:
		_place_hint.visible = false


func _show_walk_hud() -> void:
	if _walk_hud:
		_walk_hud.visible = true
	if _joystick:
		_stick_vec = Vector2.ZERO
		_joystick.queue_redraw()
	if _hotbar_selected < 0:
		_hotbar_selected = 0
	if _rename_btn:
		_rename_btn.visible = false
	if _collect_btn:
		_collect_btn.visible = false
	_reset_walk_fish()
	_refresh_hotbar()


func _hide_walk_hud() -> void:
	if _walk_hud:
		_walk_hud.visible = false
	_stick_active = false
	_stick_vec = Vector2.ZERO
	_hotbar_selected = -1
	if _rename_btn:
		_rename_btn.visible = false
	if _collect_btn:
		_collect_btn.visible = false
	if _rename_dialog and _rename_dialog.visible:
		_rename_dialog.hide()
	_rename_target = null
	_reset_walk_fish()


func _is_pointer_over_walk_ui(screen_pos: Vector2) -> bool:
	if _walk_hud and _walk_hud.visible:
		if _exit_btn and _exit_btn.get_global_rect().has_point(screen_pos):
			return true
		if _joystick and _joystick.get_global_rect().has_point(screen_pos):
			return true
		if _hotbar and _hotbar.get_global_rect().has_point(screen_pos):
			return true
		if _use_btn and _use_btn.get_global_rect().has_point(screen_pos):
			return true
		if _rename_btn and _rename_btn.visible and _rename_btn.get_global_rect().has_point(screen_pos):
			return true
		if _collect_btn and _collect_btn.visible and _collect_btn.get_global_rect().has_point(screen_pos):
			return true
	return false


func _hide_build_ui() -> void:
	_build_ui_hidden.clear()
	_day_night_kept = null
	var ui := get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene else null
	if ui == null:
		return
	for child in ui.get_children():
		# Keep backpack available so hotbar tools can be rearranged mid-walk.
		if child is InventoryBar:
			continue
		# Keep sun / moon on the walk UI layer so taps aren't blocked.
		if child is TimeOfDayControls:
			_day_night_kept = child as CanvasItem
			if _ui_layer:
				child.reparent(_ui_layer)
			continue
		if child is CanvasItem and (child as CanvasItem).visible:
			_build_ui_hidden.append(child as CanvasItem)
			(child as CanvasItem).visible = false


func _restore_build_ui() -> void:
	for item in _build_ui_hidden:
		if item != null and is_instance_valid(item):
			item.visible = true
	_build_ui_hidden.clear()
	if _day_night_kept != null and is_instance_valid(_day_night_kept):
		var ui := get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene else null
		if ui:
			_day_night_kept.reparent(ui)
	_day_night_kept = null
