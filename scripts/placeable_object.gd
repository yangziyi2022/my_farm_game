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
	obj.rotation.y = GridManager.yaw_for_steps(rotation)
	obj._attach_visual(item_type, growth_stage)
	return obj


func _attach_visual(item_type: ItemData.ItemType, growth_stage: int = 0) -> void:
	var scene := ItemData.get_visual_scene(item_type)
	if scene:
		var visual: Node3D = scene.instantiate() as Node3D
		visual.name = "Visual"
		var def := ItemData.get_item_def(item_type)
		var info: Dictionary = ItemData.ITEMS[item_type]
		var s: float = float(info.get("visual_scale", 1.0))
		var sy: float = float(info.get("visual_scale_y", s))
		var y_off: float = float(info.get("visual_y_offset", 0.0))
		if def:
			s = def.visual_scale
			sy = s
			y_off = def.visual_y_offset
		visual.scale = Vector3(s, sy, s)
		visual.position.y = y_off
		# Center multi-cell visuals on the footprint while root stays on the anchor cell.
		var footprint := ItemData.get_footprint(item_type)
		if footprint.x > 1 or footprint.y > 1:
			var avg_x := float(footprint.x - 1) * 0.5
			var avg_y := float(footprint.y - 1) * 0.5
			visual.position.x += avg_x * GridManager.TILE_WIDTH
			visual.position.z += avg_y * GridManager.TILE_HEIGHT
		add_child(visual)
		return

	# Fallback: keep existing procedural builders so gameplay never breaks.
	_build_procedural(item_type, growth_stage)


func _build_procedural(item_type: ItemData.ItemType, _growth_stage: int = 0) -> void:
	var info: Dictionary = ItemData.ITEMS[item_type]
	match item_type:
		ItemData.ItemType.TREE:
			_build_growing_tree(self, info)
		ItemData.ItemType.ROCK:
			_build_rock(self, info)
		ItemData.ItemType.HOUSE, ItemData.ItemType.HOUSE_GREEN:
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
		ItemData.ItemType.RABBIT:
			_build_rabbit(self, info)
		ItemData.ItemType.FLOWER_RED, ItemData.ItemType.FLOWER_YELLOW, ItemData.ItemType.TULIP:
			_build_growing_flower(self, info, false)
		ItemData.ItemType.SUNFLOWER:
			_build_growing_sunflower(self, info)
		ItemData.ItemType.WHEAT:
			_build_growing_wheat(self, info)
		ItemData.ItemType.CARROT:
			_build_growing_carrot(self, info)
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
		ItemData.ItemType.SHED, ItemData.ItemType.LOOKOUT_TOWER:
			# Removed from palette; keep minimal fallback for old saves.
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
	# Terrain fills the whole orthogonal cell so adjacent tiles join with no gap.
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


static func _build_growing_tree(parent: Node3D, info: Dictionary) -> void:
	# Stage 0 — seed; 1 sapling; 2 young tree; 3 mature tree.
	var s0 := Node3D.new()
	s0.name = "Stage0"
	var seed := SphereMesh.new()
	seed.radius = 0.05
	_add_mesh(s0, seed, Color(0.4, 0.28, 0.15), Vector3(0.0, 0.1, 0.0))
	parent.add_child(s0)

	var s1 := Node3D.new()
	s1.name = "Stage1"
	var sprout := CylinderMesh.new()
	sprout.top_radius = 0.03
	sprout.bottom_radius = 0.04
	sprout.height = 0.22
	_add_mesh(s1, sprout, info.get("trunk_color", Color(0.45, 0.3, 0.15)), Vector3(0.0, 0.14, 0.0))
	var leaf := SphereMesh.new()
	leaf.radius = 0.12
	leaf.height = 0.18
	_add_mesh(s1, leaf, info["color"], Vector3(0.0, 0.3, 0.0))
	parent.add_child(s1)

	var s2 := Node3D.new()
	s2.name = "Stage2"
	var trunk2 := CylinderMesh.new()
	trunk2.top_radius = 0.07
	trunk2.bottom_radius = 0.09
	trunk2.height = 0.4
	_add_mesh(s2, trunk2, info.get("trunk_color", Color(0.45, 0.3, 0.15)), Vector3(0.0, 0.22, 0.0))
	var canopy2 := SphereMesh.new()
	canopy2.radius = 0.28
	canopy2.height = 0.45
	_add_mesh(s2, canopy2, info["color"], Vector3(0.0, 0.55, 0.0))
	parent.add_child(s2)

	var s3 := Node3D.new()
	s3.name = "Stage3"
	_build_tree(s3, info)
	parent.add_child(s3)


static func _build_growing_carrot(parent: Node3D, info: Dictionary) -> void:
	var leaf_color: Color = info.get("leaf_color", Color(0.25, 0.65, 0.22))
	var carrot_color: Color = info["color"]

	var s0 := Node3D.new()
	s0.name = "Stage0"
	for offset in [
		Vector3(-0.2, 0.1, -0.2), Vector3(0.2, 0.1, -0.2),
		Vector3(-0.2, 0.1, 0.2), Vector3(0.2, 0.1, 0.2),
	]:
		var seed := SphereMesh.new()
		seed.radius = 0.04
		_add_mesh(s0, seed, Color(0.45, 0.32, 0.18), offset)
	parent.add_child(s0)

	var s1 := Node3D.new()
	s1.name = "Stage1"
	for i in range(4):
		var angle := deg_to_rad(i * 90.0 + 20.0)
		var pos := Vector3(cos(angle) * 0.22, 0.12, sin(angle) * 0.22)
		var sprout := BoxMesh.new()
		sprout.size = Vector3(0.04, 0.12, 0.04)
		_add_mesh(s1, sprout, leaf_color, pos)
	parent.add_child(s1)

	var s2 := Node3D.new()
	s2.name = "Stage2"
	for i in range(4):
		var angle := deg_to_rad(i * 90.0 + 20.0)
		var base := Vector3(cos(angle) * 0.22, 0.0, sin(angle) * 0.22)
		var top := CylinderMesh.new()
		top.top_radius = 0.0
		top.bottom_radius = 0.05
		top.height = 0.18
		_add_mesh(s2, top, carrot_color, base + Vector3(0.0, 0.12, 0.0))
		var greens := BoxMesh.new()
		greens.size = Vector3(0.05, 0.16, 0.05)
		_add_mesh(s2, greens, leaf_color, base + Vector3(0.0, 0.28, 0.0))
	parent.add_child(s2)

	var s3 := Node3D.new()
	s3.name = "Stage3"
	for i in range(4):
		var angle := deg_to_rad(i * 90.0 + 20.0)
		var base := Vector3(cos(angle) * 0.24, 0.0, sin(angle) * 0.24)
		var body := CylinderMesh.new()
		body.top_radius = 0.02
		body.bottom_radius = 0.07
		body.height = 0.28
		_add_mesh(s3, body, carrot_color, base + Vector3(0.0, 0.14, 0.0))
		var greens := BoxMesh.new()
		greens.size = Vector3(0.08, 0.22, 0.08)
		_add_mesh(s3, greens, leaf_color, base + Vector3(0.0, 0.36, 0.0))
	parent.add_child(s3)


static func _build_growing_sunflower(parent: Node3D, info: Dictionary) -> void:
	# Same 4-stage flow as wheat: seeds → sprout → budding → mature bloom.
	var s0 := Node3D.new()
	s0.name = "Stage0"
	for offset in [
		Vector3(-0.2, 0.1, -0.2), Vector3(0.2, 0.1, -0.2),
		Vector3(-0.2, 0.1, 0.2), Vector3(0.2, 0.1, 0.2),
	]:
		var seed := SphereMesh.new()
		seed.radius = 0.04
		_add_mesh(s0, seed, Color(0.45, 0.32, 0.18), offset)
	parent.add_child(s0)

	var s1 := Node3D.new()
	s1.name = "Stage1"
	var sprout := BoxMesh.new()
	sprout.size = Vector3(0.05, 0.16, 0.05)
	_add_mesh(s1, sprout, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.14, 0.0))
	parent.add_child(s1)

	var s2 := Node3D.new()
	s2.name = "Stage2"
	var stem2 := CylinderMesh.new()
	stem2.top_radius = 0.02
	stem2.bottom_radius = 0.025
	stem2.height = 0.35
	_add_mesh(s2, stem2, info.get("stem_color", Color(0.22, 0.58, 0.18)), Vector3(0.0, 0.22, 0.0))
	var bud := SphereMesh.new()
	bud.radius = 0.08
	bud.height = 0.1
	_add_mesh(s2, bud, info.get("center_color", Color(0.45, 0.32, 0.12)), Vector3(0.0, 0.42, 0.0))
	parent.add_child(s2)

	var s3 := Node3D.new()
	s3.name = "Stage3"
	_build_sunflower(s3, info)
	parent.add_child(s3)


static func _footprint_center_offset(footprint: Vector2i) -> Vector3:
	## Orthogonal: offset from anchor cell center to multi-cell footprint center.
	var avg_x := float(maxi(footprint.x, 1) - 1) * 0.5
	var avg_y := float(maxi(footprint.y, 1) - 1) * 0.5
	return Vector3(avg_x * GridManager.TILE_WIDTH, 0.0, avg_y * GridManager.TILE_HEIGHT)


static func _build_rock(parent: Node3D, info: Dictionary) -> void:
	## Natural pile of several stones clustered together.
	var base_color: Color = info.get("color", Color(0.52, 0.52, 0.54))
	var stones: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.14, 0.0), "scale": Vector3(0.55, 0.38, 0.48), "rot": Vector3(8, 20, -6), "shade": 0.0},
		{"pos": Vector3(0.22, 0.1, 0.12), "scale": Vector3(0.32, 0.26, 0.3), "rot": Vector3(-10, 55, 12), "shade": 0.08},
		{"pos": Vector3(-0.2, 0.09, 0.1), "scale": Vector3(0.28, 0.22, 0.26), "rot": Vector3(12, -40, 8), "shade": -0.06},
		{"pos": Vector3(0.08, 0.08, -0.22), "scale": Vector3(0.3, 0.2, 0.34), "rot": Vector3(-5, 110, -10), "shade": 0.1},
		{"pos": Vector3(-0.12, 0.18, -0.08), "scale": Vector3(0.24, 0.2, 0.22), "rot": Vector3(15, -15, 5), "shade": -0.1},
		{"pos": Vector3(0.28, 0.07, -0.1), "scale": Vector3(0.18, 0.14, 0.16), "rot": Vector3(0, 70, 18), "shade": 0.04},
		{"pos": Vector3(-0.26, 0.06, -0.18), "scale": Vector3(0.16, 0.12, 0.18), "rot": Vector3(20, -80, 0), "shade": 0.12},
	]
	for stone in stones:
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		var shade: float = stone["shade"]
		var color := base_color.darkened(shade) if shade > 0.0 else base_color.lightened(-shade)
		var mi := _add_mesh(parent, mesh, color, stone["pos"])
		mi.scale = stone["scale"]
		mi.rotation_degrees = stone["rot"]


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
	## Red house with a triangular gray roof.
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.35, 0.95, 1.15)
	_add_mesh(parent, body_mesh, info["color"], Vector3(0.0, 0.48, 0.0))

	var roof_color: Color = info.get("roof_color", Color(0.58, 0.58, 0.6))
	var roof := PrismMesh.new()
	roof.size = Vector3(1.5, 0.55, 1.3)
	_add_mesh(parent, roof, roof_color, Vector3(0.0, 1.18, 0.0))

	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.32, 0.5, 0.05)
	_add_mesh(parent, door_mesh, info.get("door_color", Color(0.42, 0.22, 0.14)), Vector3(0.0, 0.3, 0.6))

	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.22, 0.22, 0.05)
	var win_color: Color = info.get("window_color", Color(0.55, 0.75, 0.9))
	_add_mesh(parent, window_mesh, win_color, Vector3(-0.38, 0.58, 0.6))
	_add_mesh(parent, window_mesh, win_color, Vector3(0.38, 0.58, 0.6))


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
	# Dirt stays as terrain under the plant — only grow the crop visuals.
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


static func _build_growing_wheat(parent: Node3D, _info: Dictionary) -> void:
	## Stage 0 seeds → 1 small yellow grass → 2/3 mature wheat.glb.
	parent.add_child(_make_wheat_seed_stage())
	parent.add_child(_make_wheat_yellow_grass_stage("Stage1", 0.55))
	parent.add_child(_make_wheat_model_stage(
		"Stage2",
		"res://assets/models/crops/wheat.glb",
		0.95
	))
	# Stage 3 keeps CropGrowth.STAGE_COUNT=4; same mature field for harvest-ready.
	parent.add_child(_make_wheat_model_stage(
		"Stage3",
		"res://assets/models/crops/wheat.glb",
		1.0
	))


static func _make_wheat_seed_stage() -> Node3D:
	var node := Node3D.new()
	node.name = "Stage0"
	var seed_color := Color(0.52, 0.36, 0.18)
	var span := GridManager.TILE_WIDTH * 0.28
	var offsets := [
		Vector3(-span, 0.12, -span),
		Vector3(span, 0.12, -span),
		Vector3(-span, 0.12, span),
		Vector3(span, 0.12, span),
	]
	for offset in offsets:
		var seed_mesh := SphereMesh.new()
		seed_mesh.radius = 0.05
		seed_mesh.height = 0.08
		_add_mesh(node, seed_mesh, seed_color, offset)
	return node


static func _make_wheat_yellow_grass_stage(stage_name: String, height_scale: float) -> Node3D:
	## Low procedural yellow-green tufts (replaces old growing_wheat_*.glb).
	var node := Node3D.new()
	node.name = stage_name
	var grass_color := Color(0.82, 0.72, 0.22)
	var tip_color := Color(0.92, 0.82, 0.28)
	var positions := [
		Vector3(-0.22, 0.0, -0.18),
		Vector3(0.18, 0.0, -0.22),
		Vector3(-0.12, 0.0, 0.2),
		Vector3(0.24, 0.0, 0.12),
		Vector3(0.0, 0.0, 0.0),
	]
	for i in range(positions.size()):
		var clump := Node3D.new()
		clump.position = positions[i]
		clump.rotation.y = float(i) * 0.7
		node.add_child(clump)
		for b in range(3):
			var blade := BoxMesh.new()
			var h := (0.12 + float(b) * 0.04) * height_scale
			blade.size = Vector3(0.025, h, 0.012)
			var yaw := deg_to_rad(-25.0 + b * 25.0)
			var pos := Vector3(cos(yaw) * 0.03, h * 0.5 + 0.02, sin(yaw) * 0.03)
			var color := grass_color if b < 2 else tip_color
			var mi := _add_mesh(clump, blade, color, pos)
			mi.rotation_degrees = Vector3(8.0, rad_to_deg(yaw), float(b - 1) * 6.0)
	return node


static func _make_wheat_model_stage(
	stage_name: String,
	scene_path: String,
	tile_fill: float
) -> Node3D:
	var node := Node3D.new()
	node.name = stage_name
	if not ResourceLoader.exists(scene_path):
		push_warning("Wheat model missing: %s" % scene_path)
		return node
	var model: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	node.add_child(model)
	_fit_crop_model_to_dirt_tile(model, tile_fill)
	return node


static func _fit_crop_model_to_dirt_tile(model: Node3D, tile_fill: float) -> void:
	## Scale XZ to the dirt cell, then drop the mesh so its bottom sits on the dirt top.
	var aabb := _collect_local_aabb(model)
	if aabb.size.length_squared() < 0.000001:
		return

	var target_w: float = GridManager.TILE_WIDTH * tile_fill
	var target_d: float = GridManager.TILE_HEIGHT * tile_fill
	var sx: float = target_w / maxf(aabb.size.x, 0.001)
	var sz: float = target_d / maxf(aabb.size.z, 0.001)
	var s: float = minf(sx, sz)
	model.scale = Vector3.ONE * s

	# Terrain dirt top is flush with grass (~0.015).
	const DIRT_TOP_Y: float = 0.015
	model.position = Vector3(
		-aabb.get_center().x * s,
		DIRT_TOP_Y - aabb.position.y * s,
		-aabb.get_center().z * s
	)


static func _collect_local_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var has_any := false
	for mi in _gather_mesh_instances(root):
		var local_xf := _relative_transform(root, mi)
		var mesh_aabb := mi.get_aabb()
		for corner in _aabb_corners(mesh_aabb):
			var p: Vector3 = local_xf * corner
			if not has_any:
				merged = AABB(p, Vector3.ZERO)
				has_any = true
			else:
				merged = merged.expand(p)
	return merged


static func _gather_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_gather_mesh_instances(child))
	return out


static func _relative_transform(ancestor: Node3D, descendant: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node3D = descendant
	while current and current != ancestor:
		xf = current.transform * xf
		current = current.get_parent() as Node3D
	return xf


static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, s.y, s.z),
		p + s,
	]


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
	## Fluffy cloud-like body from overlapping wool spheres + animated Head.
	var wool: Color = info["color"]
	var face: Color = info.get("face_color", Color(0.35, 0.32, 0.3))
	var eye: Color = Color(0.08, 0.08, 0.1)

	var cloud_offsets := [
		Vector3(0.0, 0.28, 0.0),
		Vector3(0.16, 0.3, 0.06),
		Vector3(-0.16, 0.3, 0.04),
		Vector3(0.08, 0.34, -0.14),
		Vector3(-0.1, 0.34, -0.12),
		Vector3(0.0, 0.38, 0.1),
		Vector3(0.12, 0.26, 0.16),
		Vector3(-0.12, 0.26, 0.14),
	]
	var cloud_radii := [0.22, 0.16, 0.16, 0.14, 0.14, 0.12, 0.13, 0.13]
	for i in range(cloud_offsets.size()):
		var puff := SphereMesh.new()
		puff.radius = cloud_radii[i]
		puff.height = cloud_radii[i] * 1.7
		_add_mesh(parent, puff, wool, cloud_offsets[i])

	for side in [-1.0, 1.0]:
		for z in [0.06, -0.1]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.035
			leg.bottom_radius = 0.04
			leg.height = 0.16
			_add_mesh(parent, leg, face, Vector3(side * 0.1, 0.08, z))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.32, 0.28)
	parent.add_child(head)

	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.1
	face_mesh.height = 0.16
	_add_mesh(head, face_mesh, face, Vector3(0.0, 0.0, 0.04))

	for side in [-1.0, 1.0]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.022
		eye_mesh.height = 0.03
		_add_mesh(head, eye_mesh, eye, Vector3(side * 0.045, 0.02, 0.11))

	var ear_l := SphereMesh.new()
	ear_l.radius = 0.035
	ear_l.height = 0.05
	var ear_r := SphereMesh.new()
	ear_r.radius = 0.035
	ear_r.height = 0.05
	_add_mesh(head, ear_l, face, Vector3(-0.09, 0.04, 0.0))
	_add_mesh(head, ear_r, face, Vector3(0.09, 0.04, 0.0))


static func _build_pig(parent: Node3D, info: Dictionary) -> void:
	## Pink oval body, black eyes, little curly tail.
	var pink: Color = info.get("color", Color(0.95, 0.72, 0.75))
	var nose_color: Color = info.get("nose_color", Color(0.9, 0.55, 0.6))
	var eye: Color = Color(0.05, 0.05, 0.08)

	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.4
	var body_mi := _add_mesh(parent, body, pink, Vector3(0.0, 0.26, 0.0))
	# Stretch into a soft ellipse (longer front-to-back).
	body_mi.scale = Vector3(1.15, 0.82, 1.45)

	for side in [-1.0, 1.0]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.032
		eye_mesh.height = 0.038
		_add_mesh(parent, eye_mesh, eye, Vector3(side * 0.1, 0.32, 0.26))

	var snout := SphereMesh.new()
	snout.radius = 0.075
	snout.height = 0.11
	_add_mesh(parent, snout, nose_color, Vector3(0.0, 0.24, 0.34))

	var nostril_l := SphereMesh.new()
	nostril_l.radius = 0.016
	nostril_l.height = 0.02
	var nostril_r := SphereMesh.new()
	nostril_r.radius = 0.016
	nostril_r.height = 0.02
	_add_mesh(parent, nostril_l, nose_color.darkened(0.25), Vector3(-0.022, 0.24, 0.4))
	_add_mesh(parent, nostril_r, nose_color.darkened(0.25), Vector3(0.022, 0.24, 0.4))

	for side in [-1.0, 1.0]:
		var ear := SphereMesh.new()
		ear.radius = 0.055
		ear.height = 0.07
		_add_mesh(parent, ear, pink.darkened(0.05), Vector3(side * 0.15, 0.4, 0.08))

	# Tiny curly tail at the rear.
	var tail_base := SphereMesh.new()
	tail_base.radius = 0.035
	tail_base.height = 0.05
	_add_mesh(parent, tail_base, pink.darkened(0.08), Vector3(0.0, 0.3, -0.3))
	var tail_curl := SphereMesh.new()
	tail_curl.radius = 0.028
	tail_curl.height = 0.04
	_add_mesh(parent, tail_curl, pink.darkened(0.05), Vector3(0.04, 0.36, -0.34))
	var tip := SphereMesh.new()
	tip.radius = 0.018
	tip.height = 0.025
	_add_mesh(parent, tip, pink.lightened(0.05), Vector3(0.02, 0.4, -0.3))


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


static func _build_rabbit(parent: Node3D, info: Dictionary) -> void:
	var fur: Color = info["color"]
	var ear_color: Color = info.get("ear_color", Color(0.98, 0.78, 0.82))
	var eye_color: Color = info.get("eye_color", Color(0.2, 0.15, 0.15))

	var body := SphereMesh.new()
	body.radius = 0.16
	body.height = 0.26
	_add_mesh(parent, body, fur, Vector3(0.0, 0.18, 0.0))

	var head := SphereMesh.new()
	head.radius = 0.11
	head.height = 0.16
	_add_mesh(parent, head, fur, Vector3(0.0, 0.32, 0.12))

	for side in [-1.0, 1.0]:
		var ear := BoxMesh.new()
		ear.size = Vector3(0.05, 0.2, 0.04)
		_add_mesh(parent, ear, ear_color, Vector3(side * 0.06, 0.48, 0.1))

	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.02
		eye.height = 0.03
		_add_mesh(parent, eye, eye_color, Vector3(side * 0.045, 0.34, 0.2))

	var nose := SphereMesh.new()
	nose.radius = 0.025
	nose.height = 0.03
	_add_mesh(parent, nose, Color(0.9, 0.55, 0.6), Vector3(0.0, 0.3, 0.22))

	var tail := SphereMesh.new()
	tail.radius = 0.05
	tail.height = 0.08
	_add_mesh(parent, tail, fur.lightened(0.1), Vector3(0.0, 0.2, -0.14))


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
	var offsets := [
		Vector3(-0.28, 0.1, -0.22), Vector3(0.12, 0.1, -0.3),
		Vector3(0.32, 0.1, 0.05), Vector3(-0.08, 0.1, 0.28),
		Vector3(0.22, 0.1, 0.32), Vector3(-0.32, 0.1, 0.12),
	]
	for i in range(offsets.size()):
		var offset: Vector3 = offsets[i]
		var stone_mesh := BoxMesh.new()
		var size_scale := 0.18 + float(i % 3) * 0.04
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
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.position = _footprint_center_offset(Vector2i(2, 2))
	parent.add_child(visual)

	var rim_color: Color = info.get("rim_color", Color(0.52, 0.5, 0.48))
	for i in range(14):
		var angle := deg_to_rad(i * (360.0 / 14.0))
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = Vector3(0.32, 0.1, 0.2)
		var pos := Vector3(cos(angle) * 0.95, 0.05, sin(angle) * 0.95)
		var rim := _add_mesh(visual, rim_mesh, rim_color, pos)
		rim.rotation.y = angle

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.9
	water_mesh.bottom_radius = 0.85
	water_mesh.height = 0.06
	var water := _add_mesh(visual, water_mesh, info["color"], Vector3(0.0, 0.04, 0.0))
	water.scale = Vector3(1.15, 1.0, 0.95)
	var water_mat: StandardMaterial3D = water.material_override
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.15
	water_mat.metallic = 0.05

	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = 0.55
	inner_mesh.bottom_radius = 0.5
	inner_mesh.height = 0.04
	var inner := _add_mesh(visual, inner_mesh, Color(0.15, 0.42, 0.78, 0.7), Vector3(0.12, 0.06, -0.08))
	inner.scale = Vector3(1.15, 1.0, 0.85)


static func _build_fountain(parent: Node3D, info: Dictionary) -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.position = _footprint_center_offset(Vector2i(2, 2))
	parent.add_child(visual)

	var water_color: Color = info.get("water_color", Color(0.35, 0.62, 0.9, 0.75))

	# Outer rim + inner well so the basin reads as a donut groove.
	var basin_mesh := CylinderMesh.new()
	basin_mesh.top_radius = 0.95
	basin_mesh.bottom_radius = 0.88
	basin_mesh.height = 0.22
	_add_mesh(visual, basin_mesh, info["color"], Vector3(0.0, 0.12, 0.0))

	var inner_well := CylinderMesh.new()
	inner_well.top_radius = 0.42
	inner_well.bottom_radius = 0.4
	inner_well.height = 0.12
	_add_mesh(visual, inner_well, info["color"].darkened(0.12), Vector3(0.0, 0.1, 0.0))

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.78
	water_mesh.bottom_radius = 0.74
	water_mesh.height = 0.05
	var water := _add_mesh(visual, water_mesh, water_color, Vector3(0.0, 0.2, 0.0))
	var water_mat: StandardMaterial3D = water.material_override
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.2

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.1
	pillar_mesh.bottom_radius = 0.14
	pillar_mesh.height = 0.7
	_add_mesh(visual, pillar_mesh, info["color"].lightened(0.08), Vector3(0.0, 0.5, 0.0))

	var jet := Node3D.new()
	jet.name = "FountainJet"
	jet.position = Vector3(0.0, 0.9, 0.0)
	visual.add_child(jet)

	var jet_mesh := CylinderMesh.new()
	jet_mesh.top_radius = 0.03
	jet_mesh.bottom_radius = 0.08
	jet_mesh.height = 0.3
	var jet_inst := _add_mesh(jet, jet_mesh, water_color, Vector3.ZERO)
	var jet_mat: StandardMaterial3D = jet_inst.material_override
	jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var top_mesh := SphereMesh.new()
	top_mesh.radius = 0.1
	top_mesh.height = 0.12
	_add_mesh(jet, top_mesh, Color(0.45, 0.72, 0.95, 0.8), Vector3(0.0, 0.18, 0.0))

	# Marker for splash FX attachment (world-local under Visual).
	var splash_anchor := Node3D.new()
	splash_anchor.name = "FountainSplashAnchor"
	splash_anchor.position = Vector3(0.0, 0.95, 0.0)
	visual.add_child(splash_anchor)


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
