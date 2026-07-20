## Projétil do Necromante. Move em linha reta na direção capturada ao disparar e atinge SOMENTE
## o player (sobreposição com a caixa dele; ignora os outros inimigos — sem colisão física). Ao
## acertar, some. Fica na camada visual MAIS ALTA (z=300, acima do player).
class_name NecroProjectile
extends Node2D

const LIFETIME := 5.0
const TOP_Z := 300
const CORE := 10.0                 # lado do núcleo (era 6): o tiro tem de ser LIDO em movimento
const HALO := 20.0                 # lado do halo brilhante ao redor
const PULSE := 8.0                 # velocidade da pulsação do halo (rad/s)

var _vel := Vector2.ZERO
var _stats: StatBlock
var _target: Node2D
var _life := LIFETIME
var _halo: ColorRect
var _t := 0.0

func setup(dir: Vector2, speed: float, stats: StatBlock, target: Node2D) -> void:
	_vel = dir.normalized() * speed
	_stats = stats
	_target = target

func _ready() -> void:
	z_index = TOP_Z
	# Três camadas para o tiro brilhar sem shader: halo largo e translúcido, núcleo roxo e um
	# ponto quase branco no meio. O contraste do centro é o que faz o projétil ser visto contra
	# cenário escuro — sem ele, roxo sobre roxo some.
	_halo = ColorRect.new()
	_halo.color = Color(0.72, 0.42, 1.0, 0.30)
	_halo.size = Vector2(HALO, HALO)
	_halo.position = Vector2(-HALO * 0.5, -HALO * 0.5)
	add_child(_halo)

	var nucleo := ColorRect.new()
	nucleo.color = Palette.BOSS       # roxo do necromante
	nucleo.size = Vector2(CORE, CORE)
	nucleo.position = Vector2(-CORE * 0.5, -CORE * 0.5)
	add_child(nucleo)

	var brilho := ColorRect.new()
	brilho.color = Color(0.95, 0.88, 1.0)
	brilho.size = Vector2(CORE * 0.4, CORE * 0.4)
	brilho.position = Vector2(-CORE * 0.2, -CORE * 0.2)
	add_child(brilho)

func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	# Halo pulsando: dá vida ao tiro e ajuda a distingui-lo de cenário parado.
	_t += delta
	if is_instance_valid(_halo):
		var k := 1.0 + 0.22 * sin(_t * PULSE)
		_halo.scale = Vector2(k, k)
		_halo.modulate.a = 0.22 + 0.14 * (0.5 + 0.5 * sin(_t * PULSE))
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
	return d.x <= half.x + CORE * 0.5 and d.y <= half.y + CORE * 0.5   # + meia-largura do núcleo
