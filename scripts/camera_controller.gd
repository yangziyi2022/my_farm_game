class_name CameraController
extends Node

@export var camera: Camera3D

const PAN_MOUSE_SPEED: float = 0.04
const PAN_KEY_SPEED: float = 14.0
const ZOOM_STEP: float = 1.5
const ZOOM_MIN: float = 8.0
const ZOOM_MAX: float = 36.0

var _base_position: Vector3 = Vector3.ZERO
var _offset: Vector3 = Vector3.ZERO
var _zoom: float = 16.0
var _panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	_base_position = camera.position
	_zoom = camera.size
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			_pan_start = event.position
			if _panning:
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			_apply_transform()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _panning:
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
	right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	_offset += (-right * screen_delta.x + forward * screen_delta.y) * PAN_MOUSE_SPEED
	_apply_transform()


func _apply_transform() -> void:
	camera.position = _base_position + _offset
	camera.size = _zoom
