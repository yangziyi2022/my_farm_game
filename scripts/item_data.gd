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
	WHEAT,
	STONE_PATH,
	GREENHOUSE,
	POND,
	FOUNTAIN,
	WIND_WHEEL,
	LOOKOUT_TOWER,
	HOUSE_GREEN,
	CARROT,
	RABBIT,
}

const CATEGORIES: Dictionary = {
	Category.TERRAIN: "Terrain",
	Category.STRUCTURE: "Buildings",
	Category.ANIMAL: "Animals",
	Category.PLANT: "Crops",
	Category.DECOR: "Decor",
}

const ITEMS: Dictionary = {
	ItemType.GRASS: {
		"id": "grass",
		"name": "Grass",
		"category": Category.TERRAIN,
		"color": Color(0.31, 0.40, 0.09),
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
		"name": "Tree Seed",
		"category": Category.PLANT,
		"color": Color(0.2, 0.5, 0.15),
		"trunk_color": Color(0.45, 0.3, 0.15),
		"size": Vector3(0.6, 1.2, 0.6),
		"offset_y": 0.6,
		"rotatable": false,
	},
	ItemType.FENCE: {
		"id": "fence",
		"name": "Fence",
		"category": Category.DECOR,
		"def_path": "res://data/placeable_items/fence.tres",
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
		"show_in_palette": false,
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
		# Art pipeline: edit data/placeable_items/house.tres in the Inspector.
		"def_path": "res://data/placeable_items/house.tres",
	},
	ItemType.HOUSE_GREEN: {
		"id": "house_green",
		"name": "Green Farmhouse",
		"category": Category.STRUCTURE,
		"color": Color(0.55, 0.72, 0.48),
		"roof_color": Color(0.35, 0.45, 0.28),
		"door_color": Color(0.42, 0.28, 0.16),
		"window_color": Color(0.55, 0.75, 0.9),
		"size": Vector3(1.8, 1.4, 1.8),
		"offset_y": 0.7,
		"rotatable": true,
		"def_path": "res://data/placeable_items/house_green.tres",
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
		"def_path": "res://data/placeable_items/barn.tres",
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
		"def_path": "res://data/placeable_items/windmill.tres",
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
		"def_path": "res://data/placeable_items/lamp_post.tres",
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
		"def_path": "res://data/placeable_items/chicken.tres",
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
	ItemType.RABBIT: {
		"id": "rabbit",
		"name": "Rabbit",
		"category": Category.ANIMAL,
		"color": Color(0.95, 0.9, 0.88),
		"ear_color": Color(0.98, 0.78, 0.82),
		"eye_color": Color(0.2, 0.15, 0.15),
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
		"show_in_palette": false,
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
		"show_in_palette": false,
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
		"show_in_palette": false,
	},
	ItemType.WHEAT: {
		"id": "wheat",
		"name": "Wheat Seed",
		"category": Category.PLANT,
		"color": Color(0.9, 0.78, 0.25),
		"stem_color": Color(0.22, 0.58, 0.18),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.4, 0.55, 0.4),
		"offset_y": 0.28,
		"rotatable": false,
	},
	ItemType.CARROT: {
		"id": "carrot",
		"name": "Carrot Seed",
		"category": Category.PLANT,
		"color": Color(0.95, 0.55, 0.15),
		"leaf_color": Color(0.25, 0.65, 0.22),
		"dirt_color": Color(0.55, 0.38, 0.22),
		"size": Vector3(0.35, 0.45, 0.35),
		"offset_y": 0.2,
		"rotatable": false,
	},
	ItemType.STONE_PATH: {
		"id": "stone_path",
		"name": "Stone Path",
		"category": Category.TERRAIN,
		"color": Color(0.62, 0.6, 0.58),
		"stone_color": Color(0.72, 0.7, 0.68),
		"size": Vector3(1.0, 0.1, 1.0),
		"offset_y": 0.05,
		"rotatable": false,
	},
	ItemType.GREENHOUSE: {
		"id": "greenhouse",
		"name": "Greenhouse",
		"category": Category.STRUCTURE,
		"color": Color(0.55, 0.78, 0.45, 0.55),
		"frame_color": Color(0.75, 0.72, 0.68),
		"roof_color": Color(0.45, 0.65, 0.38, 0.6),
		"size": Vector3(1.6, 1.1, 1.4),
		"offset_y": 0.55,
		"rotatable": true,
	},
	ItemType.POND: {
		"id": "pond",
		"name": "Pond",
		"category": Category.DECOR,
		"color": Color(0.2, 0.48, 0.82, 0.85),
		"rim_color": Color(0.52, 0.5, 0.48),
		"size": Vector3(1.1, 0.12, 1.1),
		"offset_y": 0.06,
		"rotatable": true,
	},
	ItemType.FOUNTAIN: {
		"id": "fountain",
		"name": "Fountain",
		"category": Category.DECOR,
		"color": Color(0.58, 0.58, 0.6),
		"water_color": Color(0.35, 0.62, 0.9, 0.75),
		"size": Vector3(0.9, 0.7, 0.9),
		"offset_y": 0.35,
		"rotatable": true,
	},
	ItemType.WIND_WHEEL: {
		"id": "wind_wheel",
		"name": "Wind Wheel",
		"category": Category.DECOR,
		"color": Color(0.62, 0.45, 0.28),
		"blade_color": Color(0.88, 0.85, 0.78),
		"size": Vector3(0.5, 1.6, 0.5),
		"offset_y": 0.8,
		"rotatable": true,
	},
	ItemType.LOOKOUT_TOWER: {
		"id": "lookout_tower",
		"name": "Lookout Tower",
		"category": Category.STRUCTURE,
		"color": Color(0.68, 0.55, 0.4),
		"rail_color": Color(0.45, 0.32, 0.22),
		"roof_color": Color(0.5, 0.28, 0.18),
		"size": Vector3(1.0, 2.4, 1.0),
		"offset_y": 1.2,
		"rotatable": true,
	},
}


static func get_items_by_category(category: Category) -> Array:
	var result: Array = []
	for item_type in ITEMS:
		if ITEMS[item_type].get("category") != category:
			continue
		if ITEMS[item_type].get("show_in_palette", true) == false:
			continue
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
	return item_type in [ItemType.GRASS, ItemType.DIRT, ItemType.WATER, ItemType.STONE_PATH]


static func is_water_source(item_type: ItemType) -> bool:
	return item_type in [ItemType.WATER, ItemType.POND]


static func is_fishable(item_type: ItemType) -> bool:
	return is_water_source(item_type)


static func is_hoeable(item_type: ItemType) -> bool:
	return item_type == ItemType.GRASS


static func is_flower_seed(item_type: ItemType) -> bool:
	# Legacy flower seeds kept for old saves; not shown in the palette.
	return item_type in [
		ItemType.FLOWER_RED,
		ItemType.FLOWER_YELLOW,
		ItemType.TULIP,
	]


static func is_crop_seed(item_type: ItemType) -> bool:
	return item_type in [
		ItemType.WHEAT,
		ItemType.CARROT,
		ItemType.SUNFLOWER,
		ItemType.TREE,
	]


static func needs_dirt_to_plant(item_type: ItemType) -> bool:
	return is_crop_seed(item_type) or is_flower_seed(item_type)


static func is_growable_plant(item_type: ItemType) -> bool:
	return needs_dirt_to_plant(item_type)


static func is_harvestable_plant(item_type: ItemType) -> bool:
	return is_growable_plant(item_type)


static func can_build_over(item_type: ItemType) -> bool:
	# Terrain tiles can be replaced by other terrain, or stacked under props.
	return is_terrain(item_type)


static func stacks_on_terrain(item_type: ItemType) -> bool:
	# Animals, buildings, fences, decor sit on top of dirt/grass without deleting it.
	# Crops also keep the dirt tile underneath (planted into / on top of dirt).
	if is_terrain(item_type):
		return false
	if needs_dirt_to_plant(item_type):
		return false
	return true


static func is_animal(item_type: ItemType) -> bool:
	return ITEMS[item_type].get("category") == Category.ANIMAL


static func should_sway(item_type: ItemType) -> bool:
	return item_type == ItemType.GRASS


static func is_rotatable(item_type: ItemType) -> bool:
	return ITEMS[item_type].get("rotatable", false)


static func get_item_def(item_type: ItemType) -> PlaceableItemDef:
	var path: String = ITEMS[item_type].get("def_path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PlaceableItemDef


static func get_visual_scene(item_type: ItemType) -> PackedScene:
	var def := get_item_def(item_type)
	if def:
		var scene := def.resolve_visual_scene()
		if scene:
			return scene
	var inline_path: String = ITEMS[item_type].get("visual_scene", "")
	if inline_path.is_empty() or not ResourceLoader.exists(inline_path):
		return null
	return load(inline_path) as PackedScene


static func get_icon(item_type: ItemType) -> Texture2D:
	var def := get_item_def(item_type)
	if def and def.icon:
		return def.icon
	var inline_path: String = ITEMS[item_type].get("icon", "")
	if inline_path.is_empty() or not ResourceLoader.exists(inline_path):
		return null
	return load(inline_path) as Texture2D


static func get_display_name(item_type: ItemType) -> String:
	var def := get_item_def(item_type)
	if def and not def.display_name.is_empty():
		return def.display_name
	return get_item_name(item_type)


static func get_footprint(item_type: ItemType) -> Vector2i:
	var def := get_item_def(item_type)
	if def:
		var size: Vector2i = def.footprint_size
		return Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	return Vector2i(1, 1)
