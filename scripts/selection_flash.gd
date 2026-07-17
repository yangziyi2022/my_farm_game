class_name SelectionFlash
extends RefCounted

## Brief fade / lighten flash when an object is selected.
## Always restores original materials so deselect never leaves ghost transparency.

const META_FLASH_TWEEN := "_selection_flash_tween"
const META_ORIG_OVERRIDE := "_selection_orig_override"
const META_ORIG_SURFACES := "_selection_orig_surfaces"


static func play(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	reset(root)

	var meshes: Array[MeshInstance3D] = []
	_gather(root, meshes)
	if meshes.is_empty():
		return

	var originals: Array[Dictionary] = []
	for mi in meshes:
		var entry := {"mi": mi, "surfaces": []}
		# Remember originals so reset() can put them back exactly.
		var surface_backup: Array = []
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_active_material(i)
				surface_backup.append(mi.get_surface_override_material(i))
				var mat: BaseMaterial3D
				if src is BaseMaterial3D:
					mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				else:
					mat = StandardMaterial3D.new()
				var orig_color := mat.albedo_color
				entry["surfaces"].append({"index": i, "mat": mat, "color": orig_color})
				mi.set_surface_override_material(i, mat)
		if mi.material_override is BaseMaterial3D:
			entry["had_override"] = true
			entry["override_backup"] = mi.material_override
			var mat2 := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			entry["override"] = mat2
			entry["override_color"] = mat2.albedo_color
			mi.material_override = mat2
		mi.set_meta(META_ORIG_SURFACES, surface_backup)
		if mi.material_override:
			mi.set_meta(META_ORIG_OVERRIDE, entry.get("override_backup", mi.material_override))
		originals.append(entry)

	var tween := root.create_tween()
	root.set_meta(META_FLASH_TWEEN, tween)
	tween.tween_method(_set_flash.bind(originals), 0.0, 1.0, 0.12)
	tween.tween_method(_set_flash.bind(originals), 1.0, 0.0, 0.35)
	tween.tween_callback(func() -> void:
		if is_instance_valid(root):
			_restore_meshes(originals)
			root.remove_meta(META_FLASH_TWEEN)
	)


static func reset(root: Node3D) -> void:
	## Hard restore — call on deselect so alpha / overrides never stick.
	if root == null or not is_instance_valid(root):
		return
	if root.has_meta(META_FLASH_TWEEN):
		var tw = root.get_meta(META_FLASH_TWEEN)
		if tw is Tween and is_instance_valid(tw):
			(tw as Tween).kill()
		root.remove_meta(META_FLASH_TWEEN)

	var meshes: Array[MeshInstance3D] = []
	_gather(root, meshes)
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		if mi.has_meta(META_ORIG_SURFACES):
			var backup: Array = mi.get_meta(META_ORIG_SURFACES)
			if mi.mesh:
				for i in range(mini(backup.size(), mi.mesh.get_surface_count())):
					mi.set_surface_override_material(i, backup[i])
			mi.remove_meta(META_ORIG_SURFACES)
		if mi.has_meta(META_ORIG_OVERRIDE):
			mi.material_override = mi.get_meta(META_ORIG_OVERRIDE)
			mi.remove_meta(META_ORIG_OVERRIDE)
		# Clear leftover flash transparency on live materials.
		_force_opaque_restore(mi)


static func _restore_meshes(entries: Array) -> void:
	for entry in entries:
		var mi: MeshInstance3D = entry.get("mi")
		if mi == null or not is_instance_valid(mi):
			continue
		if entry.get("had_override", false):
			mi.material_override = entry.get("override_backup")
		elif entry.has("override"):
			# Flash created a temp override — put albedo back then keep if it was the only mat.
			var mat2: BaseMaterial3D = entry["override"]
			if is_instance_valid(mat2):
				mat2.albedo_color = entry["override_color"]
		if mi.has_meta(META_ORIG_SURFACES):
			var backup: Array = mi.get_meta(META_ORIG_SURFACES)
			if mi.mesh:
				for i in range(mini(backup.size(), mi.mesh.get_surface_count())):
					mi.set_surface_override_material(i, backup[i])
			mi.remove_meta(META_ORIG_SURFACES)
		if mi.has_meta(META_ORIG_OVERRIDE):
			mi.remove_meta(META_ORIG_OVERRIDE)
		_force_opaque_restore(mi)


static func _force_opaque_restore(mi: MeshInstance3D) -> void:
	if mi.material_override is BaseMaterial3D:
		var mat := mi.material_override as BaseMaterial3D
		# Procedural placeables use solid colors; restore full alpha if flash left it low.
		if mat.albedo_color.a < 0.99 and mat.albedo_color.a > 0.01:
			# Only bump alpha for materials that were meant to be opaque (no intentional glass).
			# Water / fountain already use alpha < 1 intentionally — skip those by roughness check is weak.
			# Safer: if alpha was reduced by flash to ~0.55 band, restore to 1.
			if mat.albedo_color.a >= 0.4 and mat.albedo_color.a <= 0.7:
				var c := mat.albedo_color
				c.a = 1.0
				mat.albedo_color = c
	if mi.mesh:
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.get_surface_override_material(i)
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				if bm.albedo_color.a >= 0.4 and bm.albedo_color.a <= 0.7:
					var c2 := bm.albedo_color
					c2.a = 1.0
					bm.albedo_color = c2


static func _set_flash(entries: Array, amount: float) -> void:
	for entry in entries:
		var surfaces: Array = entry.get("surfaces", [])
		for s in surfaces:
			var mat: BaseMaterial3D = s["mat"]
			if not is_instance_valid(mat):
				continue
			var base: Color = s["color"]
			mat.albedo_color = base.lerp(Color(1, 1, 1, base.a), amount * 0.45)
		if entry.has("override"):
			var mat2: BaseMaterial3D = entry["override"]
			if is_instance_valid(mat2):
				var base2: Color = entry["override_color"]
				mat2.albedo_color = base2.lerp(Color(1, 1, 1, base2.a), amount * 0.45)


static func _gather(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is FootprintOverlay:
		return
	if node.name in ["SelectionFootprint", "HoeFootprint", "HarvestFX", "TileCollider", "LampLight", "FountainSplash"]:
		return
	if str(node.name).begins_with("SplashDrop"):
		return
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather(child, out)
