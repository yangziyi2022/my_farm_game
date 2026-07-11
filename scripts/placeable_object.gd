class_name PlaceableObject
extends Node3D

## Generic placeable root used by GridManager.
## Visuals come from PlaceableItemDef.visual_scene when assigned;
## otherwise procedural placeholder meshes are built as a fallback.


static func create(item_type: ItemData.ItemType, grid_pos: Vector2i, rotation: int = 0, growth_stage: int = 0) -> PlaceableObject:
	var obj := PlaceableObject.new()
	obj.name = "Object_%s_%d_%d" % [ItemData.get_item_id(item_type), grid_pos.x, grid_pos.y]
	obj.set_meta("item_type", item_type)
	obj.set_meta("grid_pos", grid_pos)
	obj.set_meta("rotation", rotation)
	obj.set_meta("growth_stage", growth_stage)
	obj.rotation.y = deg_to_rad(rotation * 90.0)
	obj._attach_visual(item_type, growth_stage)
	return obj


func _attach_visual(item_type: ItemData.ItemType, growth_stage: int = 0) -> void:
	var scene := ItemData.get_visual_scene(item_type)
	if scene:
		var visual: Node3D = scene.instantiate() as Node3D
		visual.name = "Visual"
		var def := ItemData.get_item_def(item_type)
		if def:
			var s: float = def.visual_scale
			visual.scale = Vector3(s, s, s)
			visual.position.y = def.visual_y_offset
		add_child(visual)
		return

	# Fallback: keep existing procedural builders so gameplay never breaks.
	_build_procedural(item_type, growth_stage)


func _build_procedural(item_type: ItemData.ItemType, _growth_stage: int = 0) -> void:
	var info: Dictionary = ItemData.ITEMS[item_type]
	match item_type:
		ItemData.ItemType.TREE:
			_build_tree(self, info)
		ItemData.ItemType.SHED:
			_build_shed(self, info)
		ItemData.ItemType.HOUSE:
			_build_house(self, info)
		ItemData.ItemType.BARN:
			_build_barn(self, info)
		ItemData.ItemType.WINDMILL:
			_build_windmill(self, info)
		ItemData.ItemType.GRANARY:
			_build_granary(self, info)
		ItemData.ItemType.BRIDGE:
			_build_bridge(self, info)
		ItemData.ItemType.LAMPPOST:
			_build_lamppost(self, info)
		ItemData.ItemType.WELL:
			_build_well(self, info)
		ItemData.ItemType.CROP_BED:
			_build_crop_bed(self, info)
		ItemData.ItemType.COW:
			_build_cow(self, info)
		ItemData.ItemType.CHICKEN:
			_build_chicken(self, info)
		ItemData.ItemType.SHEEP:
			_build_sheep(self, info)
		ItemData.ItemType.PIG:
			_build_pig(self, info)
		ItemData.ItemType.DUCK:
			_build_duck(self, info)
		ItemData.ItemType.FLOWER_RED, ItemData.ItemType.FLOWER_YELLOW, ItemData.ItemType.TULIP:
			_build_growing_flower(self, info, false)
		ItemData.ItemType.SUNFLOWER:
			_build_growing_flower(self, info, true)
		ItemData.ItemType.WHEAT:
			_build_growing_wheat(self, info)
		ItemData.ItemType.STONE_PATH:
			_build_stone_path(self, info)
		ItemData.ItemType.GREENHOUSE:
			_build_greenhouse(self, info)
		ItemData.ItemType.POND:
			_build_pond(self, info)
		ItemData.ItemType.FOUNTAIN:
			_build_fountain(self, info)
		ItemData.ItemType.WIND_WHEEL:
			_build_wind_wheel(self, info)
		ItemData.ItemType.LOOKOUT_TOWER:
			_build_lookout_tower(self, info)
		ItemData.ItemType.FENCE:
			_build_box(self, info)
		_:
			_build_box(self, info)


static func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.position = pos
	mesh_inst.rotation_degrees = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)
	return mesh_inst


static func _build_box(parent: Node3D, info: Dictionary) -> void:
	var size: Vector3 = info["size"]
	# Terrain fills the whole cell so adjacent dirt/water tiles join with no gap.
	if info.get("category") == ItemData.Category.TERRAIN:
		size = Vector3(GridManager.TILE_WIDTH, size.y, GridManager.TILE_HEIGHT)
	var box := BoxMesh.new()
	box.size = size
	_add_mesh(parent, box, info["color"], Vector3(0.0, info.get("offset_y", size.y * 0.5), 0.0))


static func _build_tree(parent: Node3D, info: Dictionary) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.15
	trunk_mesh.height = 0.5
	_add_mesh(parent, trunk_mesh, info.get("trunk_color", Color(0.45, 0.3, 0.15)), Vector3(0.0, 0.25, 0.0))

	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = 0.4
	foliage_mesh.height = 0.7
	_add_mesh(parent, foliage_mesh, info["color"], Vector3(0.0, 0.75, 0.0))


static func _build_shed(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.2, 0.8, 1.2)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.4, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.4, 0.15, 1.4)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.5, 0.2, 0.15)), Vector3(0.0, 0.88, 0.0))


static func _build_house(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.4, 0.9, 1.2)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.45, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.55, 0.12, 1.35)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.5, 0.25, 0.15)), Vector3(0.0, 0.98, 0.0))

	var roof_peak_mesh := BoxMesh.new()
	roof_peak_mesh.size = Vector3(1.2, 0.12, 0.9)
	_add_mesh(parent, roof_peak_mesh, info.get("roof_color", Color(0.5, 0.25, 0.15)), Vector3(0.0, 1.12, 0.0), Vector3(-28.0, 0.0, 0.0))

	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.28, 0.45, 0.05)
	_add_mesh(parent, door_mesh, info.get("door_color", Color(0.4, 0.25, 0.15)), Vector3(0.0, 0.28, 0.63))

	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.22, 0.22, 0.05)
	_add_mesh(parent, window_mesh, info.get("window_color", Color(0.5, 0.7, 0.9)), Vector3(-0.35, 0.55, 0.63))
	_add_mesh(parent, window_mesh, info.get("window_color", Color(0.5, 0.7, 0.9)), Vector3(0.35, 0.55, 0.63))


static func _build_barn(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.6, 1.0, 1.2)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.5, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.75, 0.12, 1.35)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.35, 0.18, 0.12)), Vector3(0.0, 1.08, 0.0))

	var roof_peak_mesh := BoxMesh.new()
	roof_peak_mesh.size = Vector3(1.4, 0.12, 1.0)
	_add_mesh(parent, roof_peak_mesh, info.get("roof_color", Color(0.35, 0.18, 0.12)), Vector3(0.0, 1.25, 0.0), Vector3(-32.0, 0.0, 0.0))

	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.55, 0.7, 0.06)
	_add_mesh(parent, door_mesh, info.get("door_color", Color(0.5, 0.32, 0.2)), Vector3(0.0, 0.4, 0.64))


static func _build_windmill(parent: Node3D, info: Dictionary) -> void:
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.45
	tower_mesh.bottom_radius = 0.55
	tower_mesh.height = 1.4
	_add_mesh(parent, tower_mesh, info["color"], Vector3(0.0, 0.7, 0.0))

	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 0.55
	roof_mesh.height = 0.35
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.55, 0.28, 0.18)), Vector3(0.0, 1.55, 0.0))

	var blade_pivot := Node3D.new()
	blade_pivot.name = "BladePivot"
	blade_pivot.position = Vector3(0.0, 1.1, 0.55)
	parent.add_child(blade_pivot)

	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 0.1
	hub_mesh.height = 0.1
	_add_mesh(blade_pivot, hub_mesh, info.get("blade_color", Color(0.75, 0.75, 0.78)), Vector3.ZERO)

	for i in range(4):
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.08, 0.7, 0.14)
		var angle := deg_to_rad(i * 90.0)
		var pos := Vector3(sin(angle) * 0.35, 0.0, cos(angle) * 0.35)
		var mesh_inst := _add_mesh(blade_pivot, blade_mesh, info.get("blade_color", Color(0.75, 0.75, 0.78)), pos)
		mesh_inst.rotation.y = angle


static func _build_granary(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.3, 1.0, 1.1)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.5, 0.0))

	var silo_mesh := CylinderMesh.new()
	silo_mesh.top_radius = 0.35
	silo_mesh.bottom_radius = 0.4
	silo_mesh.height = 0.9
	_add_mesh(parent, silo_mesh, Color(0.78, 0.74, 0.62), Vector3(0.45, 0.55, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.45, 0.12, 1.25)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.48, 0.32, 0.22)), Vector3(0.0, 1.06, 0.0))

	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.35, 0.5, 0.05)
	_add_mesh(parent, door_mesh, info.get("door_color", Color(0.45, 0.3, 0.18)), Vector3(-0.2, 0.3, 0.58))


static func _build_bridge(parent: Node3D, info: Dictionary) -> void:
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(1.1, 0.08, 0.75)
	_add_mesh(parent, deck_mesh, info["color"], Vector3(0.0, 0.12, 0.0))

	for side in [-1.0, 1.0]:
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(1.1, 0.12, 0.06)
		_add_mesh(parent, rail_mesh, info.get("rail_color", Color(0.45, 0.3, 0.15)), Vector3(0.0, 0.28, side * 0.34))


static func _build_lamppost(parent: Node3D, info: Dictionary) -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.04
	pole_mesh.bottom_radius = 0.05
	pole_mesh.height = 0.9
	_add_mesh(parent, pole_mesh, info["color"], Vector3(0.0, 0.45, 0.0))

	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.1
	lamp_mesh.height = 0.12
	var lamp := _add_mesh(parent, lamp_mesh, info.get("light_color", Color(0.95, 0.9, 0.6)), Vector3(0.0, 0.92, 0.0))
	var lamp_mat: StandardMaterial3D = lamp.material_override
	lamp_mat.emission_enabled = true
	lamp_mat.emission = info.get("light_color", Color(0.95, 0.9, 0.6))
	lamp_mat.emission_energy_multiplier = 0.6


static func _build_well(parent: Node3D, info: Dictionary) -> void:
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.4
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.35
	_add_mesh(parent, base_mesh, info["color"], Vector3(0.0, 0.2, 0.0))

	for i in range(4):
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.04
		post_mesh.bottom_radius = 0.05
		post_mesh.height = 0.55
		var angle := deg_to_rad(45.0 + i * 90.0)
		var pos := Vector3(cos(angle) * 0.32, 0.55, sin(angle) * 0.32)
		_add_mesh(parent, post_mesh, info["color"], pos)

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(0.85, 0.08, 0.85)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.55, 0.28, 0.18)), Vector3(0.0, 0.86, 0.0))


static func _build_crop_bed(parent: Node3D, info: Dictionary) -> void:
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = info["size"]
	_add_mesh(parent, bed_mesh, info["color"], Vector3(0.0, info.get("offset_y", 0.075), 0.0))

	var crop_mesh := BoxMesh.new()
	crop_mesh.size = Vector3(0.15, 0.3, 0.15)
	_add_mesh(parent, crop_mesh, info.get("crop_color", Color(0.3, 0.75, 0.2)), Vector3(-0.2, 0.25, -0.2))
	_add_mesh(parent, crop_mesh, info.get("crop_color", Color(0.3, 0.75, 0.2)), Vector3(0.2, 0.25, 0.2))


static func _build_growing_flower(parent: Node3D, info: Dictionary, is_sunflower: bool) -> void:
	var dirt_mesh := BoxMesh.new()
	dirt_mesh.size = Vector3(1.0, 0.1, 1.0)
	_add_mesh(parent, dirt_mesh, info.get("dirt_color", Color(0.55, 0.38, 0.22)), Vector3(0.0, 0.05, 0.0))

	for stage in range(4):
		var stage_node := _make_flower_stage(info, stage, is_sunflower)
		parent.add_child(stage_node)


static func _make_flower_stage(info: Dictionary, stage: int, is_sunflower: bool) -> Node3D:
	var node := Node3D.new()
	node.name = "Stage%d" % stage

	match stage:
		0:
			var seed_mesh := SphereMesh.new()
			seed_mesh.radius = 0.04
			_add_mesh(node, seed_mesh, Color(0.45, 0.32, 0.18), Vector3(0.0, 0.1, 0.0))
		1:
			var sprout_mesh := BoxMesh.new()
			sprout_mesh.size = Vector3(0.05, 0.12, 0.05)
			_add_mesh(node, sprout_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.13, 0.0))
		2:
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.018
			stem_mesh.bottom_radius = 0.022
			stem_mesh.height = 0.22
			_add_mesh(node, stem_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.16, 0.0))
			var bud_mesh := SphereMesh.new()
			bud_mesh.radius = 0.05
			bud_mesh.height = 0.08
			_add_mesh(node, bud_mesh, info["color"], Vector3(0.0, 0.3, 0.0))
		3:
			if is_sunflower:
				_build_sunflower(node, info)
			else:
				_build_flower(node, info)

	return node


static func _build_growing_wheat(parent: Node3D, info: Dictionary) -> void:
	var dirt_mesh := BoxMesh.new()
	dirt_mesh.size = Vector3(1.0, 0.1, 1.0)
	_add_mesh(parent, dirt_mesh, info.get("dirt_color", Color(0.55, 0.38, 0.22)), Vector3(0.0, 0.05, 0.0))

	for stage in range(4):
		var stage_node := _make_wheat_stage(info, stage)
		parent.add_child(stage_node)


static func _make_wheat_stage(info: Dictionary, stage: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Stage%d" % stage
	match stage:
		0:
			var seed_mesh := SphereMesh.new()
			seed_mesh.radius = 0.04
			_add_mesh(node, seed_mesh, Color(0.45, 0.32, 0.18), Vector3(0.0, 0.1, 0.0))
		1:
			var sprout_mesh := BoxMesh.new()
			sprout_mesh.size = Vector3(0.05, 0.14, 0.05)
			_add_mesh(node, sprout_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.14, 0.0))
		2:
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.015
			stem_mesh.bottom_radius = 0.02
			stem_mesh.height = 0.3
			_add_mesh(node, stem_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.2, 0.0))
			var leaf_mesh := BoxMesh.new()
			leaf_mesh.size = Vector3(0.14, 0.05, 0.08)
			_add_mesh(node, leaf_mesh, info["color"], Vector3(0.08, 0.28, 0.0), Vector3(0.0, 0.0, 20.0))
		3:
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.02
			stem_mesh.bottom_radius = 0.025
			stem_mesh.height = 0.42
			_add_mesh(node, stem_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.24, 0.0))
			for i in range(3):
				var head_mesh := BoxMesh.new()
				head_mesh.size = Vector3(0.08, 0.16, 0.06)
				_add_mesh(node, head_mesh, info["color"], Vector3(-0.1 + i * 0.1, 0.5, 0.0))
	return node


static func _build_cow(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.55, 1.3)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.38, 0.0))

	var spot_mesh := BoxMesh.new()
	spot_mesh.size = Vector3(0.25, 0.2, 0.25)
	_add_mesh(parent, spot_mesh, info.get("spot_color", Color(0.2, 0.2, 0.2)), Vector3(0.15, 0.5, 0.1))

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.35, 0.3, 0.35)
	_add_mesh(parent, head_mesh, info["color"], Vector3(0.0, 0.45, 0.75))

	for x in [-0.28, 0.28]:
		for z in [-0.4, 0.4]:
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.06
			leg_mesh.bottom_radius = 0.07
			leg_mesh.height = 0.22
			_add_mesh(parent, leg_mesh, info.get("spot_color", Color(0.2, 0.2, 0.2)), Vector3(x, 0.11, z))


static func _build_chicken(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.28
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.18, 0.0))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.1
	head_mesh.height = 0.16
	_add_mesh(parent, head_mesh, info["color"], Vector3(0.0, 0.3, 0.12))

	var comb_mesh := BoxMesh.new()
	comb_mesh.size = Vector3(0.06, 0.08, 0.04)
	_add_mesh(parent, comb_mesh, info.get("comb_color", Color(0.8, 0.1, 0.1)), Vector3(0.0, 0.38, 0.12))

	var beak_mesh := BoxMesh.new()
	beak_mesh.size = Vector3(0.06, 0.04, 0.08)
	_add_mesh(parent, beak_mesh, Color(0.9, 0.6, 0.1), Vector3(0.0, 0.28, 0.2))


static func _build_sheep(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 0.5
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.32, 0.0))

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.22, 0.2, 0.22)
	_add_mesh(parent, head_mesh, info.get("face_color", Color(0.3, 0.3, 0.3)), Vector3(0.0, 0.3, 0.35))


static func _build_pig(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.7, 0.45, 0.95)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.3, 0.0))

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.35, 0.3, 0.3)
	_add_mesh(parent, head_mesh, info["color"], Vector3(0.0, 0.32, 0.55))

	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.08
	nose_mesh.bottom_radius = 0.08
	nose_mesh.height = 0.06
	_add_mesh(parent, nose_mesh, info.get("nose_color", Color(0.9, 0.5, 0.55)), Vector3(0.0, 0.28, 0.72), Vector3(90.0, 0.0, 0.0))


static func _build_duck(parent: Node3D, info: Dictionary) -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.28
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.2, 0.0))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.11
	head_mesh.height = 0.16
	_add_mesh(parent, head_mesh, info["color"], Vector3(0.0, 0.3, 0.16))

	var beak_mesh := BoxMesh.new()
	beak_mesh.size = Vector3(0.1, 0.05, 0.08)
	_add_mesh(parent, beak_mesh, info.get("beak_color", Color(0.9, 0.55, 0.15)), Vector3(0.0, 0.27, 0.26))


static func _build_flower(parent: Node3D, info: Dictionary) -> void:
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.02
	stem_mesh.bottom_radius = 0.025
	stem_mesh.height = 0.28
	_add_mesh(parent, stem_mesh, info.get("stem_color", Color(0.2, 0.55, 0.2)), Vector3(0.0, 0.14, 0.0))

	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = 0.1
	petal_mesh.height = 0.12
	_add_mesh(parent, petal_mesh, info["color"], Vector3(0.0, 0.32, 0.0))


static func _build_sunflower(parent: Node3D, info: Dictionary) -> void:
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 0.45
	_add_mesh(parent, stem_mesh, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.22, 0.0))

	var center_mesh := CylinderMesh.new()
	center_mesh.top_radius = 0.1
	center_mesh.bottom_radius = 0.1
	center_mesh.height = 0.05
	_add_mesh(parent, center_mesh, info.get("center_color", Color(0.45, 0.32, 0.12)), Vector3(0.0, 0.48, 0.0))

	for i in range(8):
		var angle := deg_to_rad(i * 45.0)
		var petal_mesh := BoxMesh.new()
		petal_mesh.size = Vector3(0.1, 0.04, 0.18)
		var pos := Vector3(cos(angle) * 0.14, 0.48, sin(angle) * 0.14)
		var mesh_inst := _add_mesh(parent, petal_mesh, info["color"], pos)
		mesh_inst.rotation.y = angle


static func _build_stone_path(parent: Node3D, info: Dictionary) -> void:
	var tw := GridManager.TILE_WIDTH
	var th := GridManager.TILE_HEIGHT
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(tw, 0.08, th)
	_add_mesh(parent, base_mesh, info["color"], Vector3(0.0, 0.04, 0.0))

	var stone_color: Color = info.get("stone_color", Color(0.72, 0.7, 0.68))
	var sx := tw / 1.0
	var sz := th / 1.0
	var offsets := [
		Vector3(-0.28 * sx, 0.1, -0.22 * sz), Vector3(0.12 * sx, 0.1, -0.3 * sz),
		Vector3(0.32 * sx, 0.1, 0.05 * sz), Vector3(-0.08 * sx, 0.1, 0.28 * sz),
		Vector3(0.22 * sx, 0.1, 0.32 * sz), Vector3(-0.32 * sx, 0.1, 0.12 * sz),
	]
	for i in range(offsets.size()):
		var offset: Vector3 = offsets[i]
		var stone_mesh := BoxMesh.new()
		var size_scale := (0.18 + float(i % 3) * 0.04) * minf(sx, sz)
		stone_mesh.size = Vector3(size_scale, 0.05, size_scale - 0.02)
		_add_mesh(parent, stone_mesh, stone_color, offset)


static func _build_greenhouse(parent: Node3D, info: Dictionary) -> void:
	var frame_color: Color = info.get("frame_color", Color(0.75, 0.72, 0.68))
	var glass_color: Color = info["color"]
	var roof_color: Color = info.get("roof_color", glass_color)

	for side in [-1.0, 1.0]:
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(0.06, 0.75, 1.2)
		_add_mesh(parent, wall_mesh, frame_color, Vector3(side * 0.62, 0.42, 0.0))

		var glass_mesh := BoxMesh.new()
		glass_mesh.size = Vector3(0.04, 0.68, 1.05)
		var glass := _add_mesh(parent, glass_mesh, glass_color, Vector3(side * 0.58, 0.42, 0.0))
		var glass_mat: StandardMaterial3D = glass.material_override
		glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for side in [-1.0, 1.0]:
		var end_frame := BoxMesh.new()
		end_frame.size = Vector3(1.1, 0.75, 0.06)
		_add_mesh(parent, end_frame, frame_color, Vector3(0.0, 0.42, side * 0.58))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.25, 0.06, 1.25)
	var roof := _add_mesh(parent, roof_mesh, roof_color, Vector3(0.0, 0.82, 0.0))
	var roof_mat: StandardMaterial3D = roof.material_override
	roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.35, 0.5, 0.05)
	_add_mesh(parent, door_mesh, frame_color.darkened(0.15), Vector3(0.0, 0.3, 0.62))


static func _build_pond(parent: Node3D, info: Dictionary) -> void:
	var rim_color: Color = info.get("rim_color", Color(0.52, 0.5, 0.48))
	for i in range(10):
		var angle := deg_to_rad(i * 36.0)
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = Vector3(0.22, 0.1, 0.14)
		var pos := Vector3(cos(angle) * 0.42, 0.06, sin(angle) * 0.42)
		var rim := _add_mesh(parent, rim_mesh, rim_color, pos)
		rim.rotation.y = angle

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.38
	water_mesh.bottom_radius = 0.34
	water_mesh.height = 0.06
	var water := _add_mesh(parent, water_mesh, info["color"], Vector3(0.0, 0.05, 0.0))
	water.scale = Vector3(1.15, 1.0, 0.85)
	var water_mat: StandardMaterial3D = water.material_override
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.15
	water_mat.metallic = 0.05

	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = 0.28
	inner_mesh.bottom_radius = 0.26
	inner_mesh.height = 0.04
	var inner := _add_mesh(parent, inner_mesh, Color(0.15, 0.42, 0.78, 0.7), Vector3(0.08, 0.07, -0.05))
	inner.scale = Vector3(1.2, 1.0, 0.75)


static func _build_fountain(parent: Node3D, info: Dictionary) -> void:
	var basin_mesh := CylinderMesh.new()
	basin_mesh.top_radius = 0.42
	basin_mesh.bottom_radius = 0.38
	basin_mesh.height = 0.18
	_add_mesh(parent, basin_mesh, info["color"], Vector3(0.0, 0.12, 0.0))

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.34
	water_mesh.bottom_radius = 0.32
	water_mesh.height = 0.06
	var water := _add_mesh(parent, water_mesh, info.get("water_color", Color(0.35, 0.62, 0.9, 0.75)), Vector3(0.0, 0.16, 0.0))
	var water_mat: StandardMaterial3D = water.material_override
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.06
	pillar_mesh.bottom_radius = 0.08
	pillar_mesh.height = 0.45
	_add_mesh(parent, pillar_mesh, info["color"].lightened(0.08), Vector3(0.0, 0.38, 0.0))

	var jet := Node3D.new()
	jet.name = "FountainJet"
	jet.position = Vector3(0.0, 0.62, 0.0)
	parent.add_child(jet)

	var jet_mesh := CylinderMesh.new()
	jet_mesh.top_radius = 0.02
	jet_mesh.bottom_radius = 0.05
	jet_mesh.height = 0.22
	var jet_inst := _add_mesh(jet, jet_mesh, info.get("water_color", Color(0.35, 0.62, 0.9, 0.75)), Vector3.ZERO)
	var jet_mat: StandardMaterial3D = jet_inst.material_override
	jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var top_mesh := SphereMesh.new()
	top_mesh.radius = 0.06
	top_mesh.height = 0.08
	_add_mesh(jet, top_mesh, info.get("water_color", Color(0.45, 0.72, 0.95, 0.8)), Vector3(0.0, 0.14, 0.0))


static func _build_wind_wheel(parent: Node3D, info: Dictionary) -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.04
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = 1.2
	_add_mesh(parent, pole_mesh, info["color"], Vector3(0.0, 0.6, 0.0))

	var blade_pivot := Node3D.new()
	blade_pivot.name = "BladePivot"
	blade_pivot.position = Vector3(0.0, 1.22, 0.0)
	parent.add_child(blade_pivot)

	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 0.06
	hub_mesh.height = 0.06
	_add_mesh(blade_pivot, hub_mesh, info.get("blade_color", Color(0.88, 0.85, 0.78)), Vector3.ZERO)

	for i in range(4):
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.05, 0.55, 0.1)
		var angle := deg_to_rad(i * 90.0)
		var pos := Vector3(sin(angle) * 0.28, 0.0, cos(angle) * 0.28)
		var mesh_inst := _add_mesh(blade_pivot, blade_mesh, info.get("blade_color", Color(0.88, 0.85, 0.78)), pos)
		mesh_inst.rotation.y = angle


static func _build_lookout_tower(parent: Node3D, info: Dictionary) -> void:
	var leg_positions := [
		Vector3(-0.32, 0.45, -0.32), Vector3(0.32, 0.45, -0.32),
		Vector3(-0.32, 0.45, 0.32), Vector3(0.32, 0.45, 0.32),
	]
	for pos in leg_positions:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.1, 0.9, 0.1)
		_add_mesh(parent, leg_mesh, info["color"].darkened(0.1), pos)

	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(1.0, 0.08, 1.0)
	_add_mesh(parent, platform_mesh, info["color"], Vector3(0.0, 0.92, 0.0))

	var rail_color: Color = info.get("rail_color", Color(0.45, 0.32, 0.22))
	for side in [-1.0, 1.0]:
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(1.0, 0.12, 0.06)
		_add_mesh(parent, rail_mesh, rail_color, Vector3(0.0, 1.08, side * 0.47))

		var side_rail := BoxMesh.new()
		side_rail.size = Vector3(0.06, 0.12, 0.9)
		_add_mesh(parent, side_rail, rail_color, Vector3(side * 0.47, 1.08, 0.0))

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.1, 0.08, 1.1)
	_add_mesh(parent, roof_mesh, info.get("roof_color", Color(0.5, 0.28, 0.18)), Vector3(0.0, 1.22, 0.0))

	var ladder_mesh := BoxMesh.new()
	ladder_mesh.size = Vector3(0.12, 0.75, 0.06)
	_add_mesh(parent, ladder_mesh, rail_color, Vector3(-0.42, 0.42, 0.42))

	var scope_mesh := CylinderMesh.new()
	scope_mesh.top_radius = 0.03
	scope_mesh.bottom_radius = 0.03
	scope_mesh.height = 0.12
	_add_mesh(parent, scope_mesh, Color(0.35, 0.35, 0.38), Vector3(0.15, 1.14, 0.2), Vector3(0.0, 0.0, -25.0))
