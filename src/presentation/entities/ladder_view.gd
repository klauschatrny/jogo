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
## Quanto se pode estar fora do eixo e ainda contar como "na escada". Precisa cobrir o
## deslocamento da saída no topo: quem sobe por um alçapão sai AO LADO do buraco (senão cairia
## por ele), e sem essa folga não conseguiria remontar para descer — ficaria preso lá em cima.
var tolerancia_x := WIDTH * 0.5 + 14.0

## `saida_x` = para onde o jogador escorrega ao terminar a subida. A escada fica encostada na
## BORDA de fora da plataforma (senão o tabuleiro barraria a subida por baixo), então chegar ao
## topo tem de deslocá-lo alguns px para dentro — sem isso ele terminaria a subida no ar,
## agarrado à borda, e cairia de volta.
func setup(x: float, chao_y: float, h: float, saida_x := 0.0, player: Node2D = null, tol_x := 0.0) -> void:
	if tol_x > 0.0:
		tolerancia_x = tol_x
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
	# O convite também respeita os pés no chão: prometer "escalar" a quem está no ar seria
	# prometer uma ação que não acontece.
	_prompt.visible = not em_uso and _na_base(_player) and _player_apoiado()
	_prompt.text = "%s  escalar" % KeyBinds.key_name("interact")

func _player_apoiado() -> bool:
	return is_instance_valid(_player) and _player.has_method("is_on_floor") and _player.is_on_floor()

func _na_base(player: Node2D) -> bool:
	if not is_instance_valid(player):
		return false
	if absf(player.global_position.x - global_position.x) > WIDTH * 0.5 + 8.0:
		return false
	return absf(player.global_position.y - global_position.y) <= 46.0

## O corpo está na escada? Testa a faixa horizontal e a vertical (do chão ao topo, com folga em
## cima para ainda "agarrar" quem está pisando na plataforma e quer descer).
func contem(pos: Vector2) -> bool:
	# Tolerância generosa em X: no topo o jogador sai da escada ao LADO do alçapão (senão cairia
	# de volta pelo buraco), e precisa continuar contando como "na escada" para poder descer.
	if absf(pos.x - global_position.x) > tolerancia_x:
		return false
	# A folga para CIMA precisa caber um corpo DE PÉ sobre o tabuleiro: quem terminou a subida
	# tem o centro acima do topo (a altura dele inteiro), e sem essa folga não conseguiria
	# remontar a escada para descer — subiria e ficaria preso lá em cima.
	return pos.y <= global_position.y + 4.0 and pos.y >= _topo_y - 44.0

## Altura do topo (y do mundo): quem sobe até aqui já pode pisar na plataforma.
func topo_y() -> float:
	return _topo_y

## Alinha o corpo ao eixo da escada — subir de lado faria o player raspar na parede da torre.
func eixo_x() -> float:
	return global_position.x
