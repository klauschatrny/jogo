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
var _player: Node2D
var _prompt: Label

func setup(x: float, chao_y: float, player: Node2D, nome: String) -> void:
	position = Vector2(x, chao_y)
	_player = player
	npc_nome = nome
	_build()

func _build() -> void:
	z_index = -1                 # à frente do chão, atrás do jogador

	var aco := Color(0.60, 0.64, 0.72)
	var aco_esc := Color(0.38, 0.41, 0.48)
	var manto := Color(0.44, 0.16, 0.18)

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

	# Elmo com viseira: a fresta escura é o detalhe que lê como armadura fechada.
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

	# Espadão fincado no chão ao lado — ele está descansando, não de guarda.
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

func _process(_delta: float) -> void:
	if _prompt == null:
		return
	_prompt.visible = in_reach(_player)
	_prompt.text = "%s  falar com %s" % [KeyBinds.key_name("interact"), npc_nome]

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

func falar() -> void:
	falado.emit(self)
