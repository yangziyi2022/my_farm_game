extends Node

## SFX + looping day music. Drop files under assets/audio/; missing files no-op.
## Mute persists in user://audio_settings.cfg

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://audio_settings.cfg"
const DEFAULT_MUSIC_ID := "day"

## SFX at full loudness; BGM quieter so it sits under gameplay.
const SFX_DB := 0.0
const MUSIC_DB := -14.0

const KNOWN_SFX := [
	"ui_click",
	"place",
	"harvest",
	"hoe",
	"copy_confirm",
	"delete",
	"feed",
	"fish_catch",
	"fishing_drop",
	"chick",
	"moo",
	"pig",
	"quack",
	"sheep",
	"rabbit",
]

## Filename typos / alternate names → canonical id.
const SFX_ALIASES := {
	"copy_confirm": ["copy_comfirm"],
}

## ItemData.ItemType → sfx id.
const ANIMAL_SFX_BY_ITEM := {
	ItemData.ItemType.CHICKEN: "chick",
	ItemData.ItemType.COW: "moo",
	ItemData.ItemType.PIG: "pig",
	ItemData.ItemType.DUCK: "quack",
	ItemData.ItemType.SHEEP: "sheep",
	ItemData.ItemType.RABBIT: "rabbit",
}

## Ortho zoom range (matches CameraController).
const CAM_ZOOM_NEAR := 8.0
const CAM_ZOOM_FAR := 90.0
## Ambient voices stay quiet until fairly zoomed in.
const ANIMAL_ZOOM_SOFT := 42.0
const ANIMAL_HEAR_NEAR := 10.0
const ANIMAL_HEAR_FAR := 55.0
## Extra gain for soft source clips (dB added after spatial falloff).
const ANIMAL_GAIN_DB := {
	"moo": 7.0,
}

signal mute_changed(muted: bool)
signal music_mute_changed(music_muted: bool)

var _players: Dictionary = {}  # id -> AudioStreamPlayer
var _streams: Dictionary = {}  # id -> AudioStream
var _music_player: AudioStreamPlayer
## Mute everything (SFX + music).
var _muted: bool = false
## Mute background music only (SFX still play).
var _music_muted: bool = false
var master_sfx_db: float = SFX_DB
var master_music_db: float = MUSIC_DB
## Soft throttle so many animals don't all shout at once.
var _ambient_animal_cooldown: float = 0.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)
	_load_settings()
	_reload_known()
	_apply_mute_volumes()


func _process(delta: float) -> void:
	if _ambient_animal_cooldown > 0.0:
		_ambient_animal_cooldown = maxf(0.0, _ambient_animal_cooldown - delta)


func is_muted() -> bool:
	return _muted


func is_music_muted() -> bool:
	return _music_muted


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_apply_mute_volumes()
	_save_settings()
	mute_changed.emit(_muted)


func set_music_muted(music_muted: bool) -> void:
	if _music_muted == music_muted:
		return
	_music_muted = music_muted
	_apply_mute_volumes()
	_save_settings()
	music_mute_changed.emit(_music_muted)


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func toggle_music_mute() -> bool:
	set_music_muted(not _music_muted)
	return _music_muted


func play(id: String, pitch_variance: float = 0.04, volume_db: float = INF) -> void:
	if id.is_empty() or _muted:
		return
	var stream := _ensure_stream(id)
	if stream == null:
		return
	var player := _players.get(id) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "SFX_%s" % id
		player.bus = "Master"
		add_child(player)
		_players[id] = player
	player.stream = stream
	player.volume_db = master_sfx_db if volume_db == INF else volume_db
	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
	player.play()


func play_animal_for_item(
	item_type: ItemData.ItemType,
	ambient: bool = false,
	world_pos: Vector3 = Vector3.INF
) -> void:
	if not ANIMAL_SFX_BY_ITEM.has(item_type):
		return
	_play_animal_id(str(ANIMAL_SFX_BY_ITEM[item_type]), ambient, world_pos)


func play_animal_for_species(
	species: int,
	ambient: bool = false,
	world_pos: Vector3 = Vector3.INF
) -> void:
	## AnimalController.Species → clip.
	var id := ""
	match species:
		AnimalController.Species.CHICKEN:
			id = "chick"
		AnimalController.Species.SHEEP:
			id = "sheep"
		AnimalController.Species.PIG:
			id = "pig"
		AnimalController.Species.DUCK:
			id = "quack"
		AnimalController.Species.COW:
			id = "moo"
		AnimalController.Species.RABBIT:
			id = "rabbit"
		_:
			return
	_play_animal_id(id, ambient, world_pos)


func _play_animal_id(id: String, ambient: bool, world_pos: Vector3) -> void:
	if ambient:
		if _ambient_animal_cooldown > 0.0:
			return
	var vol := _animal_volume_db(id, world_pos, ambient)
	# Too quiet to bother (far + zoomed out).
	if ambient and vol < -38.0:
		return
	if ambient:
		_ambient_animal_cooldown = 2.8
		play(id, 0.08, vol)
	else:
		# Feed / focus cues stay a bit clearer but still respect distance.
		play(id, 0.05, maxf(vol, -18.0 + float(ANIMAL_GAIN_DB.get(id, 0.0))))


func _animal_volume_db(id: String, world_pos: Vector3, ambient: bool) -> float:
	## Quiet when zoomed out; when zoomed in, nearer animals are louder.
	var gain := float(ANIMAL_GAIN_DB.get(id, 0.0))
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return master_sfx_db - (8.0 if ambient else 0.0) + gain

	var zoom_size := cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else CAM_ZOOM_FAR
	# 0 = fully zoomed out, 1 = fully zoomed in.
	var zoom_t := 1.0 - clampf(
		(zoom_size - CAM_ZOOM_NEAR) / maxf(CAM_ZOOM_FAR - CAM_ZOOM_NEAR, 0.001),
		0.0,
		1.0
	)
	# Soft gate: barely audible until past mid zoom.
	var zoom_gate := clampf(
		(ANIMAL_ZOOM_SOFT - zoom_size) / maxf(ANIMAL_ZOOM_SOFT - CAM_ZOOM_NEAR, 0.001),
		0.0,
		1.0
	)
	zoom_gate = zoom_gate * zoom_gate

	var dist_t := 0.55
	if world_pos.x < 900000.0:
		var dist := cam.global_position.distance_to(world_pos)
		var hear := lerpf(ANIMAL_HEAR_FAR, ANIMAL_HEAR_NEAR, zoom_t)
		dist_t = 1.0 - clampf(dist / maxf(hear, 1.0), 0.0, 1.0)
		dist_t = dist_t * dist_t

	var linear := zoom_gate * lerpf(0.08, 1.0, dist_t)
	if ambient:
		linear *= 0.85
	else:
		# Feeding: keep a usable floor so the cue isn't lost.
		linear = maxf(linear, 0.22)
	linear = clampf(linear, 0.0, 1.0)
	if linear <= 0.001:
		return -80.0
	return master_sfx_db + linear_to_db(linear) + gain


func play_music(id: String = DEFAULT_MUSIC_ID, fade_in: bool = false) -> void:
	var stream := _load_music_stream(id)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream = stream
	_music_player.volume_db = -80.0 if fade_in else _effective_music_db()
	_music_player.play()
	if fade_in and not _is_music_silenced():
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", _effective_music_db(), 1.2)


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


func has_sfx(id: String) -> bool:
	return _ensure_stream(id) != null


func _is_music_silenced() -> bool:
	return _muted or _music_muted


func _effective_music_db() -> float:
	return -80.0 if _is_music_silenced() else master_music_db


func _apply_mute_volumes() -> void:
	if _music_player:
		_music_player.volume_db = _effective_music_db()
		# Keep looping silently while muted so unmute resumes instantly.
		if _is_music_silenced() and _music_player.stream and not _music_player.playing:
			_music_player.play()
	for id in _players:
		var p: AudioStreamPlayer = _players[id]
		if p:
			p.volume_db = -80.0 if _muted else master_sfx_db


func _reload_known() -> void:
	for id in KNOWN_SFX:
		_ensure_stream(id)


func _ensure_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id] as AudioStream
	var stream := _load_sfx_stream(id)
	_streams[id] = stream
	return stream


func _load_sfx_stream(id: String) -> AudioStream:
	var names: Array[String] = [id]
	if SFX_ALIASES.has(id):
		for alt in SFX_ALIASES[id]:
			names.append(str(alt))
	for name in names:
		for ext: String in [".ogg", ".wav", ".mp3"]:
			var path: String = SFX_DIR + name + ext
			if ResourceLoader.exists(path):
				var res: Variant = load(path)
				if res is AudioStream:
					return res as AudioStream
	return null


func _load_music_stream(id: String) -> AudioStream:
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var path: String = MUSIC_DIR + id + ext
		if ResourceLoader.exists(path):
			var res: Variant = load(path)
			if res is AudioStream:
				return res as AudioStream
	return null


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_muted = bool(cfg.get_value("audio", "muted", false))
	_music_muted = bool(cfg.get_value("audio", "music_muted", false))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", _muted)
	cfg.set_value("audio", "music_muted", _music_muted)
	cfg.save(SETTINGS_PATH)
