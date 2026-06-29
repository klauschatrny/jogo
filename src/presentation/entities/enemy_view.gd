## Apresentação do inimigo (§2.3). IA "aggressive": persegue o alvo e ataca em janelas
## fixas quando ao alcance. Visual e barra de HP montados via código (placeholders).
## BossView estende esta classe: customiza tamanho/cor e usa o hook _on_after_damage().
class_name EnemyView
extends CharacterBody2D

signal died

const ATTACK_RANGE := 30.0
const ATTACK_VRANGE := 30.0        # alcance vertical: não acerta quem está acima (pogo)
const ATTACK_INTERVAL := 1.0
const GRAVITY := 1400.0            # mesma gravidade do player (side-scroller plano)

var data: Enemy                     # entidade Core
var target: Node2D                  # quem perseguir (o PlayerView)
var box_size := 18.0                # subclasses ajustam antes de entrar na árvore
var body_color := Palette.ENEMY

const KNOCKBACK_FORCE := 130.0

var _attack_cd := 0.0
var _hp_bar: ColorRect
var _body: ColorRect
var _knockback := Vector2.ZERO

func setup(enemy: Enemy, target_node: Node2D) -> void:
	data = enemy
	target = target_node

func _ready() -> void:
	collision_layer = 2
	# Colide APENAS com o chão (camada 4). Sem body-block entre entidades: inimigos
	# atravessam uns aos outros e o player livremente (nada de "encavalar"/travar).
	# A camada 2 é mantida só para a query de acerto da espada encontrá-los.
	collision_mask = 4
	# Profundidade por tamanho: menores ficam à frente dos maiores. Sempre acima do chão
	# (z=-5) e sempre atrás do player (z=200). box_size já está definido pelo setup().
	z_index = 100 - int(box_size)
	_build()

func _build() -> void:
	_body = ColorRect.new()
	_body.color = body_color
	_body.size = Vector2(box_size, box_size)
	_body.position = -0.5 * Vector2(box_size, box_size)
	add_child(_body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(box_size, box_size)
	col.shape = rect
	add_child(col)

	var bar_pos := Vector2(-box_size * 0.5, -box_size * 0.5 - 6.0)
	var bg := ColorRect.new()
	bg.color = Palette.HP_BACK
	bg.size = Vector2(box_size, 3)
	bg.position = bar_pos
	add_child(bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Palette.HP_FILL
	_hp_bar.size = Vector2(box_size, 3)
	_hp_bar.position = bar_pos
	add_child(_hp_bar)

func _physics_process(delta: float) -> void:
	if data == null or not is_instance_valid(target):
		return
	# Gravidade contínua; o chão (camada 4) segura o inimigo.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# IA lateral: avança no eixo X em direção ao player.
	var dx := target.global_position.x - global_position.x
	var dy := target.global_position.y - global_position.y
	if absf(dx) > ATTACK_RANGE:
		velocity.x = signf(dx) * float(data.stats.move_speed)
	else:
		velocity.x = 0.0
		# Só ataca se o player estiver ao alcance horizontal E vertical: quem pula/pogo
		# por cima fica fora do alcance e não toma dano por estar "em cima" do inimigo.
		if absf(dy) <= ATTACK_VRANGE:
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = ATTACK_INTERVAL
				if target.has_method("apply_enemy_hit"):
					target.apply_enemy_hit(data.stats)
	velocity.x += _knockback.x
	_knockback = _knockback.lerp(Vector2.ZERO, 0.2)   # recuo decai rápido
	move_and_slide()

func apply_damage(amount: int) -> void:
	data.stats.current_hp -= amount
	_refresh_hp_bar()
	Juice.flash(_body, body_color)
	Juice.burst(get_parent(), global_position, Palette.HIT_SPARK, 6)
	if is_instance_valid(target):
		_knockback = (global_position - target.global_position).normalized() * KNOCKBACK_FORCE
	_on_after_damage()
	if data.stats.current_hp <= 0:
		Juice.burst(get_parent(), global_position, body_color, 16, 140.0)
		died.emit()
		queue_free()

func _refresh_hp_bar() -> void:
	var ratio := clampf(float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1)), 0.0, 1.0)
	_hp_bar.size.x = box_size * ratio

## Hook para subclasses (Boss reage às fases aqui). Padrão: nada.
func _on_after_damage() -> void:
	pass
