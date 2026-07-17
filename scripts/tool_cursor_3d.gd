extends Node3D

## 3D cursor tools: hoe dig, sickle harvest, fishing rod cast.

const HOE_SCENE_PATH: String = "res://assets/models/crops/Hoe.glb"
const ROD_SCENE_PATH: String = "res://assets/models/others/Fishing Rod.glb"
const SICKLE_SCENE_PATH: String = "res://assets/models/others/Sickle.glb"

const HOE_EXTRA_SCALE: float = 0.85
## Rod GLB is already ×100 inside; keep final length close to the hoe.
const ROD_EXTRA_SCALE: float = 0.18
## Sickle mesh is ~2 units; scale down to hoe-like handheld size.
const SICKLE_EXTRA_SCALE: float = 0.38

const FOLLOW_DEPTH: float = 3.2
const CURSOR_SCREEN_OFFSET := Vector2(28, 36)

enum ActiveTool { NONE, HOE, ROD, SICKLE }

var camera: Camera3D
var _active_tool: ActiveTool = ActiveTool.NONE
var _swing_pivot: Node3D
var _hoe_root: Node3D
var _rod_root: Node3D
var _sickle_root: Node3D
var _hoe_model: Node3D
var _rod_model: Node3D
var _sickle_model: Node3D
var _rod_tip_local: Vector3 = Vector3(0.0, 0.55, 0.0)
var _line_mesh: MeshInstance3D
var _line_active: bool = false
var _line_target: Vector3 = Vector3.ZERO
var _animating: bool = false
var _bite_shake: bool = false
var _shake_time: float = 0.0
var _rest_rot_z: float = -10.0


func setup(p_camera: Camera3D) -> void:
	camera = p_camera


func show_hoe() -> void:
	_stop_bite_shake()
	_clear_line()
	_ensure_hoe_model()
	_show_only(ActiveTool.HOE)
	_active_tool = ActiveTool.HOE
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_reset_swing(Vector3(0.0, 0.0, _rest_rot_z))


func show_rod() -> void:
	_stop_bite_shake()
	_clear_line()
	_ensure_rod_model()
	_show_only(ActiveTool.ROD)
	_active_tool = ActiveTool.ROD
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_reset_swing(Vector3(0.0, 0.0, 12.0))


func show_sickle() -> void:
	_stop_bite_shake()
	_clear_line()
	_ensure_sickle_model()
	_show_only(ActiveTool.SICKLE)
	_active_tool = ActiveTool.SICKLE
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_reset_swing(Vector3(0.0, 0.0, 0.0))


func hide_tool() -> void:
	_stop_bite_shake()
	_clear_line()
	_animating = false
	_active_tool = ActiveTool.NONE
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func play_hoe_dig() -> void:
	if _active_tool != ActiveTool.HOE or _swing_pivot == null or _animating:
		return
	_animating = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -55.0, 0.08)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -78.0, 0.06)
	tween.tween_property(_swing_pivot, "position:y", -0.08, 0.06)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", _rest_rot_z, 0.14)
	tween.parallel().tween_property(_swing_pivot, "position:y", 0.0, 0.14)
	tween.tween_callback(func() -> void:
		_reset_swing(Vector3(0.0, 0.0, _rest_rot_z))
		_animating = false
	)


func play_sickle_swing() -> void:
	## Horizontal harvest slash.
	if _active_tool != ActiveTool.SICKLE or _swing_pivot == null or _animating:
		return
	_animating = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_swing_pivot, "rotation_degrees:y", -70.0, 0.08)
	tween.tween_property(_swing_pivot, "rotation_degrees:y", 85.0, 0.14)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:z", -20.0, 0.14)
	tween.tween_property(_swing_pivot, "rotation_degrees:y", 0.0, 0.12)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:z", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		_reset_swing(Vector3.ZERO)
		_animating = false
	)


func play_rod_cast(water_world_pos: Vector3) -> void:
	if _active_tool != ActiveTool.ROD or _swing_pivot == null:
		return
	_animating = true
	_stop_bite_shake()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", 50.0, 0.12)
	tween.tween_property(_swing_pivot, "rotation_degrees:x", -20.0, 0.12)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -30.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:x", 15.0, 0.16)
	tween.tween_callback(func() -> void:
		_set_line_target(water_world_pos)
		_animating = false
	)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", 10.0, 0.2)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:x", 8.0, 0.2)


func start_rod_bite_shake() -> void:
	if _active_tool != ActiveTool.ROD:
		return
	_bite_shake = true
	_shake_time = 0.0


func stop_rod_session() -> void:
	_stop_bite_shake()
	_clear_line()
	_animating = false
	_reset_swing(Vector3(0.0, 0.0, 12.0))


func get_rod_tip_global() -> Vector3:
	if _rod_root and is_instance_valid(_rod_root):
		return _rod_root.to_global(_rod_tip_local)
	return global_position + Vector3(0.0, 0.55, 0.0)


func _reset_swing(euler_deg: Vector3) -> void:
	if _swing_pivot and is_instance_valid(_swing_pivot):
		_swing_pivot.rotation_degrees = euler_deg
		_swing_pivot.position = Vector3.ZERO


func _stop_bite_shake() -> void:
	_bite_shake = false
	_shake_time = 0.0


func _set_line_target(world_pos: Vector3) -> void:
	_line_target = world_pos
	_line_active = true
	_ensure_line_mesh()


func _clear_line() -> void:
	_line_active = false
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.visible = false


func _ensure_line_mesh() -> void:
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.visible = true
		return
	_line_mesh = MeshInstance3D.new()
	_line_mesh.name = "FishingLine"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.88, 0.95, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh.material_override = mat
	var host: Node = get_parent()
	if host:
		host.add_child(_line_mesh)
	else:
		add_child(_line_mesh)


func _update_fishing_line() -> void:
	if not _line_active or _line_mesh == null or not is_instance_valid(_line_mesh):
		return
	var tip := get_rod_tip_global()
	var sink := _line_target
	if _bite_shake:
		sink.y += sin(_shake_time * 18.0) * 0.04
	else:
		sink.y += sin(Time.get_ticks_msec() * 0.004) * 0.015

	var mid := (tip + sink) * 0.5
	var length := tip.distance_to(sink)
	if length < 0.01:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.006
	cyl.height = length
	_line_mesh.mesh = cyl
	_line_mesh.visible = true
	_line_mesh.global_position = mid
	_line_mesh.look_at(sink, Vector3.RIGHT)
	_line_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _ensure_swing_pivot() -> void:
	if _swing_pivot and is_instance_valid(_swing_pivot):
		return
	_swing_pivot = Node3D.new()
	_swing_pivot.name = "SwingPivot"
	add_child(_swing_pivot)


func _ensure_hoe_model() -> void:
	_ensure_swing_pivot()
	if _hoe_model and is_instance_valid(_hoe_model):
		return
	if not ResourceLoader.exists(HOE_SCENE_PATH):
		push_warning("Hoe model missing: %s" % HOE_SCENE_PATH)
		return
	_hoe_root = Node3D.new()
	_hoe_root.name = "HoeVisual"
	_swing_pivot.add_child(_hoe_root)
	_hoe_model = (load(HOE_SCENE_PATH) as PackedScene).instantiate() as Node3D
	_hoe_model.scale = Vector3.ONE * HOE_EXTRA_SCALE
	_hoe_model.rotation_degrees = Vector3(0.0, 0.0, 35.0)
	_hoe_model.position = Vector3(-0.15, -0.05, 0.0)
	_hoe_root.add_child(_hoe_model)


func _ensure_rod_model() -> void:
	_ensure_swing_pivot()
	if _rod_model and is_instance_valid(_rod_model):
		return
	if not ResourceLoader.exists(ROD_SCENE_PATH):
		push_warning("Fishing rod missing: %s" % ROD_SCENE_PATH)
		return
	_rod_root = Node3D.new()
	_rod_root.name = "RodVisual"
	_swing_pivot.add_child(_rod_root)
	_rod_model = (load(ROD_SCENE_PATH) as PackedScene).instantiate() as Node3D
	_rod_model.scale = Vector3.ONE * ROD_EXTRA_SCALE
	# Tip points upward so the line leaves from the top of the rod.
	_rod_model.rotation_degrees = Vector3(-20.0, 0.0, -25.0)
	_rod_model.position = Vector3(0.05, -0.08, 0.0)
	_rod_root.add_child(_rod_model)
	_rod_tip_local = _find_highest_local_point(_rod_root)


func _ensure_sickle_model() -> void:
	_ensure_swing_pivot()
	if _sickle_model and is_instance_valid(_sickle_model):
		return
	if not ResourceLoader.exists(SICKLE_SCENE_PATH):
		push_warning("Sickle model missing: %s" % SICKLE_SCENE_PATH)
		return
	_sickle_root = Node3D.new()
	_sickle_root.name = "SickleVisual"
	_swing_pivot.add_child(_sickle_root)
	_sickle_model = (load(SICKLE_SCENE_PATH) as PackedScene).instantiate() as Node3D
	_sickle_model.scale = Vector3.ONE * SICKLE_EXTRA_SCALE
	_sickle_model.rotation_degrees = Vector3(0.0, 90.0, -15.0)
	_sickle_model.position = Vector3(0.1, -0.05, 0.0)
	_sickle_root.add_child(_sickle_model)


func _find_highest_local_point(root: Node3D) -> Vector3:
	var best := Vector3(0.0, 0.55, 0.0)
	var best_y := -INF
	for mi in _gather_meshes(root):
		var aabb := mi.get_aabb()
		var xf := _relative_transform(root, mi)
		for corner in _aabb_corners(aabb):
			var p: Vector3 = xf * corner
			if p.y > best_y:
				best_y = p.y
				best = p
	return best


func _gather_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_gather_meshes(child))
	return out


func _relative_transform(ancestor: Node3D, descendant: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node3D = descendant
	while current and current != ancestor:
		xf = current.transform * xf
		current = current.get_parent() as Node3D
	return xf


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		p, p + Vector3(s.x, 0, 0), p + Vector3(0, s.y, 0), p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0), p + Vector3(s.x, 0, s.z), p + Vector3(0, s.y, s.z), p + s,
	]


func _show_only(tool: ActiveTool) -> void:
	if _hoe_root:
		_hoe_root.visible = tool == ActiveTool.HOE
	if _rod_root:
		_rod_root.visible = tool == ActiveTool.ROD
	if _sickle_root:
		_sickle_root.visible = tool == ActiveTool.SICKLE


func _process(delta: float) -> void:
	if _active_tool == ActiveTool.NONE or camera == null:
		return

	if _line_active:
		if _bite_shake and _swing_pivot:
			_shake_time += delta
			_swing_pivot.rotation_degrees.z = 10.0 + sin(_shake_time * 28.0) * 22.0
			_swing_pivot.rotation_degrees.x = 8.0 + cos(_shake_time * 33.0) * 14.0
			_swing_pivot.position.y = sin(_shake_time * 40.0) * 0.05
		_update_fishing_line()
		return

	var screen := get_viewport().get_mouse_position() + CURSOR_SCREEN_OFFSET
	global_position = camera.project_position(screen, FOLLOW_DEPTH)
	look_at(camera.global_position, Vector3.UP)
	rotate_object_local(Vector3.UP, PI)
