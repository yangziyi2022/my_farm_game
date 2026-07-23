class_name AnimalInfoCard
extends Control

## Minimal screen-space card: name + affinity / satiety / mood bars.

const CARD_WIDTH: float = 168.0
const OFFSET := Vector2(18, -110)

var _panel: PanelContainer
var _name_lbl: Label
var _meta_lbl: Label
var _aff_bar: ProgressBar
var _sat_bar: ProgressBar
var _mood_bar: ProgressBar
var _target: Node3D
var _needs: AnimalNeeds
var _life: AnimalLife
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
	style.bg_color = Color(0.12, 0.14, 0.12, 0.82)
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

	_meta_lbl = Label.new()
	_meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_lbl.add_theme_font_size_override("font_size", 11)
	_meta_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.7))
	_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_meta_lbl)

	_aff_bar = _add_stat_row(vbox, LocaleManager.t("Affinity"), Color(0.92, 0.55, 0.62))
	_sat_bar = _add_stat_row(vbox, LocaleManager.t("Satiety"), Color(0.85, 0.72, 0.28))
	_mood_bar = _add_stat_row(vbox, LocaleManager.t("Mood"), Color(0.45, 0.78, 0.55))


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


func show_animal(animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal):
		clear()
		return
	var needs := AnimalInteraction.get_needs(animal)
	if needs == null:
		clear()
		return
	if _needs and _needs != needs and is_instance_valid(_needs):
		if _needs.needs_changed.is_connected(_on_needs_changed):
			_needs.needs_changed.disconnect(_on_needs_changed)
	if _life and is_instance_valid(_life) and _life.life_changed.is_connected(_on_life_changed):
		_life.life_changed.disconnect(_on_life_changed)
	_target = animal
	_needs = needs
	_life = AnimalInteraction.get_life(animal)
	if not _needs.needs_changed.is_connected(_on_needs_changed):
		_needs.needs_changed.connect(_on_needs_changed)
	if _life and not _life.life_changed.is_connected(_on_life_changed):
		_life.life_changed.connect(_on_life_changed)
	_name_lbl.text = AnimalInteraction.get_display_name(animal)
	_refresh_bars()
	_refresh_meta()
	visible = true


func clear() -> void:
	if _needs and is_instance_valid(_needs) and _needs.needs_changed.is_connected(_on_needs_changed):
		_needs.needs_changed.disconnect(_on_needs_changed)
	if _life and is_instance_valid(_life) and _life.life_changed.is_connected(_on_life_changed):
		_life.life_changed.disconnect(_on_life_changed)
	_target = null
	_needs = null
	_life = null
	visible = false


func _on_needs_changed() -> void:
	_refresh_bars()


func _on_life_changed() -> void:
	_refresh_meta()


func _refresh_bars() -> void:
	if _needs == null:
		return
	_aff_bar.value = _needs.affinity
	_sat_bar.value = _needs.satiety
	_mood_bar.value = _needs.mood


func _refresh_meta() -> void:
	if _meta_lbl == null:
		return
	if _life == null:
		_meta_lbl.text = ""
		return
	var bits: PackedStringArray = []
	if _life.is_baby():
		bits.append(LocaleManager.t("Baby"))
	else:
		bits.append(LocaleManager.t("Adult"))
	bits.append(_life.personality_display_name())
	if _life.can_collect_produce():
		bits.append(LocaleManager.t("Ready to collect"))
	_meta_lbl.text = " · ".join(bits)


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
	var screen := _camera.unproject_position(_target.global_position + Vector3(0, 1.1, 0))
	position = screen + OFFSET
