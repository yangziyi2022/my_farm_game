class_name GridManager
extends Node3D

signal object_placed(grid_pos: Vector2i, object_node: Node3D)
signal object_removed(grid_pos: Vector2i)
signal object_moved(from: Vector2i, to: Vector2i)
signal selection_changed(object_node: Node3D)

const TILE_WIDTH: float = 1.25
const TILE_HEIGHT: float = 1.25
## Expanded so a circular playable disc can be filled with cells.
const GRID_WIDTH: int = 56
const GRID_HEIGHT: int = 56
## Shift so world center stays near the island center.
const GRID_SHIFT: int = 8
## Circular playable area — fitted to floating_island top (island xz radius ≈ 26).
const PLAY_RADIUS: float = 24.2
const ISLAND_GLB_PATH: String = "res://assets/models/nature/floating_island.glb"
## Raw mesh top Y of floating_island.glb (used to flush the deck with y=0).
const ISLAND_TOP_LOCAL_Y: float = 0.244
const ISLAND_SCALE: float = 52.0
## Sampled from floating_island basecolor grass.
const ISLAND_GRASS_COLOR := Color(0.30, 0.40, 0.03)
const ISLAND_GRASS_TUFT_COLOR := Color(0.34, 0.45, 0.04)
## Low-poly tuft Multimesh (tiny tris) — safe to place on most cells.
const GRASS_CELL_STEP: int = 2
const GRASS_XZ_SCALE: float = 0.55
const GRASS_Y_SCALE: float = 0.7
const DRAW_GRID_LINES: bool = false

var undo_manager: UndoManager

## Two layers per cell:
## - _terrain: dirt / water / stone_path (explicit ground). Missing terrain = default grass.
## - _objects: animals, buildings, plants, decor (the selectable "content")
var _terrain: Dictionary = {}  # Vector2i -> Node3D
var _objects: Dictionary = {}  # Vector2i -> Node3D
var _selected: Node3D = null
var _grid_visual: Node3D
var _water_fish_manager: WaterFishManager
var _grass_mmi: MultiMeshInstance3D = null
var _grass_cell_index: Dictionary = {}  # Vector2i -> int
var _grass_visible_xform: Dictionary = {}  # Vector2i -> Transform3D

@onready var objects_container: Node3D = $Objects


func _ready() -> void:
	_build_grid_visual()
	_build_default_grass()
	_water_fish_manager = WaterFishManager.new()
	_water_fish_manager.name = "WaterFishManager"
	add_child(_water_fish_manager)
	_water_fish_manager.setup(self)


func _build_grid_visual() -> void:
	_grid_visual = Node3D.new()
	_grid_visual.name = "GridVisual"
	add_child(_grid_visual)

	# Per-edge MeshInstance nodes (~thousands) are expensive; off by default.
	if DRAW_GRID_LINES:
		var line_material := StandardMaterial3D.new()
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_material.albedo_color = Color(ISLAND_GRASS_COLOR.r, ISLAND_GRASS_COLOR.g, ISLAND_GRASS_COLOR.b, 0.45)
		line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for x in range(GRID_WIDTH + 1):
			for y in range(GRID_HEIGHT):
				if _cell_exists(Vector2i(x, y)) or _cell_exists(Vector2i(x - 1, y)):
					_add_line(
						grid_to_world(Vector2i(x, y)),
						grid_to_world(Vector2i(x, y + 1)),
						line_material
					)
		for y in range(GRID_HEIGHT + 1):
			for x in range(GRID_WIDTH):
				if _cell_exists(Vector2i(x, y)) or _cell_exists(Vector2i(x, y - 1)):
					_add_line(
						grid_to_world(Vector2i(x, y)),
						grid_to_world(Vector2i(x + 1, y)),
						line_material
					)

	_build_island()


func _cell_exists(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT \
		and is_in_bounds(cell)


func _build_island() -> void:
	## Art island base from floating_island.glb; playable deck stays at y=0.
	var center := get_map_center()

	var island := Node3D.new()
	island.name = "Island"
	island.position = Vector3(center.x, 0.0, center.z)
	_grid_visual.add_child(island)

	if ResourceLoader.exists(ISLAND_GLB_PATH):
		var packed := load(ISLAND_GLB_PATH) as PackedScene
		if packed:
			var model: Node3D = packed.instantiate() as Node3D
			model.name = "FloatingIslandModel"
			model.scale = Vector3.ONE * ISLAND_SCALE
			# Lift so the model's top deck sits on the playable plane (y=0).
			model.position.y = -ISLAND_TOP_LOCAL_Y * ISLAND_SCALE
			island.add_child(model)

	# Solid grass floor (cheap). Sparse Grass Patch tufts add detail on top.
	var deck := MeshInstance3D.new()
	deck.name = "PlayableDeck"
	var deck_mesh := CylinderMesh.new()
	deck_mesh.top_radius = PLAY_RADIUS
	deck_mesh.bottom_radius = PLAY_RADIUS
	deck_mesh.height = 0.04
	deck_mesh.radial_segments = 48
	deck.mesh = deck_mesh
	deck.position = Vector3(center.x, -0.015, center.z)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = ISLAND_GRASS_COLOR
	deck_mat.roughness = 0.95
	deck.material_override = deck_mat
	_grid_visual.add_child(deck)

	# Thin ring marking the circular playable boundary.
	var ring := MeshInstance3D.new()
	ring.name = "PlayableRing"
	ring.mesh = _make_circle_ring_mesh(PLAY_RADIUS, 0.12, 64)
	ring.position = Vector3(center.x, 0.03, center.z)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.95, 0.9, 0.55, 0.65)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	_grid_visual.add_child(ring)


func _build_default_grass() -> void:
	## Low-poly Multimesh tufts on a solid grass deck. ~20 tris/tuft, not Grass Patch.glb.
	var cells: Array[Vector2i] = []
	for x in range(0, GRID_WIDTH, GRASS_CELL_STEP):
		for y in range(0, GRID_HEIGHT, GRASS_CELL_STEP):
			var cell := Vector2i(x, y)
			if is_in_bounds(cell):
				cells.append(cell)
	if cells.is_empty():
		return

	_grass_mmi = MultiMeshInstance3D.new()
	_grass_mmi.name = "DefaultGrass"
	_grass_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass_mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_lowpoly_grass_tuft_mesh()
	mm.instance_count = cells.size()
	_grass_mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ISLAND_GRASS_TUFT_COLOR
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grass_mmi.material_override = mat
	objects_container.add_child(_grass_mmi)

	_grass_cell_index.clear()
	_grass_visible_xform.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var world := grid_to_world(cell)
		var yaw := rng.randf() * TAU
		var xz := GRASS_XZ_SCALE * rng.randf_range(0.85, 1.2)
		var y_s := GRASS_Y_SCALE * rng.randf_range(0.75, 1.15)
		var xf := Transform3D.IDENTITY
		xf.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(xz, y_s, xz))
		xf.origin = world + Vector3(
			rng.randf_range(-0.15, 0.15),
			0.01,
			rng.randf_range(-0.15, 0.15)
		)
		_grass_cell_index[cell] = i
		_grass_visible_xform[cell] = xf
		mm.set_instance_transform(i, xf)

	_sync_grass_visibility()


func _make_lowpoly_grass_tuft_mesh() -> ArrayMesh:
	## Three crossed blade cards (~18 tris). Cheap enough for dense Multimesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := [
		{"yaw": 0.0, "w": 0.22, "h": 0.18},
		{"yaw": deg_to_rad(60.0), "w": 0.2, "h": 0.16},
		{"yaw": deg_to_rad(120.0), "w": 0.18, "h": 0.2},
	]
	for blade in blades:
		var yaw: float = blade["yaw"]
		var half_w: float = blade["w"] * 0.5
		var h: float = blade["h"]
		var c := cos(yaw)
		var s := sin(yaw)
		var bl := Vector3(-half_w * c, 0.0, -half_w * s)
		var br := Vector3(half_w * c, 0.0, half_w * s)
		var tl := Vector3(-half_w * 0.35 * c, h, -half_w * 0.35 * s)
		var tr := Vector3(half_w * 0.35 * c, h, half_w * 0.35 * s)
		var tip := Vector3(0.0, h * 1.15, 0.0)
		# Quad
		st.add_vertex(bl)
		st.add_vertex(br)
		st.add_vertex(tr)
		st.add_vertex(bl)
		st.add_vertex(tr)
		st.add_vertex(tl)
		# Tip
		st.add_vertex(tl)
		st.add_vertex(tr)
		st.add_vertex(tip)
	st.generate_normals()
	return st.commit()


func _grass_home_for(cell: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell.x) / float(GRASS_CELL_STEP))) * GRASS_CELL_STEP,
		int(floor(float(cell.y) / float(GRASS_CELL_STEP))) * GRASS_CELL_STEP
	)


func _refresh_grass_around(cell: Vector2i) -> void:
	var home := _grass_home_for(cell)
	if not _grass_cell_index.has(home):
		return
	var show := true
	for ox in range(GRASS_CELL_STEP):
		for oy in range(GRASS_CELL_STEP):
			var c := home + Vector2i(ox, oy)
			if not has_terrain(c):
				continue
			var t: ItemData.ItemType = _terrain[c].get_meta("item_type")
			if t != ItemData.ItemType.GRASS:
				show = false
				break
		if not show:
			break
	_set_grass_cell_visible(home, show)


func _set_grass_cell_visible(cell: Vector2i, visible: bool) -> void:
	if _grass_mmi == null or not _grass_cell_index.has(cell):
		return
	var idx: int = _grass_cell_index[cell]
	if visible:
		_grass_mmi.multimesh.set_instance_transform(idx, _grass_visible_xform[cell])
	else:
		_grass_mmi.multimesh.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))


func _sync_grass_visibility() -> void:
	## Show tufts only when their local STEP×STEP block has no dirt/water/path.
	if _grass_mmi == null:
		return
	for cell: Vector2i in _grass_cell_index:
		_refresh_grass_around(cell)


func _make_circle_ring_mesh(radius: float, thickness: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := maxf(radius - thickness, 0.05)
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var o0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var o1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var i0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var i1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	st.generate_normals()
	return st.commit()


func get_map_center() -> Vector3:
	return grid_to_world(Vector2i(int(GRID_WIDTH / 2.0), int(GRID_HEIGHT / 2.0)))


static func yaw_for_steps(rotation_steps: int) -> float:
	## Player rotate steps only (90°). Orthogonal grid needs no 45° bias.
	return deg_to_rad(float(posmod(rotation_steps, 4)) * 90.0)


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
	## Orthogonal cell centers — iso look comes from the angled camera.
	var gx := float(grid_pos.x - GRID_SHIFT)
	var gy := float(grid_pos.y - GRID_SHIFT)
	return Vector3(gx * TILE_WIDTH, 0.0, gy * TILE_HEIGHT)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx := world_pos.x / TILE_WIDTH
	var gy := world_pos.z / TILE_HEIGHT
	return Vector2i(roundi(gx) + GRID_SHIFT, roundi(gy) + GRID_SHIFT)


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
	if grid_pos.x < 0 or grid_pos.x >= GRID_WIDTH \
		or grid_pos.y < 0 or grid_pos.y >= GRID_HEIGHT:
		return false
	var world := grid_to_world(grid_pos)
	var center := get_map_center()
	var dx := world.x - center.x
	var dz := world.z - center.z
	return dx * dx + dz * dz <= PLAY_RADIUS * PLAY_RADIUS


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
	var seen: Dictionary = {}
	for obj in _objects.values():
		if obj is Node3D and not seen.has(obj):
			seen[obj] = true
			result.append(obj)
	return result


func get_all_selectable_objects() -> Array[Node3D]:
	## Content + terrain (dirt / water / stone path). Used by marquee select.
	var result: Array[Node3D] = []
	var seen: Dictionary = {}
	for obj in _objects.values():
		if obj is Node3D and not seen.has(obj):
			seen[obj] = true
			result.append(obj)
	for obj in _terrain.values():
		if obj is Node3D and not seen.has(obj):
			seen[obj] = true
			result.append(obj)
	return result


func get_footprint_cells(anchor: Vector2i, footprint: Vector2i, rotation: int = 0) -> Array[Vector2i]:
	## Local cell offsets rotate with yaw_for_steps (90° CCW per step around the anchor).
	var cells: Array[Vector2i] = []
	var w: int = maxi(footprint.x, 1)
	var h: int = maxi(footprint.y, 1)
	var steps := posmod(rotation, 4)
	for x in range(w):
		for y in range(h):
			var ox := x
			var oy := y
			match steps:
				1:
					ox = y
					oy = -x
				2:
					ox = -x
					oy = -y
				3:
					ox = -y
					oy = x
			cells.append(anchor + Vector2i(ox, oy))
	return cells


func get_object_footprint(obj: Node3D) -> Vector2i:
	if obj and obj.has_meta("footprint"):
		var fp: Vector2i = obj.get_meta("footprint")
		return Vector2i(maxi(fp.x, 1), maxi(fp.y, 1))
	if obj and obj.has_meta("item_type"):
		return ItemData.get_footprint(obj.get_meta("item_type"))
	return Vector2i(1, 1)


func get_object_rotation(obj: Node3D) -> int:
	if obj and obj.has_meta("rotation"):
		return int(obj.get_meta("rotation"))
	return 0


func footprint_center_world(anchor: Vector2i, footprint: Vector2i, rotation: int = 0) -> Vector3:
	var cells := get_footprint_cells(anchor, footprint, rotation)
	var sum := Vector3.ZERO
	for cell in cells:
		sum += grid_to_world(cell)
	return sum / float(cells.size())


func _cells_for_object(obj: Node3D) -> Array[Vector2i]:
	var anchor: Vector2i = obj.get_meta("grid_pos")
	return get_footprint_cells(anchor, get_object_footprint(obj), get_object_rotation(obj))


func _register_content_cells(obj: Node3D, anchor: Vector2i, footprint: Vector2i, rotation: int = 0) -> void:
	for cell in get_footprint_cells(anchor, footprint, rotation):
		_objects[cell] = obj


func _unregister_content_object(obj: Node3D) -> void:
	var to_erase: Array[Vector2i] = []
	for cell: Vector2i in _objects:
		if _objects[cell] == obj:
			to_erase.append(cell)
	for cell in to_erase:
		_objects.erase(cell)


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
	if not enabled:
		SelectionFlash.reset(obj)


func _apply_highlight_recursive(node: Node, enabled: bool) -> void:
	if node is FootprintOverlay or str(node.name).begins_with("Footprint") \
			or node.name in ["SelectionFootprint", "HoeFootprint", "HarvestFX"]:
		return
	if node is MeshInstance3D:
		var mat: StandardMaterial3D = node.material_override
		if mat:
			mat.emission_enabled = enabled
			mat.emission = Color(0.3, 0.5, 0.8) if enabled else Color.BLACK
			mat.emission_energy_multiplier = 0.5 if enabled else 0.0
	for child in node.get_children():
		_apply_highlight_recursive(child, enabled)


func can_place_at(grid_pos: Vector2i, item_type: ItemData.ItemType, rotation: int = 0) -> bool:
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

	# Multi-cell content (e.g. 3x2 farmhouse): every cell in the rotated footprint must be free.
	var footprint := ItemData.get_footprint(item_type)
	for cell in get_footprint_cells(grid_pos, footprint, rotation):
		if not is_in_bounds(cell):
			return false
		if has_content(cell):
			return false

	# Only ducks may sit on water tiles; other animals stay on dry land.
	if ItemData.is_animal(item_type) and is_water_cell(grid_pos):
		return ItemData.can_live_on_water(item_type)

	if ItemData.stacks_on_terrain(item_type):
		return true

	# Non-stacking content on empty / build-over terrain only at the anchor.
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
		# Keep the full-size dirt tile; plant sits on top as content.
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
		if not can_place_at(grid_pos, item_type, rotation):
			return null
		return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)

	if is_occupied(grid_pos):
		var existing_type := get_item_type_at(grid_pos)
		if ItemData.can_build_over(existing_type):
			return replace_object(grid_pos, item_type, rotation, growth_stage, animate_placement)
		return null

	return _spawn_object(item_type, grid_pos, rotation, growth_stage, animate_placement, true)


func hoe_grass(grid_pos: Vector2i) -> bool:
	if not can_hoe_at(grid_pos):
		return false
	if not has_terrain(grid_pos):
		place_object(ItemData.ItemType.DIRT, grid_pos, 0, true, 0)
		return true
	replace_object(grid_pos, ItemData.ItemType.DIRT, 0, 0, true)
	return true


func can_hoe_at(grid_pos: Vector2i) -> bool:
	if not is_in_bounds(grid_pos):
		return false
	if has_content(grid_pos):
		return false
	if not has_terrain(grid_pos):
		return true
	return ItemData.is_hoeable(get_terrain_type_at(grid_pos))


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
	if ItemData.needs_dirt_to_plant(item_type):
		# Keep full-size dirt under crops (restore for legacy saves that stripped it).
		if has_content(grid_pos):
			remove_object_silent(grid_pos)
		if not has_terrain(grid_pos):
			_spawn_object(ItemData.ItemType.DIRT, grid_pos, 0, 0, false, false)
		return _spawn_object(item_type, grid_pos, rotation, growth_stage, false, false)
	if ItemData.is_terrain(item_type) and has_terrain(grid_pos) and not has_content(grid_pos):
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
	var footprint := ItemData.get_footprint(item_type)
	obj.set_meta("growth_stage", growth_stage)
	obj.set_meta("footprint", footprint)
	obj.position = grid_to_world(grid_pos)
	objects_container.add_child(obj)

	if ItemData.is_terrain(item_type):
		_terrain[grid_pos] = obj
		_refresh_grass_around(grid_pos)
	else:
		_register_content_cells(obj, grid_pos, footprint, rotation)

	# Polish first (AnimalPivot / reparent Visual) so mesh colliders match what you see.
	ObjectPolish.setup(obj, item_type, animate_placement, self)
	_add_tile_collider(obj, item_type)

	if record_undo and undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_place(grid_pos, item_type, rotation, growth_stage)

	object_placed.emit(grid_pos, obj)
	return obj


func _add_tile_collider(obj: Node3D, item_type: ItemData.ItemType) -> void:
	_disable_nested_pick_bodies(obj)

	var body := StaticBody3D.new()
	body.name = "TileCollider"
	body.collision_layer = 1
	body.collision_mask = 0

	if ItemData.is_terrain(item_type):
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TILE_WIDTH * 0.98, 0.08, TILE_HEIGHT * 0.98)
		col.position.y = 0.02
		col.shape = box
		body.add_child(col)
		obj.add_child(body)
		return

	# Crops change mesh per growth stage — keep a stable full-cell pick volume.
	if ItemData.is_growable_plant(item_type):
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TILE_WIDTH * 0.9, 1.0, TILE_HEIGHT * 0.9)
		col.position.y = 0.5
		col.shape = box
		body.add_child(col)
		obj.add_child(body)
		return

	# Content: collision follows visible meshes so clicking the model selects it.
	var host: Node3D = obj
	var animal_pivot := obj.get_node_or_null("AnimalPivot") as Node3D
	var sway_pivot := obj.get_node_or_null("SwayPivot") as Node3D
	if animal_pivot:
		host = animal_pivot
	elif sway_pivot:
		host = sway_pivot

	var added := 0
	for mesh_inst in _collect_mesh_instances(host):
		var col := _collision_shape_from_mesh(host, mesh_inst)
		if col == null:
			continue
		body.add_child(col)
		added += 1

	if added == 0:
		var footprint := ItemData.get_footprint(item_type)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var fw: float = float(maxi(footprint.x, 1))
		var fh: float = float(maxi(footprint.y, 1))
		box.size = Vector3(TILE_WIDTH * fw * 0.82, 0.55, TILE_HEIGHT * fh * 0.82)
		var center := footprint_center_world(Vector2i.ZERO, footprint)
		col.position = Vector3(center.x, 0.28, center.z)
		col.shape = box
		body.add_child(col)

	host.add_child(body)


func _disable_nested_pick_bodies(root: Node) -> void:
	## Scene wrappers may ship tiny/wrong StaticBodies; only TileCollider should be pickable.
	for child in root.get_children():
		_disable_nested_pick_bodies(child)
		if child is CollisionObject3D and child.name != "TileCollider":
			(child as CollisionObject3D).collision_layer = 0


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(root, out)
	return out


func _collect_mesh_instances_recursive(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.visible:
			out.append(mi)
	for child in node.get_children():
		_collect_mesh_instances_recursive(child, out)


func _collision_shape_from_mesh(host: Node3D, mesh_inst: MeshInstance3D) -> CollisionShape3D:
	if mesh_inst.mesh == null:
		return null
	# Convex approximates the visible silhouette well enough for click selection.
	var shape: Shape3D = mesh_inst.mesh.create_convex_shape(true, true)
	if shape == null:
		var aabb := mesh_inst.get_aabb()
		if aabb.size.length_squared() < 0.000001:
			return null
		var box := BoxShape3D.new()
		box.size = aabb.size
		var col_aabb := CollisionShape3D.new()
		col_aabb.shape = box
		col_aabb.transform = host.global_transform.affine_inverse() * mesh_inst.global_transform \
			* Transform3D(Basis.IDENTITY, aabb.get_center())
		return col_aabb

	var col := CollisionShape3D.new()
	col.shape = shape
	col.transform = host.global_transform.affine_inverse() * mesh_inst.global_transform
	return col


func find_tile_collider(obj: Node3D) -> CollisionObject3D:
	if obj == null:
		return null
	var direct := obj.get_node_or_null("TileCollider") as CollisionObject3D
	if direct:
		return direct
	return obj.find_child("TileCollider", true, false) as CollisionObject3D


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
	_unregister_content_object(obj)
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
	_refresh_grass_around(grid_pos)


func can_move_content_to(obj: Node3D, new_anchor: Vector2i) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	var footprint := get_object_footprint(obj)
	var rotation := get_object_rotation(obj)
	for cell in get_footprint_cells(new_anchor, footprint, rotation):
		if not is_in_bounds(cell):
			return false
		if has_content(cell) and _objects[cell] != obj:
			return false
	return true


func move_object(from: Vector2i, to: Vector2i) -> bool:
	if not is_in_bounds(to):
		return false

	# Content layer move (supports multi-cell footprints).
	if _objects.has(from):
		var obj: Node3D = _objects[from]
		var anchor: Vector2i = obj.get_meta("grid_pos")
		# Normalize: callers may pass any occupied cell; move from the true anchor.
		if from != anchor:
			from = anchor
		if not can_move_content_to(obj, to):
			return false
		var footprint := get_object_footprint(obj)
		var rotation := get_object_rotation(obj)
		_unregister_content_object(obj)
		obj.set_meta("grid_pos", to)
		_register_content_cells(obj, to, footprint, rotation)
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
		_refresh_grass_around(from)
		_refresh_grass_around(to)
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
		if is_terrain_object(obj):
			if not is_in_bounds(to):
				return false
			if terrain_targets.has(to):
				return false
			terrain_targets[to] = true
			if has_terrain(to):
				var occupant: Node3D = _terrain[to]
				if not moving_terrain.has(occupant):
					return false
		else:
			var footprint := get_object_footprint(obj)
			var rotation := get_object_rotation(obj)
			for cell in get_footprint_cells(to, footprint, rotation):
				if not is_in_bounds(cell):
					return false
				if content_targets.has(cell):
					return false
				content_targets[cell] = obj
				if has_content(cell):
					var occupant: Node3D = _objects[cell]
					if not moving_content.has(occupant):
						return false

	for entry in moves:
		var from: Vector2i = entry["from"]
		var obj: Node3D = entry["obj"]
		if is_terrain_object(obj):
			if _terrain.get(from) == obj:
				_terrain.erase(from)
		else:
			_unregister_content_object(obj)

	for entry in moves:
		var to: Vector2i = entry["to"]
		var obj: Node3D = entry["obj"]
		if is_terrain_object(obj):
			_terrain[to] = obj
			obj.set_meta("grid_pos", to)
			obj.position = grid_to_world(to)
		else:
			var footprint := get_object_footprint(obj)
			var rotation := get_object_rotation(obj)
			obj.set_meta("grid_pos", to)
			obj.set_meta("footprint", footprint)
			_register_content_cells(obj, to, footprint, rotation)
			obj.position = grid_to_world(to)
		if undo_manager and not undo_manager.is_applying_undo():
			undo_manager.record_move(entry["from"], to)
		object_moved.emit(entry["from"], to)
	_sync_grass_visibility()
	return true


func move_object_silent(from: Vector2i, to: Vector2i) -> bool:
	if not _objects.has(from):
		return false
	var obj: Node3D = _objects[from]
	from = obj.get_meta("grid_pos")
	if not can_move_content_to(obj, to):
		return false
	var footprint := get_object_footprint(obj)
	var rotation := get_object_rotation(obj)
	_unregister_content_object(obj)
	obj.set_meta("grid_pos", to)
	_register_content_cells(obj, to, footprint, rotation)
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
	var footprint := get_object_footprint(obj)
	var anchor: Vector2i = obj.get_meta("grid_pos")
	# Ensure the rotated footprint fits before committing.
	for cell in get_footprint_cells(anchor, footprint, new_rot):
		if not is_in_bounds(cell):
			return
		if has_content(cell) and _objects[cell] != obj:
			return
	_unregister_content_object(obj)
	obj.set_meta("rotation", new_rot)
	obj.rotation.y = yaw_for_steps(new_rot)
	if not is_terrain_object(obj):
		_register_content_cells(obj, anchor, footprint, new_rot)

	if undo_manager and not undo_manager.is_applying_undo():
		undo_manager.record_rotate(grid_pos, old_rot, new_rot)


func set_rotation_silent(grid_pos: Vector2i, rotation: int) -> void:
	var obj := get_object_at(grid_pos)
	if obj == null:
		return
	var footprint := get_object_footprint(obj)
	var anchor: Vector2i = obj.get_meta("grid_pos")
	_unregister_content_object(obj)
	obj.set_meta("rotation", rotation)
	obj.rotation.y = yaw_for_steps(rotation)
	if not is_terrain_object(obj):
		_register_content_cells(obj, anchor, footprint, rotation)


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
	# Save content once per object (anchor cell only for multi-cell footprints).
	var saved_content: Dictionary = {}
	for grid_pos: Vector2i in _objects:
		var obj: Node3D = _objects[grid_pos]
		if saved_content.has(obj):
			continue
		var anchor: Vector2i = obj.get_meta("grid_pos")
		saved_content[obj] = true
		var entry := {
			"type": ItemData.get_item_id(obj.get_meta("item_type")),
			"grid_x": anchor.x,
			"grid_y": anchor.y,
			"rotation": obj.get_meta("rotation", 0),
			"layer": "content",
		}
		if ItemData.is_growable_plant(obj.get_meta("item_type")):
			entry["growth_stage"] = obj.get_meta("growth_stage", 0)
		if has_terrain(anchor):
			entry["ground"] = ItemData.get_item_id(_terrain[anchor].get_meta("item_type"))
		result.append(entry)
	return result


func clear_all() -> void:
	_deselect()
	var content_objs: Array[Node3D] = get_all_content_objects()
	for obj in content_objs:
		if is_instance_valid(obj):
			var anchor: Vector2i = obj.get_meta("grid_pos")
			_unregister_content_object(obj)
			obj.queue_free()
			object_removed.emit(anchor)
	for grid_pos: Vector2i in _terrain.duplicate():
		_remove_terrain_silent(grid_pos)
	_sync_grass_visibility()
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
	# Dirt terrain was kept under the plant — restore only if somehow missing.
	if not has_terrain(grid_pos):
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


func animal_can_step_to(animal: Node3D, to: Vector2i) -> bool:
	if animal == null or not is_instance_valid(animal):
		return false
	if not is_in_bounds(to):
		return false
	# Occupied cells (fence, buildings, plants, other animals…) are impassable.
	if has_content(to):
		var occupant: Node3D = _objects[to]
		if occupant != animal:
			return false
	var item_type: ItemData.ItemType = animal.get_meta("item_type")
	if is_water_cell(to) and not ItemData.can_live_on_water(item_type):
		return false
	# Don't cut corners through fences / buildings on a diagonal step.
	var from: Vector2i = animal.get_meta("grid_pos")
	var delta := to - from
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		if _cell_blocks_animal_passage(from + Vector2i(delta.x, 0)):
			return false
		if _cell_blocks_animal_passage(from + Vector2i(0, delta.y)):
			return false
	return true


func _cell_blocks_animal_passage(cell: Vector2i) -> bool:
	## Any content (especially fence / buildings) blocks diagonal corner-cutting.
	if not is_in_bounds(cell):
		return true
	return has_content(cell)


func is_water_cell(grid_pos: Vector2i) -> bool:
	return get_terrain_type_at(grid_pos) == ItemData.ItemType.WATER


func find_water_within(anchor: Vector2i, radius: int) -> Array[Vector2i]:
	## Chebyshev neighborhood (square) of free water tiles, nearest first.
	var found: Array[Vector2i] = []
	for dist in range(1, radius + 1):
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if maxi(absi(dx), absi(dy)) != dist:
					continue
				var cell := anchor + Vector2i(dx, dy)
				if not is_in_bounds(cell):
					continue
				if not is_water_cell(cell):
					continue
				if has_content(cell):
					continue
				found.append(cell)
	return found


func move_animal_to(animal: Node3D, to: Vector2i) -> bool:
	## Update occupancy for a free adjacent cell; caller animates world position.
	if not animal_can_step_to(animal, to):
		return false
	var footprint := get_object_footprint(animal)
	var rotation := get_object_rotation(animal)
	_unregister_content_object(animal)
	animal.set_meta("grid_pos", to)
	_register_content_cells(animal, to, footprint, rotation)
	return true


func begin_animal_mud(grid_pos: Vector2i) -> Dictionary:
	## Temporarily turn a tile into dirt for pig wallowing. Returns restore info.
	if not is_in_bounds(grid_pos):
		return {}
	if get_terrain_type_at(grid_pos) == ItemData.ItemType.WATER:
		return {}
	if has_terrain(grid_pos):
		var current := get_terrain_type_at(grid_pos)
		if current == ItemData.ItemType.DIRT:
			return {"mode": "keep"}
		_remove_terrain_silent(grid_pos)
		_spawn_object(ItemData.ItemType.DIRT, grid_pos, 0, 0, false, false)
		return {"mode": "terrain", "type": current}
	_spawn_object(ItemData.ItemType.DIRT, grid_pos, 0, 0, false, false)
	return {"mode": "grass"}


func end_animal_mud(grid_pos: Vector2i, restore: Dictionary) -> void:
	if restore.is_empty() or not is_in_bounds(grid_pos):
		return
	var mode: String = str(restore.get("mode", "grass"))
	match mode:
		"keep":
			return
		"grass":
			if get_terrain_type_at(grid_pos) == ItemData.ItemType.DIRT:
				_remove_terrain_silent(grid_pos)
				_refresh_grass_around(grid_pos)
		"terrain":
			var previous: ItemData.ItemType = restore.get("type", ItemData.ItemType.STONE_PATH)
			if has_terrain(grid_pos):
				_remove_terrain_silent(grid_pos)
			if ItemData.is_terrain(previous):
				_spawn_object(previous, grid_pos, 0, 0, false, false)


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
	_sync_grass_visibility()
