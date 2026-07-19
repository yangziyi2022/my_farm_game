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

var grid_manager: GridManager
var camera: Camera3D
var camera_controller: CameraController
var placement_controller: PlacementController

var state: State = State.OFF
var _avatar: PlayerAvatar
var _ghost_cell: Vector2i = Vector2i(-9999, -9999)
var _busy: bool = false  # vault / hop tween lock

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
var _stick_active: bool = false
var _stick_pointer_id: int = -1  # -1 mouse, >=0 touch index
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
		status_message.emit("Can't stand here — try grass, path, bridge, or bench")
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
	status_message.emit("Exploring — joystick to move · swipe to look · Exit to leave")


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
	if _avatar != null and is_instance_valid(_avatar):
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
		_apply_follow_camera(false)


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
	# Look drag — ignore when over joystick / exit.
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


func _hide_walk_hud() -> void:
	if _walk_hud:
		_walk_hud.visible = false
	_stick_active = false
	_stick_vec = Vector2.ZERO


func _is_pointer_over_walk_ui(screen_pos: Vector2) -> bool:
	if _walk_hud and _walk_hud.visible:
		if _exit_btn and _exit_btn.get_global_rect().has_point(screen_pos):
			return true
		if _joystick and _joystick.get_global_rect().has_point(screen_pos):
			return true
	return false


func _hide_build_ui() -> void:
	_build_ui_hidden.clear()
	var ui := get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene else null
	if ui == null:
		return
	for child in ui.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			_build_ui_hidden.append(child as CanvasItem)
			(child as CanvasItem).visible = false


func _restore_build_ui() -> void:
	for item in _build_ui_hidden:
		if item != null and is_instance_valid(item):
			item.visible = true
	_build_ui_hidden.clear()
