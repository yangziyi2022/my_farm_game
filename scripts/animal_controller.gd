class_name AnimalController
extends Node

## Idle / wander / species quirks for farm animals.
## Root stays grid-anchored in meta; can step into neighboring free cells.

enum State { IDLE, WALKING, SPECIAL, SEEK_PLAYER }
enum Species { GENERIC, CHICKEN, SHEEP, PIG, RABBIT, DUCK, COW, BUTTERFLY }

const WATER_SEEK_RADIUS: int = 3
const FOOD_SEEK_RADIUS: int = 5
const FLOWER_SEEK_RADIUS: int = 5
const FOOD_SEEK_CHECK_INTERVAL: float = 0.45
const PET_BOB_DURATION: float = 0.55
const PET_BOB_HEIGHT: float = 0.11
const BUTTERFLY_HOVER_Y: float = 0.72

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

var personality: AnimalLife.Personality = AnimalLife.Personality.FRIENDLY
var _base_walk_speed: float = 0.35
var _base_idle_min: float = 2.0
var _base_idle_max: float = 5.0
var _base_walk_chance: float = 0.5
var _food_seek_radius: int = FOOD_SEEK_RADIUS

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
var _seek_check_timer: float = 0.0
var _pet_bob_t: float = 0.0
var _wing_l: Node3D
var _wing_r: Node3D
var _flutter_t: float = 0.0


func setup(pivot: Node3D, root: Node3D = null, grid: GridManager = null) -> void:
	_pivot = pivot
	_root = root if root else (pivot.get_parent() as Node3D)
	_grid = grid
	_facing_angle = randf_range(0.0, TAU)
	_target_angle = _facing_angle
	_base_pivot_y = 0.0
	_base_walk_speed = walk_speed
	_base_idle_min = idle_time_min
	_base_idle_max = idle_time_max
	_base_walk_chance = walk_chance
	_food_seek_radius = FOOD_SEEK_RADIUS
	if _pivot:
		_head = _pivot.find_child("Head", true, false) as Node3D
		if _head:
			_head_base_rot_x = _head.rotation.x
		_wing_l = _pivot.find_child("WingL", true, false) as Node3D
		_wing_r = _pivot.find_child("WingR", true, false) as Node3D
		if _wing_l == null and _root:
			_wing_l = _root.find_child("WingL", true, false) as Node3D
		if _wing_r == null and _root:
			_wing_r = _root.find_child("WingR", true, false) as Node3D
		_cache_gait_nodes()
		_sync_yaw()


func apply_personality(p: AnimalLife.Personality) -> void:
	personality = p
	walk_speed = _base_walk_speed
	idle_time_min = _base_idle_min
	idle_time_max = _base_idle_max
	walk_chance = _base_walk_chance
	_food_seek_radius = FOOD_SEEK_RADIUS
	match personality:
		AnimalLife.Personality.FRIENDLY:
			walk_chance = minf(0.85, _base_walk_chance + 0.15)
			_food_seek_radius = FOOD_SEEK_RADIUS + 1
		AnimalLife.Personality.SHY:
			walk_chance = maxf(0.35, _base_walk_chance - 0.1)
			idle_time_min = _base_idle_min + 0.4
			idle_time_max = _base_idle_max + 1.2
		AnimalLife.Personality.GLUTTONOUS:
			walk_speed = _base_walk_speed * 1.35
			walk_chance = minf(0.92, _base_walk_chance + 0.25)
			_food_seek_radius = FOOD_SEEK_RADIUS + 2
		AnimalLife.Personality.SLEEPY:
			walk_chance = maxf(0.22, _base_walk_chance - 0.28)
			idle_time_min = _base_idle_min + 1.5
			idle_time_max = _base_idle_max + 3.5
			special_chance = maxf(0.05, special_chance * 0.5)


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

	_seek_check_timer -= delta
	if _seek_check_timer <= 0.0:
		_seek_check_timer = FOOD_SEEK_CHECK_INTERVAL
		_try_begin_seek_player()

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
		State.SEEK_PLAYER:
			_update_seek_player(delta)

	_update_pet_bob(delta)
	_update_butterfly_flight(delta)
	_sync_yaw()


func _sync_yaw() -> void:
	if _pivot:
		_pivot.rotation.y = _facing_angle


func _is_on_water() -> bool:
	if _grid == null or _root == null:
		return false
	return _grid.is_swimmable_cell(_root.get_meta("grid_pos"))


func _ground_pivot_y() -> float:
	if species == Species.BUTTERFLY:
		return BUTTERFLY_HOVER_Y + sin(_flutter_t * 5.5) * 0.06
	return _swim_pivot_y if (species == Species.DUCK and _is_on_water()) else _base_pivot_y


func _update_butterfly_flight(delta: float) -> void:
	if species != Species.BUTTERFLY:
		return
	_flutter_t += delta
	# Flap around body hinges (Z): outer tips rise / fall; slight rest dihedral.
	var flap := sin(_flutter_t * 18.0) * 0.7
	var dihedral := 0.22
	if _wing_l:
		_wing_l.rotation = Vector3(0.0, 0.0, dihedral + flap)
	if _wing_r:
		_wing_r.rotation = Vector3(0.0, 0.0, -(dihedral + flap))
	# Keep hovering even while idle.
	if _pet_bob_t <= 0.0 and _pivot and _state != State.WALKING:
		_pivot.position.y = lerpf(_pivot.position.y, _ground_pivot_y(), minf(1.0, delta * 8.0))


func play_pet_react(from_world: Vector3 = Vector3.ZERO) -> void:
	_pet_bob_t = PET_BOB_DURATION
	if from_world != Vector3.ZERO and _root != null and is_instance_valid(_root):
		var to := from_world - _root.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			_target_angle = atan2(to.x, to.z)
	_spawn_pet_hearts()


func _update_pet_bob(delta: float) -> void:
	if _pivot == null:
		return
	if _pet_bob_t <= 0.0:
		return
	_pet_bob_t = maxf(0.0, _pet_bob_t - delta)
	if _pet_bob_t <= 0.0:
		_pivot.position.y = _ground_pivot_y()
		if _gait_visual:
			_gait_visual.rotation.z = 0.0
		return
	var t := 1.0 - (_pet_bob_t / PET_BOB_DURATION)
	# Double bob + slight lean = readable “happy” reaction.
	var bob := sin(t * TAU) * PET_BOB_HEIGHT * (1.0 - t * 0.35)
	_pivot.position.y = _ground_pivot_y() + bob
	if _gait_visual:
		_gait_visual.rotation.z = sin(t * PI) * 0.12


func _spawn_pet_hearts() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var anchor := Node3D.new()
	anchor.name = "PetHearts"
	anchor.position = Vector3(0.0, 0.95, 0.0)
	_root.add_child(anchor)
	for i in range(4):
		var heart := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.07
		heart.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.95, 0.35, 0.48, 0.95)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		heart.material_override = mat
		var ang := deg_to_rad(-25.0 + i * 18.0)
		heart.position = Vector3(sin(ang) * 0.12, 0.05 * i, cos(ang) * 0.08)
		anchor.add_child(heart)
		var tween := heart.create_tween()
		var rise := Vector3(heart.position.x * 1.4, 0.55 + i * 0.08, heart.position.z)
		tween.set_parallel(true)
		tween.tween_property(heart, "position", rise, 0.7 + i * 0.05) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.7 + i * 0.05) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var clear := anchor.create_tween()
	clear.tween_interval(1.0)
	clear.tween_callback(anchor.queue_free)


func _needs_node() -> AnimalNeeds:
	if _root == null:
		return null
	return _root.get_node_or_null("AnimalNeeds") as AnimalNeeds


func _try_begin_seek_player() -> void:
	if _grid == null or _root == null:
		return
	if _state == State.WALKING or _state == State.SPECIAL:
		return
	# Shy animals back away from a nearby player until affinity is high.
	if personality == AnimalLife.Personality.SHY and _try_shy_retreat():
		return
	var attract: Dictionary = _grid.get_feed_attract()
	if not attract.get("active", false):
		if _state == State.SEEK_PLAYER:
			_enter_idle()
		return
	var needs := _needs_node()
	if needs == null:
		if _state == State.SEEK_PLAYER:
			_enter_idle()
		return
	var hungry_ok := needs.is_hungry()
	if personality == AnimalLife.Personality.FRIENDLY:
		hungry_ok = needs.satiety < 65.0
	elif personality == AnimalLife.Personality.GLUTTONOUS:
		hungry_ok = needs.satiety < 75.0
	elif personality == AnimalLife.Personality.SHY:
		hungry_ok = needs.is_hungry() and needs.affinity >= 40.0
	elif personality == AnimalLife.Personality.SLEEPY:
		hungry_ok = needs.satiety < AnimalNeeds.VERY_HUNGRY_THRESHOLD
	if not hungry_ok:
		if _state == State.SEEK_PLAYER:
			_enter_idle()
		return
	var animal_type: ItemData.ItemType = _root.get_meta("item_type")
	var food: InventoryData.Item = attract["item"]
	if not AnimalDiet.can_eat(animal_type, food):
		if _state == State.SEEK_PLAYER:
			_enter_idle()
		return
	var from: Vector2i = _root.get_meta("grid_pos")
	var target: Vector2i = attract["grid"]
	var dist := maxi(absi(target.x - from.x), absi(target.y - from.y))
	if dist > _food_seek_radius:
		if _state == State.SEEK_PLAYER:
			_enter_idle()
		return
	# Look at the player even when adjacent.
	var player_pos: Vector3 = attract["pos"]
	var delta_xz := player_pos - _root.global_position
	_target_angle = atan2(delta_xz.x, delta_xz.z)
	_state = State.SEEK_PLAYER
	_timer = 0.0


func _try_shy_retreat() -> bool:
	var attract: Dictionary = _grid.get_feed_attract() if _grid else {"active": false}
	# Without a nearby player attract, no retreat.
	if not attract.get("active", false):
		return false
	var needs := _needs_node()
	if needs == null or needs.affinity >= 50.0:
		return false
	var from: Vector2i = _root.get_meta("grid_pos")
	var target: Vector2i = attract["grid"]
	var dist := maxi(absi(target.x - from.x), absi(target.y - from.y))
	if dist > 2 or dist == 0:
		return false
	# Step away from the player.
	var away := from - target
	var step := Vector2i(signi(away.x), 0) if absi(away.x) >= absi(away.y) else Vector2i(0, signi(away.y))
	if step == Vector2i.ZERO:
		return false
	return _begin_cross_tile_step(from + step)


func _update_seek_player(delta: float) -> void:
	_apply_idle_pose(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.55
	var attract: Dictionary = _grid.get_feed_attract() if _grid else {"active": false}
	if not attract.get("active", false):
		_enter_idle()
		return
	var needs := _needs_node()
	if needs == null:
		_enter_idle()
		return
	var from: Vector2i = _root.get_meta("grid_pos")
	var target: Vector2i = attract["grid"]
	var dist := maxi(absi(target.x - from.x), absi(target.y - from.y))
	if dist <= 1:
		# Adjacent: keep facing player.
		var player_pos: Vector3 = attract["pos"]
		var delta_xz := player_pos - _root.global_position
		_target_angle = atan2(delta_xz.x, delta_xz.z)
		return
	if dist > _food_seek_radius:
		_enter_idle()
		return
	var step := _best_step_toward(from, target)
	if step == Vector2i.ZERO:
		return
	_begin_cross_tile_step(from + step)


func _pick_next_action() -> void:
	if _state == State.SEEK_PLAYER:
		return
	if personality == AnimalLife.Personality.SLEEPY and randf() < 0.45 and _try_sleepy_nap_spot():
		return
	if randf() < look_around_chance and _state == State.IDLE:
		_target_angle = randf_range(0.0, TAU)
	# Occasional ambient voice — spatial volume handled by AudioManager.
	if randf() < 0.12:
		_try_ambient_voice()

	var roll := randf()
	if roll < special_chance and _try_start_special():
		# Only some quirk actions get a voice so farms stay calm.
		if randf() < 0.32:
			_try_ambient_voice()
		return
	if randf() < walk_chance:
		if species == Species.DUCK and _try_duck_water_step():
			return
		if species == Species.BUTTERFLY and _try_butterfly_flower_step():
			return
		if randf() < cross_tile_chance and _try_start_cross_tile_walk():
			return
		_start_local_walk()
	else:
		_reset_idle_timer()


func _try_sleepy_nap_spot() -> bool:
	## Prefer lingering near a tree or bench when sleepy.
	if _grid == null or _root == null:
		return false
	var from: Vector2i = _root.get_meta("grid_pos")
	for dist in range(0, 3):
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if maxi(absi(dx), absi(dy)) != dist:
					continue
				var cell := from + Vector2i(dx, dy)
				var obj := _grid.get_content_at(cell)
				if obj == null or not obj.has_meta("item_type"):
					continue
				var t: ItemData.ItemType = obj.get_meta("item_type")
				if t != ItemData.ItemType.TREE and t != ItemData.ItemType.BENCH:
					continue
				if dist == 0:
					_timer = randf_range(idle_time_min + 1.0, idle_time_max + 2.0)
					_state = State.IDLE
					return true
				var step := _best_step_toward(from, cell)
				if step != Vector2i.ZERO and _begin_cross_tile_step(from + step):
					return true
	_timer = randf_range(idle_time_min + 0.8, idle_time_max + 1.5)
	_state = State.IDLE
	return true


func _try_ambient_voice() -> void:
	var pos := Vector3.INF
	if _root and is_instance_valid(_root):
		pos = _root.global_position
	AudioManager.play_animal_for_species(int(species), true, pos)


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
		Species.BUTTERFLY:
			return false
		_:
			return false


func _try_butterfly_flower_step() -> bool:
	## Within 5 cells of a flower → step toward it; when near, flutter around it.
	if _grid == null or _root == null:
		return false
	var from: Vector2i = _root.get_meta("grid_pos")
	var flowers := _grid.find_flower_attractants_within(from, FLOWER_SEEK_RADIUS)
	if flowers.is_empty():
		return false
	var target: Vector2i = flowers[0]
	var dist := maxi(absi(target.x - from.x), absi(target.y - from.y))
	if dist <= 1:
		# Already beside a bloom — local flutter, sometimes hop to another adjacent cell.
		if randf() < 0.55:
			return _try_step_near_cell(target)
		_start_local_walk()
		return true
	var step := _best_step_toward(from, target)
	if step == Vector2i.ZERO:
		return false
	return _begin_cross_tile_step(from + step)


func _try_step_near_cell(anchor: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	dirs.shuffle()
	for dir in dirs:
		var to: Vector2i = anchor + dir
		if maxi(absi(to.x - anchor.x), absi(to.y - anchor.y)) > 1:
			continue
		if _begin_cross_tile_step(to):
			return true
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
		if not _grid.is_swimmable_cell(to):
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
