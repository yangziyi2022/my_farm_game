class_name ObjectPolish
extends RefCounted

const SWAY_PIVOT_NAME := "SwayPivot"
const ANIMAL_PIVOT_NAME := "AnimalPivot"


# Attach ambient life and placement polish without touching core grid logic.
static func setup(
	obj: Node3D,
	item_type: ItemData.ItemType,
	animate_placement: bool = true,
	grid_manager: GridManager = null
) -> void:
	# Terrain tiles must stay full size — pop-in scale makes dirt look shrunk.
	if animate_placement and not ItemData.is_terrain(item_type):
		PlacementAnimation.play(obj)

	if ItemData.should_sway(item_type):
		_attach_sway(obj, item_type)

	if ItemData.is_animal(item_type):
		_attach_animal_behavior(obj, item_type, grid_manager)

	if ItemData.is_growable_plant(item_type):
		_attach_plant_growth(obj, item_type, grid_manager)

	if item_type in [ItemData.ItemType.WINDMILL, ItemData.ItemType.WIND_WHEEL]:
		_attach_spinning_blades(obj, 52.0 if item_type == ItemData.ItemType.WIND_WHEEL else 38.0)

	if item_type == ItemData.ItemType.FOUNTAIN:
		_attach_fountain_jet(obj)

	if item_type == ItemData.ItemType.LAMPPOST:
		_attach_lamp_glow(obj)


static func _attach_spinning_blades(obj: Node3D, speed: float) -> void:
	# Procedural builds put BladePivot on the root; glb wrappers nest it under Visual.
	var pivot := obj.get_node_or_null("BladePivot") as Node3D
	if pivot == null:
		pivot = obj.find_child("BladePivot", true, false) as Node3D
	if pivot == null:
		return
	if obj.get_node_or_null("SpinningBlades"):
		return
	var axis := Vector3.UP
	if pivot.has_meta("spin_axis"):
		var meta_axis: Variant = pivot.get_meta("spin_axis")
		if meta_axis is Vector3:
			axis = meta_axis
	var spin := SpinningBlades.new()
	spin.name = "SpinningBlades"
	spin.setup(pivot, speed, axis)
	obj.add_child(spin)


static func _attach_fountain_jet(obj: Node3D) -> void:
	## Prefer markers inside the visual scene; otherwise create a tip above the mesh.
	var visual := obj.get_node_or_null("Visual") as Node3D
	var jet := obj.get_node_or_null("FountainJet") as Node3D
	if jet == null:
		jet = obj.find_child("FountainJet", true, false) as Node3D
	if jet == null and visual:
		jet = Node3D.new()
		jet.name = "FountainJet"
		# Raw stone-fountain top ≈ 0.42; sits under Visual scale.
		jet.position = Vector3(0.0, 0.42, 0.0)
		visual.add_child(jet)

	if jet and jet.get_node_or_null("FountainSway") == null:
		var sway := AmbientSway.new()
		sway.name = "FountainSway"
		sway.sway_angle_deg = 1.0
		sway.sway_speed = 2.2
		sway.bob_amount = 0.015
		jet.add_child(sway)

	if obj.find_child("FountainSplash", true, false) != null:
		return
	var anchor := obj.find_child("FountainSplashAnchor", true, false) as Node3D
	if anchor == null:
		anchor = jet
	if anchor == null:
		return
	var splash := FountainSplash.new()
	splash.name = "FountainSplash"
	var water_color := Color(0.45, 0.72, 0.95, 0.75)
	var info: Dictionary = ItemData.ITEMS.get(ItemData.ItemType.FOUNTAIN, {})
	if info.has("water_color"):
		water_color = info["water_color"]
	anchor.add_child(splash)
	splash.setup(water_color)


static func _attach_lamp_glow(obj: Node3D) -> void:
	## Light sits on the placeable root (not under visual_scale) so range stays correct.
	if obj.get_node_or_null("LampLight"):
		return

	const LAMP_TOP_Y: float = 1.05
	const GLOW_COLOR := Color(1.0, 0.92, 0.55)

	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.light_color = GLOW_COLOR
	light.light_energy = 1.45
	light.omni_range = 4.8
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	light.position = Vector3(0.0, LAMP_TOP_Y, 0.0)
	obj.add_child(light)

	var glow := MeshInstance3D.new()
	glow.name = "LampGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	glow.mesh = sphere
	glow.position = Vector3(0.0, LAMP_TOP_Y, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.7, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = GLOW_COLOR
	mat.emission_energy_multiplier = 2.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = mat
	obj.add_child(glow)

	# Soft emission on the imported mesh near the lamp head.
	_enable_top_mesh_emission(obj, LAMP_TOP_Y - 0.25, GLOW_COLOR)


static func _attach_plant_growth(obj: Node3D, item_type: ItemData.ItemType, grid_manager: GridManager = null) -> void:
	var growth := CropGrowth.new()
	growth.name = "CropGrowth"
	var start_stage: int = obj.get_meta("growth_stage", 0)
	obj.add_child(growth)
	growth.setup(obj, start_stage)
	growth.stage_changed.connect(_on_plant_stage_changed.bind(obj, item_type, grid_manager))

	if start_stage >= CropGrowth.STAGE_COUNT - 1:
		_on_plant_mature(obj, item_type, grid_manager)
		if item_type not in [ItemData.ItemType.WHEAT, ItemData.ItemType.CARROT, ItemData.ItemType.TREE]:
			_attach_flower_sway(obj)


static func _on_plant_stage_changed(
	obj: Node3D,
	item_type: ItemData.ItemType,
	grid_manager: GridManager,
	stage: int
) -> void:
	if stage < CropGrowth.STAGE_COUNT - 1:
		return
	_on_plant_mature(obj, item_type, grid_manager)
	if item_type in [ItemData.ItemType.WHEAT, ItemData.ItemType.CARROT, ItemData.ItemType.TREE]:
		return
	_attach_flower_sway(obj)


static func _on_plant_mature(obj: Node3D, item_type: ItemData.ItemType, grid_manager: GridManager) -> void:
	## Mature trees reclaim the soil as grass under the canopy.
	if item_type != ItemData.ItemType.TREE or grid_manager == null:
		return
	if not is_instance_valid(obj) or not obj.has_meta("grid_pos"):
		return
	var grid_pos: Vector2i = obj.get_meta("grid_pos")
	# Defer so we don't free dirt mid-highlight / mid-signal and trip "previously freed" checks.
	grid_manager.call_deferred("restore_default_grass_at", grid_pos)


static func _attach_flower_sway(obj: Node3D) -> void:
	if obj.get_node_or_null("SwayPivot"):
		return

	var pivot := _create_visual_pivot(obj, SWAY_PIVOT_NAME)
	for child in obj.get_children():
		if not is_instance_valid(child):
			continue
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


static func _attach_animal_behavior(
	obj: Node3D,
	item_type: ItemData.ItemType,
	grid_manager: GridManager = null
) -> void:
	var pivot := _create_visual_pivot(obj, ANIMAL_PIVOT_NAME)
	var controller := AnimalController.new()
	controller.name = "AnimalController"
	_configure_animal(controller, item_type)
	controller.setup(pivot, obj, grid_manager)
	obj.add_child(controller)


static func _configure_animal(controller: AnimalController, item_type: ItemData.ItemType) -> void:
	match item_type:
		ItemData.ItemType.CHICKEN:
			controller.species = AnimalController.Species.CHICKEN
			controller.walk_speed = 0.55
			controller.wander_radius = 0.28
			controller.idle_time_min = 1.2
			controller.idle_time_max = 3.2
			controller.cross_tile_chance = 0.6
			controller.special_chance = 0.45
		ItemData.ItemType.DUCK:
			controller.species = AnimalController.Species.DUCK
			controller.walk_speed = 0.48
			controller.wander_radius = 0.32
			controller.walk_chance = 0.75
			controller.cross_tile_chance = 0.65
			controller.special_chance = 0.4
			controller.idle_time_min = 1.0
			controller.idle_time_max = 2.8
		ItemData.ItemType.RABBIT:
			controller.species = AnimalController.Species.RABBIT
			controller.walk_speed = 0.7
			controller.wander_radius = 0.32
			controller.idle_time_min = 0.8
			controller.idle_time_max = 2.4
			controller.hop_height = 0.16
			controller.cross_tile_chance = 0.7
			controller.special_chance = 0.05
			controller.walk_chance = 0.75
		ItemData.ItemType.PIG:
			controller.species = AnimalController.Species.PIG
			controller.walk_speed = 0.32
			controller.wander_radius = 0.24
			controller.idle_time_min = 2.0
			controller.idle_time_max = 5.0
			controller.cross_tile_chance = 0.45
			controller.special_chance = 0.4
		ItemData.ItemType.SHEEP:
			controller.species = AnimalController.Species.SHEEP
			controller.walk_speed = 0.3
			controller.wander_radius = 0.22
			controller.idle_time_min = 2.5
			controller.idle_time_max = 6.0
			controller.cross_tile_chance = 0.5
			controller.special_chance = 0.45
		ItemData.ItemType.COW:
			controller.species = AnimalController.Species.COW
			controller.walk_speed = 0.24
			controller.wander_radius = 0.2
			controller.idle_time_min = 3.0
			controller.idle_time_max = 7.5
			controller.cross_tile_chance = 0.4
			controller.special_chance = 0.08
		_:
			controller.species = AnimalController.Species.GENERIC
			controller.cross_tile_chance = 0.5


static func _create_visual_pivot(obj: Node3D, pivot_name: String) -> Node3D:
	var existing := obj.get_node_or_null(pivot_name)
	if existing != null and is_instance_valid(existing) and existing is Node3D:
		return existing

	var pivot := Node3D.new()
	pivot.name = pivot_name
	obj.add_child(pivot)

	# Move render meshes / packed visuals under the pivot so grid root stays fixed.
	var children := obj.get_children()
	for child in children:
		if not is_instance_valid(child):
			continue
		if child == pivot:
			continue
		if child.name in [
			"TileCollider", "CropGrowth", "AnimalController",
			"SpinningBlades", "LampLight", "LampGlow", "SelectionFootprint",
			"FootprintOverlay",
		]:
			continue
		if child is MeshInstance3D:
			child.reparent(pivot)
		elif child is Node3D and child.name in ["Visual", "Head"]:
			# Scene wrappers + sheep Head (for graze animation).
			child.reparent(pivot)

	return pivot


static func _enable_top_mesh_emission(obj: Node3D, min_local_y: float, color: Color) -> void:
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(obj, meshes)
	for mi in meshes:
		if mi.name == "LampGlow" or mi.mesh == null:
			continue
		var local_center: Vector3 = obj.to_local(mi.global_transform * mi.get_aabb().get_center())
		if local_center.y < min_local_y:
			continue
		var surface_count: int = mi.mesh.get_surface_count()
		for i in range(surface_count):
			var src: Material = mi.get_active_material(i)
			var mat: BaseMaterial3D
			if src is BaseMaterial3D:
				mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			else:
				mat = StandardMaterial3D.new()
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = maxf(mat.emission_energy_multiplier, 1.8)
			mi.set_surface_override_material(i, mat)


static func _gather_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		if is_instance_valid(child):
			_gather_meshes(child, out)
