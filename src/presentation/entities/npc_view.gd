## Um NPC parado no mundo, com quem se FALA (INTERAGIR, E). Só desenha e avisa; o que a conversa
## faz — dar o frasco, contar o tutorial — é decidido por quem escuta o sinal (o floor_scene).
##
## O primeiro é o Sir Big T., o cavaleiro sentado ao lado da primeira fogueira. Ele existe para que
## o Estus seja RECEBIDO de alguém em vez de o jogador já nascer com ele: um objeto que aparece
## sozinho no inventário é um item; um que alguém te entrega, no começo, é um marco.
class_name NpcView
extends Node2D

signal falado(npc: NpcView)

const REACH := 34.0

var npc_nome := ""
## Aparência: "cavaleiro" (padrão), "ferreiro", "mercador" ou "mestre". Placeholder de cor e
## adereço — a silhueta é a mesma; arte de verdade vem depois, como a dos inimigos.
var variante := "cavaleiro"
## Texto de prompt customizado (ex.: "E melhorar arma (120)"). Vazio = o padrão "falar com <nome>".
## Quem vende atualiza este texto quando o preço muda — o prompt é a vitrine.
var prompt_texto := ""
var _player: Node2D
var _prompt: Label
var _indicador: Label            # "?" dourado flutuante: aceso quando há algo novo para interagir
var _dica_t := 0.0

const DICA_Y := -86.0            # altura-base do "?" (acima da cabeça e do prompt); flutua em torno dela

func setup(x: float, chao_y: float, player: Node2D, nome: String, tipo := "cavaleiro") -> void:
	position = Vector2(x, chao_y)
	_player = player
	npc_nome = nome
	variante = tipo
	_build()

## Paleta por variante: [armadura/roupa clara, escura, manto/avental]. A cor é o que distingue
## os moradores do Downtown enquanto todos dividem o mesmo boneco.
const _PALETAS := {
	"cavaleiro": [Color(0.60, 0.64, 0.72), Color(0.38, 0.41, 0.48), Color(0.44, 0.16, 0.18)],
	"ferreiro": [Color(0.45, 0.38, 0.33), Color(0.30, 0.25, 0.21), Color(0.24, 0.20, 0.17)],
	"mercador": [Color(0.36, 0.30, 0.48), Color(0.26, 0.21, 0.36), Color(0.55, 0.44, 0.20)],
	"mestre": [Color(0.30, 0.38, 0.55), Color(0.22, 0.28, 0.42), Color(0.20, 0.25, 0.38)],
}

func _build() -> void:
	z_index = -1                 # à frente do chão, atrás do jogador

	var paleta: Array = _PALETAS.get(variante, _PALETAS["cavaleiro"])
	var aco: Color = paleta[0]
	var aco_esc: Color = paleta[1]
	var manto: Color = paleta[2]

	# Manto atrás dos ombros — é o que dá silhueta de cavaleiro em vez de "sujeito cinza".
	var capa := ColorRect.new()
	capa.color = manto
	capa.size = Vector2(20.0, 26.0)
	capa.position = Vector2(-10.0, -30.0)
	add_child(capa)

	# Tronco (peitoral) e pernas.
	var tronco := ColorRect.new()
	tronco.color = aco
	tronco.size = Vector2(14.0, 18.0)
	tronco.position = Vector2(-7.0, -30.0)
	add_child(tronco)
	var pernas := ColorRect.new()
	pernas.color = aco_esc
	pernas.size = Vector2(12.0, 12.0)
	pernas.position = Vector2(-6.0, -12.0)
	add_child(pernas)

	# Cabeça: o cavaleiro usa elmo fechado com viseira e pluma; os civis, cabeça nua (a fresta
	# escura da viseira é o que lê como armadura — num civil leria como máscara).
	if variante == "cavaleiro":
		var elmo := ColorRect.new()
		elmo.color = aco
		elmo.size = Vector2(12.0, 11.0)
		elmo.position = Vector2(-6.0, -41.0)
		add_child(elmo)
		var viseira := ColorRect.new()
		viseira.color = Color(0.10, 0.10, 0.13)
		viseira.size = Vector2(10.0, 3.0)
		viseira.position = Vector2(-5.0, -37.0)
		add_child(viseira)
		var pluma := ColorRect.new()
		pluma.color = manto.lightened(0.15)
		pluma.size = Vector2(4.0, 6.0)
		pluma.position = Vector2(-2.0, -47.0)
		add_child(pluma)
	else:
		var cabeca := ColorRect.new()
		cabeca.color = Color(0.80, 0.65, 0.52)
		cabeca.size = Vector2(10.0, 10.0)
		cabeca.position = Vector2(-5.0, -40.0)
		add_child(cabeca)
		var cabelo := ColorRect.new()
		cabelo.color = aco_esc.darkened(0.3)
		cabelo.size = Vector2(12.0, 4.0)
		cabelo.position = Vector2(-6.0, -43.0)
		add_child(cabelo)

	# O adereço ao lado é o OFÍCIO: espadão fincado (cavaleiro em descanso), martelo apoiado na
	# bigorna (ferreiro), saco de mercadorias (mercador), cajado (mestre).
	match variante:
		"ferreiro":
			var bigorna := ColorRect.new()
			bigorna.color = Color(0.30, 0.32, 0.36)
			bigorna.size = Vector2(16.0, 7.0)
			bigorna.position = Vector2(8.0, -7.0)
			add_child(bigorna)
			var cabo := ColorRect.new()
			cabo.color = Color(0.48, 0.35, 0.24)
			cabo.size = Vector2(3.0, 18.0)
			cabo.position = Vector2(13.0, -25.0)
			add_child(cabo)
			var cabeca_m := ColorRect.new()
			cabeca_m.color = Color(0.55, 0.58, 0.64)
			cabeca_m.size = Vector2(10.0, 6.0)
			cabeca_m.position = Vector2(10.0, -29.0)
			add_child(cabeca_m)
		"mercador":
			var saco := ColorRect.new()
			saco.color = Color(0.62, 0.52, 0.34)
			saco.size = Vector2(14.0, 16.0)
			saco.position = Vector2(9.0, -16.0)
			add_child(saco)
			var no := ColorRect.new()
			no.color = Color(0.45, 0.37, 0.24)
			no.size = Vector2(6.0, 4.0)
			no.position = Vector2(13.0, -19.0)
			add_child(no)
		"mestre":
			var cajado := ColorRect.new()
			cajado.color = Color(0.48, 0.35, 0.24)
			cajado.size = Vector2(3.0, 42.0)
			cajado.position = Vector2(10.0, -42.0)
			add_child(cajado)
			var gema := ColorRect.new()
			gema.color = Color(0.45, 0.70, 0.95)
			gema.size = Vector2(7.0, 7.0)
			gema.position = Vector2(8.0, -47.0)
			add_child(gema)
		_:
			var lamina := ColorRect.new()
			lamina.color = Color(0.72, 0.76, 0.84)
			lamina.size = Vector2(3.0, 30.0)
			lamina.position = Vector2(9.0, -30.0)
			add_child(lamina)
			var guarda := ColorRect.new()
			guarda.color = aco_esc
			guarda.size = Vector2(11.0, 3.0)
			guarda.position = Vector2(5.0, -30.0)
			add_child(guarda)

	_prompt = Label.new()
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(200.0, 18.0)
	_prompt.position = Vector2(-100.0, -66.0)
	_prompt.visible = false
	add_child(_prompt)

	# "?" dourado flutuante acima da cabeça (quest marker). Ligado por quem escuta (set_indicador);
	# o contorno escuro o destaca sobre qualquer fundo. A fonte é TTF nítida — 24 sai crisp.
	_indicador = Label.new()
	_indicador.text = "?"
	_indicador.add_theme_font_size_override("font_size", 24)
	_indicador.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))   # dourado
	_indicador.add_theme_constant_override("outline_size", 5)
	_indicador.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.0))
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador.size = Vector2(30.0, 28.0)
	_indicador.position = Vector2(-15.0, DICA_Y)
	_indicador.visible = false
	add_child(_indicador)

func _process(delta: float) -> void:
	# "?" flutuando de leve (bob por seno) enquanto aceso — chama atenção sem timer nem RNG.
	if _indicador != null and _indicador.visible:
		_dica_t += delta
		_indicador.position.y = DICA_Y + sin(_dica_t * 3.2) * 3.0

	if _prompt == null:
		return
	_prompt.visible = in_reach(_player)
	if prompt_texto != "":
		_prompt.text = "%s  %s" % [KeyBinds.key_name("interact"), prompt_texto]
	else:
		_prompt.text = "%s  falar com %s" % [KeyBinds.key_name("interact"), npc_nome]

## Liga/desliga o "?" dourado. Quem escuta decide (ex.: há falas base do cavaleiro por ler).
func set_indicador(on: bool) -> void:
	if _indicador != null:
		_indicador.visible = on

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

func falar() -> void:
	falado.emit(self)
