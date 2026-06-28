## Apresentação do inimigo (§2.3). IA "aggressive": persegue o alvo e ataca em janelas
## fixas quando ao alcance. Visual e barra de HP montados via código (placeholders).
## BossView estende esta classe: customiza tamanho/cor e usa o hook _on_after_damage().
class_name EnemyView
extends CharacterBody2D

signal died

const ATTACK_RANGE := 30.0
const ATTACK_INTERVAL := 1.0

var data: Enemy                     # entidade Core
var target: Node2D                  # quem perseguir (o PlayerView)
var box_size := 18.0                # subclasses ajustam antes de entrar na árvore
var body_color := Color(0.9, 0.3, 0.3)

var _attack_cd := 0.0
var _hp_bar: ColorRect

func setup(enemy: Enemy, target_node: Node2D) -> void:
	data = enemy
	target = target_node

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	_build()

func _build() -> void:
	var body := ColorRect.new()
	body.color = body_color
	body.size = Vector2(box_size, box_size)
	body.position = -0.5 * Vector2(box_size, box_size)
	add_child(body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(box_size, box_size)
	col.shape = rect
	add_child(col)

	var bar_pos := Vector2(-box_size * 0.5, -box_size * 0.5 - 6.0)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(box_size, 3)
	bg.position = bar_pos
	add_child(bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.3, 0.9, 0.3)
	_hp_bar.size = Vector2(box_size, 3)
	_hp_bar.position = bar_pos
	add_child(_hp_bar)

func _physics_process(delta: float) -> void:
	if data == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target.length() > ATTACK_RANGE:
		velocity = to_target.normalized() * float(data.stats.move_speed)
	else:
		velocity = Vector2.ZERO
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			if target.has_method("apply_enemy_hit"):
				target.apply_enemy_hit(data.stats)
	move_and_slide()

func apply_damage(amount: int) -> void:
	data.stats.current_hp -= amount
	_refresh_hp_bar()
	_on_after_damage()
	if data.stats.current_hp <= 0:
		died.emit()
		queue_free()

func _refresh_hp_bar() -> void:
	var ratio := clampf(float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1)), 0.0, 1.0)
	_hp_bar.size.x = box_size * ratio

## Hook para subclasses (Boss reage às fases aqui). Padrão: nada.
func _on_after_damage() -> void:
	pass
