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

	# Ground plane
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


func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH \
		and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT


func is_occupied(grid_pos: Vector2i) -> bool:
	return _objects.has(grid_pos)


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
	for child in obj.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override
			if mat:
				mat.emission_enabled = enabled
				mat.emission = Color(0.3, 0.5, 0.8) if enabled else Color.BLACK
				mat.emission_energy_multiplier = 0.5 if enabled else 0.0


func place_object(item_type: ItemData.ItemType, grid_pos: Vector2i, rotation: int = 0) -> Node3D:
	if not is_in_bounds(grid_pos) or is_occupied(grid_pos):
		return null

	var obj: Node3D = PlaceableObject.create(item_type, grid_pos, rotation)
	obj.position = grid_to_world(grid_pos)
	objects_container.add_child(obj)
	_objects[grid_pos] = obj
	object_placed.emit(grid_pos, obj)
	return obj


func remove_object(grid_pos: Vector2i) -> void:
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
	object_moved.emit(from, to)
	return true


func rotate_object(grid_pos: Vector2i, steps: int = 1) -> void:
	if not _objects.has(grid_pos):
		return
	var obj: Node3D = _objects[grid_pos]
	var item_type: ItemData.ItemType = obj.get_meta("item_type")
	if not ItemData.is_rotatable(item_type):
		return
	var rot: int = obj.get_meta("rotation", 0)
	rot = (rot + steps) % 4
	obj.set_meta("rotation", rot)
	obj.rotation.y = deg_to_rad(rot * 90.0)


func get_all_objects_data() -> Array:
	var result: Array = []
	for grid_pos: Vector2i in _objects:
		var obj: Node3D = _objects[grid_pos]
		result.append({
			"type": ItemData.get_item_id(obj.get_meta("item_type")),
			"grid_x": grid_pos.x,
			"grid_y": grid_pos.y,
			"rotation": obj.get_meta("rotation", 0),
		})
	return result


func clear_all() -> void:
	_deselect()
	for grid_pos: Vector2i in _objects.duplicate():
		remove_object(grid_pos)


func load_objects_data(data: Array) -> void:
	clear_all()
	for entry in data:
		var item_type := ItemData.get_item_by_id(entry.get("type", "grass"))
		var grid_pos := Vector2i(entry.get("grid_x", 0), entry.get("grid_y", 0))
		var rotation: int = entry.get("rotation", 0)
		place_object(item_type, grid_pos, rotation)
