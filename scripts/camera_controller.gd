class_name CameraController
extends Node

## Orbit + pan + zoom around the island center.
## - Right mouse drag: rotate 3D view around the island
## - Middle mouse drag: pan
## - Wheel: zoom
## - WASD / arrows: pan

@export var camera: Camera3D

const PAN_MOUSE_SPEED: float = 0.045
const PAN_KEY_SPEED: float = 14.0
const ORBIT_SENSITIVITY: float = 0.0055
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


func setup(p_camera: Camera3D, focus: Vector3 = Vector3(0.0, 0.0, 25.0)) -> void:
	camera = p_camera
	_focus = focus
	_zoom = camera.size
	# Seed orbit from the camera's current pose if possible.
	var to_cam := camera.global_position - _focus
	if to_cam.length() > 0.1:
		_distance = clampf(to_cam.length(), DISTANCE_MIN, DISTANCE_MAX)
		_yaw = atan2(to_cam.x, to_cam.z)
		_pitch = asin(clampf(to_cam.y / maxf(_distance, 0.001), -1.0, 1.0))
		_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
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
					_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
					_distance = clampf(_distance - ZOOM_STEP * 0.8, DISTANCE_MIN, DISTANCE_MAX)
					_apply_transform()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
					_distance = clampf(_distance + ZOOM_STEP * 0.8, DISTANCE_MIN, DISTANCE_MAX)
					_apply_transform()
					get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * ORBIT_SENSITIVITY
			_pitch += event.relative.y * ORBIT_SENSITIVITY
			_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif _panning:
			_pan_by_screen_delta(event.relative)
			get_viewport().set_input_as_handled()


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
		_pan_by_screen_delta(input_dir * PAN_KEY_SPEED * delta * 60.0)


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
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

	_pan_offset += (-right * screen_delta.x + forward * screen_delta.y) * PAN_MOUSE_SPEED
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
