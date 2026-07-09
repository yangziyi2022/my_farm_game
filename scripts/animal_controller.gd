class_name AnimalController
extends Node

# Reusable idle wander behavior for farm animals.
# Moves and rotates a visual pivot locally so grid placement stays intact.

enum State { IDLE, WALKING }

@export var walk_speed: float = 0.35
@export var wander_radius: float = 0.28
@export var idle_time_min: float = 2.5
@export var idle_time_max: float = 6.5
@export var walk_chance: float = 0.55
@export var look_around_chance: float = 0.4
@export var turn_speed: float = 5.0

var _pivot: Node3D
var _state: State = State.IDLE
var _timer: float = 0.0
var _target_offset: Vector3 = Vector3.ZERO
var _facing_angle: float = 0.0
var _target_angle: float = 0.0


func setup(pivot: Node3D) -> void:
	_pivot = pivot
	_facing_angle = randf_range(0.0, TAU)
	_target_angle = _facing_angle
	_apply_rotation()


func _ready() -> void:
	if _pivot == null:
		_pivot = get_parent() as Node3D
	if _pivot:
		_reset_idle_timer()


func _process(delta: float) -> void:
	if _pivot == null:
		return

	_facing_angle = lerp_angle(_facing_angle, _target_angle, turn_speed * delta)
	_apply_rotation()

	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_pick_next_action()
		State.WALKING:
			var to_target := _target_offset - _pivot.position
			if to_target.length() < 0.02:
				_pivot.position = _target_offset
				_enter_idle()
			else:
				_target_angle = atan2(to_target.x, to_target.z)
				_pivot.position += to_target.normalized() * walk_speed * delta


func _pick_next_action() -> void:
	if randf() < look_around_chance:
		_target_angle = randf_range(0.0, TAU)

	if randf() < walk_chance:
		_start_walk()
	else:
		_reset_idle_timer()


func _start_walk() -> void:
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(0.12, wander_radius)
	_target_offset = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	_target_offset = _target_offset.clamp(
		Vector3(-wander_radius, 0.0, -wander_radius),
		Vector3(wander_radius, 0.0, wander_radius)
	)
	_target_angle = atan2(_target_offset.x - _pivot.position.x, _target_offset.z - _pivot.position.z)
	_state = State.WALKING


func _enter_idle() -> void:
	_state = State.IDLE
	_reset_idle_timer()


func _reset_idle_timer() -> void:
	_timer = randf_range(idle_time_min, idle_time_max)


func _apply_rotation() -> void:
	if _pivot:
		_pivot.rotation.y = _facing_angle
