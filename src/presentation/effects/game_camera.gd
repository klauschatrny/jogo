## Câmera com screen shake baseado em "trauma" (§2.4 Fase 5.2). add_trauma() acumula; o
## tremor decai sozinho e usa trauma² para um falloff mais natural. Sem trauma, fica parada.
class_name GameCamera
extends Camera2D

const DECAY := 1.6                         # quão rápido o trauma some (por segundo)
const MAX_OFFSET := Vector2(27.0, 21.0)     # deslocamento máximo do tremor (px) (= 9/7 × 3)
const MAX_ROLL := 0.04                     # rotação máxima do tremor (rad)
const FOLLOW_LERP := 8.0                   # suavidade do follow horizontal
const SCREEN_H := 1080.0                    # (= 360 × 3, viewport 1920×1080)

var _trauma := 0.0
var follow_target: Node2D                  # segue este nó no eixo X (o PlayerView)
var _base_y := SCREEN_H * 0.5              # Y fixo: corredor é plano, câmera só anda em X

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## Configura os limites do corredor: a câmera não revela além das bordas. O range
## vertical = altura da tela trava o Y (corredor plano, sem rolagem vertical).
func setup_corridor(length: float) -> void:
	limit_left = 0
	limit_right = int(length)
	limit_top = 0
	limit_bottom = int(SCREEN_H)

func _process(delta: float) -> void:
	# Follow horizontal suave; Y travado. Os limit_* clampam a vista nas bordas do corredor.
	if follow_target != null and is_instance_valid(follow_target):
		var t := 1.0 - exp(-FOLLOW_LERP * delta)
		global_position.x = lerpf(global_position.x, follow_target.global_position.x, t)
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
