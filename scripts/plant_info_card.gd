class_name PlantInfoCard
extends Control

## Screen-space card for aimed plants: stage + growth + fertilized.

const CARD_WIDTH: float = 168.0
const OFFSET := Vector2(18, -110)

var _panel: PanelContainer
var _name_lbl: Label
var _stage_lbl: Label
var _growth_bar: ProgressBar
var _fert_lbl: Label
var _target: Node3D
var _growth: CropGrowth
var _camera: Camera3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func setup(camera: Camera3D) -> void:
	_camera = camera


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.15, 0.11, 0.84)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_name_lbl = Label.new()
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	vbox.add_child(_name_lbl)

	_stage_lbl = Label.new()
	_stage_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_lbl.add_theme_font_size_override("font_size", 11)
	_stage_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.72))
	vbox.add_child(_stage_lbl)

	_growth_bar = _add_stat_row(vbox, LocaleManager.t("Growth"), Color(0.48, 0.78, 0.42))

	_fert_lbl = Label.new()
	_fert_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fert_lbl.add_theme_font_size_override("font_size", 11)
	_fert_lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.42))
	vbox.add_child(_fert_lbl)


func _add_stat_row(parent: VBoxContainer, label_text: String, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(52, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.22, 0.24, 0.22, 0.9)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	return bar


func show_plant(plant: Node3D) -> void:
	if plant == null or not is_instance_valid(plant):
		clear()
		return
	var growth := plant.get_node_or_null("CropGrowth") as CropGrowth
	if growth == null:
		clear()
		return
	if _growth and _growth != growth and is_instance_valid(_growth):
		if _growth.growth_changed.is_connected(_on_growth_changed):
			_growth.growth_changed.disconnect(_on_growth_changed)
	_target = plant
	_growth = growth
	if not _growth.growth_changed.is_connected(_on_growth_changed):
		_growth.growth_changed.connect(_on_growth_changed)
	_name_lbl.text = ItemData.get_item_name(plant.get_meta("item_type"))
	_refresh()
	visible = true


func clear() -> void:
	if _growth and is_instance_valid(_growth) and _growth.growth_changed.is_connected(_on_growth_changed):
		_growth.growth_changed.disconnect(_on_growth_changed)
	_target = null
	_growth = null
	visible = false


func _on_growth_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _growth == null:
		return
	var stage := _growth.get_stage()
	if _growth.is_mature():
		_stage_lbl.text = LocaleManager.t("Ready to harvest")
		_growth_bar.value = 100.0
	else:
		_stage_lbl.text = LocaleManager.tf("Stage %d / %d", [stage + 1, CropGrowth.STAGE_COUNT])
		_growth_bar.value = _growth.get_total_progress()
	_fert_lbl.text = (
		LocaleManager.t("Fertilized (faster)")
		if _growth.is_fertilized()
		else LocaleManager.t("Not fertilized")
	)
	_fert_lbl.visible = not _growth.is_mature() or _growth.is_fertilized()


func _process(_delta: float) -> void:
	if not visible or _target == null or not is_instance_valid(_target):
		if visible:
			clear()
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	if _camera.is_position_behind(_target.global_position):
		clear()
		return
	var screen := _camera.unproject_position(_target.global_position + Vector3(0, 0.85, 0))
	position = screen + OFFSET
