## Volumes de MÚSICA e EFEITOS, controlados pelo jogador (autoload "AudioSettings").
##
## Cria dois buses de áudio ("Music" e "SFX") sob o Master. Os autoloads Music e Sfx tocam CADA UM
## no seu bus, então mexer no volume do bus regula a categoria inteira sem tocar nos ganhos por som
## do `data/audio.json` — aqueles são a MIXAGEM (a relação entre os sons), esta é a torneira geral.
##
## O volume é guardado em `user://settings.json` e relido no próximo jogo.
extends Node

const PATH := "user://settings.json"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENT_BUS := "Ambient"   # sons do AMBIENTE (vento, fogueira): categoria de volume PRÓPRIA
const MUTE_DB := -80.0        # 0% = mudo de verdade (linear_to_db(0) é -inf)

## 0.0 (mudo) .. 1.0 (volume cheio — a mixagem do audio.json, sem corte).
var music_volume := 1.0
var sfx_volume := 1.0
var ambient_volume := 1.0

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_ensure_bus(AMBIENT_BUS)
	_load()
	_apply(MUSIC_BUS, music_volume)
	_apply(SFX_BUS, sfx_volume)
	_apply(AMBIENT_BUS, ambient_volume)

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply(MUSIC_BUS, music_volume)
	save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply(SFX_BUS, sfx_volume)
	save()

func set_ambient_volume(v: float) -> void:
	ambient_volume = clampf(v, 0.0, 1.0)
	_apply(AMBIENT_BUS, ambient_volume)
	save()

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[AudioSettings] não foi possível gravar %s" % PATH)
		return
	f.store_string(JSON.stringify({
		"audio": { "music": music_volume, "sfx": sfx_volume, "ambient": ambient_volume },
	}, "  "))
	f.close()

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return                       # 1ª vez: fica no padrão (volume cheio)
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[AudioSettings] %s inválido — usando os padrões" % PATH)
		return
	var audio: Dictionary = (data as Dictionary).get("audio", {})
	music_volume = clampf(float(audio.get("music", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(audio.get("sfx", 1.0)), 0.0, 1.0)
	ambient_volume = clampf(float(audio.get("ambient", 1.0)), 0.0, 1.0)

## O ouvido é logarítmico: a escala linear do slider vira dB. 0 vira mudo (silêncio de fato).
func _apply(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, MUTE_DB if v <= 0.0 else linear_to_db(v))
	AudioServer.set_bus_mute(idx, v <= 0.0)

func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, "Master")
