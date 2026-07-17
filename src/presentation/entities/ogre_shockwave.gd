## Onda de choque do SLAM do Ogro (fase 2). Uma lomba de terra BAIXA que corre rente ao chão na
## direção capturada no soco. A resposta pensada é PULAR por cima (ela é baixa: ~20px de ar já
## livram); rolar ATRAVÉS dela também vale (i-frames, como qualquer golpe que não seja poço) —
## mas rolar no lugar não salva. Some ao conectar o dano, ao encostar numa parede ou por tempo.
## Ignora os outros inimigos, como a rocha.
class_name OgreShockwave
extends Node2D

const LIFETIME := 4.0
const HALF_W := 22.0         # meia-largura da caixa de dano (a lomba tem 44px de base)
const HALF_H := 10.0         # meia-altura: caixa de 20px — pular por cima é fácil, rolar parado não
const ENV_LAYER := 4         # cenário (chão + paredes) — StaticBody em _build_environment
const DUST_EVERY := 0.12     # rastro de poeira enquanto corre

var _vel := Vector2.ZERO
var _damage := 0
var _target: Node2D
var _life := LIFETIME
var _dust_t := 0.0
var _hump: Polygon2D
var _wobble := 0.0

func setup(dir: float, speed: float, damage: int, target: Node2D) -> void:
	_vel = Vector2(signf(dir) * speed, 0.0)
	_damage = damage
	_target = target

## O (0,0) local é a LINHA DO CHÃO; a lomba sobe a partir dela (mesma âncora dos sprites).
func _ready() -> void:
	z_index = 150   # à frente dos inimigos, atrás do player (z=200) — igual à rocha
	_hump = Polygon2D.new()
	_hump.color = Color(0.42, 0.34, 0.24)   # terra revolvida
	_hump.polygon = PackedVector2Array([
		Vector2(-HALF_W, 0), Vector2(-HALF_W * 0.45, -HALF_H * 1.4), Vector2(0, -HALF_H * 2.0),
		Vector2(HALF_W * 0.45, -HALF_H * 1.4), Vector2(HALF_W, 0),
	])
	add_child(_hump)
	var core := Polygon2D.new()             # o miolo mais claro (pedras soltas)
	core.color = Color(0.58, 0.48, 0.34)
	core.polygon = PackedVector2Array([
		Vector2(-HALF_W * 0.4, 0), Vector2(0, -HALF_H * 1.2), Vector2(HALF_W * 0.4, 0),
	])
	add_child(core)

func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_wobble += delta * 22.0
	_hump.scale.y = 1.0 + 0.10 * sin(_wobble)   # a lomba "ferve" enquanto avança
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = DUST_EVERY
		Juice.burst(get_parent(), global_position, Color(0.5, 0.42, 0.3), 3, 60.0)
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Parede (camada 4): a onda morre nela. O ponto é o (0,0), a linha do chão — dentro do CHÃO
	# ele não está (fica em cima), então só a parede a detém.
	if _hits_environment():
		Juice.burst(get_parent(), global_position, Color(0.5, 0.42, 0.3), 8, 100.0)
		queue_free()
		return
	# Atinge SOMENTE o player (AABB, caixa BAIXA — pular por cima escapa). Some SÓ se o dano
	# conectar; se o player desviar (esquiva/god), apply_flat_damage retorna false e ela segue.
	if is_instance_valid(_target) and _overlaps_player():
		if _target.has_method("apply_flat_damage") and _target.apply_flat_damage(_damage):
			queue_free()

## Ponto da onda dentro de algum corpo do cenário (camada 4)?
func _hits_environment() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(signf(_vel.x) * HALF_W, -HALF_H)   # a frente da lomba
	q.collision_mask = ENV_LAYER
	q.collide_with_areas = false
	return not space.intersect_point(q, 1).is_empty()

func _overlaps_player() -> bool:
	var half := Vector2(8.0, 13.0)      # fallback
	if "box_w" in _target:
		half = Vector2(_target.box_w, _target.box_h) * 0.5
	var center := global_position + Vector2(0.0, -HALF_H)   # centro da caixa (o (0,0) é o chão)
	var d: Vector2 = (center - _target.global_position).abs()
	return d.x <= half.x + HALF_W and d.y <= half.y + HALF_H
