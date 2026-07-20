## Escada: o único jeito de subir a uma estrutura elevada. Só desenha e responde "estou nesta
## faixa?" — quem escala é o PlayerView (ver _update_ladder), como em toda a apresentação daqui.
##
## Ela existe porque o jogo é de chão contínuo plano: sem escada, o único acesso vertical seria o
## pulo, e um pulo alcança qualquer lugar sem pedir nada em troca. A escada é uma decisão — subir
## custa tempo e tira do jogador a esquiva e o ataque, então uma plataforma com escada é um lugar
## que se ESCOLHE ocupar, e do qual não se sai correndo.
class_name LadderView
extends Node2D

const WIDTH := 18.0              # largura útil (base 640×360): o quanto se pode estar fora do eixo
const RUNG_GAP := 9.0            # espaçamento dos degraus

var altura := 0.0                # do chão até o topo da plataforma
var _topo_y := 0.0               # y do topo (onde se sai para a plataforma)
var _saida_x := 0.0              # onde o corpo é posto ao chegar no topo (em cima do tabuleiro)
var _player: Node2D
var _prompt: Label
var em_uso := false              # o floor_scene/PlayerView avisa: escondendo o convite enquanto escala

## `saida_x` = para onde o jogador escorrega ao terminar a subida. A escada fica encostada na
## BORDA de fora da plataforma (senão o tabuleiro barraria a subida por baixo), então chegar ao
## topo tem de deslocá-lo alguns px para dentro — sem isso ele terminaria a subida no ar,
## agarrado à borda, e cairia de volta.
func setup(x: float, chao_y: float, h: float, saida_x := 0.0, player: Node2D = null) -> void:
	position = Vector2(x, chao_y)
	altura = h
	_topo_y = chao_y - h
	_saida_x = saida_x if saida_x != 0.0 else x
	_player = player
	_build()

func saida_x() -> float:
	return _saida_x

func _build() -> void:
	z_index = -2                 # à frente do chão, atrás das entidades

	# Dois montantes verticais + degraus. Madeira clara para destacar da pedra da torre: a escada
	# precisa ser LIDA de longe, senão a torre parece só um bloco intransponível.
	for lado in [-1.0, 1.0]:
		var m := ColorRect.new()
		m.color = Color(0.52, 0.38, 0.24)
		m.size = Vector2(3.0, altura)
		m.position = Vector2(lado * (WIDTH * 0.5) - (0.0 if lado < 0.0 else 3.0), -altura)
		add_child(m)

	# O convite na BASE. Sem ele a escada é só cenário de madeira — o jogador não tem como saber
	# que aquilo é usável, muito menos com qual tecla.
	_prompt = Label.new()
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(180.0, 18.0)
	_prompt.position = Vector2(-90.0, -22.0)
	_prompt.visible = false
	add_child(_prompt)

	var n := int(altura / RUNG_GAP)
	for i in n:
		var d := ColorRect.new()
		d.color = Color(0.62, 0.46, 0.30)
		d.size = Vector2(WIDTH, 2.0)
		d.position = Vector2(-WIDTH * 0.5, -altura + i * RUNG_GAP + 4.0)
		add_child(d)

func _process(_delta: float) -> void:
	if _prompt == null:
		return
	# Só na BASE e só fora de uso: quem já está escalando não precisa do convite, e quem está lá
	# em cima também não.
	_prompt.visible = not em_uso and _na_base(_player)
	_prompt.text = "%s  escalar" % KeyBinds.key_name("interact")

func _na_base(player: Node2D) -> bool:
	if not is_instance_valid(player):
		return false
	if absf(player.global_position.x - global_position.x) > WIDTH * 0.5 + 8.0:
		return false
	return absf(player.global_position.y - global_position.y) <= 46.0

## O corpo está na escada? Testa a faixa horizontal e a vertical (do chão ao topo, com folga em
## cima para ainda "agarrar" quem está pisando na plataforma e quer descer).
func contem(pos: Vector2) -> bool:
	if absf(pos.x - global_position.x) > WIDTH * 0.5 + 4.0:
		return false
	return pos.y <= global_position.y + 4.0 and pos.y >= _topo_y - 20.0

## Altura do topo (y do mundo): quem sobe até aqui já pode pisar na plataforma.
func topo_y() -> float:
	return _topo_y

## Alinha o corpo ao eixo da escada — subir de lado faria o player raspar na parede da torre.
func eixo_x() -> float:
	return global_position.x
