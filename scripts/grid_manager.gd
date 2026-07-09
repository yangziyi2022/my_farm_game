class_name GridManager
extends Node3D

signal object_placed(grid_pos: Vector2i, object_node: Node3D)
signal object_removed(grid_pos: Vector2i)
signal object_moved(from: Vector2i, to: Vector2i)
signal selection_changed(object_node: Node3D)

const TILE_WIDTH: float = 1.0
const TILE_HEIGHT: float = 1.0
const GRID_WIDTH: int = 24
const GRID_HEIGHT: int = 24

var undo_manager: UndoManager

var _objects: Dictionary = {}  # Vector2i -> Node3D
var _selected: Node3D = null
var _grid_visual: Node3D

@onready var objects_container: Node3D = $Objects


func _ready() -> void:
	_build_grid_visual()


func _build_grid_visual() -> void:
	_grid_visual = Node3D.new()
	_grid_visual.name = "GridVisual"
	add_child(_grid_visual)

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.3, 0.5, 0.3, 0.4)
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for x in range(GRID_WIDTH + 1):
		var start := grid_to_world(Vector2i(x, 0))
		var end := grid_to_world(Vector2i(x, GRID_HEIGHT))
		_add_line(start, end, line_material)

	for y in range(GRID_HEIGHT + 1):
		var start := grid_to_world(Vector2i(0, y))
		var end := grid_to_world(Vector2i(GRID_WIDTH, y))
		_add_line(start, end, line_material)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_WIDTH * TILE_WIDTH + 2, GRID_HEIGHT * TILE_HEIGHT + 2)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.62, 0.32)
	ground.material_override = ground_mat
	ground.position = grid_to_world(Vector2i(GRID_WIDTH / 2, GRID_HEIGHT / 2))
	ground.position.y = -0.01
	_grid_visual.add_child(ground)


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
	return _objects.has(grid_pos)


func get_item_type_at(grid_pos: Vector2i) -> ItemData.ItemType:
	var obj := get_object_at(grid_pos)
	if obj:
		return obj.get_meta("item_type")
	return ItemData.ItemType.GRASS


func get_object_at(grid_pos: Vector2i) -> Node3D:
	return _objects.get(grid_pos)


func get_selected() -> Node3D:
	return _selected


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
	# Only flower seeds require hoed dirt.
	if ItemData.is_flower_seed(item_type):
		return is_occupied(grid_pos) and get_item_type_at(grid_pos) == ItemData.ItemType.DIRT
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

	if is_occupied(grid_pos):
		var existing_type := get_item_type_at(grid_pos)
		if ItemData.is_flower_seed(item_type):
			if existing_type == ItemData.ItemType.DIRT:
				return replace_object(grid_pos, item_type, rotation, growth_stage, animate_placement)
			return null
		if ItemData.can_build_over(existing_type):
			return replace_object(grid_pos, item_type, rotation, growth_stage, animate_placement)
		return null

	return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)


func hoe_grass(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	if not is_occupied(grid_pos):
		place_object(ItemData.ItemType.DIRT, grid_pos, 0, true, 0)
		return true
	var item_type := get_item_type_at(grid_pos)
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
	var before_obj: Node3D = _objects[grid_pos]
	var before_rotation: int = before_obj.get_meta("rotation", 0)
	var before_growth: int = before_obj.get_meta("growth_stage", 0)

	remove_object_silent(grid_pos)
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
	return _spawn_object(item_type, grid_pos, rotation, growth_stage, false, false)


func replace_object_silent(
	grid_pos: Vector2i,
	item_type: ItemData.ItemType,
	rotation: int = 0,
	growth_stage: int = 0
) -> Node3D:
	if is_occupied(grid_pos):
		remove_object_silent(grid_pos)
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
	_objects[grid_pos] = obj
	_add_tile_collider(obj)
	ObjectPolish.setup(obj, item_type, animate_placement)

	if record_undo and undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_place(grid_pos, item_type, rotation, growth_stage)

	object_placed.emit(grid_pos, obj)
	return obj


func _add_tile_collider(obj: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "TileCollider"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_WIDTH * 0.92, 0.22, TILE_HEIGHT * 0.92)
	col.shape = box
	col.position.y = 0.11
	body.add_child(col)
	obj.add_child(body)


func remove_object(grid_pos: Vector2i) -> void:
	if not _objects.has(grid_pos):
		return

	var obj: Node3D = _objects[grid_pos]
	if undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_remove(
			grid_pos,
			obj.get_meta("item_type"),
			obj.get_meta("rotation", 0),
			obj.get_meta("growth_stage", 0)
		)
	remove_object_silent(grid_pos)


func remove_object_silent(grid_pos: Vector2i) -> void:
	if not _objects.has(grid_pos):
		return
	var obj: Node3D = _objects[grid_pos]
	if _selected == obj:
		_deselect()
	_objects.erase(grid_pos)
	obj.queue_free()
	object_removed.emit(grid_pos)


func move_object(from: Vector2i, to: Vector2i) -> bool:
	if not _objects.has(from) or not is_in_bounds(to) or is_occupied(to):
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


func move_object_silent(from: Vector2i, to: Vector2i) -> bool:
	if not _objects.has(from) or not is_in_bounds(to) or is_occupied(to):
		return false
	var obj: Node3D = _objects[from]
	_objects.erase(from)
	_objects[to] = obj
	obj.set_meta("grid_pos", to)
	obj.position = grid_to_world(to)
	object_moved.emit(from, to)
	return true


func rotate_object(grid_pos: Vector2i, steps: int = 1) -> void:
	if not _objects.has(grid_pos):
		return
	var obj: Node3D = _objects[grid_pos]
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
	if not _objects.has(grid_pos):
		return
	var obj: Node3D = _objects[grid_pos]
	obj.set_meta("rotation", rotation)
	obj.rotation.y = deg_to_rad(rotation * 90.0)


func get_all_objects_data() -> Array:
	var result: Array = []
	for grid_pos: Vector2i in _objects:
		var obj: Node3D = _objects[grid_pos]
		var entry := {
			"type": ItemData.get_item_id(obj.get_meta("item_type")),
			"grid_x": grid_pos.x,
			"grid_y": grid_pos.y,
			"rotation": obj.get_meta("rotation", 0),
		}
		if ItemData.is_growable_plant(obj.get_meta("item_type")):
			entry["growth_stage"] = obj.get_meta("growth_stage", 0)
		result.append(entry)
	return result


func clear_all() -> void:
	_deselect()
	for grid_pos: Vector2i in _objects.duplicate():
		remove_object_silent(grid_pos)
	if undo_manager:
		undo_manager.clear()


func load_objects_data(data: Array) -> void:
	clear_all()
	for entry in data:
		var item_type := ItemData.get_item_by_id(entry.get("type", "grass"))
		var grid_pos := Vector2i(entry.get("grid_x", 0), entry.get("grid_y", 0))
		var rotation: int = entry.get("rotation", 0)
		var growth_stage: int = entry.get("growth_stage", 0)
		place_object_silent(item_type, grid_pos, rotation, growth_stage)
