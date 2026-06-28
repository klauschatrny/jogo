## Apresentação do jogador (§2.3). Movimento top-down só por teclado; ataca na direção
## do movimento (Espaço/J). Monta o próprio visual/colisão via código (placeholders —
## arte de verdade entra na Fase 5). A lógica de combate vive no Core (CombatResolver).
class_name PlayerView
extends CharacterBody2D

const SIZE := 20.0
const BASE_COLOR := Palette.PLAYER

var data: Player                    # entidade Core
var god_mode := false               # debug: ignora dano recebido
var _facing := Vector2.DOWN
var _attack_cd := 0.0
var _body: ColorRect

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
	_body = ColorRect.new()
	_body.color = BASE_COLOR
	_body.size = Vector2(SIZE, SIZE)
	_body.position = -0.5 * Vector2(SIZE, SIZE)
	add_child(_body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	col.shape = rect
	add_child(col)

func _physics_process(delta: float) -> void:
	if data == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_facing = dir.normalized()
	velocity = dir * float(data.stats.move_speed)
	move_and_slide()

	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		_attack()

func _attack() -> void:
	var spd := data.weapon.attack_speed if data.weapon else 1.0
	_attack_cd = 1.0 / maxf(spd, 0.1)
	var total_dmg := 0
	for b in _enemies_in_reach():
		var dmg := int(round(CombatResolver.player_hit(data, b.data.stats)))
		b.apply_damage(dmg)
		total_dmg += dmg
	# Roubo de vida: cura uma fração do dano total causado neste golpe.
	var heal := CombatResolver.lifesteal_heal(data.stats.lifesteal, total_dmg)
	if heal > 0:
		data.heal(heal)
	if total_dmg > 0:                       # impacto: hit-stop + tremor de tela
		Juice.hit_stop(get_tree())
		_shake(0.22)
	_spawn_slash()

## Chamado pelo EnemyView quando o inimigo acerta o jogador.
func apply_enemy_hit(attacker_stats: StatBlock) -> void:
	if god_mode:
		return
	var dmg := CombatResolver.enemy_hit(attacker_stats, data)
	data.take_damage(int(round(dmg)))
	Juice.flash(_body, BASE_COLOR)
	_shake(0.15)

## Tremor de tela via a câmera ativa (GameCamera). Sem câmera, é no-op.
func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam is GameCamera:
		(cam as GameCamera).add_trauma(amount)

func _reach() -> float:
	return data.weapon.attack_range if (data and data.weapon and data.weapon.attack_range > 0.0) else 40.0

## Inimigos no alcance AGORA, na direção atual do golpe — consulta síncrona à física (sem o
## atraso de 1 frame do Area2D, que fazia o hit e a animação divergirem ao trocar de direção
## e atacar no mesmo frame). Usa o mesmo _facing do slash, então os dois sempre concordam.
func _enemies_in_reach() -> Array:
	var reach := _reach()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(reach, reach)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + _facing * (reach * 0.5))
	query.collision_mask = 2
	query.collide_with_bodies = true
	var result: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var b: Variant = hit.get("collider")
		if b is EnemyView and b.data != null:
			result.append(b)
	return result

## Arco de corte: um crescente fino na direção do golpe, que aparece e some rápido,
## com um leve "sweep" (gira um pouco) para dar sensação de movimento da lâmina.
func _spawn_slash() -> void:
	var reach := _reach()
	var radius := reach * 0.5
	var base := _facing.angle()
	var span := deg_to_rad(120.0)
	var steps := 10

	var slash := Line2D.new()
	slash.width = 5.0
	slash.default_color = Palette.SLASH
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash.joint_mode = Line2D.LINE_JOINT_ROUND
	slash.z_index = 20
	for i in steps + 1:
		var a := base - span * 0.5 + span * (float(i) / steps)
		slash.add_point(Vector2(cos(a), sin(a)) * radius)
	slash.rotation = -span * 0.25            # começa puxado pra trás...
	add_child(slash)

	var tw := slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "rotation", span * 0.25, 0.12)   # ...e varre pra frente
	tw.tween_property(slash, "modulate:a", 0.0, 0.14)
	tw.tween_property(slash, "width", 1.5, 0.14)
	tw.chain().tween_callback(slash.queue_free)
