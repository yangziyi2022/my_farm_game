class_name PlayerAvatar
extends Node3D

## Simple low-poly placeholder person for walk / explore mode.

const BODY_COLOR := Color(0.95, 0.82, 0.35)
const ACCENT_COLOR := Color(0.85, 0.55, 0.2)

const HOE_SCENE_PATH: String = "res://assets/models/crops/Hoe.glb"
const ROD_SCENE_PATH: String = "res://assets/models/others/Fishing Rod.glb"
const SICKLE_SCENE_PATH: String = "res://assets/models/others/sickle.glb"
## Handheld scales (smaller than the build-mode ToolCursor3D).
const HOE_HAND_SCALE: float = 0.55
const ROD_HAND_SCALE: float = 0.12
const SICKLE_HAND_SCALE: float = 0.3

var grid_pos: Vector2i = Vector2i.ZERO
var facing_yaw: float = 0.0

var _body: MeshInstance3D
var _head: MeshInstance3D
var _right_arm: MeshInstance3D
var _swing_pivot: Node3D
var _hand_anchor: Node3D
var _held_visual: Node3D
var _held_item = null  # InventoryData.Item or null
var _swinging: bool = false
var _rod_tip_local: Vector3 = Vector3(0.0, 0.4, 0.0)
var _line_mesh: MeshInstance3D
var _line_active: bool = false
var _line_target: Vector3 = Vector3.ZERO
var _line_bite: bool = false
var _line_shake_t: float = 0.0


func _ready() -> void:
	_build_mesh()


func _process(delta: float) -> void:
	if _line_active:
		if _line_bite:
			_line_shake_t += delta
		_update_fishing_line()


func _build_mesh() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.26
	body_mesh.height = 1.0
	_body.mesh = body_mesh
	_body.position = Vector3(0.0, 0.64, 0.0)
	_body.material_override = _mat(BODY_COLOR)
	add_child(_body)

	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	_head.mesh = head_mesh
	_head.position = Vector3(0.0, 1.28, 0.0)
	_head.material_override = _mat(ACCENT_COLOR)
	add_child(_head)

	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.07, 0.07, 0.12)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 1.26, -0.22)
	nose.material_override = _mat(Color(0.75, 0.35, 0.2))
	add_child(nose)

	_swing_pivot = Node3D.new()
	_swing_pivot.name = "SwingPivot"
	_swing_pivot.position = Vector3(0.22, 1.05, 0.0)
	add_child(_swing_pivot)

	_right_arm = MeshInstance3D.new()
	_right_arm.name = "RightArm"
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.12, 0.12, 0.42)
	_right_arm.mesh = arm_mesh
	_right_arm.position = Vector3(0.12, -0.08, -0.12)
	_right_arm.rotation_degrees = Vector3(-25.0, 18.0, 12.0)
	_right_arm.material_override = _mat(BODY_COLOR.darkened(0.08))
	_swing_pivot.add_child(_right_arm)

	_hand_anchor = Node3D.new()
	_hand_anchor.name = "RightHand"
	_hand_anchor.position = Vector3(0.22, -0.22, -0.32)
	_swing_pivot.add_child(_hand_anchor)


func set_held_inventory_item(item) -> void:
	_held_item = item
	clear_fishing_line()
	if _held_visual != null and is_instance_valid(_held_visual):
		_held_visual.queue_free()
		_held_visual = null
	if item == null or _hand_anchor == null:
		return
	match item:
		InventoryData.Item.TOOL_HOE:
			_held_visual = _make_tool_visual(HOE_SCENE_PATH, HOE_HAND_SCALE, Vector3(0.0, 0.0, 35.0), Vector3(-0.05, -0.02, 0.0))
		InventoryData.Item.TOOL_HARVEST:
			_held_visual = _make_tool_visual(SICKLE_SCENE_PATH, SICKLE_HAND_SCALE, Vector3(0.0, 90.0, -15.0), Vector3(0.04, -0.02, 0.0))
		InventoryData.Item.TOOL_ROD:
			_held_visual = _make_tool_visual(ROD_SCENE_PATH, ROD_HAND_SCALE, Vector3(-20.0, 0.0, -25.0), Vector3(0.02, -0.04, 0.0))
			if _held_visual:
				_rod_tip_local = _find_highest_local_point(_held_visual)
		_:
			_held_visual = _make_item_cube(item)
	if _held_visual:
		_hand_anchor.add_child(_held_visual)


func _make_tool_visual(path: String, model_scale: float, rot_deg: Vector3, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "HeldTool"
	if ResourceLoader.exists(path):
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		model.scale = Vector3.ONE * model_scale
		model.rotation_degrees = rot_deg
		model.position = pos
		root.add_child(model)
	else:
		var stub := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.5)
		stub.mesh = box
		stub.material_override = _mat(Color(0.6, 0.5, 0.35))
		root.add_child(stub)
	return root


func _make_item_cube(item: InventoryData.Item) -> Node3D:
	var root := Node3D.new()
	root.name = "HeldItem"
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	mesh_i.mesh = box
	mesh_i.material_override = _mat(InventoryData.get_color(item))
	root.add_child(mesh_i)
	return root


func get_held_inventory_item():
	return _held_item


func is_swinging() -> bool:
	return _swinging


func play_use_swing(on_impact: Callable = Callable()) -> void:
	if _swinging or _swing_pivot == null:
		if on_impact.is_valid():
			on_impact.call()
		return
	_swinging = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_swing_pivot, "rotation_degrees:x", -55.0, 0.1)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:y", -25.0, 0.1)
	tween.tween_callback(func() -> void:
		if on_impact.is_valid():
			on_impact.call()
	)
	tween.tween_property(_swing_pivot, "rotation_degrees:x", 35.0, 0.12)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:y", 40.0, 0.12)
	tween.tween_property(_swing_pivot, "rotation_degrees:x", 0.0, 0.14)
	tween.parallel().tween_property(_swing_pivot, "rotation_degrees:y", 0.0, 0.14)
	tween.tween_callback(func() -> void:
		if _swing_pivot:
			_swing_pivot.rotation_degrees = Vector3.ZERO
		_swinging = false
	)


func set_fishing_line_target(world_pos: Vector3, biting: bool = false) -> void:
	_line_target = world_pos
	_line_active = true
	_line_bite = biting
	_ensure_line_mesh()
	_update_fishing_line()


func clear_fishing_line() -> void:
	_line_active = false
	_line_bite = false
	_line_shake_t = 0.0
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.visible = false


func get_rod_tip_global() -> Vector3:
	if _held_visual and is_instance_valid(_held_visual):
		return _held_visual.to_global(_rod_tip_local)
	if _hand_anchor:
		return _hand_anchor.global_position
	return global_position + Vector3(0.3, 1.2, -0.2)


func _ensure_line_mesh() -> void:
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.visible = true
		return
	_line_mesh = MeshInstance3D.new()
	_line_mesh.name = "FishingLine"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.88, 0.95, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh.material_override = mat
	# Parent under scene root so global transforms stay stable while arm swings.
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
	if _line_bite:
		sink.y += sin(_line_shake_t * 18.0) * 0.04
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


func _find_highest_local_point(root: Node3D) -> Vector3:
	var best := Vector3(0.0, 0.45, 0.0)
	var best_y := -9999.0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh:
				var aabb := mi.get_aabb()
				var corners := [
					aabb.position,
					aabb.position + Vector3(aabb.size.x, 0, 0),
					aabb.position + Vector3(0, aabb.size.y, 0),
					aabb.position + Vector3(0, 0, aabb.size.z),
					aabb.position + aabb.size,
					aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
					aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
					aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
				]
				for c in corners:
					var local_in_root: Vector3 = root.to_local(mi.to_global(c))
					if local_in_root.y > best_y:
						best_y = local_in_root.y
						best = local_in_root
		for child in node.get_children():
			stack.append(child)
	return best


func set_ghost_look(enabled: bool) -> void:
	var alpha := 0.45 if enabled else 1.0
	var body_c := BODY_COLOR
	body_c.a = alpha
	var accent := ACCENT_COLOR
	accent.a = alpha
	if _body:
		_body.material_override = _mat(body_c, enabled)
	if _head:
		_head.material_override = _mat(accent, enabled)
	if _right_arm:
		var arm_c := BODY_COLOR.darkened(0.08)
		arm_c.a = alpha
		_right_arm.material_override = _mat(arm_c, enabled)
	var nose := get_node_or_null("Nose") as MeshInstance3D
	if nose:
		var nc := Color(0.75, 0.35, 0.2, alpha)
		nose.material_override = _mat(nc, enabled)


func set_facing_yaw(yaw: float) -> void:
	facing_yaw = yaw
	rotation.y = yaw


static func _mat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if transparent or color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return mat
