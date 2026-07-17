class_name WaterSurfaceFish
extends Node3D

## Swimming fish in water tiles — uses the same Fish.glb as the catch FX.

const FISH_SCENE_PATH: String = "res://assets/models/animals/Fish.glb"
## Fish.glb mesh is tiny but nodes are ×100 → keep final length under a chicken (~0.3).
const FISH_SCALE: float = 0.018

var _anchor: Vector3
var _phase: float = 0.0
var _swim_speed: float = 1.0
var _swim_radius: float = 0.2
var _model: Node3D = null


func setup(world_base: Vector3) -> void:
	_anchor = world_base + Vector3(randf_range(-0.28, 0.28), 0.06, randf_range(-0.28, 0.28))
	position = _anchor
	_phase = randf() * TAU
	_swim_speed = randf_range(0.7, 1.3)
	_swim_radius = randf_range(0.14, 0.24)
	_build_mesh()


func _build_mesh() -> void:
	if ResourceLoader.exists(FISH_SCENE_PATH):
		_model = (load(FISH_SCENE_PATH) as PackedScene).instantiate() as Node3D
		_model.name = "FishModel"
		_model.scale = Vector3.ONE * FISH_SCALE
		# Keep the mesh belly-down in the water plane.
		_model.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		add_child(_model)
		return
	_build_fallback()


func _build_fallback() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.16, 0.05, 0.07)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
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


func _process(delta: float) -> void:
	_phase += delta * _swim_speed
	position.x = _anchor.x + cos(_phase) * _swim_radius
	position.z = _anchor.z + sin(_phase * 0.85) * _swim_radius
	position.y = _anchor.y + sin(_phase * 2.8) * 0.012
	rotation.y = -_phase + PI * 0.5
