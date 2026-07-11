class_name GridManager
extends Node3D

signal object_placed(grid_pos: Vector2i, object_node: Node3D)
signal object_removed(grid_pos: Vector2i)
signal object_moved(from: Vector2i, to: Vector2i)
signal selection_changed(object_node: Node3D)

const TILE_WIDTH: float = 1.25
const TILE_HEIGHT: float = 1.25
const GRID_WIDTH: int = 40
const GRID_HEIGHT: int = 40

var undo_manager: UndoManager

## Two layers per cell:
## - _terrain: grass / dirt / water / stone_path (ground stays when animals/fences sit on top)
## - _objects: animals, buildings, plants, decor (the selectable "content")
var _terrain: Dictionary = {}  # Vector2i -> Node3D
var _objects: Dictionary = {}  # Vector2i -> Node3D
var _selected: Node3D = null
var _grid_visual: Node3D
var _water_fish_manager: WaterFishManager

@onready var objects_container: Node3D = $Objects


func _ready() -> void:
	_build_grid_visual()
	_water_fish_manager = WaterFishManager.new()
	_water_fish_manager.name = "WaterFishManager"
	add_child(_water_fish_manager)
	_water_fish_manager.setup(self)


func _build_grid_visual() -> void:
	_grid_visual = Node3D.new()
	_grid_visual.name = "GridVisual"
	add_child(_grid_visual)

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.3, 0.5, 0.3, 0.45)
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for x in range(GRID_WIDTH + 1):
		var start := grid_to_world(Vector2i(x, 0))
		var end := grid_to_world(Vector2i(x, GRID_HEIGHT))
		_add_line(start, end, line_material)

	for y in range(GRID_HEIGHT + 1):
		var start := grid_to_world(Vector2i(0, y))
		var end := grid_to_world(Vector2i(GRID_WIDTH, y))
		_add_line(start, end, line_material)

	# Diamond ground matching the isometric playable area (no leftover corner triangles).
	var ground := MeshInstance3D.new()
	ground.name = "GroundDiamond"
	ground.mesh = _make_ground_diamond_mesh()
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.62, 0.32)
	ground.material_override = ground_mat
	ground.position.y = -0.01
	_grid_visual.add_child(ground)


func _make_ground_diamond_mesh() -> ArrayMesh:
	# Outer corners of the grid line frame.
	var c0 := grid_to_world(Vector2i(0, 0))
	var c1 := grid_to_world(Vector2i(GRID_WIDTH, 0))
	var c2 := grid_to_world(Vector2i(GRID_WIDTH, GRID_HEIGHT))
	var c3 := grid_to_world(Vector2i(0, GRID_HEIGHT))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(c0)
	st.add_vertex(c1)
	st.add_vertex(c2)
	st.add_vertex(c0)
	st.add_vertex(c2)
	st.add_vertex(c3)
	st.generate_normals()
	return st.commit()


func _add_line(from: Vector3, to: Vector3, material: StandardMaterial3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_add_vertex(from + Vector3(0, 0.02, 0))
	immediate.surface_add_vertex(to + Vector3(0, 0.02, 0))
	immediate.surface_end()
	mesh_inst.mesh = immediate
	mesh_inst.material_override = material
	_grid_visual.add_child(mesh_inst)


func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var half_w := TILE_WIDTH * 0.5
	var half_h := TILE_HEIGHT * 0.5
	var world_x := (grid_pos.x - grid_pos.y) * half_w
	var world_z := (grid_pos.x + grid_pos.y) * half_h
	return Vector3(world_x, 0.0, world_z)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var half_w := TILE_WIDTH * 0.5
	var half_h := TILE_HEIGHT * 0.5
	var gx := (world_pos.x / half_w + world_pos.z / half_h) * 0.5
	var gy := (world_pos.z / half_h - world_pos.x / half_w) * 0.5
	return Vector2i(roundi(gx), roundi(gy))


func world_to_grid_nearest(world_pos: Vector3) -> Vector2i:
	var base := world_to_grid(world_pos)
	var best := base
	var best_dist := world_pos.distance_squared_to(grid_to_world(base))

	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var candidate := Vector2i(base.x + ox, base.y + oy)
			if not is_in_bounds(candidate):
				continue
			var dist := world_pos.distance_squared_to(grid_to_world(candidate))
			if dist < best_dist:
				best_dist = dist
				best = candidate
	return best


func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH \
		and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT


func is_occupied(grid_pos: Vector2i) -> bool:
	return _objects.has(grid_pos) or _terrain.has(grid_pos)


func has_content(grid_pos: Vector2i) -> bool:
	return _objects.has(grid_pos)


func has_terrain(grid_pos: Vector2i) -> bool:
	return _terrain.has(grid_pos)


func get_terrain_type_at(grid_pos: Vector2i) -> ItemData.ItemType:
	if _terrain.has(grid_pos):
		return _terrain[grid_pos].get_meta("item_type")
	return ItemData.ItemType.GRASS


func get_item_type_at(grid_pos: Vector2i) -> ItemData.ItemType:
	# Prefer content (animal/building/plant); fall back to terrain.
	if _objects.has(grid_pos):
		return _objects[grid_pos].get_meta("item_type")
	if _terrain.has(grid_pos):
		return _terrain[grid_pos].get_meta("item_type")
	return ItemData.ItemType.GRASS


func get_object_at(grid_pos: Vector2i) -> Node3D:
	if _objects.has(grid_pos):
		return _objects[grid_pos]
	return _terrain.get(grid_pos)


func get_content_at(grid_pos: Vector2i) -> Node3D:
	return _objects.get(grid_pos)


func get_terrain_at(grid_pos: Vector2i) -> Node3D:
	return _terrain.get(grid_pos)


func get_selected() -> Node3D:
	return _selected


func get_all_content_objects() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for obj in _objects.values():
		if obj is Node3D:
			result.append(obj)
	return result


func get_all_selectable_objects() -> Array[Node3D]:
	## Content + terrain (dirt / water / stone path). Used by marquee select.
	var result: Array[Node3D] = []
	for obj in _objects.values():
		if obj is Node3D:
			result.append(obj)
	for obj in _terrain.values():
		if obj is Node3D:
			result.append(obj)
	return result


func is_terrain_object(obj: Node3D) -> bool:
	return obj != null and obj.has_meta("item_type") and ItemData.is_terrain(obj.get_meta("item_type"))


func set_object_highlighted(obj: Node3D, enabled: bool) -> void:
	if obj and is_instance_valid(obj):
		_highlight_object(obj, enabled)


func select_object(obj: Node3D) -> void:
	if _selected == obj:
		return
	_deselect()
	_selected = obj
	if obj:
		obj.set_meta("selected", true)
		_highlight_object(obj, true)
	selection_changed.emit(obj)


func _deselect() -> void:
	if _selected:
		_selected.set_meta("selected", false)
		_highlight_object(_selected, false)
		_selected = null


func _highlight_object(obj: Node3D, enabled: bool) -> void:
	_apply_highlight_recursive(obj, enabled)


func _apply_highlight_recursive(node: Node, enabled: bool) -> void:
	if node is FootprintOverlay or str(node.name).begins_with("Footprint") or node.name == "SelectionFootprint":
		return
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			mat.emission_enabled = enabled
			mat.emission = Color(0.3, 0.5, 0.8) if enabled else Color.BLACK
			mat.emission_energy_multiplier = 0.5 if enabled else 0.0
	for child in node.get_children():
		_apply_highlight_recursive(child, enabled)


func can_place_at(grid_pos: Vector2i, item_type: ItemData.ItemType) -> bool:
	if not is_in_bounds(grid_pos):
		return false

	# Crops/flowers need exposed dirt (no animal/building already on the tile).
	if ItemData.needs_dirt_to_plant(item_type):
		return get_terrain_type_at(grid_pos) == ItemData.ItemType.DIRT and not has_content(grid_pos)

	# Grass = default floor. Placing it clears terrain back to empty (no stacked grass tile).
	if item_type == ItemData.ItemType.GRASS:
		return not has_content(grid_pos) and has_terrain(grid_pos)

	# Terrain replaces other terrain on the same layer (no overlap); not through content.
	if ItemData.is_terrain(item_type):
		if has_content(grid_pos):
			return false
		return true

	# Content layer: one object per cell (can stack visually on terrain below).
	if ItemData.stacks_on_terrain(item_type):
		return not has_content(grid_pos)

	if not is_occupied(grid_pos):
		return true
	return ItemData.can_build_over(get_item_type_at(grid_pos))


func place_object(
	item_type: ItemData.ItemType,
	grid_pos: Vector2i,
	rotation: int = 0,
	animate_placement: bool = true,
	growth_stage: int = 0
) -> Node3D:
	if not is_in_bounds(grid_pos):
		return null

	if ItemData.needs_dirt_to_plant(item_type):
		if get_terrain_type_at(grid_pos) != ItemData.ItemType.DIRT or has_content(grid_pos):
			return null
		if has_terrain(grid_pos):
			_remove_terrain_silent(grid_pos)
		return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)

	# Painting grass restores the default floor (remove dirt/water/path tiles).
	if item_type == ItemData.ItemType.GRASS:
		if has_content(grid_pos):
			return null
		if has_terrain(grid_pos):
			var before: Node3D = _terrain[grid_pos]
			var before_type: ItemData.ItemType = before.get_meta("item_type")
			var before_rot: int = before.get_meta("rotation", 0)
			_remove_terrain_silent(grid_pos)
			if undo_manager and not undo_manager.is_applying_undo():
				undo_manager.record_remove(grid_pos, before_type, before_rot, 0)
			object_placed.emit(grid_pos, null)
			return null
		return null

	if ItemData.is_terrain(item_type):
		if has_content(grid_pos):
			return null
		if has_terrain(grid_pos):
			return replace_object(grid_pos, item_type, rotation, growth_stage, animate_placement)
		return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)

	if ItemData.stacks_on_terrain(item_type):
		if has_content(grid_pos):
			return null
		return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)

	if is_occupied(grid_pos):
		var existing_type := get_item_type_at(grid_pos)
		if ItemData.can_build_over(existing_type):
			return replace_object(grid_pos, item_type, rotation, growth_stage, animate_placement)
		return null

	return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)


func hoe_grass(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	# Don't hoe under an animal/building.
	if has_content(grid_pos):
		return false
	if not has_terrain(grid_pos):
		place_object(ItemData.ItemType.DIRT, grid_pos, 0, true, 0)
		return true
	var item_type := get_terrain_type_at(grid_pos)
	if not ItemData.is_hoeable(item_type):
		return false
	replace_object(grid_pos, ItemData.ItemType.DIRT, 0, 0, true)
	return true


func replace_object(
	grid_pos: Vector2i,
	item_type: ItemData.ItemType,
	rotation: int = 0,
	growth_stage: int = 0,
	animate_placement: bool = true
) -> Node3D:
	if not is_in_bounds(grid_pos) or not is_occupied(grid_pos):
		return null

	var before_type := get_item_type_at(grid_pos)
	var before_obj: Node3D = get_object_at(grid_pos)
	var before_rotation: int = before_obj.get_meta("rotation", 0) if before_obj else 0
	var before_growth: int = before_obj.get_meta("growth_stage", 0) if before_obj else 0

	# Terrain replace only touches the terrain layer.
	if ItemData.is_terrain(item_type) and has_terrain(grid_pos) and not has_content(grid_pos):
		_remove_terrain_silent(grid_pos)
	elif has_content(grid_pos):
		remove_object_silent(grid_pos)
	elif has_terrain(grid_pos):
		_remove_terrain_silent(grid_pos)

	var obj := _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, false)

	if undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_replace(
			grid_pos, before_type, before_rotation, before_growth,
			item_type, rotation, growth_stage
		)
	return obj


func place_object_silent(
	item_type: ItemData.ItemType,
	grid_pos: Vector2i,
	rotation: int = 0,
	growth_stage: int = 0
) -> Node3D:
	if ItemData.needs_dirt_to_plant(item_type) and has_terrain(grid_pos):
		_remove_terrain_silent(grid_pos)
	elif ItemData.is_terrain(item_type) and has_terrain(grid_pos) and not has_content(grid_pos):
		_remove_terrain_silent(grid_pos)
	return _spawn_object(item_type, grid_pos, rotation, growth_stage, false, false)


func replace_object_silent(
	grid_pos: Vector2i,
	item_type: ItemData.ItemType,
	rotation: int = 0,
	growth_stage: int = 0
) -> Node3D:
	if has_content(grid_pos):
		remove_object_silent(grid_pos)
	elif has_terrain(grid_pos):
		_remove_terrain_silent(grid_pos)
	return _spawn_object(item_type, grid_pos, rotation, growth_stage, false, false)


func _spawn_object(
	item_type: ItemData.ItemType,
	grid_pos: Vector2i,
	rotation: int,
	growth_stage: int,
	animate_placement: bool,
	record_undo: bool
) -> Node3D:
	var obj: Node3D = PlaceableObject.create(item_type, grid_pos, rotation, growth_stage)
	obj.position = grid_to_world(grid_pos)
	obj.set_meta("growth_stage", growth_stage)
	objects_container.add_child(obj)

	if ItemData.is_terrain(item_type):
		_terrain[grid_pos] = obj
	else:
		_objects[grid_pos] = obj

	_add_tile_collider(obj, item_type)
	ObjectPolish.setup(obj, item_type, animate_placement)

	if record_undo and undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_place(grid_pos, item_type, rotation, growth_stage)

	object_placed.emit(grid_pos, obj)
	return obj


func _add_tile_collider(obj: Node3D, item_type: ItemData.ItemType) -> void:
	var body := StaticBody3D.new()
	body.name = "TileCollider"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Content (animals/buildings) gets a taller collider so raycasts prefer them over terrain.
	if ItemData.is_terrain(item_type):
		box.size = Vector3(TILE_WIDTH * 0.98, 0.18, TILE_HEIGHT * 0.98)
		col.position.y = 0.09
	else:
		box.size = Vector3(TILE_WIDTH * 0.92, 0.55, TILE_HEIGHT * 0.92)
		col.position.y = 0.3
	col.shape = box
	body.add_child(col)
	obj.add_child(body)


func remove_object(grid_pos: Vector2i) -> void:
	# Prefer removing content (animal/fence); terrain only if nothing sits on it.
	if has_content(grid_pos):
		var obj: Node3D = _objects[grid_pos]
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_remove(
				grid_pos,
				obj.get_meta("item_type"),
				obj.get_meta("rotation", 0),
				obj.get_meta("growth_stage", 0)
			)
		remove_object_silent(grid_pos)
		return

	if has_terrain(grid_pos):
		var terrain: Node3D = _terrain[grid_pos]
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_remove(
				grid_pos,
				terrain.get_meta("item_type"),
				terrain.get_meta("rotation", 0),
				0
			)
		_remove_terrain_silent(grid_pos)


func remove_node(obj: Node3D) -> bool:
	## Remove this exact node (content or terrain), used by multi-select delete.
	if obj == null or not is_instance_valid(obj) or not obj.has_meta("grid_pos"):
		return false
	var grid_pos: Vector2i = obj.get_meta("grid_pos")
	if _objects.get(grid_pos) == obj:
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_remove(
				grid_pos,
				obj.get_meta("item_type"),
				obj.get_meta("rotation", 0),
				obj.get_meta("growth_stage", 0)
			)
		remove_object_silent(grid_pos)
		return true
	if _terrain.get(grid_pos) == obj:
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_remove(
				grid_pos,
				obj.get_meta("item_type"),
				obj.get_meta("rotation", 0),
				0
			)
		_remove_terrain_silent(grid_pos)
		return true
	return false


func remove_object_silent(grid_pos: Vector2i) -> void:
	if not _objects.has(grid_pos):
		return
	var obj: Node3D = _objects[grid_pos]
	if _selected == obj:
		_deselect()
	_objects.erase(grid_pos)
	obj.queue_free()
	object_removed.emit(grid_pos)


func _remove_terrain_silent(grid_pos: Vector2i) -> void:
	if not _terrain.has(grid_pos):
		return
	var obj: Node3D = _terrain[grid_pos]
	if _selected == obj:
		_deselect()
	_terrain.erase(grid_pos)
	obj.queue_free()
	object_removed.emit(grid_pos)


func move_object(from: Vector2i, to: Vector2i) -> bool:
	if not is_in_bounds(to):
		return false

	# Content layer move.
	if _objects.has(from):
		if has_content(to):
			return false
		var obj: Node3D = _objects[from]
		_objects.erase(from)
		_objects[to] = obj
		obj.set_meta("grid_pos", to)
		obj.position = grid_to_world(to)
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_move(from, to)
		object_moved.emit(from, to)
		return true

	# Terrain layer move (dirt / water / path). May sit under content at `to`.
	if _terrain.has(from):
		if has_terrain(to):
			return false
		var terrain: Node3D = _terrain[from]
		_terrain.erase(from)
		_terrain[to] = terrain
		terrain.set_meta("grid_pos", to)
		terrain.position = grid_to_world(to)
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_move(from, to)
		object_moved.emit(from, to)
		return true

	return false


func move_content_group(moves: Array) -> bool:
	## Moves a mixed group of content and/or terrain. Each entry:
	## { "obj": Node3D, "from": Vector2i, "to": Vector2i }
	if moves.is_empty():
		return false

	var moving_content: Dictionary = {}
	var moving_terrain: Dictionary = {}
	for entry in moves:
		var obj: Node3D = entry["obj"]
		if is_terrain_object(obj):
			moving_terrain[obj] = entry["from"]
		else:
			moving_content[obj] = entry["from"]

	var content_targets: Dictionary = {}
	var terrain_targets: Dictionary = {}
	for entry in moves:
		var to: Vector2i = entry["to"]
		var obj: Node3D = entry["obj"]
		if not is_in_bounds(to):
			return false
		if is_terrain_object(obj):
			if terrain_targets.has(to):
				return false
			terrain_targets[to] = true
			if has_terrain(to):
				var occupant: Node3D = _terrain[to]
				if not moving_terrain.has(occupant):
					return false
		else:
			if content_targets.has(to):
				return false
			content_targets[to] = true
			if has_content(to):
				var occupant: Node3D = _objects[to]
				if not moving_content.has(occupant):
					return false

	for entry in moves:
		var from: Vector2i = entry["from"]
		var obj: Node3D = entry["obj"]
		if is_terrain_object(obj):
			if _terrain.get(from) == obj:
				_terrain.erase(from)
		else:
			if _objects.get(from) == obj:
				_objects.erase(from)

	for entry in moves:
		var to: Vector2i = entry["to"]
		var obj: Node3D = entry["obj"]
		if is_terrain_object(obj):
			_terrain[to] = obj
		else:
			_objects[to] = obj
		obj.set_meta("grid_pos", to)
		obj.position = grid_to_world(to)
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_move(entry["from"], to)
		object_moved.emit(entry["from"], to)
	return true


func move_object_silent(from: Vector2i, to: Vector2i) -> bool:
	if not _objects.has(from) or not is_in_bounds(to) or has_content(to):
		return false
	var obj: Node3D = _objects[from]
	_objects.erase(from)
	_objects[to] = obj
	obj.set_meta("grid_pos", to)
	obj.position = grid_to_world(to)
	object_moved.emit(from, to)
	return true


func rotate_object(grid_pos: Vector2i, steps: int = 1) -> void:
	var obj := get_object_at(grid_pos)
	if obj == null:
		return
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	if not ItemData.is_rotatable(item_type):
		return
	var old_rot: int = obj.get_meta("rotation", 0)
	var new_rot: int = (old_rot + steps) % 4
	obj.set_meta("rotation", new_rot)
	obj.rotation.y = deg_to_rad(new_rot * 90.0)

	if undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_rotate(grid_pos, old_rot, new_rot)


func set_rotation_silent(grid_pos: Vector2i, rotation: int) -> void:
	var obj := get_object_at(grid_pos)
	if obj == null:
		return
	obj.set_meta("rotation", rotation)
	obj.rotation.y = deg_to_rad(rotation * 90.0)


func get_all_objects_data() -> Array:
	var result: Array = []
	# Save terrain-only cells first.
	for grid_pos: Vector2i in _terrain:
		if has_content(grid_pos):
			continue
		var terrain: Node3D = _terrain[grid_pos]
		result.append({
			"type": ItemData.get_item_id(terrain.get_meta("item_type")),
			"grid_x": grid_pos.x,
			"grid_y": grid_pos.y,
			"rotation": terrain.get_meta("rotation", 0),
			"layer": "terrain",
		})
	# Save content; include ground type when stacked on terrain.
	for grid_pos: Vector2i in _objects:
		var obj: Node3D = _objects[grid_pos]
		var entry := {
			"type": ItemData.get_item_id(obj.get_meta("item_type")),
			"grid_x": grid_pos.x,
			"grid_y": grid_pos.y,
			"rotation": obj.get_meta("rotation", 0),
			"layer": "content",
		}
		if ItemData.is_growable_plant(obj.get_meta("item_type")):
			entry["growth_stage"] = obj.get_meta("growth_stage", 0)
		if has_terrain(grid_pos):
			entry["ground"] = ItemData.get_item_id(_terrain[grid_pos].get_meta("item_type"))
		result.append(entry)
	return result


func clear_all() -> void:
	_deselect()
	for grid_pos: Vector2i in _objects.duplicate():
		remove_object_silent(grid_pos)
	for grid_pos: Vector2i in _terrain.duplicate():
		_remove_terrain_silent(grid_pos)
	if undo_manager:
		undo_manager.clear()


func is_plant_mature(grid_pos: Vector2i) -> bool:
	var obj := get_content_at(grid_pos)
	if obj == null:
		return false
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	if not ItemData.is_harvestable_plant(item_type):
		return false
	return obj.get_meta("growth_stage", 0) >= CropGrowth.STAGE_COUNT - 1


func harvest_plant(grid_pos: Vector2i):
	if not is_plant_mature(grid_pos):
		return null
	var obj: Node3D = _objects[grid_pos]
	var plant_type: ItemData.ItemType = obj.get_meta("item_type")
	var harvest_item := InventoryData.from_plant_type(plant_type)
	remove_object_silent(grid_pos)
	_spawn_object(ItemData.ItemType.DIRT, grid_pos, 0, 0, false, false)
	return harvest_item


func try_fish(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	# Pond (content) or water (terrain) both work.
	if has_content(grid_pos) and ItemData.is_fishable(get_item_type_at(grid_pos)):
		return true
	return ItemData.is_fishable(get_terrain_type_at(grid_pos))


func is_animal_at(grid_pos: Vector2i) -> bool:
	var obj := get_content_at(grid_pos)
	if obj == null:
		return false
	return ItemData.is_animal(obj.get_meta("item_type"))


func get_animal_at(grid_pos: Vector2i) -> Node3D:
	var obj := get_content_at(grid_pos)
	if obj and ItemData.is_animal(obj.get_meta("item_type")):
		return obj
	return null


func load_objects_data(data: Array) -> void:
	clear_all()
	# First pass: terrain / ground under content.
	for entry in data:
		var ground_id: String = entry.get("ground", "")
		if ground_id.is_empty():
			continue
		var grid_pos := Vector2i(entry.get("grid_x", 0), entry.get("grid_y", 0))
		var ground_type := ItemData.get_item_by_id(ground_id)
		if ItemData.is_terrain(ground_type) and not has_terrain(grid_pos):
			place_object_silent(ground_type, grid_pos, 0, 0)

	for entry in data:
		var item_type := ItemData.get_item_by_id(entry.get("type", "grass"))
		var grid_pos := Vector2i(entry.get("grid_x", 0), entry.get("grid_y", 0))
		var rotation: int = entry.get("rotation", 0)
		var growth_stage: int = entry.get("growth_stage", 0)
		# Skip ground-only duplicates already spawned from "ground" field.
		if entry.get("layer", "") == "terrain" or ItemData.is_terrain(item_type):
			if not has_terrain(grid_pos):
				place_object_silent(item_type, grid_pos, rotation, growth_stage)
			continue
		place_object_silent(item_type, grid_pos, rotation, growth_stage)
