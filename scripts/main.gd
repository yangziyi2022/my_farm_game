extends Node3D

@onready var grid_manager: GridManager = $GridManager
@onready var camera: Camera3D = $Camera3D
@onready var camera_controller: CameraController = $CameraController
@onready var weather_controller: WeatherController = $WeatherController
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: OmniLight3D = $FillLight
@onready var placement_controller: PlacementController = $PlacementController
@onready var ui_layer: CanvasLayer = $UI
@onready var item_palette: ItemPalette = $UI/ItemPalette
@onready var status_label: Label = $UI/StatusBar/StatusLabel
@onready var save_btn: Button = $UI/Toolbar/SaveBtn
@onready var load_btn: Button = $UI/Toolbar/LoadBtn


func _ready() -> void:
	weather_controller.setup(world_environment, sun_light, fill_light)
	camera_controller.setup(camera)
	placement_controller.setup(grid_manager, camera)
	item_palette.item_selected.connect(placement_controller.set_selected_item)
	item_palette.select_tool_activated.connect(_on_select_tool_activated)
	placement_controller.select_mode_requested.connect(item_palette.activate_select_tool)
	placement_controller.status_message.connect(_on_status_message)
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)

	_on_status_message("Select tool active. Pick an item to place. WASD/middle-drag to pan, scroll to zoom.")


func _on_select_tool_activated() -> void:
	placement_controller.enter_select_mode()


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
