class_name InventoryData
extends Resource

enum Item {
	WHEAT,
	CARROT,
	SUNFLOWER,
	WOOD,
	FISH,
	MEAT,
}

const ITEMS: Dictionary = {
	Item.WHEAT: {"id": "wheat", "name": "Wheat", "color": Color(0.9, 0.78, 0.25), "feedable": true, "letter": "W"},
	Item.CARROT: {"id": "carrot", "name": "Carrot", "color": Color(0.95, 0.55, 0.15), "feedable": false, "letter": "C"},
	Item.SUNFLOWER: {"id": "sunflower", "name": "Sunflower", "color": Color(0.95, 0.78, 0.1), "feedable": false, "letter": "S"},
	Item.WOOD: {"id": "wood", "name": "Wood", "color": Color(0.55, 0.38, 0.22), "feedable": false, "letter": "T"},
	Item.FISH: {"id": "fish", "name": "Fish", "color": Color(0.35, 0.55, 0.85), "feedable": false, "letter": "F"},
	Item.MEAT: {"id": "meat", "name": "Meat", "color": Color(0.75, 0.35, 0.35), "feedable": false, "letter": "M"},
}

## Fixed backpack slot indices (8x8 grid has room to spare).
const SLOT_INDEX: Dictionary = {
	Item.WHEAT: 0,
	Item.CARROT: 1,
	Item.SUNFLOWER: 2,
	Item.WOOD: 3,
	Item.FISH: 4,
	Item.MEAT: 5,
}

static var _icon_cache: Dictionary = {}


static func from_plant_type(plant_type: ItemData.ItemType) -> Item:
	match plant_type:
		ItemData.ItemType.WHEAT:
			return Item.WHEAT
		ItemData.ItemType.CARROT:
			return Item.CARROT
		ItemData.ItemType.SUNFLOWER:
			return Item.SUNFLOWER
		ItemData.ItemType.TREE:
			return Item.WOOD
		_:
			return Item.WHEAT


static func get_item_name(item: Item) -> String:
	return ITEMS[item]["name"]


static func get_color(item: Item) -> Color:
	return ITEMS[item]["color"]


static func is_feedable(item: Item) -> bool:
	return ITEMS[item].get("feedable", false)


static func get_by_id(item_id: String) -> Item:
	# Legacy save ids map onto the trimmed inventory.
	match item_id:
		"flower_red", "flower_yellow", "tulip":
			return Item.SUNFLOWER
		"tree":
			return Item.WOOD
	for item in ITEMS:
		if ITEMS[item]["id"] == item_id:
			return item
	return Item.WHEAT


static func get_icon(item: Item) -> Texture2D:
	if _icon_cache.has(item):
		return _icon_cache[item]
	var color: Color = get_color(item)
	var letter: String = str(ITEMS[item].get("letter", "?"))
	var tex := _make_icon_texture(color, letter)
	_icon_cache[item] = tex
	return tex


static func _make_icon_texture(color: Color, letter: String) -> ImageTexture:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := 4
	for y in range(edge, size - edge):
		for x in range(edge, size - edge):
			var on_border := x == edge or y == edge or x == size - edge - 1 or y == size - edge - 1
			if on_border:
				img.set_pixel(x, y, color.darkened(0.35))
			else:
				img.set_pixel(x, y, color)
	# Simple letter mark as a darker block in the center.
	var cx := size / 2
	var cy := size / 2
	var mark := color.lightened(0.45)
	for y in range(cy - 8, cy + 9):
		for x in range(cx - 5, cx + 6):
			if x >= 0 and y >= 0 and x < size and y < size:
				img.set_pixel(x, y, mark)
	# Vary mark shape slightly by letter hash so icons feel distinct.
	var h: int = letter.unicode_at(0) % 5
	for i in range(6):
		var px := cx - 6 + h + i
		var py := cy + 6
		if px >= edge and px < size - edge:
			img.set_pixel(px, py, color.darkened(0.2))
	return ImageTexture.create_from_image(img)
