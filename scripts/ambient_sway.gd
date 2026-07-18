class_name AmbientSway
extends Node

# Gentle wind sway for plants and foliage. Sways the parent visual pivot.

@export var sway_angle_deg: float = 2.2
@export var sway_speed: float = 1.1
@export var bob_amount: float = 0.012

var _pivot: Node3D
var _phase: float = 0.0
var _speed_mult: float = 1.0
var _angle_mult: float = 1.0
var _base_rotation: Vector3 = Vector3.ZERO
var _base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_pivot = get_parent() as Node3D
	if _pivot == null:
		return
	_phase = randf_range(0.0, TAU)
	_speed_mult = randf_range(0.75, 1.35)
	_angle_mult = randf_range(0.8, 1.2)
	_base_rotation = _pivot.rotation
	_base_position = _pivot.position


func _process(delta: float) -> void:
	# Half-rate on mobile — sway is cosmetic.
	if OS.has_feature("mobile") and (Engine.get_process_frames() % 2) != 0:
		return
	if _pivot == null:
		return

	_phase += delta * sway_speed * _speed_mult
	var sway := sin(_phase) * deg_to_rad(sway_angle_deg) * _angle_mult
	var bob := sin(_phase * 1.7 + 0.6) * bob_amount
	_pivot.rotation = _base_rotation + Vector3(sway * 0.6, 0.0, sway)
	_pivot.position = _base_position + Vector3(0.0, bob, 0.0)
