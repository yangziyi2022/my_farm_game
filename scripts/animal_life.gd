class_name AnimalLife
extends Node

## Life stage, personality, breeding cooldown, and produce readiness.

signal life_changed

enum Stage { BABY, ADULT }
enum Personality { FRIENDLY, SHY, GLUTTONOUS, SLEEPY }

const BABY_SCALE: float = 0.52
## Real-time seconds until a baby becomes adult (~1.5 min).
const GROWTH_SECONDS: float = 90.0
const BREED_COOLDOWN_SEC: float = 180.0
const PRODUCE_COOLDOWN_SEC: float = 120.0
## Both parents must have been player-fed within this window.
const FEED_FRESH_SEC: float = 50.0
const BREED_MIN_SATIETY: float = 55.0
const BREED_MIN_AFFINITY: float = 30.0
const BREED_MIN_MOOD: float = 45.0
const BREED_SEARCH_RADIUS: int = 2

const PERSONALITY_IDS := {
	Personality.FRIENDLY: "friendly",
	Personality.SHY: "shy",
	Personality.GLUTTONOUS: "gluttonous",
	Personality.SLEEPY: "sleepy",
}

var stage: Stage = Stage.ADULT
var personality: Personality = Personality.FRIENDLY
var growth_elapsed: float = 0.0
var breed_cooldown: float = 0.0
var produce_cooldown: float = 0.0
## Counts down after player feeds this animal (breeding gate).
var feed_freshness: float = 0.0
## Sheep alternates wool ↔ sheep milk between collects.
var sheep_next_is_wool: bool = true

var _root: Node3D
var _animal_type: ItemData.ItemType = ItemData.ItemType.COW
var _grid: GridManager
var _pivot: Node3D


func get_grid() -> GridManager:
	return _grid


func setup(
	root: Node3D,
	animal_type: ItemData.ItemType,
	grid_manager: GridManager = null,
	as_baby: bool = false
) -> void:
	_root = root
	_animal_type = animal_type
	_grid = grid_manager
	if as_baby:
		stage = Stage.BABY
		growth_elapsed = 0.0
	else:
		stage = Stage.ADULT
		growth_elapsed = GROWTH_SECONDS
	if ItemData.can_have_personality(animal_type):
		personality = _roll_personality()
	else:
		personality = Personality.FRIENDLY
	# Fresh adults can produce after a short warm-up; babies never until grown.
	produce_cooldown = 20.0 if stage == Stage.ADULT else PRODUCE_COOLDOWN_SEC
	_cache_pivot()
	_apply_visual_scale()
	_sync_meta()


func apply_saved(data: Dictionary) -> void:
	stage = Stage.BABY if str(data.get("life_stage", "adult")) == "baby" else Stage.ADULT
	growth_elapsed = float(data.get("growth_elapsed", GROWTH_SECONDS if stage == Stage.ADULT else 0.0))
	breed_cooldown = float(data.get("breed_cooldown", 0.0))
	produce_cooldown = float(data.get("produce_cooldown", 0.0))
	sheep_next_is_wool = bool(data.get("sheep_next_is_wool", true))
	personality = personality_from_id(str(data.get("personality", "friendly")))
	_cache_pivot()
	_apply_visual_scale()
	_sync_meta()
	life_changed.emit()


func to_save_dict() -> Dictionary:
	return {
		"life_stage": "baby" if stage == Stage.BABY else "adult",
		"growth_elapsed": snappedf(growth_elapsed, 0.1),
		"breed_cooldown": snappedf(breed_cooldown, 0.1),
		"produce_cooldown": snappedf(produce_cooldown, 0.1),
		"sheep_next_is_wool": sheep_next_is_wool,
		"personality": personality_id(),
	}


func is_baby() -> bool:
	return stage == Stage.BABY


func is_adult() -> bool:
	return stage == Stage.ADULT


func can_breed() -> bool:
	if stage != Stage.ADULT:
		return false
	if breed_cooldown > 0.0:
		return false
	if feed_freshness <= 0.0:
		return false
	if not ItemData.can_breed(_animal_type):
		return false
	return true


func mark_player_fed() -> void:
	feed_freshness = FEED_FRESH_SEC


func meets_breed_needs(needs: AnimalNeeds) -> bool:
	if needs == null:
		return false
	return (
		needs.satiety >= BREED_MIN_SATIETY
		and needs.affinity >= BREED_MIN_AFFINITY
		and needs.mood >= BREED_MIN_MOOD
	)


func can_collect_produce() -> bool:
	if stage != Stage.ADULT:
		return false
	if produce_cooldown > 0.0:
		return false
	return get_produce_item() != null


func get_produce_item():
	## InventoryData.Item or null (sheep alternates wool / sheep milk).
	if _animal_type == ItemData.ItemType.SHEEP:
		if sheep_next_is_wool:
			return InventoryData.Item.WOOL
		return InventoryData.Item.SHEEP_MILK
	return ItemData.get_animal_produce(_animal_type)


func get_collect_button_label() -> String:
	var item = get_produce_item()
	if item == null:
		return LocaleManager.t("Collect")
	match item:
		InventoryData.Item.MILK:
			return LocaleManager.t("Milk")
		InventoryData.Item.SHEEP_MILK:
			return LocaleManager.t("Sheep Milk")
		InventoryData.Item.WOOL:
			return LocaleManager.t("Shear")
		_:
			return LocaleManager.t("Collect")


func collect_produce() -> Dictionary:
	## { ok, message, item }.
	if not can_collect_produce():
		if stage == Stage.BABY:
			return {"ok": false, "message": LocaleManager.t("Too young to collect from")}
		if produce_cooldown > 0.0:
			return {"ok": false, "message": LocaleManager.t("Nothing ready yet — wait a bit")}
		return {"ok": false, "message": LocaleManager.t("Can't collect from that")}
	var item = get_produce_item()
	if item == null:
		return {"ok": false, "message": LocaleManager.t("Can't collect from that")}
	produce_cooldown = PRODUCE_COOLDOWN_SEC
	if _animal_type == ItemData.ItemType.SHEEP:
		sheep_next_is_wool = not sheep_next_is_wool
	life_changed.emit()
	var who := AnimalInteraction.get_display_name(_root) if _root else ItemData.get_item_name(_animal_type)
	return {
		"ok": true,
		"item": item,
		"message": LocaleManager.tf("Collected %s from %s", [
			InventoryData.get_item_name(item),
			who,
		]),
	}


func personality_id() -> String:
	return str(PERSONALITY_IDS.get(personality, "friendly"))


func personality_display_name() -> String:
	match personality:
		Personality.FRIENDLY:
			return LocaleManager.t("Friendly")
		Personality.SHY:
			return LocaleManager.t("Shy")
		Personality.GLUTTONOUS:
			return LocaleManager.t("Gluttonous")
		Personality.SLEEPY:
			return LocaleManager.t("Sleepy")
		_:
			return LocaleManager.t("Friendly")


static func personality_from_id(id: String) -> Personality:
	match id:
		"shy":
			return Personality.SHY
		"gluttonous":
			return Personality.GLUTTONOUS
		"sleepy":
			return Personality.SLEEPY
		_:
			return Personality.FRIENDLY


func mark_bred() -> void:
	breed_cooldown = BREED_COOLDOWN_SEC
	life_changed.emit()


func _process(delta: float) -> void:
	breed_cooldown = maxf(0.0, breed_cooldown - delta)
	produce_cooldown = maxf(0.0, produce_cooldown - delta)
	feed_freshness = maxf(0.0, feed_freshness - delta)
	if stage == Stage.BABY:
		growth_elapsed += delta
		if growth_elapsed >= GROWTH_SECONDS:
			_become_adult()


func _become_adult() -> void:
	stage = Stage.ADULT
	growth_elapsed = GROWTH_SECONDS
	produce_cooldown = 15.0
	_apply_visual_scale()
	_sync_meta()
	life_changed.emit()
	if _root and is_instance_valid(_root):
		# Soft pop when growing up.
		var pivot := _pivot
		if pivot:
			var tw := pivot.create_tween()
			tw.tween_property(pivot, "scale", Vector3.ONE * 1.08, 0.12)
			tw.tween_property(pivot, "scale", Vector3.ONE, 0.18)


func _roll_personality() -> Personality:
	var roll := randi() % 4
	match roll:
		1:
			return Personality.SHY
		2:
			return Personality.GLUTTONOUS
		3:
			return Personality.SLEEPY
		_:
			return Personality.FRIENDLY


func _cache_pivot() -> void:
	if _root == null:
		return
	_pivot = _root.get_node_or_null(ObjectPolish.ANIMAL_PIVOT_NAME) as Node3D


func _apply_visual_scale() -> void:
	_cache_pivot()
	if _pivot == null or not is_instance_valid(_pivot):
		return
	var s := BABY_SCALE if stage == Stage.BABY else 1.0
	_pivot.scale = Vector3.ONE * s


func _sync_meta() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_root.set_meta("life_stage", "baby" if stage == Stage.BABY else "adult")
	_root.set_meta("personality", personality_id())
