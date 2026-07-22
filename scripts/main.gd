extends Node3D

const ToolCursor3D = preload("res://scripts/tool_cursor_3d.gd")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var grid_manager: GridManager = $GridManager
@onready var camera: Camera3D = $Camera3D
@onready var camera_controller: CameraController = $CameraController
@onready var weather_controller: WeatherController = $WeatherController
@onready var day_night_cycle: DayNightCycle = $DayNightCycle
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var moon_light: DirectionalLight3D = $MoonLight
@onready var fill_light: OmniLight3D = $FillLight
@onready var undo_manager: UndoManager = $UndoManager
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var placement_controller: PlacementController = $PlacementController
@onready var item_palette: ItemPalette = $UI/ItemPalette
@onready var inventory_bar: InventoryBar = $UI/InventoryBar
@onready var cursor_overlay: CursorOverlay = $UI/CursorOverlay
@onready var tool_cursor: ToolCursor3D = $ToolCursor3D
@onready var status_label: Label = $UI/StatusBar/StatusLabel
@onready var worlds_btn: Button = $UI/Toolbar/WorldsBtn

var _time_controls: TimeOfDayControls
var _walk_mode: WalkModeController
## True when farm differs from last successful save (or never saved after edits).
var _world_dirty: bool = false
var _undo_depth_at_save: int = 0


func _ready() -> void:
	SaveManager.ensure_ready()
	var boot_id := ""
	var boot_is_new := false
	if get_tree().has_meta("boot_world_id"):
		boot_id = str(get_tree().get_meta("boot_world_id"))
		get_tree().remove_meta("boot_world_id")
	if get_tree().has_meta("boot_is_new"):
		boot_is_new = bool(get_tree().get_meta("boot_is_new"))
		get_tree().remove_meta("boot_is_new")

	if boot_id.is_empty():
		boot_id = SaveManager.get_current_world_id()
	if boot_id.is_empty() or not SaveManager.world_exists(boot_id):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	SaveManager.set_current_world_id(boot_id)

	_apply_mobile_performance()
	weather_controller.setup(world_environment, sun_light, fill_light)
	var map_center := grid_manager.get_map_center()
	day_night_cycle.setup(world_environment, sun_light, fill_light, map_center, moon_light)
	day_night_cycle.phase_changed.connect(_on_day_night_phase_changed)
	camera_controller.setup(camera, map_center)
	grid_manager.undo_manager = undo_manager
	placement_controller.setup(grid_manager, camera, undo_manager, inventory_manager, cursor_overlay, tool_cursor)
	inventory_bar.setup(inventory_manager)
	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	inventory_bar.walk_mode_pressed.connect(_on_walk_mode_pressed)

	_walk_mode = WalkModeController.new()
	_walk_mode.name = "WalkModeController"
	add_child(_walk_mode)
	_walk_mode.setup(grid_manager, camera, camera_controller, placement_controller, inventory_manager)
	_walk_mode.status_message.connect(_on_status_message)

	var animal_card := AnimalInfoCard.new()
	animal_card.name = "AnimalInfoCard"
	$UI.add_child(animal_card)
	animal_card.setup(camera)
	placement_controller.animal_info_card = animal_card
	_walk_mode.animal_info_card = animal_card

	item_palette.item_selected.connect(placement_controller.set_selected_item)
	item_palette.select_tool_activated.connect(_on_select_tool_activated)
	item_palette.multiselect_tool_activated.connect(_on_multiselect_tool_activated)
	item_palette.hoe_tool_activated.connect(_on_hoe_tool_activated)
	item_palette.harvest_tool_activated.connect(_on_harvest_tool_activated)
	item_palette.rod_tool_activated.connect(_on_rod_tool_activated)
	item_palette.tool_highlight_changed.connect(_on_palette_tool_highlight)
	placement_controller.select_mode_requested.connect(item_palette.activate_select_tool)
	placement_controller.feed_mode_cancelled.connect(inventory_bar.clear_feed_selection)
	placement_controller.status_message.connect(_on_status_message)
	placement_controller.need_hoe_hint.connect(_on_need_hoe_hint)
	inventory_bar.feed_item_selected.connect(_on_feed_item_selected)
	inventory_bar.feed_selection_cleared.connect(_on_feed_selection_cleared)

	_style_worlds_button()
	worlds_btn.pressed.connect(_on_worlds)
	undo_manager.stack_changed.connect(_on_undo_stack_changed)
	undo_manager.undo_applied.connect(_on_status_message)

	_time_controls = TimeOfDayControls.new()
	_time_controls.name = "TimeOfDayControls"
	$UI.add_child(_time_controls)
	_time_controls.setup(day_night_cycle, grid_manager)
	_time_controls.expand_done.connect(_on_status_message)
	_time_controls.select_pressed.connect(_on_select_pressed)
	_time_controls.multiselect_pressed.connect(_on_multiselect_pressed)
	_time_controls.undo_pressed.connect(_on_undo)
	_time_controls.save_pressed.connect(_on_save)

	# Fix any desynced placeables from earlier rotate/select bugs.
	grid_manager.repair_content_registry()

	if not boot_is_new and SaveManager.world_has_save(boot_id):
		if SaveManager.load_farm(grid_manager, inventory_manager):
			var meta := SaveManager.load_meta(boot_id)
			var wname := str(meta.get("display_name", "Farm"))
			_on_status_message("Loaded \"%s\"" % wname)
			_mark_world_clean()
		else:
			_on_status_message("Could not load world — starting empty")
			_mark_world_clean()
	else:
		var meta := SaveManager.load_meta(boot_id)
		var wname := str(meta.get("display_name", "Farm"))
		_on_status_message("New world \"%s\" — tap Save to keep progress" % wname)
		_mark_world_clean()

	_on_undo_stack_changed(undo_manager.can_undo())
	item_palette.activate_select_tool()
	AudioManager.play_music("day", true)


func _apply_mobile_performance() -> void:
	## iPad/iPhone: lower 3D resolution + cheaper shadows to keep FPS up.
	if not (OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")):
		return
	var vp := get_viewport()
	vp.scaling_3d_scale = 0.65
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if sun_light:
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun_light.directional_shadow_max_distance = 40.0
		sun_light.shadow_blur = 0.35
		# Harder cut: many iPads struggle more with shadows than resolution.
		sun_light.shadow_enabled = false
	if moon_light:
		moon_light.shadow_enabled = false
	if fill_light:
		fill_light.light_energy = 0.18
		fill_light.omni_range = 32.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
	)


func _on_day_night_phase_changed(phase: String) -> void:
	var labels := {
		"dawn": "Dawn",
		"sunrise": "Sunrise",
		"day": "Daytime",
		"sunset": "Sunset",
		"dusk": "Dusk",
		"night": "Night",
		"predawn": "Before dawn",
	}
	var label: String = str(labels.get(phase, phase.capitalize()))
	_on_status_message("%s — 5 min day / 5 min night cycle" % label)


func _style_worlds_button() -> void:
	_apply_btn_colors(worlds_btn, Color(0.45, 0.4, 0.32))
	worlds_btn.focus_mode = Control.FOCUS_NONE


func _apply_btn_colors(btn: Button, tint: Color) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.95)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(tint.r, tint.g, tint.b, 0.4)
	disabled.border_color = Color(1, 1, 1, 0.15)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.96))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.88))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))


func _on_select_pressed() -> void:
	AudioManager.play("ui_click")
	item_palette.activate_select_tool()
	_on_select_tool_activated()


func _on_multiselect_pressed() -> void:
	AudioManager.play("ui_click")
	item_palette.activate_multiselect_tool()
	_on_multiselect_tool_activated()


func _on_palette_tool_highlight(tool: int, item_type: int) -> void:
	var select_on := tool == int(ItemPalette.Tool.SELECT) and item_type == ItemPalette.SELECT_TOOL
	var multi_on := tool == int(ItemPalette.Tool.MULTISELECT)
	if _time_controls:
		_time_controls.set_select_highlight(select_on, multi_on)


func _on_select_tool_activated() -> void:
	placement_controller.enter_select_mode()


func _on_multiselect_tool_activated() -> void:
	placement_controller.enter_multiselect_mode()


func _on_hoe_tool_activated() -> void:
	placement_controller.enter_hoe_mode()


func _on_need_hoe_hint() -> void:
	## Player tried to plant on grass — open Tools → Hoe with a pulse highlight.
	item_palette.guide_to_hoe()
	_on_status_message("Seeds need dirt — use Hoe on grass first, then plant again")


func _on_harvest_tool_activated() -> void:
	placement_controller.enter_harvest_mode()


func _on_rod_tool_activated() -> void:
	placement_controller.enter_fish_mode()


func _on_walk_mode_pressed() -> void:
	AudioManager.play("ui_click")
	if _walk_mode:
		_walk_mode.begin_place_avatar()


func _on_feed_item_selected(item: InventoryData.Item) -> void:
	placement_controller.enter_feed_mode(item)


func _on_feed_selection_cleared() -> void:
	if placement_controller.mode == PlacementController.Mode.FEED:
		placement_controller.enter_select_mode()


func _on_undo() -> void:
	AudioManager.play("ui_click")
	placement_controller.perform_undo()


func _on_undo_stack_changed(can_undo: bool) -> void:
	if _time_controls:
		_time_controls.set_undo_enabled(can_undo)
	_world_dirty = undo_manager.stack_depth() != _undo_depth_at_save


func _on_inventory_changed() -> void:
	# Harvest / rearrange backpack is not on the undo stack.
	_world_dirty = true


func _on_status_message(text: String) -> void:
	status_label.text = text


func _mark_world_clean() -> void:
	_undo_depth_at_save = undo_manager.stack_depth()
	_world_dirty = false


func _on_save() -> void:
	AudioManager.play("ui_click")
	if SaveManager.save_farm(grid_manager, inventory_manager):
		_mark_world_clean()
		var meta := SaveManager.load_meta(SaveManager.get_current_world_id())
		var wname := str(meta.get("display_name", "Farm"))
		_on_status_message("Saved \"%s\"" % wname)
	else:
		_on_status_message("Save failed!")


func _on_worlds() -> void:
	AudioManager.play("ui_click")
	# Already matches last save — leave without nagging.
	if not _world_dirty:
		_go_to_worlds_menu()
		return

	var dlg := ConfirmationDialog.new()
	dlg.title = "Leave World"
	dlg.dialog_text = "Save your farm before returning to Worlds?"
	dlg.ok_button_text = "Save"
	dlg.cancel_button_text = "Cancel"
	dlg.add_button("Don't Save", true, "nosave")
	dlg.confirmed.connect(func() -> void:
		if SaveManager.save_farm(grid_manager, inventory_manager):
			_mark_world_clean()
		dlg.queue_free()
		_go_to_worlds_menu()
	)
	dlg.custom_action.connect(func(action: StringName) -> void:
		if str(action) == "nosave":
			dlg.hide()
			dlg.queue_free()
			_go_to_worlds_menu()
	)
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _go_to_worlds_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
