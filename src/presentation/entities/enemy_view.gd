## Apresentação do inimigo (§2.3). IA "aggressive": persegue o alvo e ataca em janelas
## fixas quando ao alcance. Visual e barra de HP montados via código (placeholders).
## BossView estende esta classe: customiza tamanho/cor e usa o hook _on_after_damage().
class_name EnemyView
extends CharacterBody2D

signal died

const ATTACK_RANGE := 30.0         # base 640×360
const ATTACK_VRANGE := 30.0        # alcance vertical: não acerta quem está acima (pogo)
const ATTACK_INTERVAL := 1.0
const WINDUP := 0.18               # 180 ms de aviso ("!") antes do golpe conectar (janela p/ desviar)
const GRAVITY := 1400.0            # mesma gravidade do player (side-scroller plano)

var data: Enemy                     # entidade Core
var target: Node2D                  # quem perseguir (o PlayerView)
var dormant := false                # passivo: não persegue nem ataca até ser ativado (elites em estágio)
var attack_range := ATTACK_RANGE    # alcance de GATILHO/aproximação do golpe melee
var hit_range := 0.0                # alcance de DANO/efeito do golpe (0 = usa attack_range)
var attack_style := "slash"         # estilo do efeito melee: "slash" (arco) | "thrust" (estocada)
var windup_time := WINDUP            # duração do windup (s) — data-driven via "windup" no JSON
var attack_interval := ATTACK_INTERVAL  # cooldown entre golpes (s) — data-driven via "attack_cooldown"
var box_size := 18.0                # footprint quadrado padrão por rank — subclasses ajustam antes de entrar na árvore
var box_w := 0.0                    # hitbox efetiva (px); resolvida em _build a partir de data.hitbox
var box_h := 0.0                    # (ou box_size × box_size se o JSON da entidade não definir "hitbox")
var body_color := Palette.ENEMY
var hp_bar_visible := true           # false nos bosses (usam a barra grande no rodapé)
var sprite_subdir := "enemies"      # subpasta da arte (BossView usa "bosses")
var sprite_id_override := ""        # id de sprite alternativo; vazio = usa data.id (o eco usa "player")

const KNOCKBACK_FORCE := 130.0     # base 640×360

var _attack_cd := 0.0
var _windup := 0.0                  # >0 = em windup (aviso "!" visível); ao zerar, resolve o golpe
var _warn: Node2D                   # o "!" acima do inimigo durante o windup
var _hp_bar: ColorRect
var _body: ColorRect
var _sprite: AnimatedSprite2D       # arte (null = usa o placeholder _body)
var _faces_left := false            # true se a arte foi desenhada virada p/ esquerda (manifesto)
var _anim_lock := 0.0
var _knockback := Vector2.ZERO

func setup(enemy: Enemy, target_node: Node2D) -> void:
	data = enemy
	target = target_node
	if enemy != null and enemy.attack_range > 0.0:
		attack_range = enemy.attack_range   # alcance de gatilho/aproximação data-driven
	if enemy != null and enemy.hit_range > 0.0:
		hit_range = enemy.hit_range         # alcance de dano/efeito (separado do gatilho)
	if enemy != null and enemy.attack_style != "":
		attack_style = enemy.attack_style   # estilo do efeito: "slash" (padrão) | "thrust"
	if enemy != null and enemy.windup >= 0.0:
		windup_time = enemy.windup          # duração do windup data-driven
	if enemy != null and enemy.attack_cooldown >= 0.0:
		attack_interval = enemy.attack_cooldown   # cooldown data-driven

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

	# Barra acima da cabeça (inimigos comuns/eco). Bosses escondem: usam a barra grande no rodapé.
	if hp_bar_visible:
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

	# Windup: parado com o "!" visível; ao zerar (80 ms), resolve o golpe (re-checando alcance).
	if _windup > 0.0:
		_windup -= delta
		velocity.x = _knockback.x
		_knockback = _knockback.lerp(Vector2.ZERO, 0.2)
		move_and_slide()
		_update_sprite(dx, false)
		if _windup <= 0.0:
			_resolve_attack(dx)
		return

	var dy := target.global_position.y - global_position.y
	var moving := false
	if absf(dx) > attack_range:
		velocity.x = signf(dx) * float(data.stats.move_speed) * ViewScale.WORLD
		moving = true
	else:
		velocity.x = 0.0
		# Só ataca se o player estiver ao alcance horizontal E vertical: quem pula/pogo
		# por cima fica fora do alcance e não toma dano por estar "em cima" do inimigo.
		if absf(dy) <= ATTACK_VRANGE:
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = attack_interval
				_start_windup()   # mostra o aviso "!" e agenda o golpe (80 ms)
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
	_anim_lock = attack_interval * 0.5

## Alcance efetivo de DANO/efeito do golpe: hit_range se definido, senão o attack_range (gatilho).
func _hit_range() -> float:
	return hit_range if hit_range > 0.0 else attack_range

## Efeito de golpe melee na direção do player, dimensionado por _hit_range(). O estilo vem de
## attack_style: "thrust" (estocada reta) ou "slash" (arco, padrão). Funciona mesmo sem arte.
func _spawn_attack_fx(dx: float) -> void:
	var ang := 0.0 if dx >= 0.0 else PI
	var pos := Vector2(0.0, -box_h * 0.25)
	var col := body_color.lightened(0.3)
	if attack_style == "thrust":
		Juice.thrust(self, pos, ang, _hit_range(), col)
	else:
		Juice.slash_arc(self, pos, ang, _hit_range(), col)

## Inicia o windup: mostra o "!" e trava o golpe por WINDUP segundos (janela para o player desviar).
func _start_windup() -> void:
	_windup = windup_time
	_show_warn()

## Fim do windup: some o "!" e conecta o golpe se o player ainda estiver ao alcance (sair do
## alcance evita; a esquiva também, via i-frames em apply_enemy_hit). O swing/anim sempre tocam.
func _resolve_attack(dx: float) -> void:
	_hide_warn()
	if is_instance_valid(target):
		var in_range := absf(dx) <= _hit_range() \
			and absf(target.global_position.y - global_position.y) <= ATTACK_VRANGE
		if in_range and target.has_method("apply_enemy_hit"):
			target.apply_enemy_hit(data.stats)
	_play_attack_anim()
	_spawn_attack_fx(dx)
	# Som do golpe (id no JSON do inimigo; vazio = mudo). Sem variação explícita, o Sfx faz o
	# rodízio das variações — golpes seguidos não repetem o mesmo som.
	if data != null:
		Sfx.play(data.attack_sfx)

## "!" vermelho acima da cabeça (feito com ColorRects — nítido no low-res). Só durante o windup.
func _show_warn() -> void:
	_hide_warn()
	var col := Color(1.0, 0.22, 0.22)
	var w := Node2D.new()
	w.z_index = 30
	var bar := ColorRect.new()
	bar.color = col
	bar.size = Vector2(2, 6)
	bar.position = Vector2(-1, 0)
	w.add_child(bar)
	var dot := ColorRect.new()
	dot.color = col
	dot.size = Vector2(2, 2)
	dot.position = Vector2(-1, 8)
	w.add_child(dot)
	w.position = Vector2(0, -box_h * 0.5 - 16)   # acima da cabeça
	add_child(w)
	_warn = w

func _hide_warn() -> void:
	if _warn != null and is_instance_valid(_warn):
		_warn.queue_free()
	_warn = null

func apply_damage(amount: int, knockback_mult := 1.0) -> void:
	data.stats.current_hp -= amount
	# Golpe fatal tem som próprio (o grito de morte); os demais, o de dano. Ids no JSON da
	# entidade; sem eles, silêncio.
	Sfx.play(data.death_sfx if data.stats.current_hp <= 0 else data.hurt_sfx)
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
	if _hp_bar == null:   # bosses não têm barra acima da cabeça
		return
	var ratio := clampf(float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1)), 0.0, 1.0)
	_hp_bar.size.x = box_w * ratio

## Hook para subclasses (Boss reage às fases aqui). Padrão: nada.
func _on_after_damage() -> void:
	pass
