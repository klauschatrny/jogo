## Rocha arremessada pelo Ogro. Move em linha reta na direção capturada ao disparar. Some ao
## ACERTAR o player (dano fixo) — se o player desviar (esquiva/god), a rocha PASSA RETO e segue.
## Também some ao encostar no cenário (chão/paredes/teto = camada 4). Ignora os outros inimigos.
class_name OgreRock
extends Node2D

const LIFETIME := 5.0
const HALF := 8.0            # meia-largura da rocha (rocha grande = 16×16)
const ENV_LAYER := 4        # cenário (chão + paredes) — StaticBody em _build_environment

var _vel := Vector2.ZERO
var _damage := 0
var _target: Node2D
var _life := LIFETIME

func setup(dir: Vector2, speed: float, damage: int, target: Node2D) -> void:
	_vel = dir.normalized() * speed
	_damage = damage
	_target = target

func _ready() -> void:
	z_index = 150   # à frente dos inimigos, atrás do player (z=200)
	var r := ColorRect.new()
	r.color = Color(0.45, 0.38, 0.32)   # pedra
	r.size = Vector2(HALF * 2.0, HALF * 2.0)
	r.position = Vector2(-HALF, -HALF)
	add_child(r)
	var edge := ColorRect.new()
	edge.color = Color(0.28, 0.23, 0.19)
	edge.size = Vector2(HALF * 2.0, 2.0)
	edge.position = Vector2(-HALF, HALF - 2.0)
	add_child(edge)

func _physics_process(delta: float) -> void:
	global_position += _vel * delta   # linha reta na direção capturada ao arremessar
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Cenário (chão/paredes/teto = camada 4): some ao encostar.
	if _hits_environment():
		queue_free()
		return
	# Atinge SOMENTE o player (AABB): some SÓ se o dano conectar. Se o player desviar
	# (esquiva/god), apply_flat_damage retorna false → a rocha passa reto e continua voando.
	if is_instance_valid(_target) and _overlaps_player():
		if _target.has_method("apply_flat_damage") and _target.apply_flat_damage(_damage):
			queue_free()

## Ponto da rocha dentro de algum corpo do cenário (camada 4)?
func _hits_environment() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position
	q.collision_mask = ENV_LAYER
	q.collide_with_areas = false
	return not space.intersect_point(q, 1).is_empty()

func _overlaps_player() -> bool:
	var half := Vector2(8.0, 13.0)      # fallback
	if "box_w" in _target:
		half = Vector2(_target.box_w, _target.box_h) * 0.5
	var d: Vector2 = (global_position - _target.global_position).abs()
	return d.x <= half.x + HALF and d.y <= half.y + HALF
