class_name CameraController
extends Node

## Orbit + pan + zoom around the island center.
## Desktop:
## - Right mouse drag: orbit
## - Middle mouse drag: pan
## - Wheel: zoom
## - WASD / arrows: pan
## Touch (PointerInput):
## - One-finger drag (when gameplay isn't capturing): orbit yaw + pitch
## - Two-finger drag: pan
## - Two-finger pinch: zoom
## - Two-finger twist: orbit yaw

@export var camera: Camera3D

const PAN_MOUSE_SPEED: float = 0.045
const PAN_TOUCH_SPEED: float = 0.055
const PAN_KEY_SPEED: float = 14.0
const ORBIT_SENSITIVITY: float = 0.0055
const ORBIT_TOUCH_SENSITIVITY: float = 0.0045
const ORBIT_TOUCH_DRAG_THRESHOLD: float = 12.0
const PINCH_ZOOM_SENSITIVITY: float = 0.045
const ZOOM_STEP: float = 2.0
const ZOOM_MIN: float = 8.0
const ZOOM_MAX: float = 90.0
const PITCH_MIN: float = deg_to_rad(6.0)
const PITCH_MAX: float = deg_to_rad(78.0)
const DISTANCE_MIN: float = 16.0
const DISTANCE_MAX: float = 140.0

var _focus: Vector3 = Vector3(0.0, 0.0, 25.0)
var _pan_offset: Vector3 = Vector3.ZERO
var _yaw: float = deg_to_rad(45.0)
var _pitch: float = deg_to_rad(42.0)
var _distance: float = 32.0
var _zoom: float = 16.0
var _panning: bool = false
var _orbiting: bool = false

var _pinch_active: bool = false
var _pinch_last_dist: float = 0.0
var _pinch_last_angle: float = 0.0
var _pinch_last_center: Vector2 = Vector2.ZERO

## One-finger orbit (scheme B): start after drag threshold on free gesture.
var _touch_orbit_tracking: bool = false
var _touch_orbit_active: bool = false
var _touch_orbit_start: Vector2 = Vector2.ZERO
var _touch_orbit_last: Vector2 = Vector2.ZERO


func setup(p_camera: Camera3D, focus: Vector3 = Vector3(0.0, 0.0, 25.0)) -> void:
	camera = p_camera
	_focus = focus
	_zoom = camera.size
	var to_cam := camera.global_position - _focus
	if to_cam.length() > 0.1:
		_distance = clampf(to_cam.length(), DISTANCE_MIN, DISTANCE_MAX)
		_yaw = atan2(to_cam.x, to_cam.z)
		_pitch = asin(clampf(to_cam.y / maxf(_distance, 0.001), -1.0, 1.0))
		_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	# --- Touch camera ---
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch_camera(event)
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = event.pressed
				if _orbiting:
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				if _panning:
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_by(-ZOOM_STEP)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_by(ZOOM_STEP)
					get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * ORBIT_SENSITIVITY
			_pitch += event.relative.y * ORBIT_SENSITIVITY
			_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif _panning:
			_pan_by_screen_delta(event.relative, PAN_MOUSE_SPEED)
			get_viewport().set_input_as_handled()


func _handle_touch_camera(event: InputEvent) -> void:
	var count := PointerInput.touch_count()

	# Two fingers: pan / pinch / twist — cancel one-finger orbit.
	if count >= 2:
		_reset_touch_orbit()
		_handle_two_finger_camera()
		get_viewport().set_input_as_handled()
		return

	_pinch_active = false

	# One finger: orbit yaw + pitch when gameplay isn't capturing the gesture.
	if count == 1:
		if PointerInput.gameplay_captures_primary:
			_reset_touch_orbit()
			return
		_handle_one_finger_orbit(event)
		return

	_reset_touch_orbit()


func _handle_one_finger_orbit(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_orbit_tracking = true
			_touch_orbit_active = false
			_touch_orbit_start = st.position
			_touch_orbit_last = st.position
		else:
			_reset_touch_orbit()
		return

	if event is InputEventScreenDrag and _touch_orbit_tracking:
		if PointerInput.gameplay_captures_primary:
			_reset_touch_orbit()
			return

		var sd := event as InputEventScreenDrag
		if not _touch_orbit_active:
			if sd.position.distance_to(_touch_orbit_start) < ORBIT_TOUCH_DRAG_THRESHOLD:
				_touch_orbit_last = sd.position
				return
			_touch_orbit_active = true

		var relative := sd.position - _touch_orbit_last
		_touch_orbit_last = sd.position
		_yaw -= relative.x * ORBIT_TOUCH_SENSITIVITY
		_pitch += relative.y * ORBIT_TOUCH_SENSITIVITY
		_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
		_apply_transform()
		get_viewport().set_input_as_handled()


func _handle_two_finger_camera() -> void:
	var info: Dictionary = PointerInput.pinch_info()
	if not info.get("valid", false):
		_pinch_active = false
		return

	var center: Vector2 = info["center"]
	var dist: float = info["distance"]
	var angle: float = info["angle"]

	if not _pinch_active:
		_pinch_active = true
		_pinch_last_dist = dist
		_pinch_last_angle = angle
		_pinch_last_center = center
		return

	# Pinch zoom
	var dist_delta := dist - _pinch_last_dist
	if absf(dist_delta) > 0.5:
		_zoom_by(-dist_delta * PINCH_ZOOM_SENSITIVITY)

	# Two-finger pan (midpoint movement)
	var center_delta := center - _pinch_last_center
	if center_delta.length() > 0.5:
		_pan_by_screen_delta(center_delta, PAN_TOUCH_SPEED)

	# Twist → orbit yaw (sign flipped to match finger twist direction)
	var angle_delta := angle_difference(_pinch_last_angle, angle)
	if absf(angle_delta) > 0.001:
		_yaw += angle_delta * (ORBIT_TOUCH_SENSITIVITY / ORBIT_SENSITIVITY) * 0.35
		_apply_transform()

	_pinch_last_dist = dist
	_pinch_last_angle = angle
	_pinch_last_center = center


func _reset_touch_orbit() -> void:
	_touch_orbit_tracking = false
	_touch_orbit_active = false


func _zoom_by(amount: float) -> void:
	_zoom = clampf(_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	_distance = clampf(_distance + amount * 0.8, DISTANCE_MIN, DISTANCE_MAX)
	_apply_transform()


func _process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	if input_dir != Vector2.ZERO:
		_pan_by_screen_delta(input_dir * PAN_KEY_SPEED * delta * 60.0, PAN_MOUSE_SPEED)


func _pan_by_screen_delta(screen_delta: Vector2, speed: float = PAN_MOUSE_SPEED) -> void:
	if camera == null:
		return
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	_pan_offset += (-right * screen_delta.x + forward * screen_delta.y) * speed
	_apply_transform()


func _apply_transform() -> void:
	if camera == null:
		return
	var focus := _focus + _pan_offset
	var cos_p := cos(_pitch)
	var offset := Vector3(
		sin(_yaw) * cos_p,
		sin(_pitch),
		cos(_yaw) * cos_p
	) * _distance
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
	camera.size = _zoom
