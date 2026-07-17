class_name FountainSplash
extends Node3D

## Radial “flower” droplets that rise from the jet and fall into the basin ring.

const DROP_COUNT: int = 10
const CYCLE: float = 1.15
const RING_RADIUS: float = 0.62
const PEAK_Y: float = 0.55

var _drops: Array[MeshInstance3D] = []
var _phases: PackedFloat32Array = PackedFloat32Array()
var _water_color: Color = Color(0.45, 0.72, 0.95, 0.75)


func setup(water_color: Color = Color(0.45, 0.72, 0.95, 0.75)) -> void:
	_water_color = water_color
	_phases.resize(DROP_COUNT)
	for i in range(DROP_COUNT):
		var drop := MeshInstance3D.new()
		drop.name = "SplashDrop_%d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.07
		drop.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _water_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.material_override = mat
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drop)
		_drops.append(drop)
		_phases[i] = float(i) / float(DROP_COUNT)


func _process(delta: float) -> void:
	for i in range(_drops.size()):
		_phases[i] = fmod(_phases[i] + delta / CYCLE, 1.0)
		var t: float = _phases[i]
		var angle := TAU * float(i) / float(DROP_COUNT) + t * 0.35
		# Ease out rise, then fall into the donut groove.
		var rise := sin(t * PI)
		var outward := smoothstep(0.0, 1.0, t)
		var radius := outward * RING_RADIUS
		var y := rise * PEAK_Y
		var drop := _drops[i]
		drop.position = Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var scale_amt := 0.55 + rise * 0.7
		drop.scale = Vector3.ONE * scale_amt
		var mat := drop.material_override as BaseMaterial3D
		if mat:
			var c := _water_color
			# Fade near start/end so drops appear to leave the jet and vanish in the basin.
			c.a = _water_color.a * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.82, 1.0, t))
			mat.albedo_color = c
