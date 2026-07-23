@tool
extends VBoxContainer

## Editor dock: one-click bake of inventory item icons.


func _ready() -> void:
	name = "Item Icons"
	custom_minimum_size = Vector2(220, 0)
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Item Icon Baker"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var hint := Label.new()
	hint.text = "Writes PNGs to\nres://assets/icons/items/"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	add_child(hint)

	var bake_btn := Button.new()
	bake_btn.text = "Bake All Inventory Icons"
	bake_btn.pressed.connect(_on_bake_pressed)
	add_child(bake_btn)

	var core_btn := Button.new()
	core_btn.text = "Bake Milk / Wool / Apple"
	core_btn.pressed.connect(_on_bake_core_pressed)
	add_child(core_btn)

	var status := Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)


func _status() -> Label:
	return get_node_or_null("Status") as Label


func _on_bake_pressed() -> void:
	_run_bake(ItemIconBaker.bake_all)


func _on_bake_core_pressed() -> void:
	_run_bake(ItemIconBaker.bake_core)


func _run_bake(fn: Callable) -> void:
	var status := _status()
	if status:
		status.text = "Baking…"
	await get_tree().process_frame
	var result: Dictionary = await fn.call(self)
	if status:
		var n: int = int(result.get("count", 0))
		var err: String = str(result.get("error", ""))
		if err.is_empty():
			status.text = "Done — wrote %d icons." % n
		else:
			status.text = "Done with issues (%d):\n%s" % [n, err]
	# Refresh FileSystem so new PNGs appear.
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
