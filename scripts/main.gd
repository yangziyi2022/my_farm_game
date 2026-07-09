extends Node3D

@onready var grid_manager: GridManager = $GridManager
@onready var camera: Camera3D = $Camera3D
@onready var camera_controller: CameraController = $CameraController
@onready var weather_controller: WeatherController = $WeatherController
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: OmniLight3D = $FillLight
@onready var undo_manager: UndoManager = $UndoManager
@onready var placement_controller: PlacementController = $PlacementController
@onready var item_palette: ItemPalette = $UI/ItemPalette
@onready var status_label: Label = $UI/StatusBar/StatusLabel
@onready var save_btn: Button = $UI/Toolbar/SaveBtn
@onready var load_btn: Button = $UI/Toolbar/LoadBtn
@onready var undo_btn: Button = $UI/Toolbar/UndoBtn


func _ready() -> void:
	weather_controller.setup(world_environment, sun_light, fill_light)
	camera_controller.setup(camera)
	grid_manager.undo_manager = undo_manager
	placement_controller.setup(grid_manager, camera, undo_manager)

	item_palette.item_selected.connect(placement_controller.set_selected_item)
	item_palette.select_tool_activated.connect(_on_select_tool_activated)
	item_palette.hoe_tool_activated.connect(_on_hoe_tool_activated)
	placement_controller.select_mode_requested.connect(item_palette.activate_select_tool)
	placement_controller.status_message.connect(_on_status_message)

	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	undo_btn.pressed.connect(_on_undo)
	undo_manager.stack_changed.connect(_on_undo_stack_changed)
	undo_manager.undo_applied.connect(_on_status_message)

	_on_undo_stack_changed(undo_manager.can_undo())
	_on_status_message("Place items on grass freely. Hoe dirt only for flower seeds.")


func _on_select_tool_activated() -> void:
	placement_controller.enter_select_mode()


func _on_hoe_tool_activated() -> void:
	placement_controller.enter_hoe_mode()


func _on_undo() -> void:
	placement_controller.perform_undo()


func _on_undo_stack_changed(can_undo: bool) -> void:
	undo_btn.disabled = not can_undo


func _on_status_message(text: String) -> void:
	status_label.text = text


func _on_save() -> void:
	if SaveManager.save_farm(grid_manager):
		_on_status_message("Farm saved!")
	else:
		_on_status_message("Save failed!")


func _on_load() -> void:
	if SaveManager.load_farm(grid_manager):
		_on_status_message("Farm loaded!")
	else:
		_on_status_message("No save file found.")
