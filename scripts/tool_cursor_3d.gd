extends Node3D

## 3D tool that follows the mouse (replaces the OS cursor while active).

const HOE_SCENE_PATH: String = "res://assets/models/crops/Hoe.glb"
## Extra uniform scale on top of the GLB's built-in node scale (×100).
const HOE_EXTRA_SCALE: float = 0.85
const FOLLOW_DEPTH: float = 3.2
const CURSOR_SCREEN_OFFSET := Vector2(28, 36)

var camera: Camera3D
var _tool_root: Node3D
var _swing_pivot: Node3D
var _active: bool = false
var _swinging: bool = false


func setup(p_camera: Camera3D) -> void:
	camera = p_camera


func show_hoe() -> void:
	_ensure_hoe_model()
	visible = true
	_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func hide_tool() -> void:
	_active = false
	_swinging = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func play_hoe_dig() -> void:
	if not _active or _swing_pivot == null or _swinging:
		return
	_swinging = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	# Dig swing — mirrored for the flipped hoe grip.
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -55.0, 0.08)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -78.0, 0.06)
	tween.tween_property(_swing_pivot, "position:y", -0.08, 0.06)
	tween.tween_property(_swing_pivot, "rotation_degrees:z", -10.0, 0.14)
	tween.parallel().tween_property(_swing_pivot, "position:y", 0.0, 0.14)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_swing_pivot):
			_swing_pivot.rotation_degrees.z = -10.0
			_swing_pivot.position.y = 0.0
		_swinging = false
	)


func _ensure_hoe_model() -> void:
	if _tool_root:
		return
	if not ResourceLoader.exists(HOE_SCENE_PATH):
		push_warning("Hoe model missing: %s" % HOE_SCENE_PATH)
		return

	_swing_pivot = Node3D.new()
	_swing_pivot.name = "SwingPivot"
	_swing_pivot.rotation_degrees.z = -10.0
	add_child(_swing_pivot)

	_tool_root = Node3D.new()
	_tool_root.name = "HoeVisual"
	_swing_pivot.add_child(_tool_root)

	var model: Node3D = (load(HOE_SCENE_PATH) as PackedScene).instantiate() as Node3D
	# Dig swing stays correct; yaw the blade so it faces the dig, not sideways.
	model.scale = Vector3.ONE * HOE_EXTRA_SCALE
	model.rotation_degrees = Vector3(0.0, 0.0, 35.0)
	model.position = Vector3(-0.15, -0.05, 0.0)
	_tool_root.add_child(model)


func _process(_delta: float) -> void:
	if not _active or camera == null:
		return
	var screen := get_viewport().get_mouse_position() + CURSOR_SCREEN_OFFSET
	global_position = camera.project_position(screen, FOLLOW_DEPTH)
	# Keep the tool facing the camera so the silhouette stays readable.
	look_at(camera.global_position, Vector3.UP)
	rotate_object_local(Vector3.UP, PI)
