class_name ItemIconBaker
extends RefCounted

## Renders inventory icons via SubViewport (GLB capture or procedural meshes).
## Output: res://assets/icons/items/<id>.png

const OUT_DIR := "res://assets/icons/items"
const ICON_SIZE := 256
const SETTLE_FRAMES := 6

const TREE_ALBEDO := "res://assets/models/nature/apple_polygonal+apple+tree+3d+model_basecolor.jpg"

## Inventory item → optional GLB path (empty = procedural / special).
const ITEM_SOURCES := {
	"wheat": "res://assets/models/crops/wheat.glb",
	"carrot": "res://assets/models/crops/carrot.glb",
	"sunflower": "res://assets/models/crops/sunflower.glb",
	"compost": "res://assets/models/crops/compost.glb",
	"fish": "res://assets/models/animals/Fish.glb",
	"tool_harvest": "res://assets/models/others/Sickle.glb",
	"tool_rod": "res://assets/models/others/Fishing Rod.glb",
	"tool_hoe": "res://assets/models/crops/Hoe.glb",
	"milk": "",
	"sheep_milk": "",
	"wool": "",
	"apple": "",
	"wood": "",
	"meat": "",
}


static func bake_all(host: Node) -> Dictionary:
	return await _bake_ids(host, ITEM_SOURCES.keys())


static func bake_core(host: Node) -> Dictionary:
	return await _bake_ids(host, ["milk", "sheep_milk", "wool", "apple"])


static func _bake_ids(host: Node, ids: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count := 0
	var errors: PackedStringArray = []
	for raw_id in ids:
		var id := str(raw_id)
		var err := await _bake_one(host, id)
		if err.is_empty():
			count += 1
		else:
			errors.append("%s: %s" % [id, err])
	return {"count": count, "error": "\n".join(errors)}


static func _bake_one(host: Node, item_id: String) -> String:
	# Prefer GPU-free paths so CLI --headless works.
	match item_id:
		"apple":
			var apple_img := _paint_apple_icon_from_tree()
			if apple_img:
				return _save_icon(apple_img, item_id)
			return "apple paint failed"
		"milk":
			return _save_icon(_paint_milk_bottle_icon(Color(0.97, 0.97, 0.94), Color(0.92, 0.55, 0.35)), item_id)
		"sheep_milk":
			return _save_icon(_paint_milk_bottle_icon(Color(0.95, 0.92, 0.84), Color(0.78, 0.62, 0.4)), item_id)
		"wool":
			return _save_icon(_paint_wool_cloud_icon(), item_id)

	var subject: Node3D = _make_subject(item_id)
	if subject == null:
		return "no subject"
	var img := await _render_subject(host, subject)
	if is_instance_valid(subject):
		subject.queue_free()
	if img == null or img.is_empty():
		return "empty render"
	img = _trim_and_pad(img, 0.1)
	return _save_icon(img, item_id)


static func _save_icon(img: Image, item_id: String) -> String:
	img.convert(Image.FORMAT_RGBA8)
	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.png" % [OUT_DIR, item_id]
	var abs_path := ProjectSettings.globalize_path(path)
	var save_err := img.save_png(abs_path)
	if save_err != OK:
		return "save failed (%d)" % save_err
	return ""


static func _make_subject(item_id: String) -> Node3D:
	match item_id:
		"milk":
			return _make_milk_bottle(Color(0.96, 0.96, 0.92), Color(0.78, 0.86, 0.92))
		"sheep_milk":
			return _make_milk_bottle(Color(0.94, 0.91, 0.82), Color(0.74, 0.8, 0.86))
		"wool":
			return _make_wool_cloud()
		"apple":
			return _make_procedural_apple(_sample_tree_apple_color())
		"wood":
			return _make_wood_log()
		"meat":
			return _make_meat()
		_:
			var glb_path := str(ITEM_SOURCES.get(item_id, ""))
			if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
				return null
			return _instantiate_glb(glb_path)


static func _instantiate_glb(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := Node3D.new()
	root.name = "Subject"
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		root.free()
		return null
	model.name = "Model"
	root.add_child(model)
	return root


static func _render_subject(host: Node, subject: Node3D) -> Image:
	var vp := SubViewport.new()
	vp.name = "IconBakeVP"
	vp.size = Vector2i(ICON_SIZE, ICON_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = World3D.new()
	host.add_child(vp)

	var world := Node3D.new()
	world.name = "World"
	vp.add_child(world)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.76, 0.8)
	env.ambient_light_energy = 0.6
	env_node.environment = env
	world.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-42, -35, 0)
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.38
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-20, 140, 0)
	world.add_child(fill)

	world.add_child(subject)
	_fit_to_unit_box(subject)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 30.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(1.5, 1.1, 1.8), Vector3(0.0, 0.2, 0.0), Vector3.UP)

	for _i in range(SETTLE_FRAMES):
		await host.get_tree().process_frame

	var tex := vp.get_texture()
	var img: Image = null
	if tex:
		img = tex.get_image()
	vp.queue_free()
	return img


static func _fit_to_unit_box(root: Node3D) -> void:
	var aabb := _combined_aabb(root)
	if aabb.size.length() < 0.0001:
		return
	var center := aabb.get_center()
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s := 1.4 / maxf(longest, 0.001)
	for child in root.get_children():
		if child is Node3D:
			var n := child as Node3D
			n.global_position = (n.global_position - center) * s
			n.scale *= s
	# Rest on y=0.
	aabb = _combined_aabb(root)
	root.global_position.y -= aabb.position.y


static func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh and mi.is_inside_tree():
				var world_aabb := mi.global_transform * mi.get_aabb()
				if first:
					result = world_aabb
					first = false
				else:
					result = result.merge(world_aabb)
		for c in n.get_children():
			stack.append(c)
	return result


static func _trim_and_pad(img: Image, pad_frac: float) -> Image:
	if img == null or img.is_empty():
		return img
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return img
	var bw := max_x - min_x + 1
	var bh := max_y - min_y + 1
	var side := maxi(bw, bh)
	var pad := int(ceil(float(side) * pad_frac))
	side += pad * 2
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var ox := (side - bw) / 2
	var oy := (side - bh) / 2
	out.blit_rect(img, Rect2i(min_x, min_y, bw, bh), Vector2i(ox, oy))
	return out


static func _paint_milk_bottle_icon(milk_col: Color, label_col: Color) -> Image:
	var size := ICON_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size / 2
	# Soft shadow
	_fill_ellipse(img, cx, int(size * 0.86), int(size * 0.22), int(size * 0.06), Color(0, 0, 0, 0.18))
	# Bottle body glass
	var glass := Color(0.78, 0.88, 0.95, 0.9)
	_fill_round_rect(img, int(size * 0.30), int(size * 0.28), int(size * 0.40), int(size * 0.48), 18, glass)
	# Milk fill
	_fill_round_rect(img, int(size * 0.34), int(size * 0.36), int(size * 0.32), int(size * 0.36), 14, milk_col)
	# Neck
	_fill_round_rect(img, int(size * 0.40), int(size * 0.16), int(size * 0.20), int(size * 0.14), 8, glass)
	# Cap
	_fill_round_rect(img, int(size * 0.38), int(size * 0.10), int(size * 0.24), int(size * 0.08), 6, Color(0.55, 0.34, 0.2, 1))
	# Label
	_fill_round_rect(img, int(size * 0.36), int(size * 0.44), int(size * 0.28), int(size * 0.16), 6, label_col)
	# Highlight
	_fill_round_rect(img, int(size * 0.34), int(size * 0.32), int(size * 0.06), int(size * 0.34), 4, Color(1, 1, 1, 0.35))
	return img


static func _paint_wool_cloud_icon() -> Image:
	var size := ICON_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, size / 2, int(size * 0.82), int(size * 0.28), int(size * 0.07), Color(0, 0, 0, 0.16))
	var wool := Color(0.95, 0.95, 0.98, 1)
	var puffs := [
		[0.50, 0.52, 0.28],
		[0.34, 0.50, 0.20],
		[0.66, 0.50, 0.20],
		[0.42, 0.38, 0.18],
		[0.58, 0.38, 0.18],
		[0.50, 0.32, 0.16],
		[0.38, 0.58, 0.16],
		[0.62, 0.58, 0.16],
		[0.50, 0.62, 0.15],
	]
	for i in range(puffs.size()):
		var p: Array = puffs[i]
		var col := wool.darkened(0.02 * (i % 3))
		_fill_ellipse(img, int(size * float(p[0])), int(size * float(p[1])), int(size * float(p[2])), int(size * float(p[2]) * 0.85), col)
	# Soft top highlight
	_fill_ellipse(img, int(size * 0.46), int(size * 0.40), int(size * 0.08), int(size * 0.05), Color(1, 1, 1, 0.35))
	return img


static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	var w := img.get_width()
	var h := img.get_height()
	for y in range(cy - ry, cy + ry + 1):
		if y < 0 or y >= h:
			continue
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or x >= w:
				continue
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				var dst := img.get_pixel(x, y)
				img.set_pixel(x, y, _blend(dst, col))


static func _fill_round_rect(img: Image, x0: int, y0: int, bw: int, bh: int, radius: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r := mini(radius, mini(bw, bh) / 2)
	for y in range(y0, y0 + bh):
		if y < 0 or y >= h:
			continue
		for x in range(x0, x0 + bw):
			if x < 0 or x >= w:
				continue
			var inside := true
			# Corner distance checks
			if x < x0 + r and y < y0 + r:
				inside = _in_circle(x, y, x0 + r, y0 + r, r)
			elif x >= x0 + bw - r and y < y0 + r:
				inside = _in_circle(x, y, x0 + bw - r - 1, y0 + r, r)
			elif x < x0 + r and y >= y0 + bh - r:
				inside = _in_circle(x, y, x0 + r, y0 + bh - r - 1, r)
			elif x >= x0 + bw - r and y >= y0 + bh - r:
				inside = _in_circle(x, y, x0 + bw - r - 1, y0 + bh - r - 1, r)
			if inside:
				var dst := img.get_pixel(x, y)
				img.set_pixel(x, y, _blend(dst, col))


static func _in_circle(x: int, y: int, cx: int, cy: int, r: int) -> bool:
	var dx := x - cx
	var dy := y - cy
	return dx * dx + dy * dy <= r * r


static func _blend(dst: Color, src: Color) -> Color:
	var a := src.a
	if a >= 0.999:
		return Color(src.r, src.g, src.b, 1.0)
	if a <= 0.001:
		return dst
	var out_a := a + dst.a * (1.0 - a)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	return Color(
		(src.r * a + dst.r * dst.a * (1.0 - a)) / out_a,
		(src.g * a + dst.g * dst.a * (1.0 - a)) / out_a,
		(src.b * a + dst.b * dst.a * (1.0 - a)) / out_a,
		out_a
	)


static func _make_milk_bottle(milk_col: Color, glass_tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "MilkBottle"

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.26
	cyl.height = 0.72
	cyl.radial_segments = 20
	body.mesh = cyl
	body.position = Vector3(0.0, 0.36, 0.0)
	var glass := glass_tint
	glass.a = 0.72
	body.material_override = _mat(glass, 0.12, 0.05)
	root.add_child(body)

	var milk := MeshInstance3D.new()
	var milk_mesh := CylinderMesh.new()
	milk_mesh.top_radius = 0.175
	milk_mesh.bottom_radius = 0.215
	milk_mesh.height = 0.5
	milk.mesh = milk_mesh
	milk.position = Vector3(0.0, 0.3, 0.0)
	milk.material_override = _mat(milk_col, 0.65, 0.0)
	root.add_child(milk)

	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.1
	neck_mesh.bottom_radius = 0.14
	neck_mesh.height = 0.18
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 0.8, 0.0)
	neck.material_override = _mat(glass, 0.12, 0.05)
	root.add_child(neck)

	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.12
	cap_mesh.bottom_radius = 0.12
	cap_mesh.height = 0.08
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 0.93, 0.0)
	cap.material_override = _mat(Color(0.55, 0.35, 0.22), 0.4, 0.15)
	root.add_child(cap)

	var label := MeshInstance3D.new()
	var label_mesh := BoxMesh.new()
	label_mesh.size = Vector3(0.28, 0.22, 0.02)
	label.mesh = label_mesh
	label.position = Vector3(0.0, 0.38, 0.25)
	label.material_override = _mat(Color(0.92, 0.55, 0.35), 0.45, 0.05)
	root.add_child(label)
	return root


static func _make_wool_cloud() -> Node3D:
	var root := Node3D.new()
	root.name = "WoolCloud"
	var wool := Color(0.94, 0.94, 0.97)
	var offsets := [
		Vector3(0.0, 0.28, 0.0),
		Vector3(0.22, 0.3, 0.08),
		Vector3(-0.22, 0.3, 0.06),
		Vector3(0.12, 0.4, -0.16),
		Vector3(-0.14, 0.4, -0.14),
		Vector3(0.0, 0.48, 0.12),
		Vector3(0.18, 0.24, 0.2),
		Vector3(-0.18, 0.24, 0.18),
		Vector3(0.05, 0.18, -0.05),
	]
	var radii := [0.28, 0.2, 0.2, 0.18, 0.18, 0.16, 0.17, 0.17, 0.15]
	for i in range(offsets.size()):
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radii[i]
		sphere.height = radii[i] * 1.7
		puff.mesh = sphere
		puff.position = offsets[i]
		puff.material_override = _mat(wool.darkened(0.015 * (i % 3)), 0.85, 0.0)
		root.add_child(puff)
	return root


static func _make_procedural_apple(fruit_col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Apple"
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.72
	body.mesh = sphere
	body.position = Vector3(0.0, 0.34, 0.0)
	body.scale = Vector3(1.0, 0.92, 1.0)
	body.material_override = _mat(fruit_col, 0.45, 0.05)
	root.add_child(body)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.035
	stem_mesh.height = 0.14
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, 0.72, 0.0)
	stem.material_override = _mat(Color(0.35, 0.22, 0.12), 0.4, 0.1)
	root.add_child(stem)

	var leaf := MeshInstance3D.new()
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.12
	leaf_mesh.height = 0.06
	leaf.mesh = leaf_mesh
	leaf.position = Vector3(0.12, 0.7, 0.0)
	leaf.rotation_degrees = Vector3(0, 0, -35)
	leaf.scale = Vector3(1.4, 0.35, 0.7)
	leaf.material_override = _mat(Color(0.28, 0.55, 0.22), 0.55, 0.0)
	root.add_child(leaf)
	return root


static func _sample_tree_apple_color() -> Color:
	var img := _load_tree_albedo()
	if img == null:
		return Color(0.82, 0.2, 0.18)
	var w := img.get_width()
	var h := img.get_height()
	var sum := Color(0, 0, 0, 0)
	var n := 0
	var step := maxi(1, int(w / 128))
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			if _is_fruit_pixel(c):
				sum += c
				n += 1
	if n == 0:
		return Color(0.82, 0.2, 0.18)
	return sum / float(n)


static func _paint_apple_icon_from_tree() -> Image:
	## Clean apple silhouette filled with real fruit pixels sampled from the tree albedo.
	var albedo := _load_tree_albedo()
	var fruit := _sample_tree_apple_color()
	var fruit_dark := fruit.darkened(0.18)
	var fruit_light := fruit.lightened(0.12)
	var size := ICON_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, size / 2, int(size * 0.82), int(size * 0.22), int(size * 0.06), Color(0, 0, 0, 0.16))

	var cx := size / 2
	var cy := int(size * 0.54)
	var rx := int(size * 0.30)
	var ry := int(size * 0.28)
	# Body
	_fill_ellipse(img, cx, cy, rx, ry, fruit)
	# Bottom shade
	_fill_ellipse(img, cx + 4, cy + 10, int(rx * 0.75), int(ry * 0.55), fruit_dark)
	# Specular
	_fill_ellipse(img, cx - 14, cy - 12, int(rx * 0.28), int(ry * 0.22), Color(fruit_light.r, fruit_light.g, fruit_light.b, 0.55))
	# Cavity
	_fill_ellipse(img, cx, cy - ry + 6, 10, 6, fruit_dark)
	# Stem
	_fill_round_rect(img, cx - 3, cy - ry - 10, 7, 18, 3, Color(0.36, 0.22, 0.12, 1))
	# Leaf
	_fill_ellipse(img, cx + 16, cy - ry - 2, 16, 8, Color(0.30, 0.55, 0.22, 1))

	# Stamp real tree-apple texels into the fruit body for authenticity.
	if albedo:
		var samples: Array[Color] = []
		var w := albedo.get_width()
		var h := albedo.get_height()
		var step := maxi(1, int(w / 96))
		for y in range(0, h, step):
			for x in range(0, w, step):
				var c := albedo.get_pixel(x, y)
				if _is_fruit_pixel(c):
					samples.append(c)
		if not samples.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for y in range(cy - ry, cy + ry + 1):
				for x in range(cx - rx, cx + rx + 1):
					var nx := float(x - cx) / float(rx)
					var ny := float(y - cy) / float(ry)
					if nx * nx + ny * ny > 0.92:
						continue
					if img.get_pixel(x, y).a < 0.1:
						continue
					# Soft mix with a real texel.
					var src: Color = samples[rng.randi() % samples.size()]
					var dst := img.get_pixel(x, y)
					var mixed := dst.lerp(src, 0.55)
					mixed.a = 1.0
					img.set_pixel(x, y, mixed)
	return img


static func _is_fruit_pixel(c: Color) -> bool:
	return c.r > 0.45 and c.r > c.g + 0.12 and c.r > c.b + 0.12 and c.g < 0.65


static func _load_tree_albedo() -> Image:
	if not ResourceLoader.exists(TREE_ALBEDO) and not FileAccess.file_exists(TREE_ALBEDO):
		var abs_try := ProjectSettings.globalize_path(TREE_ALBEDO)
		if not FileAccess.file_exists(abs_try):
			return null
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(TREE_ALBEDO)
	if img.load(abs_path) != OK:
		return null
	return img


static func _make_wood_log() -> Node3D:
	var root := Node3D.new()
	var logm := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.9
	logm.mesh = cyl
	logm.rotation_degrees = Vector3(0, 0, 90)
	logm.position = Vector3(0.0, 0.28, 0.0)
	logm.material_override = _mat(Color(0.55, 0.36, 0.2), 0.45, 0.05)
	root.add_child(logm)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.275
	disc.bottom_radius = 0.275
	disc.height = 0.04
	ring.mesh = disc
	ring.rotation_degrees = Vector3(0, 0, 90)
	ring.position = Vector3(0.45, 0.28, 0.0)
	ring.material_override = _mat(Color(0.78, 0.68, 0.45), 0.55, 0.0)
	root.add_child(ring)
	return root


static func _make_meat() -> Node3D:
	var root := Node3D.new()
	var steak := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.28
	steak.mesh = mesh
	steak.scale = Vector3(1.3, 0.55, 1.0)
	steak.position = Vector3(0.0, 0.2, 0.0)
	steak.material_override = _mat(Color(0.72, 0.28, 0.28), 0.5, 0.05)
	root.add_child(steak)
	return root


static func _mat(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if albedo.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
