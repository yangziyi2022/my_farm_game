class_name ObjectPolish
extends RefCounted

const SWAY_PIVOT_NAME := "SwayPivot"
const ANIMAL_PIVOT_NAME := "AnimalPivot"


# Attach ambient life and placement polish without touching core grid logic.
static func setup(obj: Node3D, item_type: ItemData.ItemType, animate_placement: bool = true) -> void:
	if animate_placement:
		PlacementAnimation.play(obj)

	if ItemData.should_sway(item_type):
		_attach_sway(obj, item_type)

	if ItemData.is_animal(item_type):
		_attach_animal_behavior(obj)

	if ItemData.is_growable_plant(item_type):
		_attach_plant_growth(obj, item_type)


static func _attach_plant_growth(obj: Node3D, item_type: ItemData.ItemType) -> void:
	var growth := CropGrowth.new()
	growth.name = "CropGrowth"
	var start_stage: int = obj.get_meta("growth_stage", 0)
	obj.add_child(growth)
	growth.setup(obj, start_stage)
	growth.stage_changed.connect(_on_plant_stage_changed.bind(obj, item_type))

	if start_stage >= CropGrowth.STAGE_COUNT - 1:
		_attach_flower_sway(obj)


static func _on_plant_stage_changed(obj: Node3D, item_type: ItemData.ItemType, stage: int) -> void:
	if stage >= CropGrowth.STAGE_COUNT - 1:
		_attach_flower_sway(obj)


static func _attach_flower_sway(obj: Node3D) -> void:
	if obj.get_node_or_null("SwayPivot"):
		return

	var pivot := _create_visual_pivot(obj, SWAY_PIVOT_NAME)
	for child in obj.get_children():
		if child == pivot or child.name in ["TileCollider", "CropGrowth", "AnimalController"]:
			continue
		if child is Node3D and str(child.name).begins_with("Stage"):
			child.reparent(pivot)

	var sway := AmbientSway.new()
	sway.name = "AmbientSway"
	sway.sway_angle_deg = 2.2
	sway.sway_speed = 1.1
	pivot.add_child(sway)


static func _attach_sway(obj: Node3D, item_type: ItemData.ItemType) -> void:
	var pivot := _create_visual_pivot(obj, SWAY_PIVOT_NAME)
	var sway := AmbientSway.new()
	sway.name = "AmbientSway"

	# Grass tiles sway more subtly than tall plants.
	if item_type == ItemData.ItemType.GRASS:
		sway.sway_angle_deg = 0.8
		sway.sway_speed = 0.9
		sway.bob_amount = 0.004
	elif item_type == ItemData.ItemType.CROP_BED:
		sway.sway_angle_deg = 1.6
		sway.sway_speed = 1.0
	elif item_type == ItemData.ItemType.TREE:
		sway.sway_angle_deg = 1.4
		sway.sway_speed = 0.85
	else:
		sway.sway_angle_deg = 2.4
		sway.sway_speed = 1.15

	pivot.add_child(sway)


static func _attach_animal_behavior(obj: Node3D) -> void:
	var pivot := _create_visual_pivot(obj, ANIMAL_PIVOT_NAME)
	var controller := AnimalController.new()
	controller.name = "AnimalController"
	_configure_animal(controller, obj.get_meta("item_type"))
	controller.setup(pivot)
	obj.add_child(controller)


static func _configure_animal(controller: AnimalController, item_type: ItemData.ItemType) -> void:
	match item_type:
		ItemData.ItemType.CHICKEN:
			controller.walk_speed = 0.42
			controller.wander_radius = 0.3
			controller.idle_time_min = 1.8
			controller.idle_time_max = 4.5
		ItemData.ItemType.DUCK:
			controller.walk_speed = 0.38
			controller.wander_radius = 0.32
			controller.walk_chance = 0.65
		ItemData.ItemType.PIG:
			controller.walk_speed = 0.3
			controller.wander_radius = 0.26
		ItemData.ItemType.SHEEP:
			controller.walk_speed = 0.28
			controller.wander_radius = 0.24
			controller.idle_time_min = 3.0
			controller.idle_time_max = 7.0
		ItemData.ItemType.COW:
			controller.walk_speed = 0.22
			controller.wander_radius = 0.22
			controller.idle_time_min = 3.5
			controller.idle_time_max = 8.0


static func _create_visual_pivot(obj: Node3D, pivot_name: String) -> Node3D:
	var existing := obj.get_node_or_null(pivot_name)
	if existing is Node3D:
		return existing

	var pivot := Node3D.new()
	pivot.name = pivot_name
	obj.add_child(pivot)

	# Move render meshes under the pivot so grid position/rotation stay stable.
	var children := obj.get_children()
	for child in children:
		if child == pivot:
			continue
		if child is MeshInstance3D:
			child.reparent(pivot)

	return pivot
