## Fogueira (checkpoint soulslike). Apagada até você chegar perto e apertar INTERAGIR (E, padrão):
## aí ela acende, cura por completo e passa a ser o ponto de retorno da sua morte.
##
## Uma vez acesa, fica acesa — inclusive depois de morrer. Descansar de novo numa fogueira já
## acesa só refaz a cura e move o ponto de retorno para ela.
##
## A brasa pisca por seno (sem timer nem RNG): é presentation pura. O ESTADO (qual fogueira está
## acesa, qual é o checkpoint) vive no RunState, não aqui — este nó só desenha e avisa.
class_name BonfireView
extends Node2D

signal rested(bonfire: BonfireView)

const REACH := 42.0              # distância para poder descansar (base 640×360)
const W := 20.0                  # largura da pilha de lenha
const FLAME_H := 16.0

# Som do fogo por PROXIMIDADE: o crepitar (audio.json "campfire") sobe conforme o player se
# aproxima. Voz própria (não passa pelo Sfx.play) porque o volume é ajustado a cada frame.
const FIRE_SFX := "campfire"     # id em data/audio.json
const FIRE_SFX_REACH := 240.0    # a partir daqui já se ouve; encostado = volume cheio (do JSON)
const FIRE_SFX_SILENT_DB := -40.0  # praticamente mudo no limite do alcance

var pos_x := 0.0                 # x no nível (id da fogueira, junto com o andar)
var lit := false
## Fogueira DECORATIVA (a do Downtown): só marca o ponto de renascimento — sempre acesa, sem
## prompt e sem função. Descanso/cura/menu são da fogueira-checkpoint, que está fora do loop.
var decorativa := false

var _player: Node2D
var _flame: ColorRect
var _core: ColorRect
var _glow: ColorRect
var _prompt: Label
var _t := 0.0
var _fire_audio: AudioStreamPlayer   # crepitar por proximidade (só acesa)
var _fire_base_db := 0.0             # volume ao encostar (de audio.json)

func setup(x: float, already_lit: bool, player: Node2D) -> void:
	pos_x = x
	lit = already_lit
	_player = player
	# SÓ o x. O y é a linha do chão e quem instancia já o definiu — sobrescrevê-lo aqui (era
	# `position = Vector2(x, 0.0)`) jogava a fogueira 300px acima do solo, fora do topo da tela.
	# Não dava erro nenhum: in_reach() compara apenas o x, então dava para descansar numa fogueira
	# que ninguém via.
	position.x = x
	_build()
	_refresh()

## O desenho tem de se ler APAGADA — senão a fogueira vira um enigma: você precisaria encontrar
## uma coisa invisível para poder acendê-la. Por isso a silhueta forte (cinzas + lenha + a espada
## fincada, o símbolo do gênero) existe sempre; a chama e o halo é que só entram ao acender.
func _build() -> void:
	z_index = -3                  # à frente do chão, atrás das entidades

	# Halo: brilho fraco em volta da chama (só aceso). Fica justo nela — um halo largo demais
	# lava a cor do cenário ao redor em vez de sugerir uma luz.
	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.55, 0.15, 0.11)
	_glow.size = Vector2(W * 2.0, W * 2.0)
	_glow.position = Vector2(-W, -W * 1.7)
	add_child(_glow)

	# Monte de cinzas: base clara, que destaca a fogueira do chão escuro mesmo apagada.
	var ash := ColorRect.new()
	ash.color = Color(0.62, 0.60, 0.58)
	ash.size = Vector2(W + 8.0, 4.0)
	ash.position = Vector2(-(W + 8.0) * 0.5, -4.0)
	add_child(ash)

	# Lenha: duas achas cruzadas sobre as cinzas.
	for i in 2:
		var log_rect := ColorRect.new()
		log_rect.color = Color(0.45, 0.32, 0.22)
		log_rect.size = Vector2(W, 4.0)
		log_rect.position = Vector2(-W * 0.5, -8.0)
		log_rect.pivot_offset = Vector2(W * 0.5, 2.0)
		log_rect.rotation = deg_to_rad(16.0 if i == 0 else -16.0)
		add_child(log_rect)

	# A espada fincada nas cinzas: aço claro, alta o bastante para ser vista de longe. É ELA que
	# diz "aqui tem uma fogueira" antes de qualquer chama existir.
	var blade := ColorRect.new()
	blade.color = Color(0.72, 0.75, 0.82)
	blade.size = Vector2(3.0, 26.0)
	blade.position = Vector2(-1.5, -30.0)
	add_child(blade)
	var guard := ColorRect.new()
	guard.color = Color(0.55, 0.57, 0.63)
	guard.size = Vector2(11.0, 2.0)
	guard.position = Vector2(-5.5, -26.0)
	add_child(guard)

	# Chama: corpo alaranjado com um núcleo claro dentro (só acesa).
	_flame = ColorRect.new()
	_flame.color = Color(0.95, 0.45, 0.12)
	add_child(_flame)
	_core = ColorRect.new()
	_core.color = Color(1.0, 0.86, 0.45)
	add_child(_core)

	_prompt = Label.new()
	# fonte 16 (nativa da bitmap — menor sai ilegível); caixa larga para caber "X  descansar"
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(160.0, 18.0)
	_prompt.position = Vector2(-80.0, -54.0)
	_prompt.visible = false
	add_child(_prompt)

	# Crepitar por proximidade: voz própria (o volume muda a cada frame — ver _update_fire_audio).
	_fire_audio = AudioStreamPlayer.new()
	_fire_audio.bus = AudioSettings.AMBIENT_BUS   # categoria "Ambiente" nas Opções (não o SFX geral)
	_fire_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # web/mp3: "Stream" toca, "Sample" sai mudo
	var st := Sfx.stream_for(FIRE_SFX)
	if st != null:
		if "loop" in st:
			st.set("loop", true)   # cama contínua: o loop é do recurso, não do player
		_fire_audio.stream = st
		_fire_base_db = Sfx.volume_for(FIRE_SFX)
	add_child(_fire_audio)

func _process(delta: float) -> void:
	_t += delta
	_refresh()
	_update_fire_audio()

	# O aviso só aparece quando dá para descansar de fato. Apagada, ele CONVIDA ("acender");
	# acesa, oferece o que ela faz. A decorativa nunca oferece nada — prometer descanso que não
	# existe é pior do que não prometer.
	if decorativa:
		if _prompt != null:
			_prompt.visible = false
		return
	if _prompt != null and is_instance_valid(_player):
		_prompt.visible = absf(_player.global_position.x - global_position.x) <= REACH
		var k: String = KeyBinds.key_name("interact")
		_prompt.text = ("%s  descansar" if lit else "%s  acender") % k

func _refresh() -> void:
	if _flame == null:
		return
	if not lit:
		_flame.visible = false
		_core.visible = false
		_glow.visible = false
		return
	_flame.visible = true
	_core.visible = true
	_glow.visible = true

	# Bruxuleio: duas senoides de períodos diferentes, para não parecer um pulso metronômico.
	var flick := 1.0 + 0.12 * sin(_t * 9.0) + 0.06 * sin(_t * 21.0)
	var h := FLAME_H * flick
	_flame.size = Vector2(9.0, h)
	_flame.position = Vector2(-4.5, -h - 3.0)
	_core.size = Vector2(3.0, h * 0.5)
	_core.position = Vector2(-1.5, -h * 0.5 - 4.0)
	_glow.modulate.a = 0.75 + 0.25 * sin(_t * 6.0)

## Crepitar por proximidade: toca só ACESA; o volume interpola do silêncio (no limite do alcance)
## ao volume cheio (encostado), pela distância horizontal até o player. Apagada = muda.
func _update_fire_audio() -> void:
	if _fire_audio == null or _fire_audio.stream == null:
		return
	if not lit:
		if _fire_audio.playing:
			_fire_audio.stop()
		return
	if not _fire_audio.playing:
		_fire_audio.play()
	if not is_instance_valid(_player):
		_fire_audio.volume_db = FIRE_SFX_SILENT_DB
		return
	var d := absf(_player.global_position.x - global_position.x)
	var t := clampf(1.0 - d / FIRE_SFX_REACH, 0.0, 1.0)   # 1 encostado, 0 no limite do alcance
	_fire_audio.volume_db = lerpf(FIRE_SFX_SILENT_DB, _fire_base_db, t)

## Dá para descansar agora? (perto o bastante)
func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

## Acende (se preciso) e avisa quem escuta. Quem cuida da cura/checkpoint é o RunState.
func rest() -> void:
	lit = true
	_refresh()
	rested.emit(self)
