class_name AnimalNeeds
extends Node

## Persistent needs for a farm animal: satiety, affinity, mood (0–100).

signal needs_changed

const DEFAULT_SATIETY: float = 70.0
const DEFAULT_AFFINITY: float = 20.0
const DEFAULT_MOOD: float = 60.0

const SATIETY_DECAY_PER_SEC: float = 0.35
const PET_AFFINITY_GAIN: float = 6.0
const PET_COOLDOWN_SEC: float = 2.5
const HUNGRY_THRESHOLD: float = 40.0
const VERY_HUNGRY_THRESHOLD: float = 20.0

## Crowding: Chebyshev radius and soft animal-count caps by species.
const CROWD_RADIUS: int = 2
const CROWD_CHECK_INTERVAL: float = 1.25
const ENV_TICK_INTERVAL: float = 0.5

var satiety: float = DEFAULT_SATIETY
var affinity: float = DEFAULT_AFFINITY
var mood: float = DEFAULT_MOOD

var _animal_type: ItemData.ItemType = ItemData.ItemType.COW
var _grid: GridManager
var _root: Node3D
var _pet_cooldown: float = 0.0
var _crowd_timer: float = 0.0
var _env_timer: float = 0.0
var _crowd_pressure: float = 0.0
var _water_comfort: float = 0.0


func setup(root: Node3D, animal_type: ItemData.ItemType, grid_manager: GridManager = null) -> void:
	_root = root
	_animal_type = animal_type
	_grid = grid_manager


func apply_saved(saved_satiety: float, saved_affinity: float, saved_mood: float) -> void:
	satiety = clampf(saved_satiety, 0.0, 100.0)
	affinity = clampf(saved_affinity, 0.0, 100.0)
	mood = clampf(saved_mood, 0.0, 100.0)
	needs_changed.emit()


func to_save_dict() -> Dictionary:
	return {
		"satiety": snappedf(satiety, 0.1),
		"affinity": snappedf(affinity, 0.1),
		"mood": snappedf(mood, 0.1),
	}


func is_hungry() -> bool:
	return satiety < HUNGRY_THRESHOLD


func get_animal_type() -> ItemData.ItemType:
	return _animal_type


func try_feed(food: InventoryData.Item) -> Dictionary:
	## Returns { ok, message, favorite }. Does not consume inventory.
	if not AnimalDiet.can_eat(_animal_type, food):
		return {
			"ok": false,
			"favorite": false,
			"message": "%s won't eat %s" % [
				ItemData.get_item_name(_animal_type),
				InventoryData.get_item_name(food),
			],
		}
	var favorite := AnimalDiet.is_favorite(_animal_type, food)
	satiety = clampf(satiety + AnimalDiet.satiety_restore(_animal_type, food), 0.0, 100.0)
	affinity = clampf(affinity + AnimalDiet.affinity_restore(_animal_type, food), 0.0, 100.0)
	_recompute_mood(0.0)
	needs_changed.emit()
	var verb := "loved" if favorite else "ate"
	return {
		"ok": true,
		"favorite": favorite,
		"message": "%s %s the %s!" % [
			ItemData.get_item_name(_animal_type),
			verb,
			InventoryData.get_item_name(food),
		],
	}


func try_pet() -> Dictionary:
	## Returns { ok, message }.
	if _pet_cooldown > 0.0:
		return {
			"ok": false,
			"message": "%s needs a moment" % ItemData.get_item_name(_animal_type),
		}
	_pet_cooldown = PET_COOLDOWN_SEC
	affinity = clampf(affinity + PET_AFFINITY_GAIN, 0.0, 100.0)
	mood = clampf(mood + 3.0, 0.0, 100.0)
	needs_changed.emit()
	return {
		"ok": true,
		"message": "Pet %s (+affinity)" % ItemData.get_item_name(_animal_type),
	}


func _process(delta: float) -> void:
	_pet_cooldown = maxf(0.0, _pet_cooldown - delta)
	var before_s := satiety
	var before_m := mood
	satiety = maxf(0.0, satiety - SATIETY_DECAY_PER_SEC * delta)

	_crowd_timer -= delta
	if _crowd_timer <= 0.0:
		_crowd_timer = CROWD_CHECK_INTERVAL
		_update_crowd_pressure()

	_env_timer -= delta
	if _env_timer <= 0.0:
		_env_timer = ENV_TICK_INTERVAL
		_update_water_comfort()

	_recompute_mood(delta)

	if absf(satiety - before_s) > 0.05 or absf(mood - before_m) > 0.05:
		needs_changed.emit()


func _crowd_cap() -> int:
	match _animal_type:
		ItemData.ItemType.PIG:
			return 4
		ItemData.ItemType.RABBIT:
			return 2
		ItemData.ItemType.CHICKEN, ItemData.ItemType.DUCK:
			return 3
		_:
			return 3


func _update_crowd_pressure() -> void:
	_crowd_pressure = 0.0
	if _grid == null or _root == null or not is_instance_valid(_root):
		return
	if not _root.has_meta("grid_pos"):
		return
	var anchor: Vector2i = _root.get_meta("grid_pos")
	var count := _grid.count_animals_near(anchor, CROWD_RADIUS, _root)
	var over := count - _crowd_cap()
	if over > 0:
		_crowd_pressure = float(over)


func _update_water_comfort() -> void:
	_water_comfort = 0.0
	if _animal_type != ItemData.ItemType.DUCK:
		return
	if _grid == null or _root == null or not is_instance_valid(_root):
		return
	if not _root.has_meta("grid_pos"):
		return
	var cell: Vector2i = _root.get_meta("grid_pos")
	if _grid.is_swimmable_cell(cell) or _grid.has_water_near(cell, 1):
		_water_comfort = 1.0


func _recompute_mood(delta: float) -> void:
	## Soft blend toward an environment-influenced target.
	var target := 55.0 + affinity * 0.25
	if satiety < VERY_HUNGRY_THRESHOLD:
		target -= 25.0
	elif satiety < HUNGRY_THRESHOLD:
		target -= 10.0
	target -= _crowd_pressure * 8.0
	target += _water_comfort * 18.0
	target = clampf(target, 5.0, 100.0)
	var blend := 1.0 if delta <= 0.0 else minf(1.0, delta * 0.35)
	mood = lerpf(mood, target, blend)
	mood = clampf(mood, 0.0, 100.0)
