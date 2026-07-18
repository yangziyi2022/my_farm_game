class_name CursorOverlay
extends Control

var _panel: PanelContainer
var _label: Label
var _visible_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.visible = false
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	margin.add_child(_label)


func show_item(text: String, color: Color) -> void:
	_label.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = true
	_visible_active = true


func hide_overlay() -> void:
	_panel.visible = false
	_visible_active = false


func _process(_delta: float) -> void:
	if not _visible_active:
		return
	global_position = PointerInput.get_position() + Vector2(18, 18)
