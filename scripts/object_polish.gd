class_name ObjectPolish
extends RefCounted

const SWAY_PIVOT_NAME := "SwayPivot"
const ANIMAL_PIVOT_NAME := "AnimalPivot"


# Attach ambient life and placement polish without touching core grid logic.
static func setup(obj: Node3D, item_type: ItemData.ItemType, animate_placement: bool = true) -> void:
	# Terrain tiles must stay full size — pop-in scale makes dirt look shrunk.
	if animate_placement and not ItemData.is_terrain(item_type):
		PlacementAnimation.play(obj)

	if ItemData.should_sway(item_type):
		_attach_sway(obj, item_type)

	if ItemData.is_animal(item_type):
		_attach_animal_behavior(obj)

	if ItemData.is_growable_plant(item_type):
		_attach_plant_growth(obj, item_type)

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
	var jet := obj.get_node_or_null("FountainJet") as Node3D
	if jet == null:
		return
	var sway := AmbientSway.new()
	sway.name = "FountainSway"
	sway.sway_angle_deg = 1.2
	sway.sway_speed = 2.4
	sway.bob_amount = 0.02
	jet.add_child(sway)


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


static func _attach_plant_growth(obj: Node3D, item_type: ItemData.ItemType) -> void:
	var growth := CropGrowth.new()
	growth.name = "CropGrowth"
	var start_stage: int = obj.get_meta("growth_stage", 0)
	obj.add_child(growth)
	growth.setup(obj, start_stage)
	growth.stage_changed.connect(_on_plant_stage_changed.bind(obj, item_type))

	if start_stage >= CropGrowth.STAGE_COUNT - 1 \
			and item_type not in [ItemData.ItemType.WHEAT, ItemData.ItemType.CARROT]:
		_attach_flower_sway(obj)


static func _on_plant_stage_changed(obj: Node3D, item_type: ItemData.ItemType, stage: int) -> void:
	# Crops that should stay planted firmly (no soft flower sway).
	if item_type in [ItemData.ItemType.WHEAT, ItemData.ItemType.CARROT]:
		return
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
		ItemData.ItemType.RABBIT:
			controller.walk_speed = 0.48
			controller.wander_radius = 0.34
			controller.idle_time_min = 1.2
			controller.idle_time_max = 3.5
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

	# Move render meshes / packed visuals under the pivot so grid root stays fixed.
	var children := obj.get_children()
	for child in children:
		if child == pivot:
			continue
		if child.name in ["TileCollider", "CropGrowth", "AnimalController", "SpinningBlades", "LampLight", "LampGlow"]:
			continue
		if child is MeshInstance3D:
			child.reparent(pivot)
		elif child is Node3D and child.name == "Visual":
			# Scene-based assets (e.g. Chicken.glb wrapper) live under Visual.
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
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_meshes(child, out)
