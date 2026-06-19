extends Node

# AudioManager — gestisce tutti i suoni del gioco
# Mette AudioStreamPlayer per ogni canale; carica i file da res://audio/ se esistono.
# Senza file audio il manager è silenzioso ma non crasha.

var _ambient: AudioStreamPlayer
var _music: AudioStreamPlayer
var _sfx_punch: AudioStreamPlayer
var _sfx_step: AudioStreamPlayer
var _sfx_engine: AudioStreamPlayer

const AUDIO_DIR := "res://audio/"

func setup() -> void:
	_ambient  = _make_player("Ambient", -12.0)
	_music    = _make_player("Music",   -8.0)
	_sfx_punch = _make_player("SFX_Punch",  -2.0)
	_sfx_step  = _make_player("SFX_Step",  -8.0)
	_sfx_engine = _make_player("SFX_Engine", -10.0)

	_try_load(_ambient,   "ambient_night.ogg",  true)
	_try_load(_music,     "theme.ogg",           true)
	_try_load(_sfx_punch, "punch.wav",           false)
	_try_load(_sfx_step,  "footstep.wav",        false)
	_try_load(_sfx_engine,"engine.ogg",          true)

func _make_player(bus_name: String, vol_db: float) -> AudioStreamPlayer:
	var asp := AudioStreamPlayer.new()
	asp.name   = bus_name
	asp.volume_db = vol_db
	asp.bus    = "Master"
	add_child(asp)
	return asp

func _try_load(asp: AudioStreamPlayer, filename: String, loop: bool) -> void:
	var path := AUDIO_DIR + filename
	var stream = load(path) if ResourceLoader.exists(path) else null
	if stream:
		asp.stream = stream
		if loop and asp.stream.has_method("set_loop"):
			asp.stream.set_loop(true)
		print("Audio caricato: ", filename)
	else:
		print("Audio mancante (silenzioso): ", filename)

func play_ambient() -> void:
	if _ambient and _ambient.stream and not _ambient.playing:
		_ambient.play()

func stop_ambient() -> void:
	if _ambient:
		_ambient.stop()

func play_music() -> void:
	if _music and _music.stream and not _music.playing:
		_music.play()

func stop_music() -> void:
	if _music:
		_music.stop()

func play_punch() -> void:
	if _sfx_punch and _sfx_punch.stream:
		_sfx_punch.play()

func play_footstep() -> void:
	if _sfx_step and _sfx_step.stream and not _sfx_step.playing:
		_sfx_step.play()

func play_engine(on: bool) -> void:
	if not _sfx_engine:
		return
	if on and _sfx_engine.stream and not _sfx_engine.playing:
		_sfx_engine.play()
	elif not on and _sfx_engine.playing:
		_sfx_engine.stop()
