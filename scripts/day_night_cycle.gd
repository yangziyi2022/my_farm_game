class_name DayNightCycle
extends Node3D

## Continuous day/night orbit around the farm map center.
## 5 minutes of daylight, 5 minutes of night, looping forever.
## Drives sun/moon visuals, directional light, sky colors, and ambient fill.

signal time_changed(normalized_time: float, is_day: bool)
signal phase_changed(phase: String)

const DAY_SECONDS := 300.0
const NIGHT_SECONDS := 300.0
const CYCLE_SECONDS := DAY_SECONDS + NIGHT_SECONDS

@export var orbit_radius: float = 32.0
@export var sun_disc_radius: float = 1.15
@export var moon_disc_radius: float = 0.95
## 0 = sunrise, 0.25 = noon, 0.5 = sunset, 0.75 = midnight.
@export var start_normalized_time: float = 0.06
## Jump targets for the sun / moon UI buttons.
const TIME_SUNRISE := 0.06
const TIME_MOONRISE := 0.52

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var fill_light: OmniLight3D

var _elapsed: float = 0.0
var _center: Vector3 = Vector3(0.0, 0.0, 25.0)
var _sky_mat: ProceduralSkyMaterial
var _sun_visual: MeshInstance3D
var _moon_visual: Node3D
var _stars: MultiMeshInstance3D
var _last_phase: String = ""
var _energy_mul: float = 1.0


func setup(
	p_environment: WorldEnvironment,
	p_sun: DirectionalLight3D,
	p_fill: OmniLight3D,
	p_center: Vector3,
	p_moon: DirectionalLight3D = null
) -> void:
	world_environment = p_environment
	sun_light = p_sun
	fill_light = p_fill
	moon_light = p_moon
	_center = p_center
	_elapsed = clampf(start_normalized_time, 0.0, 0.999) * CYCLE_SECONDS
	_ensure_environment()
	_ensure_celestial_visuals()
	_apply_frame(true)
	set_process(true)


func set_weather_energy_multiplier(mul: float) -> void:
	_energy_mul = clampf(mul, 0.2, 1.5)


func set_normalized_time(t: float) -> void:
	_elapsed = clampf(t, 0.0, 0.999) * CYCLE_SECONDS
	_apply_frame(true)


func jump_to_sunrise() -> void:
	## Sun just rising — morning.
	set_normalized_time(TIME_SUNRISE)


func jump_to_moonrise() -> void:
	## Moon just rising — evening / early night.
	set_normalized_time(TIME_MOONRISE)


func get_normalized_time() -> float:
	return fposmod(_elapsed / CYCLE_SECONDS, 1.0)


func is_daytime() -> bool:
	return get_normalized_time() < 0.5


func get_phase() -> String:
	var t := get_normalized_time()
	if t < 0.08:
		return "dawn"
	if t < 0.20:
		return "sunrise"
	if t < 0.42:
		return "day"
	if t < 0.50:
		return "sunset"
	if t < 0.58:
		return "dusk"
	if t < 0.92:
		return "night"
	return "predawn"


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, CYCLE_SECONDS)
	# Sky/fog palette is expensive — refresh less often on tablets.
	var update_sky := true
	if OS.has_feature("mobile"):
		update_sky = (Engine.get_process_frames() % 3) == 0
	_apply_frame(update_sky)


func _apply_frame(update_sky: bool = true) -> void:
	var t := get_normalized_time()
	var sun_theta := t * TAU
	# Rise from +X (right), arc over +Y, set at -X (left), then under the map.
	var sun_pos := _center + Vector3(cos(sun_theta), sin(sun_theta), 0.0) * orbit_radius
	var moon_pos := _center + Vector3(cos(sun_theta + PI), sin(sun_theta + PI), 0.0) * orbit_radius

	# Keep discs visible through the rise/set band (slightly below the deck plane).
	var sun_above := sun_pos.y > _center.y - 2.5
	var moon_above := moon_pos.y > _center.y - 2.5
	var sun_elevation := clampf((sun_pos.y - _center.y) / orbit_radius, -1.0, 1.0)
	var moon_elevation := clampf((moon_pos.y - _center.y) / orbit_radius, -1.0, 1.0)

	if _sun_visual:
		_sun_visual.global_position = sun_pos
		_sun_visual.visible = sun_above
		var sun_mat := _sun_visual.material_override as StandardMaterial3D
		if sun_mat:
			var warmth := _sunset_factor(t, sun_elevation)
			sun_mat.albedo_color = Color(1.0, 0.92, 0.55).lerp(Color(1.0, 0.55, 0.25), warmth)
			sun_mat.emission = sun_mat.albedo_color
			sun_mat.emission_energy_multiplier = lerpf(5.5, 3.2, warmth)
	if _moon_visual:
		_moon_visual.global_position = moon_pos
		_moon_visual.visible = moon_above
		# Keep the crescent facing the farm so the lit half reads clearly.
		if moon_above and moon_pos.distance_squared_to(_center) > 0.01:
			_moon_visual.look_at(_center, Vector3.UP)

	_update_stars(t, sun_elevation, moon_above)
	_update_lights(sun_pos, moon_pos, sun_above, moon_above, sun_elevation, moon_elevation, t)
	if update_sky:
		_update_sky_and_ambient(t, sun_elevation)
		_update_fill(t, sun_elevation)

	var phase := get_phase()
	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase)
	time_changed.emit(t, sun_above)


func _update_lights(
	sun_pos: Vector3,
	moon_pos: Vector3,
	sun_above: bool,
	moon_above: bool,
	sun_elevation: float,
	moon_elevation: float,
	t: float
) -> void:
	if sun_light:
		# Aim light so -Z points from sun toward the map center.
		var look := _center
		var from := sun_pos
		if from.distance_squared_to(look) < 0.01:
			from = look + Vector3(0.0, 1.0, 0.0)
		sun_light.look_at_from_position(from, look, Vector3.FORWARD if absf(sun_elevation) > 0.95 else Vector3.UP)

		var day_factor := smoothstep(0.0, 0.18, sun_elevation)
		var sunset_warmth := _sunset_factor(t, sun_elevation)
		var sun_color := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.55, 0.28), sunset_warmth)
		sun_light.light_color = sun_color
		sun_light.light_energy = (0.15 + 1.25 * day_factor) * _energy_mul
		# Soft shadows are expensive on tablets — keep them on phone/desktop day only at lower cost.
		if OS.has_feature("mobile"):
			sun_light.shadow_enabled = false
		else:
			sun_light.shadow_enabled = sun_above
		sun_light.visible = true

	if moon_light:
		var look := _center
		var from := moon_pos
		if from.distance_squared_to(look) < 0.01:
			from = look + Vector3(0.0, 1.0, 0.0)
		moon_light.look_at_from_position(from, look, Vector3.UP)
		var night_factor := smoothstep(0.0, 0.2, moon_elevation)
		moon_light.light_color = Color(0.72, 0.74, 0.78)
		moon_light.light_energy = (0.04 + 0.28 * night_factor) * _energy_mul
		# Moon shadows off on mobile — fill is enough at night.
		moon_light.shadow_enabled = (not OS.has_feature("mobile")) and moon_above and not sun_above
		moon_light.visible = moon_above


func _update_sky_and_ambient(t: float, sun_elevation: float) -> void:
	if _sky_mat == null or world_environment == null or world_environment.environment == null:
		return

	var palette := _sample_sky_palette(t, sun_elevation)
	_sky_mat.sky_top_color = palette.top
	_sky_mat.sky_horizon_color = palette.horizon
	_sky_mat.ground_horizon_color = palette.ground_horizon
	_sky_mat.ground_bottom_color = palette.ground_bottom
	_sky_mat.sky_energy_multiplier = palette.sky_energy
	_sky_mat.ground_energy_multiplier = palette.ground_energy

	var env := world_environment.environment
	env.ambient_light_energy = palette.ambient
	env.tonemap_exposure = palette.exposure
	env.fog_light_color = palette.fog
	env.fog_density = palette.fog_density


func _update_fill(t: float, sun_elevation: float) -> void:
	if fill_light == null:
		return
	var sunset_warmth := _sunset_factor(t, sun_elevation)
	var day_factor := smoothstep(-0.05, 0.25, sun_elevation)
	var night_factor := 1.0 - day_factor
	var fill_color := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.62, 0.4), sunset_warmth)
	fill_color = fill_color.lerp(Color(0.35, 0.42, 0.7), night_factor)
	fill_light.light_color = fill_color
	fill_light.light_energy = (0.12 + 0.22 * day_factor + 0.08 * night_factor) * _energy_mul
	fill_light.position = _center + Vector3(0.0, 12.0, 0.0)
	fill_light.omni_range = 55.0


func _sunset_factor(t: float, sun_elevation: float) -> float:
	# Strong near sunrise/sunset band while the sun is low.
	var near_rise := 1.0 - clampf(absf(t - 0.0) / 0.12, 0.0, 1.0)
	var near_set := 1.0 - clampf(absf(t - 0.5) / 0.12, 0.0, 1.0)
	var near_edge := maxf(near_rise, near_set)
	var low_sun := 1.0 - smoothstep(0.05, 0.35, absf(sun_elevation))
	return clampf(near_edge * low_sun, 0.0, 1.0)


func _sample_sky_palette(t: float, sun_elevation: float) -> Dictionary:
	# Keyframes across a full day. Values blend by normalized cycle time.
	var keys: Array = [
		# dawn
		{"t": 0.00, "top": Color(0.12, 0.14, 0.28), "horizon": Color(0.95, 0.45, 0.35), "gh": Color(0.55, 0.35, 0.28), "gb": Color(0.18, 0.16, 0.14), "sky_e": 0.7, "gnd_e": 0.55, "amb": 0.45, "exp": 0.9, "fog": Color(0.85, 0.55, 0.4), "fog_d": 0.0024},
		# sunrise
		{"t": 0.08, "top": Color(0.35, 0.45, 0.85), "horizon": Color(1.0, 0.62, 0.35), "gh": Color(0.7, 0.5, 0.35), "gb": Color(0.28, 0.24, 0.18), "sky_e": 0.95, "gnd_e": 0.75, "amb": 0.7, "exp": 1.0, "fog": Color(0.95, 0.75, 0.55), "fog_d": 0.002},
		# morning / day
		{"t": 0.22, "top": Color(0.28, 0.55, 0.95), "horizon": Color(0.62, 0.8, 0.96), "gh": Color(0.55, 0.72, 0.45), "gb": Color(0.32, 0.42, 0.28), "sky_e": 1.15, "gnd_e": 1.0, "amb": 0.95, "exp": 1.08, "fog": Color(0.78, 0.88, 0.98), "fog_d": 0.0015},
		# noon
		{"t": 0.35, "top": Color(0.22, 0.5, 0.95), "horizon": Color(0.55, 0.78, 0.98), "gh": Color(0.52, 0.7, 0.42), "gb": Color(0.3, 0.4, 0.26), "sky_e": 1.2, "gnd_e": 1.05, "amb": 1.0, "exp": 1.1, "fog": Color(0.75, 0.86, 0.98), "fog_d": 0.0013},
		# late afternoon
		{"t": 0.45, "top": Color(0.3, 0.42, 0.8), "horizon": Color(1.0, 0.58, 0.32), "gh": Color(0.75, 0.48, 0.3), "gb": Color(0.32, 0.24, 0.16), "sky_e": 0.95, "gnd_e": 0.8, "amb": 0.75, "exp": 1.0, "fog": Color(0.95, 0.7, 0.5), "fog_d": 0.0019},
		# sunset
		{"t": 0.50, "top": Color(0.18, 0.16, 0.35), "horizon": Color(1.0, 0.4, 0.25), "gh": Color(0.6, 0.3, 0.22), "gb": Color(0.2, 0.14, 0.12), "sky_e": 0.65, "gnd_e": 0.5, "amb": 0.42, "exp": 0.88, "fog": Color(0.9, 0.5, 0.35), "fog_d": 0.0025},
		# early night
		{"t": 0.58, "top": Color(0.04, 0.05, 0.14), "horizon": Color(0.12, 0.14, 0.28), "gh": Color(0.12, 0.16, 0.14), "gb": Color(0.06, 0.08, 0.07), "sky_e": 0.35, "gnd_e": 0.25, "amb": 0.28, "exp": 0.78, "fog": Color(0.2, 0.25, 0.4), "fog_d": 0.0022},
		# midnight
		{"t": 0.75, "top": Color(0.02, 0.03, 0.1), "horizon": Color(0.08, 0.1, 0.22), "gh": Color(0.08, 0.12, 0.12), "gb": Color(0.04, 0.06, 0.06), "sky_e": 0.28, "gnd_e": 0.2, "amb": 0.22, "exp": 0.72, "fog": Color(0.15, 0.18, 0.32), "fog_d": 0.002},
		# predawn
		{"t": 0.95, "top": Color(0.08, 0.1, 0.22), "horizon": Color(0.55, 0.3, 0.35), "gh": Color(0.3, 0.2, 0.22), "gb": Color(0.1, 0.1, 0.12), "sky_e": 0.45, "gnd_e": 0.35, "amb": 0.32, "exp": 0.82, "fog": Color(0.45, 0.3, 0.4), "fog_d": 0.0023},
		# wrap to dawn
		{"t": 1.00, "top": Color(0.12, 0.14, 0.28), "horizon": Color(0.95, 0.45, 0.35), "gh": Color(0.55, 0.35, 0.28), "gb": Color(0.18, 0.16, 0.14), "sky_e": 0.7, "gnd_e": 0.55, "amb": 0.45, "exp": 0.9, "fog": Color(0.85, 0.55, 0.4), "fog_d": 0.0024},
	]

	var a: Dictionary = keys[0]
	var b: Dictionary = keys[1]
	for i in range(keys.size() - 1):
		if t >= keys[i]["t"] and t <= keys[i + 1]["t"]:
			a = keys[i]
			b = keys[i + 1]
			break

	var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
	var w: float = clampf((t - float(a["t"])) / span, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)

	# Keep night a bit brighter when the moon is high.
	var moon_boost := 0.0
	if sun_elevation < 0.0:
		moon_boost = smoothstep(0.0, 0.6, -sun_elevation) * 0.08

	return {
		"top": (a["top"] as Color).lerp(b["top"] as Color, w),
		"horizon": (a["horizon"] as Color).lerp(b["horizon"] as Color, w),
		"ground_horizon": (a["gh"] as Color).lerp(b["gh"] as Color, w),
		"ground_bottom": (a["gb"] as Color).lerp(b["gb"] as Color, w),
		"sky_energy": lerpf(float(a["sky_e"]), float(b["sky_e"]), w),
		"ground_energy": lerpf(float(a["gnd_e"]), float(b["gnd_e"]), w),
		"ambient": (lerpf(float(a["amb"]), float(b["amb"]), w) + moon_boost) * _energy_mul,
		"exposure": lerpf(float(a["exp"]), float(b["exp"]), w),
		"fog": (a["fog"] as Color).lerp(b["fog"] as Color, w),
		"fog_density": lerpf(float(a["fog_d"]), float(b["fog_d"]), w),
	}


func _ensure_environment() -> void:
	if world_environment == null:
		return
	var env := Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 30.0
	_sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.4
	env.sdfgi_enabled = false
	world_environment.environment = env


func _ensure_celestial_visuals() -> void:
	if _sun_visual == null:
		_sun_visual = _make_disc("SunDisc", sun_disc_radius, Color(1.0, 0.92, 0.55), 4.5)
		add_child(_sun_visual)
	if _moon_visual == null:
		_moon_visual = _make_waxing_crescent_moon("MoonCrescent", moon_disc_radius)
		add_child(_moon_visual)
	if _stars == null:
		_stars = _make_starfield("NightStars", 120 if OS.has_feature("mobile") else 280)
		add_child(_stars)


func _make_disc(mesh_name: String, radius: float, color: Color, emission: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var inst := MeshInstance3D.new()
	inst.name = mesh_name
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _make_waxing_crescent_moon(mesh_name: String, radius: float) -> Node3D:
	## 上弦月: soft gray crescent, only faintly lit.
	var root := Node3D.new()
	root.name = mesh_name

	var lit := _make_disc("Lit", radius, Color(0.62, 0.64, 0.68), 0.35)
	root.add_child(lit)

	# Dark occluder shifted left → leaves a bright crescent / first-quarter shape.
	var shade := SphereMesh.new()
	shade.radius = radius * 0.96
	shade.height = radius * 1.92
	var shade_inst := MeshInstance3D.new()
	shade_inst.name = "Shade"
	shade_inst.mesh = shade
	shade_inst.position = Vector3(-radius * 0.55, 0.0, radius * 0.08)
	var shade_mat := StandardMaterial3D.new()
	shade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade_mat.albedo_color = Color(0.02, 0.03, 0.08)
	shade_mat.emission_enabled = false
	shade_inst.material_override = shade_mat
	shade_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shade_inst)
	return root


func _make_starfield(field_name: String, count: int) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = field_name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.045
	star_mesh.height = 0.09
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	mm.mesh = star_mesh
	mm.instance_count = count
	mmi.multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.96, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.93, 1.0)
	mat.emission_energy_multiplier = 2.4
	mmi.material_override = mat

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var radius := orbit_radius * 1.55
	for i in range(count):
		# Full sphere around the island so stars wrap the horizon when orbiting.
		var u := rng.randf()
		var v := rng.randf()
		var yaw := u * TAU
		var pitch := acos(2.0 * v - 1.0)  # 0..PI uniform on sphere
		var dir := Vector3(
			sin(pitch) * cos(yaw),
			cos(pitch),
			sin(pitch) * sin(yaw)
		)
		var pos := dir * radius
		var s := rng.randf_range(0.55, 1.4)
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * s), pos)
		mm.set_instance_transform(i, xf)
	mmi.visible = false
	return mmi


func _update_stars(t: float, sun_elevation: float, _moon_above: bool) -> void:
	if _stars == null:
		return
	# Fade in after dusk; full sparkle through night.
	var night := 0.0
	if t >= 0.5 and t < 0.95:
		night = smoothstep(0.5, 0.6, t) * (1.0 - smoothstep(0.88, 0.95, t))
	elif sun_elevation < 0.0:
		night = smoothstep(0.0, 0.25, -sun_elevation)
	_stars.visible = night > 0.02
	_stars.position = _center
	_stars.transparency = clampf(1.0 - night, 0.0, 1.0)
	var mat := _stars.material_override as StandardMaterial3D
	if mat:
		mat.emission_energy_multiplier = lerpf(0.5, 3.0, night) * (0.88 + 0.12 * sin(_elapsed * 1.7))
