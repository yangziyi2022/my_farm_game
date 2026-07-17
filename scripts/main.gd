extends Node3D

const ToolCursor3D = preload("res://scripts/tool_cursor_3d.gd")

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
@onready var save_btn: Button = $UI/Toolbar/SaveBtn
@onready var load_btn: Button = $UI/Toolbar/LoadBtn
@onready var undo_btn: Button = $UI/Toolbar/UndoBtn


func _ready() -> void:
	weather_controller.setup(world_environment, sun_light, fill_light)
	var map_center := grid_manager.get_map_center()
	day_night_cycle.setup(world_environment, sun_light, fill_light, map_center, moon_light)
	day_night_cycle.phase_changed.connect(_on_day_night_phase_changed)
	camera_controller.setup(camera, map_center)
	grid_manager.undo_manager = undo_manager
	placement_controller.setup(grid_manager, camera, undo_manager, inventory_manager, cursor_overlay, tool_cursor)
	inventory_bar.setup(inventory_manager)

	item_palette.item_selected.connect(placement_controller.set_selected_item)
	item_palette.select_tool_activated.connect(_on_select_tool_activated)
	item_palette.hoe_tool_activated.connect(_on_hoe_tool_activated)
	item_palette.harvest_tool_activated.connect(_on_harvest_tool_activated)
	item_palette.rod_tool_activated.connect(_on_rod_tool_activated)
	placement_controller.select_mode_requested.connect(item_palette.activate_select_tool)
	placement_controller.feed_mode_cancelled.connect(inventory_bar.clear_feed_selection)
	placement_controller.status_message.connect(_on_status_message)
	inventory_bar.feed_item_selected.connect(_on_feed_item_selected)
	inventory_bar.feed_selection_cleared.connect(_on_feed_selection_cleared)

	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	undo_btn.pressed.connect(_on_undo)
	undo_manager.stack_changed.connect(_on_undo_stack_changed)
	undo_manager.undo_applied.connect(_on_status_message)

	var time_controls := TimeOfDayControls.new()
	time_controls.name = "TimeOfDayControls"
	$UI.add_child(time_controls)
	time_controls.setup(day_night_cycle, grid_manager)
	time_controls.expand_done.connect(_on_status_message)

	_on_undo_stack_changed(undo_manager.can_undo())
	_on_status_message("Island view: right-drag orbit, middle-drag pan, scroll zoom. Expand (right) grows the floor.")


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


func _on_select_tool_activated() -> void:
	placement_controller.enter_select_mode()


func _on_hoe_tool_activated() -> void:
	placement_controller.enter_hoe_mode()


func _on_harvest_tool_activated() -> void:
	placement_controller.enter_harvest_mode()


func _on_rod_tool_activated() -> void:
	placement_controller.enter_fish_mode()


func _on_feed_item_selected(item: InventoryData.Item) -> void:
	placement_controller.enter_feed_mode(item)


func _on_feed_selection_cleared() -> void:
	if placement_controller.mode == PlacementController.Mode.FEED:
		placement_controller.enter_select_mode()


func _on_undo() -> void:
	placement_controller.perform_undo()


func _on_undo_stack_changed(can_undo: bool) -> void:
	undo_btn.disabled = not can_undo


func _on_status_message(text: String) -> void:
	status_label.text = text


func _on_save() -> void:
	if SaveManager.save_farm(grid_manager, inventory_manager):
		_on_status_message("Farm saved!")
	else:
		_on_status_message("Save failed!")


func _on_load() -> void:
	if SaveManager.load_farm(grid_manager, inventory_manager):
		_on_status_message("Farm loaded!")
	else:
		_on_status_message("No save file found.")
