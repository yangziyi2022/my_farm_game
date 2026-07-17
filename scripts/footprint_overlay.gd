class_name FootprintOverlay
extends Node3D

## Semi-transparent square footprint (matches orthogonal grid cells).
## Parent under a placeable / ghost so it rotates with the object.

const FILL_VALID := Color(0.35, 0.9, 0.45, 0.32)
const FILL_INVALID := Color(0.95, 0.3, 0.3, 0.35)
const EDGE_VALID := Color(0.2, 0.75, 0.35, 0.9)
const EDGE_INVALID := Color(0.95, 0.25, 0.25, 0.95)

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
			_add_square_cell(local, grid_manager.TILE_WIDTH, grid_manager.TILE_HEIGHT)


func _add_square_cell(local_pos: Vector3, tile_w: float, tile_h: float) -> void:
	var hw := tile_w * 0.5
	var hh := tile_h * 0.5
	# Axis-aligned square in XZ (matches orthogonal grid + box meshes).
	var corners: Array[Vector3] = [
		Vector3(-hw, 0.0, -hh),
		Vector3(hw, 0.0, -hh),
		Vector3(hw, 0.0, hh),
		Vector3(-hw, 0.0, hh),
	]

	var fill := MeshInstance3D.new()
	fill.name = "FootprintFill"
	fill.mesh = _make_quad_mesh(corners, 0.02)
	fill.position = local_pos + Vector3(0.0, 0.03, 0.0)
	fill.material_override = _make_mat(FILL_VALID)
	add_child(fill)
	_fill_meshes.append(fill)

	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var edge := MeshInstance3D.new()
		edge.name = "FootprintEdge"
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, length)
		edge.mesh = box
		edge.position = local_pos + mid + Vector3(0.0, 0.05, 0.0)
		if dir.length_squared() > 0.0001:
			edge.basis = Basis.looking_at(dir, Vector3.UP)
		edge.material_override = _make_mat(EDGE_VALID)
		add_child(edge)
		_edge_meshes.append(edge)


func _make_quad_mesh(corners: Array[Vector3], thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := thickness * 0.5
	_add_tri(st, corners[0] + Vector3(0, y, 0), corners[1] + Vector3(0, y, 0), corners[2] + Vector3(0, y, 0))
	_add_tri(st, corners[0] + Vector3(0, y, 0), corners[2] + Vector3(0, y, 0), corners[3] + Vector3(0, y, 0))
	_add_tri(st, corners[0] + Vector3(0, -y, 0), corners[2] + Vector3(0, -y, 0), corners[1] + Vector3(0, -y, 0))
	_add_tri(st, corners[0] + Vector3(0, -y, 0), corners[3] + Vector3(0, -y, 0), corners[2] + Vector3(0, -y, 0))
	st.generate_normals()
	return st.commit()


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


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
