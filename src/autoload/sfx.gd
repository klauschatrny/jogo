## Efeitos sonoros (autoload "Sfx"). Data-driven, igual à trilha: os sons vivem em `data/audio.json`
## (bloco "sfx") indexados por id, cada um com uma LISTA de variações. Nenhum caminho de arquivo ou
## volume aparece no código de jogo.
##
##   Sfx.play("skeleton_attack")      # rodízio: alterna as variações a cada toque (não repete)
##   Sfx.play("player_attack", 1)     # variação fixa: quem chama escolhe (ex.: pelo passo do combo)
##   Sfx.loop("player_footsteps")     # som contínuo (passos); loop_stop() o corta
##
## Toca em vozes reutilizáveis (VOICES): sons simultâneos não se cortam. Id vazio = silêncio
## (permite "sem som" data-driven); id desconhecido avisa, mas não quebra.
extends Node

const CONFIG := "res://data/audio.json"
const VOICES := 8            # sons curtos simultâneos antes de reciclar a voz mais antiga

var _defs: Dictionary = {}   # id -> { "streams": [AudioStream], "volume_db": float }
var _cycle: Dictionary = {}  # id -> índice da PRÓXIMA variação do rodízio
var _voices: Array = []      # AudioStreamPlayer reutilizáveis (sons curtos)
var _next := 0
var _loops: Dictionary = {}      # id -> AudioStreamPlayer dedicado (sons contínuos, cortáveis)
var _sustained: Dictionary = {}  # id -> AudioStreamPlayer dedicado (sustain: nunca corta no meio)

func _ready() -> void:
	var cfg: Variant = JsonLoader.load_file(CONFIG)
	var block: Dictionary = ((cfg as Dictionary).get("sfx", {}) if typeof(cfg) == TYPE_DICTIONARY else {})
	for id in block:
		var def: Dictionary = block[id]
		var streams: Array = []
		for path in def.get("streams", []):
			var s := (load(String(path)) as AudioStream) if ResourceLoader.exists(String(path)) else null
			if s == null:
				push_warning("[Sfx] '%s': stream ausente (%s)" % [id, path])
				continue
			if bool(def.get("loop", false)) and "loop" in s:
				s.set("loop", true)   # sons contínuos (passos): o loop é do recurso, não do player
			streams.append(s)
		if streams.is_empty():
			continue
		_defs[id] = {
			"streams": streams,
			"volume_db": float(def.get("volume_db", 0.0)),
			"impact_at": float(def.get("impact_at", 0.0)),
			"step_every": float(def.get("step_every", 0.0)),
			"first_step": float(def.get("first_step", 0.0)),
		}
		_cycle[id] = 0

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)

## Toca `id` uma vez. `variant` = índice da variação (0-based, dá a volta se estourar);
## -1 = rodízio automático — cada toque usa a próxima variação, alternando o som.
func play(id: String, variant := -1) -> void:
	if id == "":
		return          # "sem som" é uma configuração válida (ex.: boss sem sfx de impacto)
	var def: Dictionary = _defs.get(id, {})
	if def.is_empty():
		push_warning("[Sfx] id desconhecido: '%s'" % id)
		return
	var streams: Array = def["streams"]
	var idx := 0
	if variant >= 0:
		idx = variant % streams.size()
	else:
		idx = int(_cycle[id]) % streams.size()
		_cycle[id] = idx + 1
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = streams[idx]
	voice.volume_db = float(def["volume_db"])
	voice.play()

## Garante que `id` está tocando em loop, num player só dele. Chamar de novo enquanto toca é no-op
## (não reinicia), então dá para chamar todo frame enquanto a condição valer.
func loop(id: String) -> void:
	if id == "" or not _defs.has(id):
		return
	var p: AudioStreamPlayer = _loops.get(id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "Loop_%s" % id
		add_child(p)
		_loops[id] = p
	if p.playing:
		return
	var def: Dictionary = _defs[id]
	p.stream = def["streams"][0]
	p.volume_db = float(def["volume_db"])
	p.play()

## Ciclo de passadas que NUNCA é cortado no meio de um passo. Chame todo frame com `active` = a
## condição vale (ex.: "o ogro está andando").
##
## O clipe é um CICLO em loop: uma passada a cada `step_every` segundos, a primeira em `first_step`
## (audio.json). Enquanto `active`, ele roda em loop. Quando deixa de valer, o som NÃO para na hora
## nem é cortado: segue até um ponto de SILÊNCIO — um triz antes da próxima passada — e só aí para.
## Assim a passada em curso soa inteira e nenhuma passada extra nasce. A espera é de no máximo um
## `step_every`, quase todo ele silêncio. Voltar a andar antes disso cancela a parada (sem emenda).
##
## Diferença para loop(): loop() é cortável em qualquer ponto (loop_stop() para onde estiver).
const STOP_MARGIN := 0.06    # para este tanto ANTES da próxima passada (folga p/ não a iniciar)

func sustain(id: String, active: bool) -> void:
	if id == "" or not _defs.has(id):
		return
	var st: Dictionary = _sustained.get(id, {})
	if st.is_empty():
		if not active:
			return                        # nada tocando e nada a fazer: não cria o player à toa
		var p := AudioStreamPlayer.new()
		p.name = "Sustain_%s" % id
		add_child(p)
		st = { "player": p, "stop_at": -1.0 }
		_sustained[id] = st

	var player: AudioStreamPlayer = st["player"]
	var def: Dictionary = _defs[id]
	if active:
		st["stop_at"] = -1.0              # voltou a andar: cancela qualquer parada agendada
		if not player.playing:
			player.stream = def["streams"][0]
			player.volume_db = float(def["volume_db"])
			player.play()
		return

	# Parou de andar: agenda a parada no próximo ponto de silêncio (uma vez só).
	if player.playing and float(st["stop_at"]) < 0.0:
		st["stop_at"] = _quiet_point(def, player.get_playback_position())

## Vigia as paradas agendadas: para o ciclo exatamente no ponto de silêncio calculado.
func _process(_delta: float) -> void:
	for id in _sustained:
		var st: Dictionary = _sustained[id]
		var stop_at := float(st["stop_at"])
		if stop_at < 0.0:
			continue
		var player: AudioStreamPlayer = st["player"]
		if not player.playing or player.get_playback_position() >= stop_at:
			player.stop()
			st["stop_at"] = -1.0

## Próximo instante do clipe em que dá para cortar sem picotar uma passada: um triz antes da
## passada seguinte. Sem grade (`step_every` = 0), corta no fim do clipe (que é silêncio).
func _quiet_point(def: Dictionary, pos: float) -> float:
	var every := float(def["step_every"])
	var length: float = (def["streams"][0] as AudioStream).get_length()
	if every <= 0.0:
		return length
	var first := float(def["first_step"])
	# Índice da próxima passada depois da posição atual (com a margem já descontada).
	var k := floori((pos + STOP_MARGIN - first) / every) + 1
	var next_step := first + float(k) * every
	return minf(next_step - STOP_MARGIN, length)

## Duração (s) de uma variação de `id` — útil para sincronizar uma cutscene com o som.
## 0.0 se o id não existe.
func length(id: String, variant := 0) -> float:
	var def: Dictionary = _defs.get(id, {})
	if def.is_empty():
		return 0.0
	var streams: Array = def["streams"]
	return (streams[variant % streams.size()] as AudioStream).get_length()

## Instante DENTRO do clipe em que está o acento (o baque, o golpe). 0 = logo no começo.
## Quem sincroniza uma ação com o som toca-o adiantado deste tanto — ver floor_scene._boss_intro.
func impact_at(id: String) -> float:
	var def: Dictionary = _defs.get(id, {})
	return float(def.get("impact_at", 0.0)) if not def.is_empty() else 0.0

func loop_stop(id: String) -> void:
	var p: AudioStreamPlayer = _loops.get(id)
	if p != null and p.playing:
		p.stop()
