class_name FountainSplash
extends Node3D

## Parabolic water arcs from the fountain tip into the basin.

const STREAM_COUNT: int = 8
const DROPS_PER_STREAM: int = 7
const CYCLE: float = 0.85
## Speeds are in Visual-local units (stone fountain Visual is scaled ~2.4).
const OUT_SPEED: float = 0.52
const UP_SPEED: float = 1.05
const GRAVITY: float = 2.9
const FLIGHT: float = 0.68

var _drops: Array[MeshInstance3D] = []
var _stream_of: PackedInt32Array = PackedInt32Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _water_color: Color = Color(0.45, 0.72, 0.95, 0.75)


func setup(water_color: Color = Color(0.45, 0.72, 0.95, 0.75)) -> void:
	_water_color = water_color
	var total := STREAM_COUNT * DROPS_PER_STREAM
	_phases.resize(total)
	_stream_of.resize(total)
	var idx := 0
	for s in range(STREAM_COUNT):
		for d in range(DROPS_PER_STREAM):
			var drop := MeshInstance3D.new()
			drop.name = "SplashDrop_%d_%d" % [s, d]
			var mesh := SphereMesh.new()
			mesh.radius = 0.028
			mesh.height = 0.056
			drop.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _water_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = Color(0.55, 0.8, 1.0)
			mat.emission_energy_multiplier = 0.45
			drop.material_override = mat
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(drop)
			_drops.append(drop)
			_stream_of[idx] = s
			# Stagger drops along the arc so each stream looks continuous.
			_phases[idx] = float(d) / float(DROPS_PER_STREAM)
			idx += 1

	# Thin central spout rising before it breaks into arcs.
	var spout := MeshInstance3D.new()
	spout.name = "CenterSpout"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.04
	cyl.height = 0.22
	spout.mesh = cyl
	spout.position = Vector3(0.0, 0.1, 0.0)
	var spout_mat := StandardMaterial3D.new()
	spout_mat.albedo_color = Color(_water_color.r, _water_color.g, _water_color.b, 0.55)
	spout_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spout_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spout.material_override = spout_mat
	spout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spout)


func _process(delta: float) -> void:
	for i in range(_drops.size()):
		_phases[i] = fmod(_phases[i] + delta / CYCLE, 1.0)
		var t: float = _phases[i] * FLIGHT
		var s: int = _stream_of[i]
		var angle := TAU * float(s) / float(STREAM_COUNT)

		var vx := cos(angle) * OUT_SPEED
		var vz := sin(angle) * OUT_SPEED
		var vy := UP_SPEED
		# Ballistic: x = v*t, y = v_up*t - 0.5*g*t^2
		var x := vx * t
		var z := vz * t
		var y := vy * t - 0.5 * GRAVITY * t * t

		var drop := _drops[i]
		drop.position = Vector3(x, y, z)

		# Stretch slightly along velocity for a streak look.
		var vel := Vector3(vx, vy - GRAVITY * t, vz)
		var speed := maxf(vel.length(), 0.05)
		drop.scale = Vector3(0.65, 0.65 + speed * 0.35, 0.65)
		var dir := vel.normalized()
		if speed > 0.08 and absf(dir.dot(Vector3.UP)) < 0.97:
			drop.look_at(drop.global_position + dir, Vector3.UP)

		var mat := drop.material_override as BaseMaterial3D
		if mat:
			var c := _water_color
			var life := _phases[i]
			c.a = _water_color.a * smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.78, 1.0, life))
			mat.albedo_color = c
