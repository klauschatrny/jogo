## Câmera com screen shake baseado em "trauma" (§2.4 Fase 5.2). add_trauma() acumula; o
## tremor decai sozinho e usa trauma² para um falloff mais natural. Sem trauma, fica parada.
class_name GameCamera
extends Camera2D

const DECAY := 1.6                         # quão rápido o trauma some (por segundo)
const MAX_OFFSET := Vector2(9.0, 7.0)     # deslocamento máximo do tremor (px) (base 640×360)
const MAX_ROLL := 0.04                     # rotação máxima do tremor (rad)
const FOLLOW_LERP := 8.0                   # suavidade do follow horizontal
const LOOK_AHEAD := 72.0                    # avanço da câmera à frente do player (px, base 640×360)
const LOOK_AHEAD_LERP := 2.4               # suavidade com que o avanço cresce/inverte de lado
const LOOK_MIN_SPEED := 8.0                # velocidade mínima p/ empurrar (evita jitter parado)
const SCREEN_H := 360.0                    # altura do viewport base 640×360

var _trauma := 0.0
var follow_target: Node2D                  # segue este nó no eixo X (o PlayerView)
var _base_y := SCREEN_H * 0.5              # Y fixo: corredor é plano, câmera só anda em X
var _look := 0.0                           # avanço horizontal atual, já suavizado
var _follow_y := false                     # escadaria: a câmera também sobe com o player
const CLIMB_Y_BIAS := 30.0                 # olha um pouco ACIMA do player: subindo, o que importa vem de cima

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## Configura os limites do corredor: a câmera não revela além das bordas. O range
## vertical = altura da tela trava o Y (corredor plano, sem rolagem vertical).
func setup_corridor(length: float) -> void:
	limit_left = 0
	limit_right = int(length)
	limit_top = 0
	limit_bottom = int(SCREEN_H)
	_follow_y = false

## Escadaria (nível vertical): o teto sobe até `top_limit` (y do mundo, negativo = acima da tela
## base) e a câmera passa a seguir o player também no Y. Os limit_* seguram a vista nas bordas,
## então no chão a tela é idêntica à do corredor — a rolagem só aparece quando se sobe.
func setup_climb(length: float, top_limit: float) -> void:
	limit_left = 0
	limit_right = int(length)
	limit_top = int(top_limit)
	limit_bottom = int(SCREEN_H)
	_follow_y = true

func _process(delta: float) -> void:
	# Follow horizontal suave, empurrado à frente do player na direção do movimento.
	# O look-ahead corrige o "atraso" da suavização, mantendo à vista o que vem pela frente.
	# Y travado. Os limit_* clampam a vista nas bordas do corredor.
	if follow_target != null and is_instance_valid(follow_target):
		var vx := 0.0
		if follow_target is CharacterBody2D:
			vx = (follow_target as CharacterBody2D).velocity.x
		var want := signf(vx) * LOOK_AHEAD if absf(vx) > LOOK_MIN_SPEED else 0.0
		_look = lerpf(_look, want, 1.0 - exp(-LOOK_AHEAD_LERP * delta))
		var target_x := follow_target.global_position.x + _look
		var t := 1.0 - exp(-FOLLOW_LERP * delta)
		global_position.x = lerpf(global_position.x, target_x, t)
		if _follow_y:
			# Sobe/desce com o player (suavizado); os limit_* clampam a vista, então no chão
			# nada muda — a rolagem vertical só existe onde o teto foi aberto (setup_climb).
			global_position.y = lerpf(global_position.y,
				follow_target.global_position.y - CLIMB_Y_BIAS, t)
		else:
			global_position.y = _base_y

	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	offset = Vector2(
		randf_range(-1.0, 1.0) * MAX_OFFSET.x,
		randf_range(-1.0, 1.0) * MAX_OFFSET.y) * shake
	rotation = randf_range(-1.0, 1.0) * MAX_ROLL * shake
