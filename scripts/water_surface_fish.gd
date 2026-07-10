class_name WaterSurfaceFish
extends Node3D

var _anchor: Vector3
var _phase: float = 0.0
var _swim_speed: float = 1.0
var _swim_radius: float = 0.2


func setup(world_base: Vector3) -> void:
	_anchor = world_base + Vector3(randf_range(-0.28, 0.28), 0.07, randf_range(-0.28, 0.28))
	position = _anchor
	_phase = randf() * TAU
	_swim_speed = randf_range(0.7, 1.3)
	_swim_radius = randf_range(0.14, 0.24)
	_build_mesh()


func _build_mesh() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.16, 0.05, 0.07)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.position = Vector3.ZERO
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.92, 0.55, 0.2)
	body.material_override = body_mat
	add_child(body)

	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.06, 0.03, 0.05)
	var tail := MeshInstance3D.new()
	tail.mesh = tail_mesh
	tail.position = Vector3(-0.1, 0.0, 0.0)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.85, 0.48, 0.18)
	tail.material_override = tail_mat
	add_child(tail)

	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(0.02, 0.05, 0.06)
	var fin := MeshInstance3D.new()
	fin.mesh = fin_mesh
	fin.position = Vector3(0.0, 0.03, 0.0)
	fin.material_override = tail_mat
	add_child(fin)


func _process(delta: float) -> void:
	_phase += delta * _swim_speed
	position.x = _anchor.x + cos(_phase) * _swim_radius
	position.z = _anchor.z + sin(_phase * 0.85) * _swim_radius
	position.y = _anchor.y + sin(_phase * 2.8) * 0.012
	rotation.y = -_phase + PI * 0.5
