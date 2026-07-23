class_name AnimalDiet
extends RefCounted

## Species diet table: favorite / acceptable / rejected inventory foods.

enum Quality { REJECTED, ACCEPTABLE, FAVORITE }

## Per animal ItemType → { favorites: Array[Item], accepts: Array[Item] }
const DIETS: Dictionary = {
	ItemData.ItemType.COW: {
		"favorites": [InventoryData.Item.WHEAT],
		"accepts": [InventoryData.Item.APPLE],
	},
	ItemData.ItemType.SHEEP: {
		"favorites": [InventoryData.Item.WHEAT],
		"accepts": [],
	},
	ItemData.ItemType.PIG: {
		"favorites": [InventoryData.Item.CARROT],
		"accepts": [InventoryData.Item.WHEAT, InventoryData.Item.APPLE],
	},
	ItemData.ItemType.CHICKEN: {
		"favorites": [InventoryData.Item.SUNFLOWER],
		"accepts": [InventoryData.Item.WHEAT],
	},
	ItemData.ItemType.DUCK: {
		"favorites": [InventoryData.Item.WHEAT, InventoryData.Item.FISH],
		"accepts": [InventoryData.Item.CARROT],
	},
	ItemData.ItemType.RABBIT: {
		"favorites": [InventoryData.Item.CARROT],
		"accepts": [InventoryData.Item.WHEAT],
	},
}

const FAVORITE_SATIETY: float = 35.0
const ACCEPTABLE_SATIETY: float = 22.0
const FAVORITE_AFFINITY: float = 8.0
const ACCEPTABLE_AFFINITY: float = 0.0


static func get_quality(animal_type: ItemData.ItemType, food: InventoryData.Item) -> Quality:
	if not DIETS.has(animal_type):
		return Quality.REJECTED
	var diet: Dictionary = DIETS[animal_type]
	var favorites: Array = diet.get("favorites", [])
	if food in favorites:
		return Quality.FAVORITE
	var accepts: Array = diet.get("accepts", [])
	if food in accepts:
		return Quality.ACCEPTABLE
	return Quality.REJECTED


static func can_eat(animal_type: ItemData.ItemType, food: InventoryData.Item) -> bool:
	return get_quality(animal_type, food) != Quality.REJECTED


static func is_favorite(animal_type: ItemData.ItemType, food: InventoryData.Item) -> bool:
	return get_quality(animal_type, food) == Quality.FAVORITE


static func satiety_restore(animal_type: ItemData.ItemType, food: InventoryData.Item) -> float:
	match get_quality(animal_type, food):
		Quality.FAVORITE:
			return FAVORITE_SATIETY
		Quality.ACCEPTABLE:
			return ACCEPTABLE_SATIETY
		_:
			return 0.0


static func affinity_restore(animal_type: ItemData.ItemType, food: InventoryData.Item) -> float:
	match get_quality(animal_type, food):
		Quality.FAVORITE:
			return FAVORITE_AFFINITY
		Quality.ACCEPTABLE:
			return ACCEPTABLE_AFFINITY
		_:
			return 0.0


static func is_potential_feed(food: InventoryData.Item) -> bool:
	## True if any species can eat this item (backpack feed selection).
	for animal_type in DIETS:
		if can_eat(animal_type, food):
			return true
	return false
