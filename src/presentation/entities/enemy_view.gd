## Apresentação do inimigo (§2.3). IA "aggressive": persegue o alvo e ataca em janelas
## fixas quando ao alcance. Visual e barra de HP montados via código (placeholders).
## BossView estende esta classe: customiza tamanho/cor e usa o hook _on_after_damage().
class_name EnemyView
extends CharacterBody2D

signal died

const ATTACK_RANGE := 30.0         # base 640×360
const ATTACK_VRANGE := 30.0        # alcance vertical: não acerta quem está acima (pogo)
const ATTACK_INTERVAL := 1.0
const GRAVITY := 1400.0            # mesma gravidade do player (side-scroller plano)

var data: Enemy                     # entidade Core
var target: Node2D                  # quem perseguir (o PlayerView)
var dormant := false                # passivo: não persegue nem ataca até ser ativado (elites em estágio)
var box_size := 18.0                # footprint quadrado padrão por rank — subclasses ajustam antes de entrar na árvore
var box_w := 0.0                    # hitbox efetiva (px); resolvida em _build a partir de data.hitbox
var box_h := 0.0                    # (ou box_size × box_size se o JSON da entidade não definir "hitbox")
var body_color := Palette.ENEMY
var sprite_subdir := "enemies"      # subpasta da arte (BossView usa "bosses")
var sprite_id_override := ""        # id de sprite alternativo; vazio = usa data.id (o eco usa "player")

const KNOCKBACK_FORCE := 130.0     # base 640×360

var _attack_cd := 0.0
var _hp_bar: ColorRect
var _body: ColorRect
var _sprite: AnimatedSprite2D       # arte (null = usa o placeholder _body)
var _faces_left := false            # true se a arte foi desenhada virada p/ esquerda (manifesto)
var _anim_lock := 0.0
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
	# (z=-5) e sempre atrás do player (z=200). Normaliza pela escala para o mesmo spread
	# do espaço lógico original. box_size já está definido pelo setup().
	z_index = 100 - int(box_size / ViewScale.WORLD)
	_build()

func _build() -> void:
	_resolve_hitbox()
	var box := Vector2(box_w, box_h)
	_body = ColorRect.new()
	_body.color = body_color
	_body.size = box
	_body.position = -0.5 * box
	add_child(_body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box
	col.shape = rect
	add_child(col)

	# Arte: usa sprite_id_override (ex.: o eco empresta a arte "player") ou o id da entidade.
	# Adicionado antes da barra de HP para a barra ficar por cima do sprite.
	var sprite_id := _sprite_id()
	if sprite_id != "":
		_sprite = SpriteLoader.build(sprite_id, sprite_subdir)
		if _sprite != null:
			_sprite.position.y = box_h * 0.5   # âncora nos pés: base do sprite = base da hitbox (chão)
			_faces_left = bool(_sprite.get_meta("faces_left", false))
			add_child(_sprite)
			_body.visible = false

	var bar_pos := Vector2(-box_w * 0.5, -box_h * 0.5 - 6.0)   # base 640×360
	var bg := ColorRect.new()
	bg.color = Palette.HP_BACK
	bg.size = Vector2(box_w, 3)                                # base 640×360
	bg.position = bar_pos
	add_child(bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Palette.HP_FILL
	_hp_bar.size = Vector2(box_w, 3)
	_hp_bar.position = bar_pos
	add_child(_hp_bar)

## Id usado para carregar arte E hitbox/scale do manifesto. sprite_id_override permite que uma
## view empreste a arte de outro id (o eco usa "player" → herda arte, hitbox e scale do jogador).
func _sprite_id() -> String:
	return sprite_id_override if sprite_id_override != "" else (data.id if data != null else "")

## Resolve a hitbox efetiva: "hitbox": [w, h] do manifesto (ou box_size por rank), multiplicada
## pelo "scale" do manifesto — assim a hitbox cresce junto com a arte e a proporção se mantém.
func _resolve_hitbox() -> void:
	var sid := _sprite_id()
	var s := SpriteLoader.scale_for(sid)
	var hb := SpriteLoader.hitbox_for(sid)
	if hb != Vector2.ZERO:
		box_w = hb.x * s
		box_h = hb.y * s
	else:
		box_w = box_size * s
		box_h = box_size * s

func _physics_process(delta: float) -> void:
	if data == null or not is_instance_valid(target):
		return
	_anim_lock = maxf(0.0, _anim_lock - delta)
	# Gravidade contínua; o chão (camada 4) segura o inimigo.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# IA lateral: avança no eixo X em direção ao player.
	var dx := target.global_position.x - global_position.x
	# Dormente (elite em estágio): parado, encarando o player, só gravidade e recuo, até ativar.
	if dormant:
		velocity.x = _knockback.x
		_knockback = _knockback.lerp(Vector2.ZERO, 0.2)
		move_and_slide()
		_update_sprite(dx, false)
		return
	var dy := target.global_position.y - global_position.y
	var moving := false
	if absf(dx) > ATTACK_RANGE:
		velocity.x = signf(dx) * float(data.stats.move_speed) * ViewScale.WORLD
		moving = true
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
				_play_attack_anim()
	velocity.x += _knockback.x
	_knockback = _knockback.lerp(Vector2.ZERO, 0.2)   # recuo decai rápido
	move_and_slide()
	_update_sprite(dx, moving)

## Vira o sprite para o player e escolhe walk/idle (salvo durante a anim de ataque travada).
func _update_sprite(dx: float, moving: bool) -> void:
	if _sprite == null:
		return
	if dx != 0.0:
		# Quer olhar p/ esquerda quando o alvo está à esquerda (dx<0); XOR com a direção
		# em que a arte foi desenhada (_faces_left) resolve o espelhamento correto.
		_sprite.flip_h = (dx < 0.0) != _faces_left
	if _anim_lock > 0.0:
		return
	SpriteLoader.play_safe(_sprite, "walk" if moving else "idle")

func _play_attack_anim() -> void:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation("attack"):
		return
	_sprite.play("attack")
	_sprite.frame = 0
	_anim_lock = ATTACK_INTERVAL * 0.5

func apply_damage(amount: int, knockback_mult := 1.0) -> void:
	data.stats.current_hp -= amount
	_refresh_hp_bar()
	if _sprite != null:
		Juice.flash_modulate(_sprite)
	else:
		Juice.flash(_body, body_color)
	Juice.burst(get_parent(), global_position, Palette.HIT_SPARK, 6)
	if is_instance_valid(target):
		# Recuo horizontal (afastando do atacante); o finisher do combo empurra mais.
		var dir := signf(global_position.x - target.global_position.x)
		if dir == 0.0:
			dir = 1.0
		_knockback = Vector2(dir * KNOCKBACK_FORCE * knockback_mult, 0.0)
	_on_after_damage()
	if data.stats.current_hp <= 0:
		Juice.burst(get_parent(), global_position, body_color, 16, 140.0)
		died.emit()
		queue_free()

func _refresh_hp_bar() -> void:
	var ratio := clampf(float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1)), 0.0, 1.0)
	_hp_bar.size.x = box_w * ratio

## Hook para subclasses (Boss reage às fases aqui). Padrão: nada.
func _on_after_damage() -> void:
	pass
