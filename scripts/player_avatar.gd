class_name PlayerAvatar
extends Node3D

## Simple low-poly placeholder person for walk / explore mode.

const BODY_COLOR := Color(0.95, 0.82, 0.35)
const ACCENT_COLOR := Color(0.85, 0.55, 0.2)

var grid_pos: Vector2i = Vector2i.ZERO
var facing_yaw: float = 0.0

var _body: MeshInstance3D
var _head: MeshInstance3D


func _ready() -> void:
	_build_mesh()


func _build_mesh() -> void:
	# Capsule body
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 0.85
	_body.mesh = body_mesh
	_body.position = Vector3(0.0, 0.55, 0.0)
	_body.material_override = _mat(BODY_COLOR)
	add_child(_body)

	# Sphere head
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	_head.mesh = head_mesh
	_head.position = Vector3(0.0, 1.12, 0.0)
	_head.material_override = _mat(ACCENT_COLOR)
	add_child(_head)

	# Tiny nose so facing is readable
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.06, 0.06, 0.1)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 1.1, -0.2)
	nose.material_override = _mat(Color(0.75, 0.35, 0.2))
	add_child(nose)


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
	for child in get_children():
		if child is MeshInstance3D and child != _body and child != _head:
			var c := Color(0.75, 0.35, 0.2, alpha)
			(child as MeshInstance3D).material_override = _mat(c, enabled)


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
