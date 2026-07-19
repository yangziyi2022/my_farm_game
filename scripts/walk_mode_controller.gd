class_name WalkModeController
extends Node

## Build ↔ Walk explore mode.
## 1) Place a yellow ghost avatar on a free cell
## 2) Drop in → third-person follow + on-screen move pad

signal status_message(text: String)
signal walk_started
signal walk_ended

enum State { OFF, PLACING, WALKING }

const LOOK_SENSITIVITY: float = 0.0042
const LOOK_PITCH_MIN: float = deg_to_rad(8.0)
const LOOK_PITCH_MAX: float = deg_to_rad(55.0)
const FOLLOW_DISTANCE: float = 5.5
const FOLLOW_HEIGHT: float = 2.4
const STEP_DURATION: float = 0.18
const GHOST_HOVER_Y: float = 0.55

var grid_manager: GridManager
var camera: Camera3D
var camera_controller: CameraController
var placement_controller: PlacementController

var state: State = State.OFF
var _avatar: PlayerAvatar
var _ghost_cell: Vector2i = Vector2i(-9999, -9999)
var _stepping: bool = false

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
const PLACE_TAP_THRESHOLD: float = 14.0

## UI
var _ui_layer: CanvasLayer
var _place_hint: Label
var _walk_hud: Control
var _exit_btn: Button
var _pad: HBoxContainer
var _build_ui_hidden: Array[CanvasItem] = []


func setup(
	p_grid: GridManager,
	p_camera: Camera3D,
	p_cam_ctrl: CameraController,
	p_placement: PlacementController
) -> void:
	grid_manager = p_grid
	camera = p_camera
	camera_controller = p_cam_ctrl
	placement_controller = p_placement
	_build_ui()


func is_active() -> bool:
	return state != State.OFF


func begin_place_avatar() -> void:
	if state == State.WALKING:
		return
	if state == State.PLACING:
		# Second press on the Walk button while placing: try drop under ghost.
		_try_confirm_place()
		return
	_enter_placing()


func exit_walk() -> void:
	if state == State.OFF:
		return
	_teardown_avatar()
	_hide_walk_hud()
	_hide_place_hint()
	_restore_build_camera()
	_restore_build_ui()
	if camera_controller:
		camera_controller.set_build_orbit_enabled(true)
	if placement_controller:
		placement_controller.set_walk_mode_blocked(false)
	state = State.OFF
	walk_ended.emit()
	status_message.emit("Back to build view")


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
	status_message.emit("Walk — drag yellow figure · tap again to drop in")


func _try_confirm_place() -> void:
	if state != State.PLACING:
		return
	if not grid_manager.player_can_stand_at(_ghost_cell):
		status_message.emit("Can't stand here — try grass or a path")
		return
	_start_walking(_ghost_cell)


func _start_walking(cell: Vector2i) -> void:
	state = State.WALKING
	_ensure_avatar()
	_avatar.set_ghost_look(false)
	_avatar.grid_pos = cell
	_avatar.position = grid_manager.grid_to_world(cell)
	_avatar.set_facing_yaw(_look_yaw)
	_hide_place_hint()
	_hide_build_ui()
	_show_walk_hud()
	_snapshot_build_camera()
	if camera_controller:
		camera_controller.set_build_orbit_enabled(false)
	# Start look roughly matching previous build camera angle.
	if camera:
		var focus := _avatar.global_position + Vector3(0.0, 1.0, 0.0)
		var to_cam := camera.global_position - focus
		if to_cam.length_squared() > 0.01:
			_look_yaw = atan2(to_cam.x, to_cam.z)
			_look_pitch = asin(clampf(to_cam.y / to_cam.length(), -1.0, 1.0))
			_look_pitch = clampf(_look_pitch, LOOK_PITCH_MIN, LOOK_PITCH_MAX)
	_apply_follow_camera(true)
	walk_started.emit()
	status_message.emit("Exploring — swipe to look · pad to move · Exit to leave")


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
	if _avatar != null and is_instance_valid(_avatar):
		_avatar.queue_free()
	_avatar = null
	_ghost_cell = Vector2i(-9999, -9999)


func _set_ghost_cell(cell: Vector2i) -> void:
	_ghost_cell = cell
	if _avatar == null or not is_instance_valid(_avatar):
		return
	var world := grid_manager.grid_to_world(cell)
	var valid := grid_manager.player_can_stand_at(cell)
	_avatar.position = world + Vector3(0.0, GHOST_HOVER_Y, 0.0)
	if valid:
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


func _process(_delta: float) -> void:
	if state == State.PLACING:
		if PointerInput.primary_down:
			PointerInput.gameplay_captures_primary = true
			_update_ghost_from_pointer()
			if _place_pressing and PointerInput.get_position().distance_to(_place_press_pos) > PLACE_TAP_THRESHOLD:
				_place_dragged = true
		_update_ghost_from_pointer()
	elif state == State.WALKING:
		PointerInput.gameplay_captures_primary = _look_dragging
		_apply_follow_camera(false)


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
	## Drag moves the ghost; a short tap (or Walk button again) drops in.
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
		match event.keycode:
			KEY_ESCAPE:
				exit_walk()
				get_viewport().set_input_as_handled()
				return
			KEY_W, KEY_UP:
				_step(Vector2(0, -1))
				get_viewport().set_input_as_handled()
				return
			KEY_S, KEY_DOWN:
				_step(Vector2(0, 1))
				get_viewport().set_input_as_handled()
				return
			KEY_A, KEY_LEFT:
				_step(Vector2(-1, 0))
				get_viewport().set_input_as_handled()
				return
			KEY_D, KEY_RIGHT:
				_step(Vector2(1, 0))
				get_viewport().set_input_as_handled()
				return
	# Swipe / drag to look (one finger or left mouse).
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


func _apply_look_delta(relative: Vector2) -> void:
	_look_yaw -= relative.x * LOOK_SENSITIVITY
	_look_pitch += relative.y * LOOK_SENSITIVITY
	_look_pitch = clampf(_look_pitch, LOOK_PITCH_MIN, LOOK_PITCH_MAX)
	if _avatar and is_instance_valid(_avatar):
		# Keep avatar facing roughly with look yaw when idle.
		pass
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


func _step(dir_cam: Vector2) -> void:
	## dir_cam: y=-1 forward, +1 back, x=-1 left, +1 right (camera-relative).
	if state != State.WALKING or _stepping or _avatar == null:
		return
	var forward := Vector3(-sin(_look_yaw), 0.0, -cos(_look_yaw))
	var right := Vector3(cos(_look_yaw), 0.0, -sin(_look_yaw))
	var wish := (-forward * dir_cam.y + right * dir_cam.x)
	if wish.length_squared() < 0.01:
		return
	wish = wish.normalized()
	# Snap to nearest cardinal grid step.
	var step := Vector2i.ZERO
	if absf(wish.x) >= absf(wish.z):
		step = Vector2i(1 if wish.x > 0.0 else -1, 0)
	else:
		step = Vector2i(0, 1 if wish.z > 0.0 else -1)
	var to: Vector2i = _avatar.grid_pos + step
	if not grid_manager.player_can_stand_at(to):
		status_message.emit("Blocked")
		return
	_stepping = true
	var from_pos := _avatar.position
	var to_pos := grid_manager.grid_to_world(to)
	if to_pos.distance_squared_to(from_pos) > 0.0001:
		var look := to_pos
		look.y = from_pos.y
		_avatar.look_at(look, Vector3.UP)
		_avatar.facing_yaw = _avatar.rotation.y
	_avatar.grid_pos = to
	var tw := create_tween()
	tw.tween_property(_avatar, "position", to_pos, STEP_DURATION).from(from_pos)
	tw.finished.connect(func() -> void:
		_stepping = false
	)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "WalkModeUI"
	_ui_layer.layer = 40
	add_child(_ui_layer)

	_place_hint = Label.new()
	_place_hint.visible = false
	_place_hint.text = "Drag figure · tap to enter"
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

	_exit_btn = _make_hud_button("Exit", Color(0.75, 0.3, 0.28))
	_exit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_exit_btn.offset_left = -140.0
	_exit_btn.offset_top = 56.0
	_exit_btn.offset_right = -28.0
	_exit_btn.offset_bottom = 112.0
	_exit_btn.pressed.connect(exit_walk)
	_walk_hud.add_child(_exit_btn)

	_pad = HBoxContainer.new()
	_pad.add_theme_constant_override("separation", 10)
	_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pad.offset_left = 24.0
	_pad.offset_top = -200.0
	_pad.offset_right = 320.0
	_pad.offset_bottom = -48.0
	_walk_hud.add_child(_pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_pad.add_child(col)

	var forward := _make_hud_button("▲", Color(0.3, 0.55, 0.4))
	forward.custom_minimum_size = Vector2(72, 64)
	forward.pressed.connect(func() -> void: _step(Vector2(0, -1)))
	col.add_child(forward)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	col.add_child(mid)
	var left := _make_hud_button("◀", Color(0.3, 0.5, 0.55))
	left.custom_minimum_size = Vector2(72, 64)
	left.pressed.connect(func() -> void: _step(Vector2(-1, 0)))
	mid.add_child(left)
	var back := _make_hud_button("▼", Color(0.3, 0.55, 0.4))
	back.custom_minimum_size = Vector2(72, 64)
	back.pressed.connect(func() -> void: _step(Vector2(0, 1)))
	mid.add_child(back)
	var right := _make_hud_button("▶", Color(0.3, 0.5, 0.55))
	right.custom_minimum_size = Vector2(72, 64)
	right.pressed.connect(func() -> void: _step(Vector2(1, 0)))
	mid.add_child(right)


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


func _hide_walk_hud() -> void:
	if _walk_hud:
		_walk_hud.visible = false


func _is_pointer_over_walk_ui(screen_pos: Vector2) -> bool:
	if _walk_hud and _walk_hud.visible:
		if _exit_btn and _exit_btn.get_global_rect().has_point(screen_pos):
			return true
		if _pad and _pad.get_global_rect().has_point(screen_pos):
			return true
	return false


func _hide_build_ui() -> void:
	_build_ui_hidden.clear()
	var ui := get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene else null
	if ui == null:
		return
	for child in ui.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			# Keep nothing from build UI; walk HUD is on our own layer.
			_build_ui_hidden.append(child as CanvasItem)
			(child as CanvasItem).visible = false


func _restore_build_ui() -> void:
	for item in _build_ui_hidden:
		if item != null and is_instance_valid(item):
			item.visible = true
	_build_ui_hidden.clear()
