## Portão de madeira (barreira de mecanismo). Fechado, é uma parede sólida (StaticBody2D na
## camada 4) que barra player E inimigos. Uma alavanca o abre; aberto, fica aberto para sempre —
## a colisão some e as tábuas sobem para fora do vão. O ESTADO (aberto ou não) vive no RunState;
## este nó só desenha e trava/destrava a passagem.
class_name GateView
extends Node2D

const W := 34.0                  # largura padrão do vão (base 640×360)
const H := 92.0                  # altura padrão das tábuas

# Tamanho REAL deste portão (setup pode ampliar). O portão da cidade é grande de propósito: ele
# não é um mecanismo qualquer, é a saída de um lugar — e o tamanho é o que diz isso sem texto.
var w := W
var h := H

var _body: StaticBody2D
var _planks: Node2D              # as tábuas (somem ao abrir)
var _open := false

## `x` = posição no corredor; `already_open` = já foi aberto nesta run (persistido no RunState).
func setup(x: float, already_open: bool, largura := W, altura := H) -> void:
	position.x = x
	w = largura
	h = altura
	_build()
	if already_open:
		open(false)              # sem animação: já nasce aberto

func _build() -> void:
	z_index = -3                 # à frente do chão, atrás das entidades

	# Umbrais de pedra dos dois lados (ficam mesmo com o portão aberto — emolduram a passagem).
	for side in [-1.0, 1.0]:
		var jamb := ColorRect.new()
		jamb.color = Color(0.24, 0.22, 0.26)
		jamb.size = Vector2(6.0, h + 8.0)
		jamb.position = Vector2(side * (w * 0.5) - (0.0 if side < 0 else 6.0), -h - 8.0)
		add_child(jamb)

	# Barreira sólida: só existe fechada. Camada 4 = a mesma do chão/paredes, então player e
	# inimigos esbarram nela.
	_body = StaticBody2D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h + 40.0)
	col.shape = rect
	col.position = Vector2(0.0, -h * 0.5)
	_body.add_child(col)
	add_child(_body)

	# Tábuas verticais preenchendo o vão + duas travessas na diagonal (cara de portão de madeira).
	_planks = Node2D.new()
	add_child(_planks)
	var n := 4
	var pw := (w - 4.0) / float(n)
	for i in n:
		var plank := ColorRect.new()
		plank.color = Color(0.40, 0.28, 0.17) if i % 2 == 0 else Color(0.34, 0.23, 0.14)
		plank.size = Vector2(pw - 1.0, h)
		plank.position = Vector2(-w * 0.5 + 2.0 + i * pw, -h)
		_planks.add_child(plank)
	for k in 2:
		var brace := ColorRect.new()
		brace.color = Color(0.22, 0.15, 0.09)
		brace.size = Vector2(w - 4.0, 5.0)
		brace.pivot_offset = Vector2((w - 4.0) * 0.5, 2.5)
		brace.position = Vector2(-w * 0.5 + 2.0, -h * 0.66 + k * (h * 0.4))
		brace.rotation = deg_to_rad(10.0 if k == 0 else -10.0)
		_planks.add_child(brace)

## Abre o portão: destrava a passagem (colisão off) e tira as tábuas do vão. `animate` sobe as
## tábuas num tween; sem ele (carregando um portão já aberto), some na hora.
func open(animate := true) -> void:
	if _open:
		return
	_open = true
	# Desliga a colisão no próximo passo ocioso (mexer em física dentro de um callback é arriscado).
	_body.set_deferred("collision_layer", 0)
	if animate:
		var tw := create_tween()
		tw.tween_property(_planks, "position:y", -h - 12.0, 0.5).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(_planks, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_planks.hide)
	else:
		_planks.hide()

func is_open() -> bool:
	return _open
