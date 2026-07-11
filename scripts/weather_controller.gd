class_name WeatherController
extends Node

signal weather_changed(weather_id: String)

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D
@export var fill_light: OmniLight3D

const WEATHER_SUNNY := "sunny"
const WEATHER_RAIN := "rain"
const WEATHER_SNOW := "snow"
const WEATHER_FOG := "fog"
const WEATHER_NIGHT := "night"

var _current_weather: String = WEATHER_SUNNY


func setup(p_environment: WorldEnvironment, p_sun: DirectionalLight3D, p_fill: OmniLight3D = null) -> void:
	world_environment = p_environment
	sun_light = p_sun
	fill_light = p_fill
	_current_weather = WEATHER_SUNNY
	# Lighting/sky is driven by DayNightCycle; weather only modulates intensity.
	_notify_day_night_mul(1.0)
	weather_changed.emit(_current_weather)


func get_current_weather() -> String:
	return _current_weather


func apply_weather(weather_id: String) -> void:
	_current_weather = weather_id
	# DayNightCycle owns continuous sky/sun lighting. Weather only adjusts intensity hooks.
	match weather_id:
		WEATHER_SUNNY:
			_notify_day_night_mul(1.0)
		WEATHER_RAIN:
			_notify_day_night_mul(0.75)
		WEATHER_SNOW:
			_notify_day_night_mul(0.85)
		WEATHER_FOG:
			_notify_day_night_mul(0.7)
		WEATHER_NIGHT:
			_notify_day_night_mul(1.0)
		_:
			_notify_day_night_mul(1.0)

	weather_changed.emit(_current_weather)


func _notify_day_night_mul(mul: float) -> void:
	var day_night := get_parent().get_node_or_null("DayNightCycle")
	if day_night and day_night.has_method("set_weather_energy_multiplier"):
		day_night.set_weather_energy_multiplier(mul)


func _apply_sunny() -> void:
	var env := _build_base_environment()
	env.ambient_light_energy = 0.9
	env.fog_density = 0.0016
	world_environment.environment = env

	sun_light.visible = true
	sun_light.light_color = Color(1.0, 0.95, 0.82)
	sun_light.light_energy = 1.3
	sun_light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)

	_apply_soft_fill(Color(1.0, 0.97, 0.9), 0.28, Vector3(2.0, 10.0, 14.0))


func _apply_rain() -> void:
	# Hook: plug in rain particles and audio here later.
	_apply_sunny()
	if world_environment.environment:
		world_environment.environment.fog_density = 0.003
	_apply_soft_fill(Color(0.82, 0.88, 0.95), 0.35, Vector3(0.0, 9.0, 12.0))


func _apply_snow() -> void:
	# Hook: plug in snowfall particles here later.
	_apply_sunny()
	if world_environment.environment:
		world_environment.environment.fog_light_color = Color(0.92, 0.94, 0.98)
		world_environment.environment.fog_density = 0.0025
	_apply_soft_fill(Color(0.9, 0.93, 1.0), 0.4, Vector3(0.0, 8.0, 12.0))


func _apply_fog() -> void:
	# Hook: thicken fog and mute sun for misty mornings.
	_apply_sunny()
	if world_environment.environment:
		world_environment.environment.fog_density = 0.006
		world_environment.environment.fog_aerial_perspective = 0.6
	sun_light.light_energy = 0.95
	_apply_soft_fill(Color(0.88, 0.9, 0.92), 0.45, Vector3(0.0, 6.0, 10.0))


func _apply_night() -> void:
	# Hook: add moon light and stars later.
	var env := _build_base_environment()
	env.ambient_light_energy = 0.35
	env.fog_density = 0.002
	env.tonemap_exposure = 0.75
	world_environment.environment = env

	sun_light.visible = true
	sun_light.light_color = Color(0.55, 0.62, 0.9)
	sun_light.light_energy = 0.45
	sun_light.rotation_degrees = Vector3(-70.0, 25.0, 0.0)
	_apply_soft_fill(Color(0.45, 0.5, 0.75), 0.18, Vector3(0.0, 7.0, 10.0))


func _build_base_environment() -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.52, 0.92)
	sky_mat.sky_horizon_color = Color(0.62, 0.78, 0.95)
	sky_mat.ground_horizon_color = Color(0.52, 0.68, 0.42)
	sky_mat.ground_bottom_color = Color(0.32, 0.42, 0.28)
	sky_mat.sun_angle_max = 38.0
	sky_mat.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.88, 0.98)
	env.fog_aerial_perspective = 0.35
	env.sdfgi_enabled = false
	return env


func _apply_soft_fill(color: Color, energy: float, position: Vector3) -> void:
	if fill_light == null:
		return
	fill_light.visible = true
	fill_light.light_color = color
	fill_light.light_energy = energy
	fill_light.omni_range = 42.0
	fill_light.omni_attenuation = 0.35
	fill_light.position = position
