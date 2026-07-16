class_name SelectionFlash
extends RefCounted

## Brief fade / lighten flash when an object is selected.


static func play(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	var meshes: Array[MeshInstance3D] = []
	_gather(root, meshes)
	if meshes.is_empty():
		return

	var originals: Array[Dictionary] = []
	for mi in meshes:
		var entry := {"mi": mi, "surfaces": []}
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_active_material(i)
				var mat: BaseMaterial3D
				if src is BaseMaterial3D:
					mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				else:
					mat = StandardMaterial3D.new()
					if src:
						pass
				var orig_color := mat.albedo_color
				entry["surfaces"].append({"index": i, "mat": mat, "color": orig_color})
				mi.set_surface_override_material(i, mat)
		elif mi.material_override is BaseMaterial3D:
			var mat2 := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			entry["override"] = mat2
			entry["override_color"] = mat2.albedo_color
			mi.material_override = mat2
		originals.append(entry)

	# Lighten quickly, then ease back.
	var tween := root.create_tween()
	tween.tween_method(_set_flash.bind(originals), 0.0, 1.0, 0.12)
	tween.tween_method(_set_flash.bind(originals), 1.0, 0.0, 0.35)


static func _set_flash(entries: Array, amount: float) -> void:
	for entry in entries:
		var surfaces: Array = entry.get("surfaces", [])
		for s in surfaces:
			var mat: BaseMaterial3D = s["mat"]
			if not is_instance_valid(mat):
				continue
			var base: Color = s["color"]
			mat.albedo_color = base.lerp(Color(1, 1, 1, base.a * 0.55), amount)
		if entry.has("override"):
			var mat2: BaseMaterial3D = entry["override"]
			if is_instance_valid(mat2):
				var base2: Color = entry["override_color"]
				mat2.albedo_color = base2.lerp(Color(1, 1, 1, base2.a * 0.55), amount)


static func _gather(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is FootprintOverlay:
		return
	if node.name in ["SelectionFootprint", "HoeFootprint", "HarvestFX", "TileCollider", "LampLight"]:
		return
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather(child, out)
