## Apresentação do jogador (§2.3). Movimento top-down só por teclado; ataca na direção
## do movimento (Espaço/J). Monta o próprio visual/colisão via código (placeholders —
## arte de verdade entra na Fase 5). A lógica de combate vive no Core (CombatResolver).
class_name PlayerView
extends CharacterBody2D

const SIZE := 20.0

var data: Player                    # entidade Core
var god_mode := false               # debug: ignora dano recebido
var _facing := Vector2.DOWN
var _attack_cd := 0.0
var _hitbox: Area2D
var _swing: ColorRect

func setup(player: Player) -> void:
	data = player

func _ready() -> void:
	collision_layer = 1
	# Inimigos são obstáculos sólidos para o jogador (camada 2), mas os inimigos
	# não colidem de volta (ver EnemyView): assim o jogador não atravessa hordas,
	# sem o inimigo encavalar nele. Cenário com colisão entra numa camada futura.
	collision_mask = 2
	_build()

func _build() -> void:
	var body := ColorRect.new()
	body.color = Color(0.3, 0.6, 1.0)
	body.size = Vector2(SIZE, SIZE)
	body.position = -0.5 * Vector2(SIZE, SIZE)
	add_child(body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	col.shape = rect
	add_child(col)

	var reach := _reach()
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2       # só detecta inimigos
	var hb_col := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(reach, reach)
	hb_col.shape = hb_rect
	_hitbox.add_child(hb_col)
	add_child(_hitbox)

	_swing = ColorRect.new()
	_swing.color = Color(1.0, 1.0, 0.3, 0.35)
	_swing.size = Vector2(reach, reach)
	_swing.position = -0.5 * Vector2(reach, reach)
	_swing.visible = false
	_hitbox.add_child(_swing)
	_position_hitbox()

func _physics_process(delta: float) -> void:
	if data == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_facing = dir.normalized()
		_position_hitbox()
	velocity = dir * float(data.stats.move_speed)
	move_and_slide()

	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		_attack()

func _attack() -> void:
	var spd := data.weapon.attack_speed if data.weapon else 1.0
	_attack_cd = 1.0 / maxf(spd, 0.1)
	var total_dmg := 0
	for b in _hitbox.get_overlapping_bodies():
		if b is EnemyView and b.data != null:
			var dmg := int(round(CombatResolver.player_hit(data, b.data.stats)))
			b.apply_damage(dmg)
			total_dmg += dmg
	# Roubo de vida: cura uma fração do dano total causado neste golpe.
	var heal := CombatResolver.lifesteal_heal(data.stats.lifesteal, total_dmg)
	if heal > 0:
		data.heal(heal)
	_flash_swing()

## Chamado pelo EnemyView quando o inimigo acerta o jogador.
func apply_enemy_hit(attacker_stats: StatBlock) -> void:
	if god_mode:
		return
	var dmg := CombatResolver.enemy_hit(attacker_stats, data)
	data.take_damage(int(round(dmg)))

func _reach() -> float:
	return data.weapon.attack_range if (data and data.weapon and data.weapon.attack_range > 0.0) else 40.0

func _position_hitbox() -> void:
	if _hitbox:
		_hitbox.position = _facing * (_reach() * 0.5)

func _flash_swing() -> void:
	_swing.visible = true
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_swing):
			_swing.visible = false)
