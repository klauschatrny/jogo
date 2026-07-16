## Trilha sonora (autoload "Music"). Data-driven: as faixas vivem em `data/audio.json`, indexadas
## por id — nenhum caminho de arquivo nem volume fica hardcoded aqui. Toca UMA faixa por vez, com
## fade in/out; pedir a faixa que já toca é no-op (não reinicia).
##
## Camada de apresentação: o Core NUNCA fala com este autoload. Quem decide o que toca é a cena.
extends Node

const CONFIG := "res://data/audio.json"
const SILENT_DB := -60.0     # volume de "mudo" usado como ponta dos fades

# Abafado (pausa): passa-baixa + corte de ganho no BUS da música — não toca no volume do player
# (que os fades usam) nem no volume do bus (que é do jogador, via AudioSettings/Opções).
const MUFFLE_CUTOFF := 700.0     # Hz com o filtro fechado ("atrás da porta")
const OPEN_CUTOFF := 20500.0     # Hz com o filtro aberto (acima do audível = transparente)
const MUFFLE_GAIN_DB := -9.0     # a música também recua, além de perder os agudos
const MUFFLE_TIME := 0.25        # segundos da transição (nos dois sentidos)

var _tracks: Dictionary = {}   # id -> { stream, volume_db, loop, fade_in, fade_out }
var _player: AudioStreamPlayer
var _current := ""             # id da faixa tocando ("" = silêncio)
var _fade: Tween
var _lowpass: AudioEffectLowPassFilter
var _duck_gain: AudioEffectAmplify
var _muffle: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # a música continua com o jogo pausado
	var cfg: Variant = JsonLoader.load_file(CONFIG)
	if typeof(cfg) == TYPE_DICTIONARY:
		_tracks = (cfg as Dictionary).get("music", {})
	_player = AudioStreamPlayer.new()
	_player.name = "Stream"
	_player.bus = AudioSettings.MUSIC_BUS   # o jogador regula esta categoria nas Opções
	# Web: "Sample" (padrão do Godot 4.3+) sai mudo com mp3; "Stream" toca certo. Ver Sfx._ready.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_setup_muffle_effects()

## Pausou (painel aberto): a música fica "atrás da porta" — abafada e mais baixa — em vez de
## seguir em primeiro plano. `set_muffled(false)` a traz de volta. Idempotente nos dois sentidos.
func set_muffled(on: bool) -> void:
	if _lowpass == null:
		return
	if _muffle != null and _muffle.is_valid():
		_muffle.kill()
	var idx := AudioServer.get_bus_index(AudioSettings.MUSIC_BUS)
	if idx >= 0:      # os efeitos ficam SEMPRE ligados; "desligado" = filtro aberto e ganho 0
		AudioServer.set_bus_effect_enabled(idx, 0, true)
		AudioServer.set_bus_effect_enabled(idx, 1, true)
	_muffle = create_tween().set_parallel()
	_muffle.tween_property(_lowpass, "cutoff_hz",
		MUFFLE_CUTOFF if on else OPEN_CUTOFF, MUFFLE_TIME)
	_muffle.tween_property(_duck_gain, "volume_db",
		MUFFLE_GAIN_DB if on else 0.0, MUFFLE_TIME)

## Pendura o passa-baixa + ganho no bus da música (uma vez, já "abertos" = sem efeito audível).
func _setup_muffle_effects() -> void:
	var idx := AudioServer.get_bus_index(AudioSettings.MUSIC_BUS)
	if idx < 0:
		return
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = OPEN_CUTOFF
	_duck_gain = AudioEffectAmplify.new()
	_duck_gain.volume_db = 0.0
	AudioServer.add_bus_effect(idx, _lowpass, 0)
	AudioServer.add_bus_effect(idx, _duck_gain, 1)

## Toca a faixa `id` de audio.json. Se já for a que está tocando, não faz nada (não reinicia).
func play(id: String) -> void:
	if _player == null:
		return
	if id == _current and _player.playing:
		return
	var track: Dictionary = _tracks.get(id, {})
	var path := String(track.get("stream", ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[Music] faixa '%s' sem stream válido ('%s')" % [id, path])
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	# O loop de mp3/ogg é uma flag do recurso (vem da importação). Forçamos aqui para não
	# depender de o .import estar configurado — a faixa de boss precisa durar a luta inteira.
	if "loop" in stream:
		stream.set("loop", bool(track.get("loop", true)))

	_kill_fade()
	_current = id
	var target_db := float(track.get("volume_db", 0.0))
	var fade_in := float(track.get("fade_in", 1.0))
	_player.stream = stream
	_player.volume_db = SILENT_DB if fade_in > 0.0 else target_db
	_player.play()
	if fade_in > 0.0:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", target_db, fade_in)

## Silencia a faixa atual. `fade_out` < 0 usa o fade declarado na faixa; 0 corta na hora.
func stop(fade_out := -1.0) -> void:
	if _player == null or not _player.playing:
		_current = ""
		return
	if fade_out < 0.0:
		var track: Dictionary = _tracks.get(_current, {})
		fade_out = float(track.get("fade_out", 1.0))
	_current = ""
	_kill_fade()
	if fade_out <= 0.0:
		_player.stop()
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", SILENT_DB, fade_out)
	_fade.tween_callback(_player.stop)

## Id da faixa tocando agora ("" = silêncio).
func current() -> String:
	return _current

func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
