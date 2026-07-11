class_name FootprintOverlay
extends Node3D

## Semi-transparent grid footprint under placement ghosts.
## Shows the gameplay tile(s) an item will occupy — independent of visual mesh size.

const FILL_VALID := Color(0.35, 0.9, 0.45, 0.32)
const FILL_INVALID := Color(0.95, 0.3, 0.3, 0.35)
const EDGE_VALID := Color(0.2, 0.75, 0.35, 0.85)
const EDGE_INVALID := Color(0.95, 0.25, 0.25, 0.9)

var _fill_meshes: Array[MeshInstance3D] = []
var _edge_meshes: Array[MeshInstance3D] = []


static func create_for_item(item_type: ItemData.ItemType, grid_manager: GridManager) -> FootprintOverlay:
	var overlay := FootprintOverlay.new()
	overlay.name = "FootprintOverlay"
	overlay._build(ItemData.get_footprint(item_type), grid_manager)
	return overlay


func _build(footprint: Vector2i, grid_manager: GridManager) -> void:
	var w: int = maxi(footprint.x, 1)
	var h: int = maxi(footprint.y, 1)
	var origin := grid_manager.grid_to_world(Vector2i.ZERO)

	for x in range(w):
		for y in range(h):
			var cell_world := grid_manager.grid_to_world(Vector2i(x, y))
			var local := cell_world - origin
			_add_cell(local, grid_manager.TILE_WIDTH, grid_manager.TILE_HEIGHT)


func _add_cell(local_pos: Vector3, tile_w: float, tile_h: float) -> void:
	var fill := MeshInstance3D.new()
	fill.name = "FootprintFill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(tile_w * 0.92, 0.035, tile_h * 0.92)
	fill.mesh = fill_mesh
	fill.position = local_pos + Vector3(0.0, 0.025, 0.0)
	fill.material_override = _make_mat(FILL_VALID)
	add_child(fill)
	_fill_meshes.append(fill)

	# Bright border so the unit cell is obvious even when the model is huge/tiny.
	var edge_t := 0.04
	var half_w := tile_w * 0.46
	var half_h := tile_h * 0.46
	var y := 0.045
	_add_edge(local_pos + Vector3(0.0, y, -half_h), Vector3(tile_w * 0.92, edge_t, edge_t))
	_add_edge(local_pos + Vector3(0.0, y, half_h), Vector3(tile_w * 0.92, edge_t, edge_t))
	_add_edge(local_pos + Vector3(-half_w, y, 0.0), Vector3(edge_t, edge_t, tile_h * 0.92))
	_add_edge(local_pos + Vector3(half_w, y, 0.0), Vector3(edge_t, edge_t, tile_h * 0.92))


func _add_edge(pos: Vector3, size: Vector3) -> void:
	var edge := MeshInstance3D.new()
	edge.name = "FootprintEdge"
	var mesh := BoxMesh.new()
	mesh.size = size
	edge.mesh = mesh
	edge.position = pos
	edge.material_override = _make_mat(EDGE_VALID)
	add_child(edge)
	_edge_meshes.append(edge)


func set_valid(valid: bool) -> void:
	var fill_color := FILL_VALID if valid else FILL_INVALID
	var edge_color := EDGE_VALID if valid else EDGE_INVALID
	for mesh in _fill_meshes:
		_set_color(mesh, fill_color)
	for mesh in _edge_meshes:
		_set_color(mesh, edge_color)


static func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


static func _set_color(mesh: MeshInstance3D, color: Color) -> void:
	var mat: StandardMaterial3D = mesh.material_override
	if mat:
		mat.albedo_color = color
