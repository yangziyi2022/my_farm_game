class_name ItemPalette
extends PanelContainer

signal item_selected(item_type: ItemData.ItemType)
signal select_tool_activated
signal hoe_tool_activated
signal harvest_tool_activated
signal rod_tool_activated

enum Tool { SELECT, HOE, HARVEST, ROD }

const SELECT_TOOL := -1
const ICON_SIZE := Vector2(48, 48)
const CHILD_BTN_SIZE := Vector2(120, 34)

var _buttons: Dictionary = {}
var _select_btn: Button
var _hoe_btn: Button
var _harvest_btn: Button
var _rod_btn: Button
var _active_type: int = SELECT_TOOL
var _active_tool: Tool = Tool.SELECT

var _section_bodies: Dictionary = {}  # section_id -> Control
var _section_headers: Dictionary = {}  # section_id -> Button
var _open_section: String = ""


func _ready() -> void:
	_build_palette()
	activate_select_tool()


func _build_palette() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(150, 480)
	margin.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	scroll.add_child(outer)

	# Always-available Select (pointer).
	_select_btn = _make_icon_header("Select", _icon_select(), Color(0.35, 0.55, 0.85))
	_select_btn.toggle_mode = true
	_select_btn.pressed.connect(_on_select_tool_pressed)
	outer.add_child(_select_btn)

	# Tools accordion: hammer -> hoe / harvest / rod
	var tools_body := VBoxContainer.new()
	tools_body.add_theme_constant_override("separation", 4)
	_hoe_btn = _make_child_button("Hoe")
	_hoe_btn.pressed.connect(_on_hoe_tool_pressed)
	tools_body.add_child(_hoe_btn)
	_harvest_btn = _make_child_button("Harvest")
	_harvest_btn.pressed.connect(_on_harvest_tool_pressed)
	tools_body.add_child(_harvest_btn)
	_rod_btn = _make_child_button("Rod")
	_rod_btn.pressed.connect(_on_rod_tool_pressed)
	tools_body.add_child(_rod_btn)
	_add_section(outer, "tools", "Tools", _icon_hammer(), Color(0.55, 0.45, 0.35), tools_body)

	# Category accordions
	var cat_meta := {
		ItemData.Category.TERRAIN: {"id": "terrain", "icon": _icon_dirt(), "color": Color(0.55, 0.38, 0.22)},
		ItemData.Category.STRUCTURE: {"id": "buildings", "icon": _icon_house(), "color": Color(0.7, 0.45, 0.35)},
		ItemData.Category.ANIMAL: {"id": "animals", "icon": _icon_rabbit(), "color": Color(0.85, 0.75, 0.7)},
		ItemData.Category.PLANT: {"id": "crops", "icon": _icon_wheat(), "color": Color(0.85, 0.72, 0.25)},
		ItemData.Category.DECOR: {"id": "decor", "icon": _icon_bulb(), "color": Color(0.95, 0.85, 0.35)},
	}

	for category in ItemData.CATEGORIES:
		var meta: Dictionary = cat_meta[category]
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 4)
		for item_type in ItemData.get_items_by_category(category):
			var btn := _make_child_button(ItemData.get_display_name(item_type))
			var item_icon := ItemData.get_icon(item_type)
			if item_icon:
				btn.icon = item_icon
				btn.expand_icon = true
			btn.toggle_mode = true
			btn.pressed.connect(_on_item_pressed.bind(item_type))
			body.add_child(btn)
			_buttons[item_type] = btn
		_add_section(
			outer,
			str(meta["id"]),
			ItemData.CATEGORIES[category],
			meta["icon"],
			meta["color"],
			body
		)


func _add_section(
	parent: Control,
	section_id: String,
	title: String,
	icon: Texture2D,
	tint: Color,
	body: Control
) -> void:
	var header := _make_icon_header(title, icon, tint)
	header.pressed.connect(_on_section_header_pressed.bind(section_id))
	parent.add_child(header)
	body.visible = false
	parent.add_child(body)
	_section_headers[section_id] = header
	_section_bodies[section_id] = body


func _make_icon_header(title: String, icon: Texture2D, tint: Color) -> Button:
	var btn := Button.new()
	btn.tooltip_text = title
	btn.custom_minimum_size = ICON_SIZE
	btn.icon = icon
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.45)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _make_child_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = CHILD_BTN_SIZE
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func _on_section_header_pressed(section_id: String) -> void:
	if _open_section == section_id:
		_set_open_section("")
	else:
		_set_open_section(section_id)


func _set_open_section(section_id: String) -> void:
	_open_section = section_id
	for id in _section_bodies:
		var body: Control = _section_bodies[id]
		var open: bool = (str(id) == _open_section)
		body.visible = open
		var header: Button = _section_headers[id]
		header.modulate = Color(1.15, 1.1, 0.9) if open else Color.WHITE


func _on_select_tool_pressed() -> void:
	activate_select_tool()
	select_tool_activated.emit()


func _on_hoe_tool_pressed() -> void:
	activate_hoe_tool()
	hoe_tool_activated.emit()


func _on_harvest_tool_pressed() -> void:
	activate_harvest_tool()
	harvest_tool_activated.emit()


func _on_rod_tool_pressed() -> void:
	activate_rod_tool()
	rod_tool_activated.emit()


func _on_item_pressed(item_type: ItemData.ItemType) -> void:
	if _active_type == item_type and _active_tool == Tool.SELECT:
		activate_select_tool()
		select_tool_activated.emit()
		return
	select_item(item_type)
	item_selected.emit(item_type)


func activate_select_tool() -> void:
	_active_tool = Tool.SELECT
	_active_type = SELECT_TOOL
	_update_button_styles()


func activate_hoe_tool() -> void:
	_active_tool = Tool.HOE
	_active_type = SELECT_TOOL
	_set_open_section("tools")
	_update_button_styles()


func activate_harvest_tool() -> void:
	_active_tool = Tool.HARVEST
	_active_type = SELECT_TOOL
	_set_open_section("tools")
	_update_button_styles()


func activate_rod_tool() -> void:
	_active_tool = Tool.ROD
	_active_type = SELECT_TOOL
	_set_open_section("tools")
	_update_button_styles()


func select_item(item_type: ItemData.ItemType) -> void:
	_active_tool = Tool.SELECT
	_active_type = item_type
	var cat: ItemData.Category = ItemData.ITEMS[item_type]["category"]
	var section_map: Dictionary = {
		ItemData.Category.TERRAIN: "terrain",
		ItemData.Category.STRUCTURE: "buildings",
		ItemData.Category.ANIMAL: "animals",
		ItemData.Category.PLANT: "crops",
		ItemData.Category.DECOR: "decor",
	}
	var section: String = str(section_map.get(cat, ""))
	if section != "":
		_set_open_section(section)
	_update_button_styles()


func _update_button_styles() -> void:
	if _select_btn:
		_select_btn.button_pressed = _active_tool == Tool.SELECT and _active_type == SELECT_TOOL
		_select_btn.modulate = Color(1.2, 1.15, 0.85) if _select_btn.button_pressed else Color.WHITE
	if _hoe_btn:
		_hoe_btn.button_pressed = _active_tool == Tool.HOE
	if _harvest_btn:
		_harvest_btn.button_pressed = _active_tool == Tool.HARVEST
	if _rod_btn:
		_rod_btn.button_pressed = _active_tool == Tool.ROD
	for type in _buttons:
		var btn: Button = _buttons[type]
		btn.button_pressed = _active_tool == Tool.SELECT and type == _active_type


# --- Category / tool icons (procedural) ---------------------------------

func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, c)


func _icon_select() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1, 1, 1, 1)
	# Pointer triangle
	for y in range(12, 48):
		var w: int = int((y - 12) * 0.55)
		for x in range(18, 18 + maxi(w, 1)):
			img.set_pixel(x, y, c)
	_fill_rect(img, 18, 40, 28, 54, c)
	return ImageTexture.create_from_image(img)


func _icon_hammer() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var head := Color(0.75, 0.75, 0.78)
	var handle := Color(0.55, 0.35, 0.18)
	# Handle diagonal
	for i in range(18, 52):
		for t in range(-3, 4):
			var x := i + t
			var y := i
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				img.set_pixel(x, y, handle)
	# Head
	_fill_rect(img, 10, 12, 34, 28, head)
	_fill_rect(img, 8, 16, 14, 24, head.darkened(0.15))
	return ImageTexture.create_from_image(img)


func _icon_dirt() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var soil := Color(0.55, 0.38, 0.22)
	var dark := Color(0.4, 0.28, 0.15)
	# Isometric-ish mound
	for y in range(20, 50):
		var span: int = 8 + (y - 20)
		_fill_rect(img, 32 - span, y, 32 + span, y + 1, soil if y % 3 != 0 else dark)
	return ImageTexture.create_from_image(img)


func _icon_house() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wall := Color(0.92, 0.88, 0.8)
	var roof := Color(0.75, 0.35, 0.28)
	var door := Color(0.45, 0.28, 0.15)
	# Walls
	_fill_rect(img, 16, 30, 48, 52, wall)
	# Roof triangle
	for y in range(12, 32):
		var w: int = (y - 12) * 2
		_fill_rect(img, 32 - w, y, 32 + w, y + 1, roof)
	# Door
	_fill_rect(img, 28, 38, 36, 52, door)
	return ImageTexture.create_from_image(img)


func _icon_rabbit() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fur := Color(0.95, 0.9, 0.88)
	var ear := Color(0.98, 0.8, 0.85)
	var eye := Color(0.15, 0.12, 0.12)
	# Body
	_fill_rect(img, 20, 28, 44, 50, fur)
	# Head
	_fill_rect(img, 24, 18, 40, 34, fur)
	# Ears
	_fill_rect(img, 24, 6, 30, 22, ear)
	_fill_rect(img, 34, 6, 40, 22, ear)
	# Eyes
	_fill_rect(img, 27, 24, 30, 27, eye)
	_fill_rect(img, 34, 24, 37, 27, eye)
	return ImageTexture.create_from_image(img)


func _icon_wheat() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stem := Color(0.35, 0.55, 0.2)
	var head := Color(0.92, 0.78, 0.25)
	_fill_rect(img, 30, 28, 34, 54, stem)
	for i in range(5):
		var y := 12 + i * 4
		_fill_rect(img, 24, y, 40, y + 3, head)
	return ImageTexture.create_from_image(img)


func _icon_bulb() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var glass := Color(1.0, 0.92, 0.45)
	var base := Color(0.55, 0.55, 0.58)
	# Bulb circle-ish
	for y in range(10, 42):
		for x in range(16, 48):
			var dx := x - 32
			var dy := y - 26
			if dx * dx + dy * dy <= 196:
				img.set_pixel(x, y, glass)
	_fill_rect(img, 26, 40, 38, 52, base)
	_fill_rect(img, 28, 52, 36, 56, base.darkened(0.2))
	return ImageTexture.create_from_image(img)
