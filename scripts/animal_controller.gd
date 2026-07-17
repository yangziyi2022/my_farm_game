class_name AnimalController
extends Node

## Idle / wander / species quirks for farm animals.
## Root stays grid-anchored in meta; can step into neighboring free cells.

enum State { IDLE, WALKING, SPECIAL }
enum Species { GENERIC, CHICKEN, SHEEP, PIG, RABBIT, DUCK, COW }

const WATER_SEEK_RADIUS: int = 3

@export var walk_speed: float = 0.35
@export var wander_radius: float = 0.22
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 5.0
@export var walk_chance: float = 0.5
@export var cross_tile_chance: float = 0.55
@export var special_chance: float = 0.4
@export var look_around_chance: float = 0.35
@export var turn_speed: float = 5.0
@export var hop_height: float = 0.12
@export var species: Species = Species.GENERIC

var _root: Node3D
var _pivot: Node3D
var _head: Node3D
var _grid: GridManager
var _state: State = State.IDLE
var _timer: float = 0.0
var _target_offset: Vector3 = Vector3.ZERO
var _walk_from: Vector3 = Vector3.ZERO
var _walk_to: Vector3 = Vector3.ZERO
var _walk_progress: float = 0.0
var _cross_tile: bool = false
var _facing_angle: float = 0.0
var _target_angle: float = 0.0
var _special_phase: float = 0.0
var _special_duration: float = 1.0
var _peck_count: int = 0
var _mud_restore: Dictionary = {}
var _mud_cell: Vector2i = Vector2i.ZERO
var _base_pivot_y: float = 0.0
var _swim_pivot_y: float = -0.04
var _head_base_rot_x: float = 0.0
var _swim_time: float = 0.0
var _gait_visual: Node3D
var _legs: Array[Node3D] = []
var _walk_phase: float = 0.0


func setup(pivot: Node3D, root: Node3D = null, grid: GridManager = null) -> void:
	_pivot = pivot
	_root = root if root else (pivot.get_parent() as Node3D)
	_grid = grid
	_facing_angle = randf_range(0.0, TAU)
	_target_angle = _facing_angle
	_base_pivot_y = 0.0
	if _pivot:
		_head = _pivot.find_child("Head", true, false) as Node3D
		if _head:
			_head_base_rot_x = _head.rotation.x
		_cache_gait_nodes()
		_sync_yaw()


func _cache_gait_nodes() -> void:
	_gait_visual = null
	_legs.clear()
	if _pivot == null or not is_instance_valid(_pivot):
		return
	var visual := _pivot.get_node_or_null("Visual")
	if visual != null and is_instance_valid(visual) and visual is Node3D:
		_gait_visual = visual as Node3D
	for node in _pivot.find_children("*", "Node3D", true, false):
		if not is_instance_valid(node):
			continue
		if str(node.name).begins_with("Leg"):
			_legs.append(node as Node3D)


func _ready() -> void:
	if _pivot == null:
		_pivot = get_parent() as Node3D
	if _pivot:
		_reset_idle_timer()


func _exit_tree() -> void:
	_restore_mud_if_needed()


func _process(delta: float) -> void:
	if _pivot == null or not is_instance_valid(_pivot):
		return
	if _root == null or not is_instance_valid(_root):
		return

	_facing_angle = lerp_angle(_facing_angle, _target_angle, turn_speed * delta)
	_swim_time += delta

	match _state:
		State.IDLE:
			_timer -= delta
			_apply_idle_pose(delta)
			if _timer <= 0.0:
				_pick_next_action()
		State.WALKING:
			_update_walk(delta)
		State.SPECIAL:
			_update_special(delta)

	_sync_yaw()


func _sync_yaw() -> void:
	if _pivot:
		_pivot.rotation.y = _facing_angle


func _is_on_water() -> bool:
	if _grid == null or _root == null:
		return false
	return _grid.is_water_cell(_root.get_meta("grid_pos"))


func _ground_pivot_y() -> float:
	return _swim_pivot_y if (species == Species.DUCK and _is_on_water()) else _base_pivot_y


func _pick_next_action() -> void:
	if randf() < look_around_chance and _state == State.IDLE:
		_target_angle = randf_range(0.0, TAU)

	var roll := randf()
	if roll < special_chance and _try_start_special():
		return
	if randf() < walk_chance:
		if species == Species.DUCK and _try_duck_water_step():
			return
		if randf() < cross_tile_chance and _try_start_cross_tile_walk():
			return
		_start_local_walk()
	else:
		_reset_idle_timer()


func _try_start_special() -> bool:
	match species:
		Species.CHICKEN:
			_start_peck()
			return true
		Species.SHEEP:
			_start_graze()
			return true
		Species.PIG:
			return _start_mud_roll()
		Species.DUCK:
			if _is_on_water():
				_start_swim_glide()
				return true
			return false
		Species.RABBIT:
			return false
		_:
			return false


func _try_duck_water_step() -> bool:
	## Prefer stepping onto nearby water (within 3), or sliding between water tiles.
	if _grid == null or _root == null:
		return false
	var from: Vector2i = _root.get_meta("grid_pos")
	if _is_on_water():
		return _try_step_to_adjacent_water(from)
	return _try_step_toward_water(from, WATER_SEEK_RADIUS)


func _try_step_toward_water(from: Vector2i, radius: int) -> bool:
	var waters := _grid.find_water_within(from, radius)
	if waters.is_empty():
		return false
	var target: Vector2i = waters[0]
	var step := _best_step_toward(from, target)
	if step == Vector2i.ZERO:
		return false
	return _begin_cross_tile_step(from + step)


func _try_step_to_adjacent_water(from: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	dirs.shuffle()
	for dir in dirs:
		var to: Vector2i = from + dir
		if not _grid.is_water_cell(to):
			continue
		if _begin_cross_tile_step(to):
			return true
	return false


func _best_step_toward(from: Vector2i, target: Vector2i) -> Vector2i:
	var sx := mini(1, maxi(-1, target.x - from.x))
	var sy := mini(1, maxi(-1, target.y - from.y))
	var candidates: Array[Vector2i] = []
	# Prefer axis-aligned first so ducks don't try diagonal around fence corners.
	if sx != 0:
		candidates.append(Vector2i(sx, 0))
	if sy != 0:
		candidates.append(Vector2i(0, sy))
	for delta in candidates:
		var to: Vector2i = from + delta
		if _grid.animal_can_step_to(_root, to):
			return delta
	return Vector2i.ZERO


func _start_local_walk() -> void:
	_cross_tile = false
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(0.08, wander_radius)
	_target_offset = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	_target_offset = _target_offset.clamp(
		Vector3(-wander_radius, 0.0, -wander_radius),
		Vector3(wander_radius, 0.0, wander_radius)
	)
	_walk_from = _pivot.position
	_walk_to = _target_offset
	_walk_progress = 0.0
	_target_angle = atan2(_walk_to.x - _walk_from.x, _walk_to.z - _walk_from.z)
	_state = State.WALKING


func _try_start_cross_tile_walk() -> bool:
	if _grid == null or _root == null:
		return false
	var from: Vector2i = _root.get_meta("grid_pos")
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	dirs.shuffle()
	for dir in dirs:
		if _begin_cross_tile_step(from + dir):
			return true
	return false


func _begin_cross_tile_step(to: Vector2i) -> bool:
	if not _grid.animal_can_step_to(_root, to):
		return false
	if not _grid.move_animal_to(_root, to):
		return false
	_cross_tile = true
	_pivot.position = Vector3(0.0, _ground_pivot_y(), 0.0)
	_walk_from = _root.position
	_walk_to = _grid.grid_to_world(to)
	_walk_progress = 0.0
	var delta_xz := _walk_to - _walk_from
	_target_angle = atan2(delta_xz.x, delta_xz.z)
	_state = State.WALKING
	return true


func _update_walk(delta: float) -> void:
	var dist := _walk_from.distance_to(_walk_to)
	var step := walk_speed * delta
	if species == Species.DUCK and _is_on_water():
		step *= 0.85
	if dist < 0.001:
		_finish_walk()
		return
	_walk_progress = minf(1.0, _walk_progress + step / dist)
	var pos := _walk_from.lerp(_walk_to, _walk_progress)
	var py := _ground_pivot_y()

	if _cross_tile:
		_root.position = Vector3(pos.x, _walk_to.y, pos.z)
		_pivot.position = Vector3.ZERO
	else:
		_pivot.position = Vector3(pos.x, py, pos.z)

	if species == Species.RABBIT:
		var hop := sin(_walk_progress * PI) * hop_height
		_pivot.position.y = py + hop
	elif species == Species.DUCK and _is_on_water():
		# Gentle slide bob while paddling across water.
		_pivot.position.y = py + sin(_swim_time * 3.5) * 0.018
		_pivot.rotation.z = sin(_swim_time * 2.2) * deg_to_rad(6.0)
	elif species == Species.COW:
		_apply_cow_walk_gait(delta)

	if _walk_progress >= 1.0:
		_finish_walk()


func _apply_cow_walk_gait(delta: float) -> void:
	## Single-mesh cow has no skeleton — fake footfalls via body bob + leg pivots if present.
	_walk_phase += delta * 9.0
	var step := sin(_walk_phase)
	var step2 := sin(_walk_phase + PI)  # opposite diagonal
	if _gait_visual != null and is_instance_valid(_gait_visual):
		_gait_visual.position.y = absf(step) * 0.02
		_gait_visual.rotation.z = step * deg_to_rad(3.5)
		_gait_visual.rotation.x = sin(_walk_phase * 0.5) * deg_to_rad(2.0)
	# Procedural / named legs: alternate FL-BR vs FR-BL.
	for i in range(_legs.size()):
		var leg := _legs[i]
		if leg == null or not is_instance_valid(leg):
			continue
		var phase := step if (i % 2 == 0) else step2
		leg.rotation.x = phase * deg_to_rad(24.0)


func _reset_cow_gait() -> void:
	_walk_phase = 0.0
	if _gait_visual != null and is_instance_valid(_gait_visual):
		_gait_visual.position.y = 0.0
		_gait_visual.rotation.x = 0.0
		_gait_visual.rotation.z = 0.0
	for leg in _legs:
		if leg != null and is_instance_valid(leg):
			leg.rotation.x = 0.0


func _finish_walk() -> void:
	if _cross_tile:
		_root.position = _walk_to
		_pivot.position = Vector3(0.0, _ground_pivot_y(), 0.0)
	else:
		_pivot.position = Vector3(_walk_to.x, _ground_pivot_y(), _walk_to.z)
	if species != Species.DUCK:
		_pivot.rotation.z = 0.0
	if species == Species.COW:
		_reset_cow_gait()
	_enter_idle()


func _start_peck() -> void:
	_state = State.SPECIAL
	_special_phase = 0.0
	_special_duration = 1.1
	_peck_count = 3


func _start_graze() -> void:
	_state = State.SPECIAL
	_special_phase = 0.0
	_special_duration = 3.2


func _start_swim_glide() -> void:
	_state = State.SPECIAL
	_special_phase = 0.0
	_special_duration = randf_range(1.6, 2.8)
	_cross_tile = false
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(0.1, wander_radius * 1.2)
	_walk_from = _pivot.position
	_walk_to = Vector3(cos(angle) * distance, _swim_pivot_y, sin(angle) * distance)
	_walk_to = _walk_to.clamp(
		Vector3(-wander_radius, _swim_pivot_y, -wander_radius),
		Vector3(wander_radius, _swim_pivot_y, wander_radius)
	)
	_walk_progress = 0.0
	_target_angle = atan2(_walk_to.x - _walk_from.x, _walk_to.z - _walk_from.z)


func _start_mud_roll() -> bool:
	if _grid == null or _root == null:
		return false
	var cell: Vector2i = _root.get_meta("grid_pos")
	var restore := _grid.begin_animal_mud(cell)
	if restore.is_empty():
		return false
	_mud_restore = restore
	_mud_cell = cell
	_state = State.SPECIAL
	_special_phase = 0.0
	_special_duration = randf_range(2.2, 3.6)
	_pivot.position = Vector3.ZERO
	return true


func _update_special(delta: float) -> void:
	_special_phase += delta
	var t := clampf(_special_phase / _special_duration, 0.0, 1.0)

	match species:
		Species.CHICKEN:
			_animate_peck(t)
		Species.SHEEP:
			_animate_graze(t)
		Species.PIG:
			_animate_mud_roll(t)
		Species.DUCK:
			_animate_swim_glide(t, delta)
		_:
			pass

	if _special_phase >= _special_duration:
		_end_special()


func _animate_peck(t: float) -> void:
	var local := fmod(t * float(_peck_count), 1.0)
	var dip := sin(local * PI)
	_pivot.rotation.x = dip * deg_to_rad(38.0)
	_pivot.position.y = _base_pivot_y - dip * 0.04


func _animate_graze(t: float) -> void:
	if _head == null:
		_pivot.rotation.x = sin(t * PI) * deg_to_rad(18.0)
		return
	var down: float
	if t < 0.25:
		down = t / 0.25
	elif t < 0.75:
		down = 1.0
	else:
		down = 1.0 - (t - 0.75) / 0.25
	var nibble := sin(t * TAU * 3.0) * 0.08 if t > 0.25 and t < 0.75 else 0.0
	_head.rotation.x = _head_base_rot_x + deg_to_rad(42.0) * down + nibble


func _animate_mud_roll(t: float) -> void:
	## Gentle left-right rock in the mud (no full spins).
	var rock := sin(t * TAU * 2.2) * deg_to_rad(32.0)
	_pivot.rotation.z = rock
	_pivot.rotation.x = sin(t * TAU * 1.4) * deg_to_rad(10.0)
	_pivot.position.y = _base_pivot_y + absf(sin(t * TAU * 2.2)) * 0.035


func _animate_swim_glide(t: float, _delta: float) -> void:
	var pos := _walk_from.lerp(_walk_to, t)
	_pivot.position = Vector3(pos.x, _swim_pivot_y + sin(_swim_time * 3.8) * 0.02, pos.z)
	_pivot.rotation.z = sin(_swim_time * 2.6) * deg_to_rad(8.0)
	_pivot.rotation.x = sin(_swim_time * 1.8) * deg_to_rad(4.0)


func _end_special() -> void:
	_pivot.rotation.x = 0.0
	_pivot.rotation.z = 0.0
	_pivot.position.y = _ground_pivot_y()
	if _head:
		_head.rotation.x = _head_base_rot_x
	if species == Species.PIG:
		_restore_mud_if_needed()
	_enter_idle()


func _restore_mud_if_needed() -> void:
	if _mud_restore.is_empty() or _grid == null:
		return
	_grid.end_animal_mud(_mud_cell, _mud_restore)
	_mud_restore = {}


func _apply_idle_pose(delta: float) -> void:
	var py := _ground_pivot_y()
	if species == Species.DUCK and _is_on_water():
		_pivot.position.y = lerpf(_pivot.position.y, py + sin(_swim_time * 2.8) * 0.015, 6.0 * delta)
		_pivot.rotation.z = lerp_angle(_pivot.rotation.z, sin(_swim_time * 1.6) * deg_to_rad(5.0), 4.0 * delta)
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, 0.0, 6.0 * delta)
		return
	_pivot.rotation.x = lerp_angle(_pivot.rotation.x, 0.0, 8.0 * delta)
	_pivot.rotation.z = lerp_angle(_pivot.rotation.z, 0.0, 8.0 * delta)
	if species != Species.RABBIT:
		_pivot.position.y = lerpf(_pivot.position.y, py, 8.0 * delta)
	if _head and species == Species.SHEEP:
		_head.rotation.x = lerp_angle(_head.rotation.x, _head_base_rot_x, 4.0 * delta)
	if species == Species.COW and _gait_visual != null and is_instance_valid(_gait_visual):
		_gait_visual.position.y = lerpf(_gait_visual.position.y, 0.0, 8.0 * delta)
		_gait_visual.rotation.x = lerp_angle(_gait_visual.rotation.x, 0.0, 8.0 * delta)
		_gait_visual.rotation.z = lerp_angle(_gait_visual.rotation.z, 0.0, 8.0 * delta)
		for leg in _legs:
			if leg != null and is_instance_valid(leg):
				leg.rotation.x = lerp_angle(leg.rotation.x, 0.0, 8.0 * delta)


func _enter_idle() -> void:
	_state = State.IDLE
	_cross_tile = false
	_reset_idle_timer()


func _reset_idle_timer() -> void:
	_timer = randf_range(idle_time_min, idle_time_max)
