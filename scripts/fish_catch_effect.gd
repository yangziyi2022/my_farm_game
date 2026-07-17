class_name FishCatchEffect
extends RefCounted

## Caught-fish popup using Fish.glb — rises from the water and fades out.

const FISH_SCENE_PATH: String = "res://assets/models/animals/Fish.glb"
## Slightly larger than water fish for catch readability, still under chicken size.
const FISH_SCALE: float = 0.03


static func play(host: Node3D, water_world_pos: Vector3) -> void:
	if host == null or not is_instance_valid(host):
		return

	var fish := Node3D.new()
	fish.name = "CaughtFishFX"
	host.add_child(fish)
	fish.global_position = water_world_pos + Vector3(0.0, 0.12, 0.0)

	if ResourceLoader.exists(FISH_SCENE_PATH):
		var model: Node3D = (load(FISH_SCENE_PATH) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * FISH_SCALE
		model.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		fish.add_child(model)
		_make_fadeable(model)
	else:
		_add_fallback_fish(fish)

	for i in range(5):
		var spark := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03
		spark.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(0.7, 0.9, 1.0, 0.95)
		smat.emission_enabled = true
		smat.emission = Color(0.7, 0.9, 1.0)
		smat.emission_energy_multiplier = 1.4
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark.material_override = smat
		spark.position = Vector3(randf_range(-0.15, 0.15), randf_range(0.05, 0.2), randf_range(-0.1, 0.1))
		fish.add_child(spark)
		var st := spark.create_tween()
		st.set_parallel(true)
		st.tween_property(spark, "position:y", spark.position.y + randf_range(0.5, 0.9), 0.85)
		st.tween_property(spark, "scale", Vector3.ZERO, 0.85)

	var tween := fish.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fish, "position:y", fish.position.y + 1.4, 1.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(fish, "rotation:y", fish.rotation.y + 2.2, 1.05)
	tween.tween_property(fish, "rotation:z", 0.55, 1.05)
	tween.tween_method(_fade_fish.bind(fish), 1.0, 0.0, 1.05)
	tween.chain().tween_callback(fish.queue_free)


static func _add_fallback_fish(parent: Node3D) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.12
	body_mesh.height = 0.28
	body.mesh = body_mesh
	body.scale = Vector3(1.4, 0.7, 0.85)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.9, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body.material_override = mat
	parent.add_child(body)


static func _make_fadeable(node: Node) -> void:
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
	for child in node.get_children():
		_make_fadeable(child)


static func _fade_fish(root: Node, alpha: float) -> void:
	if not is_instance_valid(root):
		return
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D:
					var bm := mat as BaseMaterial3D
					var c := bm.albedo_color
					c.a = alpha
					bm.albedo_color = c
		if mi.material_override is BaseMaterial3D:
			var bm2 := mi.material_override as BaseMaterial3D
			var c2 := bm2.albedo_color
			c2.a = alpha
			bm2.albedo_color = c2
	for child in root.get_children():
		_fade_fish(child, alpha)
