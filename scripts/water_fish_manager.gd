class_name WaterFishManager
extends Node

const MAX_FISH_PER_CLUSTER: int = 5

var _grid_manager: GridManager
var _fish_container: Node3D
var _refresh_pending: bool = false


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	_fish_container = Node3D.new()
	_fish_container.name = "WaterFish"
	grid_manager.add_child(_fish_container)

	grid_manager.object_placed.connect(_on_grid_changed)
	grid_manager.object_removed.connect(_on_grid_changed)
	grid_manager.object_moved.connect(_on_object_moved)

	call_deferred("refresh_all")


func _on_grid_changed(_grid_pos: Vector2i, _obj: Node3D = null) -> void:
	_schedule_refresh()


func _on_object_moved(from: Vector2i, to: Vector2i) -> void:
	if _is_water_tile(from) or _is_water_tile(to):
		_schedule_refresh()


func _schedule_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("refresh_all")


func refresh_all() -> void:
	_refresh_pending = false
	if _fish_container == null or _grid_manager == null:
		return

	for child in _fish_container.get_children():
		child.queue_free()

	for cluster: Array in _find_water_clusters():
		var fish_count := _fish_count_for_cluster(cluster.size())
		_spawn_fish_in_cluster(cluster, fish_count)


func _fish_count_for_cluster(tile_count: int) -> int:
	if tile_count <= 0:
		return 0
	var scaled := int(round(float(tile_count) * 0.35))
	return clampi(max(scaled, 1), 1, MAX_FISH_PER_CLUSTER)


func _is_water_tile(grid_pos: Vector2i) -> bool:
	if not _grid_manager.is_in_bounds(grid_pos):
		return false
	if ItemData.is_water_source(_grid_manager.get_terrain_type_at(grid_pos)):
		return true
	# Pond is content (decor), not terrain.
	var content := _grid_manager.get_content_at(grid_pos)
	if content and ItemData.is_water_source(content.get_meta("item_type")):
		return true
	return false


func _find_water_clusters() -> Array:
	var visited: Dictionary = {}
	var clusters: Array = []

	for x in range(GridManager.GRID_WIDTH):
		for y in range(GridManager.GRID_HEIGHT):
			var pos := Vector2i(x, y)
			if visited.has(pos) or not _is_water_tile(pos):
				continue
			var cluster: Array[Vector2i] = []
			var queue: Array[Vector2i] = [pos]
			visited[pos] = true

			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				cluster.append(current)
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var neighbor := current + offset
					if visited.has(neighbor) or not _is_water_tile(neighbor):
						continue
					visited[neighbor] = true
					queue.append(neighbor)

			clusters.append(cluster)

	return clusters


func _spawn_fish_in_cluster(cluster: Array, count: int) -> void:
	if cluster.is_empty() or count <= 0:
		return

	var tiles: Array = cluster.duplicate()
	tiles.shuffle()

	for i in range(count):
		var grid_pos: Vector2i = tiles[i % tiles.size()]
		var fish := WaterSurfaceFish.new()
		fish.name = "Fish_%d_%d_%d" % [grid_pos.x, grid_pos.y, i]
		_fish_container.add_child(fish)
		fish.setup(_grid_manager.grid_to_world(grid_pos))
