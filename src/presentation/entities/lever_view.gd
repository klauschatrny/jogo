## Alavanca de madeira. Fica SEMPRE no lugar (mesmo com o Necromante vivo), mas só FUNCIONA depois
## que ele cai — até lá está "travada" (sem convite, e puxá-la não faz nada). Puxá-la (INTERAGIR,
## E/F) abre o portão que fechava a passagem; puxada uma vez, fica puxada. Só desenha e avisa —
## quem abre o portão e persiste o estado é o floor_scene/RunState.
class_name LeverView
extends Node2D

signal pulled(lever: LeverView)

const REACH := 40.0              # distância para puxar (base 640×360)

var _player: Node2D
var _handle: ColorRect
var _prompt: Label
var _is_pulled := false
var _armed := false             # só destrava quando o Necromante cai (nível vencido)

func setup(x: float, player: Node2D, already_pulled := false, armed := false) -> void:
	position.x = x
	_player = player
	_is_pulled = already_pulled
	_armed = armed
	_build()
	if _is_pulled:
		_handle.rotation = deg_to_rad(50.0)

func _build() -> void:
	z_index = -2                 # à frente do chão, à frente do portão, atrás das entidades

	# Base de pedra fincada no chão.
	var base := ColorRect.new()
	base.color = Color(0.30, 0.30, 0.34)
	base.size = Vector2(14.0, 10.0)
	base.position = Vector2(-7.0, -10.0)
	add_child(base)

	# A haste da alavanca, com o punho (bola) na ponta. Pivô na base, inclinada; ao puxar, tomba.
	_handle = ColorRect.new()
	_handle.color = Color(0.45, 0.32, 0.20)
	_handle.size = Vector2(4.0, 30.0)
	_handle.pivot_offset = Vector2(2.0, 30.0)          # gira em torno da base
	_handle.position = Vector2(-2.0, -40.0)
	_handle.rotation = deg_to_rad(-30.0)               # começa levantada para um lado
	add_child(_handle)
	var knob := ColorRect.new()
	knob.color = Color(0.74, 0.77, 0.82)               # punho metálico (aço claro), não vermelho
	knob.size = Vector2(9.0, 9.0)
	knob.position = Vector2(-2.5, -4.0)                 # topo da haste (segue a rotação do pai)
	_handle.add_child(knob)
	# Brilho metálico: um reflexo claro no canto do punho.
	var shine := ColorRect.new()
	shine.color = Color(0.92, 0.94, 0.98)
	shine.size = Vector2(3.0, 3.0)
	shine.position = Vector2(0.5, 1.0)
	knob.add_child(shine)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(90.0, 10.0)
	_prompt.position = Vector2(-45.0, -58.0)
	_prompt.visible = false
	add_child(_prompt)

func _process(_delta: float) -> void:
	if _prompt == null:
		return
	# O convite só aparece com a alavanca destravada (Necromante morto) — antes disso ela é só
	# cenário, para não prometer uma ação que ainda não funciona.
	_prompt.visible = _armed and not _is_pulled and in_reach(_player)
	_prompt.text = "E  abrir portão"

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

## Destrava a alavanca (o Necromante caiu): a partir daqui ela pode ser puxada.
func arm() -> void:
	_armed = true

func is_armed() -> bool:
	return _armed

## Puxa a alavanca: tomba a haste, esconde o aviso e avisa quem escuta (uma vez só). Travada, é no-op.
func pull() -> void:
	if _is_pulled or not _armed:
		return
	_is_pulled = true
	var tw := create_tween()
	tw.tween_property(_handle, "rotation", deg_to_rad(50.0), 0.25).set_trans(Tween.TRANS_BACK)
	pulled.emit(self)

func is_pulled() -> bool:
	return _is_pulled
