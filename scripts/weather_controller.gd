class_name WeatherController
extends Node

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

const WEATHER_SUNNY := "sunny"


func setup(p_environment: WorldEnvironment, p_sun: DirectionalLight3D) -> void:
	world_environment = p_environment
	sun_light = p_sun
	apply_weather(WEATHER_SUNNY)


func apply_weather(weather_id: String) -> void:
	match weather_id:
		WEATHER_SUNNY:
			_apply_sunny()
		_:
			_apply_sunny()


func _apply_sunny() -> void:
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
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.88, 0.98)
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.35
	env.sdfgi_enabled = false

	world_environment.environment = env

	sun_light.light_color = Color(1.0, 0.95, 0.82)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
