class_name HarvestEffect
extends RefCounted

## Soft float-up + fade when a mature crop is harvested.


static func play(plant_root: Node3D) -> void:
	if not is_instance_valid(plant_root):
		return
	var source := _find_harvest_visual(plant_root)
	if source == null or not is_instance_valid(source):
		return

	var parent: Node = plant_root.get_parent()
	if parent == null:
		return

	var fx: Node3D = source.duplicate() as Node3D
	if fx == null:
		return
	fx.name = "HarvestFX"
	fx.visible = true
	# AmbientSway (flowers/sunflower) overwrites position every frame — strip it.
	_strip_runtime_nodes(fx)
	parent.add_child(fx)
	fx.global_transform = source.global_transform

	_make_fadeable(fx)
	_spawn_sparkles(fx)

	var start_y: float = fx.position.y
	var start_scale: Vector3 = fx.scale
	var rise := 1.55
	var tween := fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "position:y", start_y + rise, 0.95) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "rotation:y", fx.rotation.y + 0.55, 0.95) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(fx, "scale", start_scale * 0.55, 0.95) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_fade.bind(fx), 1.0, 0.0, 0.95)
	tween.chain().tween_callback(fx.queue_free)


static func _find_harvest_visual(plant_root: Node3D) -> Node3D:
	## Prefer an explicit full harvest mesh (e.g. unburied carrot).
	var harvest := plant_root.find_child("HarvestVisual", true, false) as Node3D
	if harvest != null and is_instance_valid(harvest):
		return harvest
	## Stages may sit under SwayPivot after flower/sunflower mature polish.
	for i in range(CropGrowth.STAGE_COUNT - 1, -1, -1):
		var stage := plant_root.find_child("Stage%d" % i, true, false) as Node3D
		if stage and stage.visible:
			return stage
	var sway := plant_root.get_node_or_null("SwayPivot") as Node3D
	if sway:
		return sway
	return plant_root


static func _strip_runtime_nodes(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var to_free: Array[Node] = []
	for child in node.get_children():
		if child is AmbientSway or child.name in ["AmbientSway", "CropGrowth", "TileCollider"]:
			to_free.append(child)
		else:
			_strip_runtime_nodes(child)
	for child in to_free:
		node.remove_child(child)
		child.free()


static func _make_fadeable(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		if not gi.has_meta("_harvest_prev_transparency"):
			gi.set_meta("_harvest_prev_transparency", gi.transparency)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_active_material(i)
				var mat: BaseMaterial3D
				if src is BaseMaterial3D:
					mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				else:
					mat = StandardMaterial3D.new()
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.set_surface_override_material(i, mat)
		elif mi.material_override is BaseMaterial3D:
			var mat := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = mat
	for child in node.get_children():
		_make_fadeable(child)


static func _set_fade(node: Node, alpha: float) -> void:
	if not is_instance_valid(node):
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = 1.0 - alpha
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D:
					var bm := mat as BaseMaterial3D
					var c := bm.albedo_color
					c.a = alpha
					bm.albedo_color = c
					if bm.emission_enabled:
						bm.emission_energy_multiplier = alpha * 1.2
		if mi.material_override is BaseMaterial3D:
			var bm2 := mi.material_override as BaseMaterial3D
			var c2 := bm2.albedo_color
			c2.a = alpha
			bm2.albedo_color = c2
	for child in node.get_children():
		_set_fade(child, alpha)


static func _spawn_sparkles(fx_root: Node3D) -> void:
	for i in range(6):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.06
		spark.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.92, 0.45, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.88, 0.4)
		mat.emission_energy_multiplier = 1.6
		spark.material_override = mat
		spark.position = Vector3(
			randf_range(-0.25, 0.25),
			randf_range(0.2, 0.6),
			randf_range(-0.25, 0.25)
		)
		fx_root.add_child(spark)

		var rise := spark.position.y + randf_range(0.7, 1.3)
		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position:y", rise, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(spark, "scale", Vector3.ZERO, 0.9)
		tw.chain().tween_callback(spark.queue_free)
