## Projétil do Necromante. Move em linha reta na direção capturada ao disparar e atinge
## SOMENTE o player (checa distância ao alvo; ignora os outros inimigos — não tem colisão física).
## Fica na camada visual mais alta (z alto), junto com o necromante.
class_name NecroProjectile
extends Node2D

const HIT_RADIUS := 12.0
const LIFETIME := 5.0
const TOP_Z := 300

var _vel := Vector2.ZERO
var _stats: StatBlock
var _target: Node2D
var _life := LIFETIME

func setup(dir: Vector2, speed: float, stats: StatBlock, target: Node2D) -> void:
	_vel = dir.normalized() * speed
	_stats = stats
	_target = target

func _ready() -> void:
	z_index = TOP_Z
	var r := ColorRect.new()
	r.color = Palette.BOSS       # roxo do necromante
	r.size = Vector2(6, 6)
	r.position = Vector2(-3, -3)
	add_child(r)

func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Atinge SOMENTE o player: checa a distância ao alvo; nenhum outro inimigo é afetado.
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= HIT_RADIUS:
		if _target.has_method("apply_enemy_hit"):
			_target.apply_enemy_hit(_stats)
		queue_free()
