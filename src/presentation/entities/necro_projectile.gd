## Projétil do Necromante. Move em linha reta na direção capturada ao disparar e atinge SOMENTE
## o player (sobreposição com a caixa dele; ignora os outros inimigos — sem colisão física). Ao
## acertar, some. Fica na camada visual MAIS ALTA (z=300, acima do player).
class_name NecroProjectile
extends Node2D

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
	# Atinge SOMENTE o player: sobreposição com a caixa dele (AABB). Nenhum outro inimigo é afetado.
	# Ao acertar (ou sobrepor), o projétil SOME. Se o player sair do caminho, ele segue voando.
	if is_instance_valid(_target) and _overlaps_player():
		if _target.has_method("apply_enemy_hit"):
			_target.apply_enemy_hit(_stats)
		queue_free()

func _overlaps_player() -> bool:
	var half := Vector2(8.0, 13.0)      # fallback
	if "box_w" in _target:
		half = Vector2(_target.box_w, _target.box_h) * 0.5
	var d: Vector2 = (global_position - _target.global_position).abs()
	return d.x <= half.x + 3.0 and d.y <= half.y + 3.0   # +3 = meia-largura do projétil
