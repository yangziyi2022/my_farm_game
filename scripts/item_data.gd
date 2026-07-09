class_name ItemData
extends Resource

enum Category {
	TERRAIN,
	STRUCTURE,
	ANIMAL,
	PLANT,
	DECOR,
}

enum ItemType {
	GRASS,
	DIRT,
	WATER,
	ROCK,
	TREE,
	FENCE,
	CROP_BED,
	SHED,
	HOUSE,
	BARN,
	WINDMILL,
	GRANARY,
	BRIDGE,
	LAMPPOST,
	WELL,
	COW,
	CHICKEN,
	SHEEP,
	PIG,
	DUCK,
	FLOWER_RED,
	FLOWER_YELLOW,
	SUNFLOWER,
	TULIP,
}

const CATEGORIES: Dictionary = {
	Category.TERRAIN: "Terrain",
	Category.STRUCTURE: "Buildings",
	Category.ANIMAL: "Animals",
	Category.PLANT: "Flowers",
	Category.DECOR: "Decor",
}

const ITEMS: Dictionary = {
	ItemType.GRASS: {
		"id": "grass",
		"name": "Grass",
		"category": Category.TERRAIN,
		"color": Color(0.35, 0.65, 0.25),
		"size": Vector3(1.0, 0.1, 1.0),
		"offset_y": 0.05,
		"rotatable": false,
	},
	ItemType.DIRT: {
		"id": "dirt",
		"name": "Dirt",
		"category": Category.TERRAIN,
		"color": Color(0.55, 0.38, 0.22),
		"size": Vector3(1.0, 0.1, 1.0),
		"offset_y": 0.05,
		"rotatable": false,
	},
	ItemType.WATER: {
		"id": "water",
		"name": "Water",
		"category": Category.TERRAIN,
		"color": Color(0.2, 0.45, 0.85, 0.8),
		"size": Vector3(1.0, 0.08, 1.0),
		"offset_y": 0.04,
		"rotatable": false,
	},
	ItemType.ROCK: {
		"id": "rock",
		"name": "Rock",
		"category": Category.DECOR,
		"color": Color(0.5, 0.5, 0.52),
		"size": Vector3(0.7, 0.4, 0.7),
		"offset_y": 0.2,
		"rotatable": true,
	},
	ItemType.TREE: {
		"id": "tree",
		"name": "Tree",
		"category": Category.DECOR,
		"color": Color(0.2, 0.5, 0.15),
		"trunk_color": Color(0.45, 0.3, 0.15),
		"size": Vector3(0.6, 1.2, 0.6),
		"offset_y": 0.6,
		"rotatable": true,
	},
	ItemType.FENCE: {
		"id": "fence",
		"name": "Fence",
		"category": Category.DECOR,
		"color": Color(0.6, 0.45, 0.25),
		"size": Vector3(0.9, 0.5, 0.15),
		"offset_y": 0.25,
		"rotatable": true,
	},
	ItemType.CROP_BED: {
		"id": "crop_bed",
		"name": "Crop Bed",
		"category": Category.PLANT,
		"color": Color(0.4, 0.25, 0.12),
		"crop_color": Color(0.3, 0.75, 0.2),
		"size": Vector3(0.9, 0.15, 0.9),
		"offset_y": 0.075,
		"rotatable": true,
	},
	ItemType.SHED: {
		"id": "shed",
		"name": "Shed",
		"category": Category.STRUCTURE,
		"color": Color(0.7, 0.35, 0.2),
		"roof_color": Color(0.5, 0.2, 0.15),
		"size": Vector3(1.5, 1.2, 1.5),
		"offset_y": 0.6,
		"rotatable": true,
	},
	ItemType.HOUSE: {
		"id": "house",
		"name": "Farmhouse",
		"category": Category.STRUCTURE,
		"color": Color(0.85, 0.78, 0.65),
		"roof_color": Color(0.55, 0.28, 0.18),
		"door_color": Color(0.42, 0.28, 0.16),
		"window_color": Color(0.55, 0.75, 0.9),
		"size": Vector3(1.8, 1.4, 1.8),
		"offset_y": 0.7,
		"rotatable": true,
	},
	ItemType.BARN: {
		"id": "barn",
		"name": "Barn",
		"category": Category.STRUCTURE,
		"color": Color(0.75, 0.22, 0.18),
		"roof_color": Color(0.35, 0.18, 0.12),
		"door_color": Color(0.5, 0.32, 0.2),
		"size": Vector3(2.0, 1.6, 1.6),
		"offset_y": 0.8,
		"rotatable": true,
	},
	ItemType.WINDMILL: {
		"id": "windmill",
		"name": "Windmill",
		"category": Category.STRUCTURE,
		"color": Color(0.82, 0.78, 0.7),
		"blade_color": Color(0.75, 0.75, 0.78),
		"roof_color": Color(0.55, 0.28, 0.18),
		"size": Vector3(1.4, 2.2, 1.4),
		"offset_y": 1.1,
		"rotatable": true,
	},
	ItemType.GRANARY: {
		"id": "granary",
		"name": "Granary",
		"category": Category.STRUCTURE,
		"color": Color(0.72, 0.68, 0.55),
		"roof_color": Color(0.48, 0.32, 0.22),
		"door_color": Color(0.45, 0.3, 0.18),
		"size": Vector3(1.6, 1.5, 1.4),
		"offset_y": 0.75,
		"rotatable": true,
	},
	ItemType.BRIDGE: {
		"id": "bridge",
		"name": "Bridge",
		"category": Category.DECOR,
		"color": Color(0.55, 0.38, 0.22),
		"rail_color": Color(0.45, 0.3, 0.15),
		"size": Vector3(1.2, 0.25, 0.8),
		"offset_y": 0.15,
		"rotatable": true,
	},
	ItemType.LAMPPOST: {
		"id": "lamppost",
		"name": "Lamp Post",
		"category": Category.DECOR,
		"color": Color(0.35, 0.35, 0.38),
		"light_color": Color(0.95, 0.9, 0.6),
		"size": Vector3(0.2, 1.1, 0.2),
		"offset_y": 0.55,
		"rotatable": true,
	},
	ItemType.WELL: {
		"id": "well",
		"name": "Well",
		"category": Category.DECOR,
		"color": Color(0.5, 0.5, 0.52),
		"roof_color": Color(0.55, 0.28, 0.18),
		"size": Vector3(0.9, 0.9, 0.9),
		"offset_y": 0.45,
		"rotatable": true,
	},
	ItemType.COW: {
		"id": "cow",
		"name": "Cow",
		"category": Category.ANIMAL,
		"color": Color(0.92, 0.92, 0.9),
		"spot_color": Color(0.25, 0.25, 0.28),
		"size": Vector3(0.9, 0.6, 1.4),
		"offset_y": 0.35,
		"rotatable": true,
	},
	ItemType.CHICKEN: {
		"id": "chicken",
		"name": "Chicken",
		"category": Category.ANIMAL,
		"color": Color(0.95, 0.88, 0.55),
		"comb_color": Color(0.85, 0.15, 0.12),
		"size": Vector3(0.35, 0.35, 0.45),
		"offset_y": 0.2,
		"rotatable": true,
	},
	ItemType.SHEEP: {
		"id": "sheep",
		"name": "Sheep",
		"category": Category.ANIMAL,
		"color": Color(0.92, 0.92, 0.95),
		"face_color": Color(0.35, 0.32, 0.3),
		"size": Vector3(0.7, 0.55, 0.9),
		"offset_y": 0.3,
		"rotatable": true,
	},
	ItemType.PIG: {
		"id": "pig",
		"name": "Pig",
		"category": Category.ANIMAL,
		"color": Color(0.95, 0.72, 0.75),
		"nose_color": Color(0.9, 0.55, 0.6),
		"size": Vector3(0.75, 0.5, 1.0),
		"offset_y": 0.28,
		"rotatable": true,
	},
	ItemType.DUCK: {
		"id": "duck",
		"name": "Duck",
		"category": Category.ANIMAL,
		"color": Color(0.92, 0.78, 0.28),
		"beak_color": Color(0.9, 0.55, 0.15),
		"size": Vector3(0.4, 0.35, 0.5),
		"offset_y": 0.2,
		"rotatable": true,
	},
	ItemType.FLOWER_RED: {
		"id": "flower_red",
		"name": "Red Flower Seed",
		"category": Category.PLANT,
		"color": Color(0.85, 0.15, 0.2),
		"stem_color": Color(0.2, 0.55, 0.2),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.3, 0.45, 0.3),
		"offset_y": 0.22,
		"rotatable": false,
	},
	ItemType.FLOWER_YELLOW: {
		"id": "flower_yellow",
		"name": "Yellow Flower Seed",
		"category": Category.PLANT,
		"color": Color(0.95, 0.85, 0.15),
		"stem_color": Color(0.2, 0.55, 0.2),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.3, 0.45, 0.3),
		"offset_y": 0.22,
		"rotatable": false,
	},
	ItemType.SUNFLOWER: {
		"id": "sunflower",
		"name": "Sunflower Seed",
		"category": Category.PLANT,
		"color": Color(0.95, 0.78, 0.1),
		"center_color": Color(0.45, 0.32, 0.12),
		"stem_color": Color(0.22, 0.58, 0.18),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.5, 0.7, 0.5),
		"offset_y": 0.35,
		"rotatable": false,
	},
	ItemType.TULIP: {
		"id": "tulip",
		"name": "Tulip Seed",
		"category": Category.PLANT,
		"color": Color(0.8, 0.25, 0.55),
		"stem_color": Color(0.2, 0.55, 0.2),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.25, 0.5, 0.25),
		"offset_y": 0.25,
		"rotatable": false,
	},
}


static func get_items_by_category(category: Category) -> Array:
	var result: Array = []
	for item_type in ITEMS:
		if ITEMS[item_type].get("category") == category:
			result.append(item_type)
	return result


static func get_item_by_id(item_id: String) -> ItemType:
	if item_id == "crop":
		return ItemType.FLOWER_RED
	for type in ITEMS:
		if ITEMS[type]["id"] == item_id:
			return type
	return ItemType.GRASS


static func get_item_id(item_type: ItemType) -> String:
	return ITEMS[item_type]["id"]


static func get_item_name(item_type: ItemType) -> String:
	return ITEMS[item_type]["name"]


static func is_terrain(item_type: ItemType) -> bool:
	return item_type in [ItemType.GRASS, ItemType.DIRT, ItemType.WATER]


static func is_hoeable(item_type: ItemType) -> bool:
	return item_type == ItemType.GRASS


static func is_flower_seed(item_type: ItemType) -> bool:
	return item_type in [
		ItemType.FLOWER_RED,
		ItemType.FLOWER_YELLOW,
		ItemType.SUNFLOWER,
		ItemType.TULIP,
	]


static func is_growable_plant(item_type: ItemType) -> bool:
	return is_flower_seed(item_type)


static func can_build_over(item_type: ItemType) -> bool:
	# Any terrain tile can be replaced by buildings, decor, or animals.
	return is_terrain(item_type)


static func is_animal(item_type: ItemType) -> bool:
	return ITEMS[item_type].get("category") == Category.ANIMAL


static func should_sway(item_type: ItemType) -> bool:
	return item_type in [
		ItemType.GRASS,
		ItemType.TREE,
		ItemType.CROP_BED,
	]


static func is_rotatable(item_type: ItemType) -> bool:
	return ITEMS[item_type].get("rotatable", false)
