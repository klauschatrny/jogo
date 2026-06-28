## Câmera com screen shake baseado em "trauma" (§2.4 Fase 5.2). add_trauma() acumula; o
## tremor decai sozinho e usa trauma² para um falloff mais natural. Sem trauma, fica parada.
class_name GameCamera
extends Camera2D

const DECAY := 1.6                         # quão rápido o trauma some (por segundo)
const MAX_OFFSET := Vector2(9.0, 7.0)      # deslocamento máximo do tremor (px)
const MAX_ROLL := 0.04                     # rotação máxima do tremor (rad)

var _trauma := 0.0

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
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
