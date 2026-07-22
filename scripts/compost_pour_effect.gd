class_name CompostPourEffect
extends RefCounted

## Dirt / compost crumbs that tumble out of a tipped bag.


static func play(host: Node, from_world: Vector3, toward_world: Vector3 = Vector3.ZERO) -> void:
	if host == null or not is_instance_valid(host):
		return
	var root := Node3D.new()
	root.name = "CompostPourFX"
	host.add_child(root)
	root.global_position = from_world

	var aim := toward_world
	if aim == Vector3.ZERO:
		aim = from_world + Vector3(0.0, -0.8, 0.0)
	var fall_dir := (aim - from_world)
	if fall_dir.length_squared() < 0.0001:
		fall_dir = Vector3(0.0, -1.0, 0.0)
	else:
		fall_dir = fall_dir.normalized()

	for i in range(14):
		_spawn_crumb(root, fall_dir, i)

	var cleaner := root.create_tween()
	cleaner.tween_interval(0.85)
	cleaner.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
	)


static func _spawn_crumb(root: Node3D, fall_dir: Vector3, index: int) -> void:
	var crumb := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var s := randf_range(0.03, 0.07)
	mesh.size = Vector3(s, s * randf_range(0.6, 1.1), s)
	crumb.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var soil := Color(
		randf_range(0.32, 0.55),
		randf_range(0.2, 0.34),
		randf_range(0.1, 0.18),
		0.95
	)
	mat.albedo_color = soil
	crumb.material_override = mat
	crumb.position = Vector3(
		randf_range(-0.04, 0.04),
		randf_range(-0.02, 0.04),
		randf_range(-0.04, 0.04)
	)
	crumb.rotation_degrees = Vector3(randf_range(0.0, 360.0), randf_range(0.0, 360.0), 0.0)
	root.add_child(crumb)

	var side := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
	var end := fall_dir * randf_range(0.55, 1.05) + side + Vector3(0.0, randf_range(-0.15, 0.05), 0.0)
	var dur := randf_range(0.35, 0.65) + float(index) * 0.012
	var tw := crumb.create_tween()
	tw.set_parallel(true)
	tw.tween_property(crumb, "position", crumb.position + end, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(crumb, "rotation_degrees:x", crumb.rotation_degrees.x + randf_range(90.0, 240.0), dur)
	tw.tween_property(crumb, "rotation_degrees:z", crumb.rotation_degrees.z + randf_range(-180.0, 180.0), dur)
	tw.tween_property(crumb, "scale", Vector3.ONE * randf_range(0.15, 0.4), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(crumb):
			var c := mat.albedo_color
			c.a = 0.0
			mat.albedo_color = c
			crumb.queue_free()
	)
