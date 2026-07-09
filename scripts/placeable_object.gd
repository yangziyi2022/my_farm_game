class_name PlaceableObject
extends Node3D


static func create(item_type: ItemData.ItemType, grid_pos: Vector2i, rotation: int = 0, growth_stage: int = 0) -> Node3D:
	var obj := Node3D.new()
	obj.name = "Object_%s_%d_%d" % [ItemData.get_item_id(item_type), grid_pos.x, grid_pos.y]
	obj.set_meta("item_type", item_type)
	obj.set_meta("grid_pos", grid_pos)
	obj.set_meta("rotation", rotation)
	obj.set_meta("growth_stage", growth_stage)

	var info: Dictionary = ItemData.ITEMS[item_type]
	obj.rotation.y = deg_to_rad(rotation * 90.0)

	match item_type:
		ItemData.ItemType.TREE:
			_build_tree(obj, info)
		ItemData.ItemType.SHED:
			_build_shed(obj, info)
		ItemData.ItemType.HOUSE:
			_build_house(obj, info)
		ItemData.ItemType.BARN:
			_build_barn(obj, info)
		ItemData.ItemType.WINDMILL:
			_build_windmill(obj, info)
		ItemData.ItemType.GRANARY:
			_build_granary(obj, info)
		ItemData.ItemType.BRIDGE:
			_build_bridge(obj, info)
		ItemData.ItemType.LAMPPOST:
			_build_lamppost(obj, info)
		ItemData.ItemType.WELL:
			_build_well(obj, info)
		ItemData.ItemType.CROP_BED:
			_build_crop_bed(obj, info)
		ItemData.ItemType.COW:
			_build_cow(obj, info)
		ItemData.ItemType.CHICKEN:
			_build_chicken(obj, info)
		ItemData.ItemType.SHEEP:
			_build_sheep(obj, info)
		ItemData.ItemType.PIG:
			_build_pig(obj, info)
		ItemData.ItemType.DUCK:
			_build_duck(obj, info)
		ItemData.ItemType.FLOWER_RED, ItemData.ItemType.FLOWER_YELLOW, ItemData.ItemType.TULIP:
			_build_growing_flower(obj, info, false)
		ItemData.ItemType.SUNFLOWER:
			_build_growing_flower(obj, info, true)
		ItemData.ItemType.FENCE:
			_build_box(obj, info)
		_:
			_build_box(obj, info)

	return obj


static func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	mesh_inst.position = pos
	mesh_inst.rotation_degrees = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)
	return mesh_inst


static func _build_box(parent: Node3D, info: Dictionary) -> void:
	var size: Vector3 = info["size"]
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

	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 0.1
	hub_mesh.height = 0.1
	_add_mesh(parent, hub_mesh, info.get("blade_color", Color(0.75, 0.75, 0.78)), Vector3(0.0, 1.1, 0.55))

	for i in range(4):
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.08, 0.7, 0.14)
		var angle := deg_to_rad(i * 90.0)
		var pos := Vector3(sin(angle) * 0.35, 1.1, 0.55 + cos(angle) * 0.35)
		var mesh_inst := _add_mesh(parent, blade_mesh, info.get("blade_color", Color(0.75, 0.75, 0.78)), pos)
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
