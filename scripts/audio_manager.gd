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
]

## Filename typos / alternate names → canonical id.
const SFX_ALIASES := {
	"copy_confirm": ["copy_comfirm"],
}

signal mute_changed(muted: bool)

var _players: Dictionary = {}  # id -> AudioStreamPlayer
var _streams: Dictionary = {}  # id -> AudioStream
var _music_player: AudioStreamPlayer
var _muted: bool = false
var master_sfx_db: float = SFX_DB
var master_music_db: float = MUSIC_DB


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)
	_load_settings()
	_reload_known()
	_apply_mute_volumes()


func is_muted() -> bool:
	return _muted


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_apply_mute_volumes()
	_save_settings()
	mute_changed.emit(_muted)


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func play(id: String, pitch_variance: float = 0.04) -> void:
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
	player.volume_db = master_sfx_db
	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
	player.play()


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
	if fade_in and not _muted:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", _effective_music_db(), 1.2)


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


func has_sfx(id: String) -> bool:
	return _ensure_stream(id) != null


func _effective_music_db() -> float:
	return -80.0 if _muted else master_music_db


func _apply_mute_volumes() -> void:
	if _music_player:
		_music_player.volume_db = _effective_music_db()
		# Keep looping silently while muted so unmute resumes instantly.
		if _muted and _music_player.stream and not _music_player.playing:
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


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", _muted)
	cfg.save(SETTINGS_PATH)
