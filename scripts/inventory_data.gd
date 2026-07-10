class_name InventoryData
extends Resource

enum Item {
	WHEAT,
	FLOWER_RED,
	FLOWER_YELLOW,
	SUNFLOWER,
	TULIP,
	FISH,
	MEAT,
}

const ITEMS: Dictionary = {
	Item.WHEAT: {"id": "wheat", "name": "Wheat", "color": Color(0.9, 0.78, 0.25), "feedable": true},
	Item.FLOWER_RED: {"id": "flower_red", "name": "Red Flower", "color": Color(0.85, 0.15, 0.2), "feedable": false},
	Item.FLOWER_YELLOW: {"id": "flower_yellow", "name": "Yellow Flower", "color": Color(0.95, 0.85, 0.15), "feedable": false},
	Item.SUNFLOWER: {"id": "sunflower", "name": "Sunflower", "color": Color(0.95, 0.78, 0.1), "feedable": false},
	Item.TULIP: {"id": "tulip", "name": "Tulip", "color": Color(0.8, 0.25, 0.55), "feedable": false},
	Item.FISH: {"id": "fish", "name": "Fish", "color": Color(0.35, 0.55, 0.85), "feedable": false},
	Item.MEAT: {"id": "meat", "name": "Meat", "color": Color(0.75, 0.35, 0.35), "feedable": false},
}


static func from_plant_type(plant_type: ItemData.ItemType) -> Item:
	match plant_type:
		ItemData.ItemType.WHEAT:
			return Item.WHEAT
		ItemData.ItemType.FLOWER_RED:
			return Item.FLOWER_RED
		ItemData.ItemType.FLOWER_YELLOW:
			return Item.FLOWER_YELLOW
		ItemData.ItemType.SUNFLOWER:
			return Item.SUNFLOWER
		ItemData.ItemType.TULIP:
			return Item.TULIP
	return Item.WHEAT


static func get_item_name(item: Item) -> String:
	return ITEMS[item]["name"]


static func get_color(item: Item) -> Color:
	return ITEMS[item]["color"]


static func is_feedable(item: Item) -> bool:
	return ITEMS[item].get("feedable", false)


static func get_by_id(item_id: String) -> Item:
	for item in ITEMS:
		if ITEMS[item]["id"] == item_id:
			return item
	return Item.WHEAT
