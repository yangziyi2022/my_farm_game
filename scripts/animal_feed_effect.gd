class_name AnimalFeedEffect
extends RefCounted

# Brief heart pop when an animal is fed.
static func play(animal_root: Node3D) -> void:
	if not is_instance_valid(animal_root):
		return

	var pivot := animal_root.get_node_or_null("AnimalPivot") as Node3D
	var target: Node3D = pivot if pivot else animal_root
	var base_scale := target.scale

	var tween := animal_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "scale", base_scale * 1.12, 0.12).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(target, "scale", base_scale, 0.18)

	_spawn_hearts(animal_root)


static func _spawn_hearts(animal_root: Node3D) -> void:
	for i in range(3):
		var heart := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.08
		heart.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.25, 0.45)
		mat.emission_enabled = true
		mat.emission = Color(0.95, 0.3, 0.5)
		mat.emission_energy_multiplier = 0.8
		heart.material_override = mat
		heart.position = Vector3(randf_range(-0.15, 0.15), 0.55 + i * 0.08, randf_range(-0.1, 0.2))
		animal_root.add_child(heart)

		var tween := heart.create_tween()
		tween.tween_property(heart, "position:y", heart.position.y + 0.45, 0.7)
		tween.parallel().tween_property(heart, "scale", Vector3.ZERO, 0.7)
		tween.tween_callback(heart.queue_free)
