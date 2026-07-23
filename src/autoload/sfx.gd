## Efeitos sonoros (autoload "Sfx"). Data-driven, igual à trilha: os sons vivem em `data/audio.json`
## (bloco "sfx") indexados por id, cada um com uma LISTA de variações. Nenhum caminho de arquivo ou
## volume aparece no código de jogo.
##
##   Sfx.play("skeleton_attack")            # rodízio: alterna as variações a cada toque
##   Sfx.play("player_attack", 1)           # variação fixa: quem chama escolhe (ex.: passo do combo)
##   Sfx.sustain("player_footsteps", true)  # ciclo de passadas; nunca corta uma no meio
##
## Toca em vozes reutilizáveis (VOICES): sons simultâneos não se cortam. Id vazio = silêncio
## (permite "sem som" data-driven); id desconhecido avisa, mas não quebra.
extends Node

const CONFIG := "res://data/audio.json"
const VOICES := 8            # sons curtos simultâneos antes de reciclar a voz mais antiga

var _defs: Dictionary = {}   # id -> { "streams": [AudioStream], "volume_db": float }
var _cycle: Dictionary = {}  # id -> índice da PRÓXIMA variação do rodízio
var _bag: Dictionary = {}    # id -> "saco" restante do sorteio SEM reposição (play_random)
var _bag_last: Dictionary = {}  # id -> última variação sorteada (evita repetir na virada do saco)
var _rng := RandomNumberGenerator.new()  # RNG PRÓPRIO cosmético: NÃO usa o RNGService semeado do run
                                         # (sortear grunt não pode perturbar a determinística do run)
var _voices: Array = []      # AudioStreamPlayer reutilizáveis (sons curtos)
var _next := 0
var _sustained: Dictionary = {}  # id -> { player, stop_at, last_pos } — ciclos de passadas (sustain)
var _ambients: Dictionary = {}   # id -> { player, tween } — camas de ambiência em loop (ambient)
var _world_paused := false        # espelho da pausa da árvore, p/ congelar os loops do mundo (passos)

const AMBIENT_FADE := 0.8        # fade só nas TRANSIÇÕES (entrar/sair da arena, menu). O LOOP da
                                 # faixa recomeça sozinho, sem passar por aqui — logo, sem corte.
const AMBIENT_SILENT_DB := -60.0 # ponta "muda" dos fades da ambiência

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # toca com o jogo pausado (cliques do menu de pausa),
	                                           # igual ao autoload Music; as vozes herdam por INHERIT
	_rng.randomize()                           # semente própria; independente do run
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
		# "pitch" (opcional): tons por variação. Permite variar um som SEM um arquivo novo — uma só
		# amostra com dois tons já são duas variações. O nº de variações é o maior entre streams e
		# pitches, e cada lista é percorrida em ciclo.
		var pitches: Array = def.get("pitch", [])
		_defs[id] = {
			"streams": streams,
			"pitches": (pitches if not pitches.is_empty() else [1.0]),
			"volume_db": float(def.get("volume_db", 0.0)),
			"impact_at": float(def.get("impact_at", 0.0)),
			"step_every": float(def.get("step_every", 0.0)),
			"first_step": float(def.get("first_step", 0.0)),
			"step_dur": float(def.get("step_dur", 0.0)),   # quanto tempo UMA passada ainda soa
			"steps": def.get("steps", []),   # instantes das passadas, quando NÃO são uniformes
		}
		_cycle[id] = 0

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		p.bus = AudioSettings.SFX_BUS
		# Web: o padrão do Godot 4.3+ é "Sample", que sai MUDO com mp3 no navegador. "Stream" toca
		# certo (exige os headers COOP/COEP, que o itch e o servidor local de teste já mandam). No
		# desktop, "Stream" é o caminho normal — sem efeito colateral.
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
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
	var pitches: Array = def["pitches"]
	var n := maxi(streams.size(), pitches.size())   # nº de variações: arquivos e/ou tons
	var v := 0
	if variant >= 0:
		v = variant % n
	else:
		v = int(_cycle[id]) % n
		_cycle[id] = v + 1
	var voice := _take_voice()
	voice.stream = streams[v % streams.size()]
	voice.pitch_scale = float(pitches[v % pitches.size()])   # sempre reposto: a voz é reaproveitada
	voice.volume_db = float(def["volume_db"])
	voice.play()

## Toca `id` numa ordem ALEATÓRIA sem repetição (shuffle bag): sorteia sem reposição de um "saco"
## com TODAS as variações; só quando todas tocaram o saco é reabastecido (embaralhado de novo). Na
## virada evita que a última do saco anterior seja a primeira do novo — nada toca duas vezes seguidas.
## Diferente de play(id, -1), que é rodízio fixo (0,1,2,…). Usa o RNG próprio (não perturba o run).
func play_random(id: String) -> void:
	if id == "":
		return
	if not _defs.has(id):
		push_warning("[Sfx] id desconhecido: '%s'" % id)
		return
	var def: Dictionary = _defs[id]
	var n := maxi((def["streams"] as Array).size(), (def["pitches"] as Array).size())
	if n <= 1:
		play(id, 0)   # 0 ou 1 variação: nada a sortear
		return
	var bag: Array = _bag.get(id, [])
	if bag.is_empty():
		bag = _refill_bag(id, n)
		_bag[id] = bag
	var v: int = bag.pop_back()
	_bag_last[id] = v
	play(id, v)

## Reabastece o saco: [0..n-1] embaralhado (Fisher-Yates com o RNG próprio). Se o TOPO (o próximo a
## sair, via pop_back) for igual à última tocada, troca-o com o começo — sem repetição na virada.
func _refill_bag(id: String, n: int) -> Array:
	var bag: Array = []
	for i in n:
		bag.append(i)
	for i in range(n - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: int = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	if _bag_last.has(id) and int(bag[n - 1]) == int(_bag_last[id]):
		var tmp2: int = bag[n - 1]
		bag[n - 1] = bag[0]
		bag[0] = tmp2
	return bag

## Toca UMA passada isolada do ciclo (a `index`-ésima, em rodízio), no TOM ORIGINAL — cortando-a
## antes da passada seguinte do arquivo. Serve para remontar a cadência livremente: a CORRIDA do
## ogro são as mesmas passadas da caminhada dele, só mais juntas. (Acelerar por `pitch` mudaria o
## tom junto; assim, muda só o ritmo.)
func play_step(id: String, index: int) -> void:
	if id == "" or not _defs.has(id):
		return
	var def: Dictionary = _defs[id]
	var n := step_count(id)
	if n <= 0:
		push_warning("[Sfx] '%s' não declara passadas (steps ou step_every)" % id)
		return
	var stream: AudioStream = def["streams"][0]
	var explicit: Array = def["steps"]
	var every := float(def["step_every"])
	var from := 0.0
	if not explicit.is_empty():
		from = float(explicit[posmod(index, n)])          # instantes avulsos, declarados um a um
	else:
		from = float(def["first_step"]) + float(posmod(index, n)) * every   # grade uniforme
	var dur := float(def["step_dur"])
	if dur <= 0.0:
		dur = every                          # sem medida: vai até onde a próxima passada começaria
	# O corte não pode passar do fim do clipe: o arquivo está em LOOP, a posição daria a volta e a
	# voz nunca chegaria no ponto de parada — ficaria tocando o ciclo inteiro, para sempre.
	var stop_pos := minf(from + dur, stream.get_length())

	var voice := _take_voice()
	voice.stream = stream
	voice.pitch_scale = 1.0
	voice.volume_db = float(def["volume_db"])
	voice.play(from)
	voice.set_meta("stop_pos", stop_pos)     # o _process a corta aqui (senão emendaria a próxima)
	voice.set_meta("last_pos", from)

## Quantas passadas o ciclo de `id` contém.
func step_count(id: String) -> int:
	var def: Dictionary = _defs.get(id, {})
	if def.is_empty():
		return 0
	var explicit: Array = def["steps"]
	if not explicit.is_empty():
		return explicit.size()
	var every := float(def["step_every"])
	if every <= 0.0:
		return 0
	var length: float = (def["streams"][0] as AudioStream).get_length()
	return maxi(1, floori((length - float(def["first_step"])) / every) + 1)

## Próxima voz do rodízio, limpa de qualquer corte agendado pelo uso anterior.
func _take_voice() -> AudioStreamPlayer:
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	if voice.has_meta("stop_pos"):
		voice.remove_meta("stop_pos")
	return voice

## Ciclo de passadas que NUNCA é cortado no meio de um passo. Chame todo frame com `active` = a
## condição vale (ex.: "está andando").
##
## O clipe é um CICLO em loop: uma passada a cada `step_every` segundos, a primeira em `first_step`
## (audio.json). Enquanto `active`, ele roda em loop. Quando deixa de valer, o som NÃO para na hora
## nem é cortado: segue até um ponto de SILÊNCIO — um triz antes da próxima passada — e só aí para.
## Assim a passada em curso soa inteira e nenhuma passada extra nasce. A espera é de no máximo um
## `step_every`, quase todo ele silêncio. Voltar a andar antes disso cancela a parada (sem emenda).
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
		p.bus = AudioSettings.SFX_BUS
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # ver nota em _ready (web/mp3 x Sample)
		add_child(p)
		st = { "player": p, "stop_at": -1.0, "last_pos": 0.0 }
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
		var pos := player.get_playback_position()
		st["last_pos"] = pos
		st["stop_at"] = _quiet_point(def, pos)

## Cama de ambiência em LOOP (vento, etc.): liga/desliga um som contínuo. Diferente de `sustain`
## (ciclo de passadas cortado num ponto de silêncio), aqui o clipe só faz LOOP. O fade é SÓ nas
## transições desta chamada (entrar/sair da área) — o loop em si recomeça sem corte, pois nenhuma
## chamada acontece na virada. Idempotente: ligar o que já toca (ou desligar o que já parou) é no-op.
## `fade` < 0 usa o AMBIENT_FADE padrão (transições de sala); um valor explícito o sobrescreve
## (ex.: um fade-in mais longo na ENTRADA do jogo, após o Play — ver floor_scene).
func ambient(id: String, on: bool, fade := -1.0) -> void:
	if id == "" or not _defs.has(id):
		return
	var f := fade if fade >= 0.0 else AMBIENT_FADE
	var st: Dictionary = _ambients.get(id, {})
	var def: Dictionary = _defs[id]
	if on:
		var player: AudioStreamPlayer
		if st.is_empty():
			player = AudioStreamPlayer.new()
			player.name = "Ambient_%s" % id
			player.bus = AudioSettings.AMBIENT_BUS   # categoria "Ambiente" nas Opções (não o SFX geral)
			player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # ver nota em _ready (web/mp3 x Sample)
			add_child(player)
			st = { "player": player, "tween": null }
			_ambients[id] = st
		player = st["player"]
		_kill_ambient_tween(st)
		if not player.playing:
			player.stream = def["streams"][0]
			player.volume_db = AMBIENT_SILENT_DB
			player.play()
		var tw_in := create_tween()
		tw_in.tween_property(player, "volume_db", float(def["volume_db"]), f)
		st["tween"] = tw_in
	else:
		if st.is_empty():
			return
		var player: AudioStreamPlayer = st["player"]
		if not player.playing:
			return
		_kill_ambient_tween(st)
		var tw_out := create_tween()
		tw_out.tween_property(player, "volume_db", AMBIENT_SILENT_DB, f)
		tw_out.tween_callback(player.stop)
		st["tween"] = tw_out

func _kill_ambient_tween(st: Dictionary) -> void:
	var tw = st.get("tween", null)
	if tw != null and (tw as Tween).is_valid():
		(tw as Tween).kill()
	st["tween"] = null

## Stream (1ª variação) e volume base de um id — para quem gere a PRÓPRIA voz (ex.: o som posicional
## por proximidade da fogueira, com o volume ajustado quadro a quadro). null / 0 se o id não existe.
func stream_for(id: String) -> AudioStream:
	var def: Dictionary = _defs.get(id, {})
	return (def["streams"][0] as AudioStream) if not def.is_empty() else null

func volume_for(id: String) -> float:
	var def: Dictionary = _defs.get(id, {})
	return float(def["volume_db"]) if not def.is_empty() else 0.0

## Corta NA HORA todos os ciclos sustentados (passos, corrida) e as camas de ambiência. Para a
## troca de cena (sair para o menu): nenhum loop do mundo deve seguir soando fora dele.
func stop_sustains() -> void:
	for id in _sustained:
		var st: Dictionary = _sustained[id]
		(st["player"] as AudioStreamPlayer).stop()
		st["stop_at"] = -1.0
	for id in _ambients:
		var amb: Dictionary = _ambients[id]
		_kill_ambient_tween(amb)
		(amb["player"] as AudioStreamPlayer).stop()

## Vigia as paradas agendadas: (a) as passadas isoladas de play_step, cortadas antes que a
## passada SEGUINTE do arquivo comece a soar; (b) os ciclos de sustain, no ponto de silêncio.
func _process(_delta: float) -> void:
	# Loops do MUNDO (passos do boss/player) não devem soar com o jogo PAUSADO: este autoload roda
	# sempre (PROCESS_MODE_ALWAYS), então um player sustentado seguiria tocando — o _process do dono
	# (ex.: o Ogro) está pausado e nunca chega a chamar sustain(false). Espelha o stream_paused no
	# estado da árvore; despausar retoma do mesmo ponto. (Ambiência/música seguem — são atmosfera.)
	var pausado := get_tree().paused
	if pausado != _world_paused:
		_world_paused = pausado
		for sid in _sustained:
			(_sustained[sid]["player"] as AudioStreamPlayer).stream_paused = pausado

	for voice in _voices:
		var v: AudioStreamPlayer = voice
		if not v.has_meta("stop_pos"):
			continue
		if not v.playing:
			v.remove_meta("stop_pos")
			continue
		var pos := v.get_playback_position()
		# Rede de segurança: se o clipe é em loop e a posição VOLTOU, a passada já acabou (e o
		# ponto de corte nunca chegaria). Corta aqui, senão a voz tocaria o ciclo inteiro.
		var deu_a_volta := pos < float(v.get_meta("last_pos")) - 0.001
		v.set_meta("last_pos", pos)
		if pos >= float(v.get_meta("stop_pos")) or deu_a_volta:
			v.stop()
			v.remove_meta("stop_pos")

	for id in _sustained:
		var st: Dictionary = _sustained[id]
		if float(st["stop_at"]) < 0.0:
			continue
		var player: AudioStreamPlayer = st["player"]
		var pos := player.get_playback_position()
		# O clipe está em loop: se a posição VOLTOU, ele deu a volta e já passou do ponto de
		# parada sem que a comparação abaixo pegasse. Parar aqui evita o som ficar preso pra sempre.
		var deu_a_volta := pos < float(st["last_pos"]) - 0.001
		st["last_pos"] = pos
		if not player.playing or pos >= float(st["stop_at"]) or deu_a_volta:
			player.stop()
			st["stop_at"] = -1.0

## Próximo instante do clipe em que dá para cortar sem picotar uma passada: um triz antes da
## passada seguinte. Se não há mais passada no clipe (ou não há grade), o ponto é o FIM dele — a
## emenda do loop, onde a última passada já se extinguiu. Esse fim nunca é "alcançado" pela posição
## (o loop dá a volta antes), e é o _process que o pega, pela volta — ver `deu_a_volta`.
func _quiet_point(def: Dictionary, pos: float) -> float:
	var length: float = (def["streams"][0] as AudioStream).get_length()
	var every := float(def["step_every"])
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

