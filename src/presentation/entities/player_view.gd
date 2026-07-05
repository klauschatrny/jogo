## Apresentação do jogador (§2.3). Side-scroller de chão plano: A/D anda, Espaço/W pula,
## J/K ataca (combo de 3 golpes; pra baixo no ar = pogo), Shift esquiva (dash direcional
## com i-frames + rastro). Monta o próprio visual/colisão via código (placeholder ColorRect
## — spritesheet entra na Leva 4). A lógica de combate vive no Core (CombatResolver).
class_name PlayerView
extends CharacterBody2D

const SIZE := 20.0               # footprint do player (base 640×360)
const BASE_COLOR := Palette.PLAYER
const SPRITE_ID := "player"      # arte: assets/sprites/player/player.png + data/sprites/player.json

# Feel de movimento (constantes de apresentação no espaço base 640×360).
const GRAVITY := 1400.0
const JUMP_VELOCITY := -460.0
const DODGE_SPEED := 430.0
const DODGE_TIME := 0.20          # dash + i-frames: invencibilidade de 200 ms a partir do frame 0
const DODGE_COOLDOWN := 0.4       # tempo mínimo entre uma esquiva e a próxima
const POGO_BOUNCE := -380.0      # impulso pra cima ao acertar um golpe pra baixo no ar
const COMBO_GRACE := 0.28        # folga sobre o cooldown do golpe para encadear o combo
const COMBO_MAX := 3             # combo de 3 golpes (0, 1, 2=finisher)
const COMBO_HIT_CD := 0.2        # gap ALÉM da anim completa, entre os golpes DENTRO da sequência de 3
const COMBO_SEQ_CD := 1.0        # gap ALÉM da anim completa, após o 3º golpe, antes da próxima sequência
const FINISHER_KNOCKBACK := 2.4  # o 3º golpe empurra bem mais
const ATTACK_CONTACT_FRAME := 2  # quadro da anim de ataque em que a lâmina conecta (impacto)
const HIT_HEIGHT := 56.0         # altura do retângulo de dano; o comprimento vem do attack_range da arma
const CONTACT_CD := 1.0          # imunidade entre hits por COLISÃO sequenciais
const CONTACT_KNOCKBACK := 520.0 # empurrão horizontal ao encostar num inimigo (base 640×360)

var data: Player                    # entidade Core
var god_mode := false               # debug: ignora dano recebido
var _facing := Vector2.RIGHT        # no lateral só importa o eixo X (RIGHT/LEFT)
var _attack_dir := Vector2.RIGHT    # direção do golpe atual (facing, ou DOWN no ar)
var _attack_cd := 0.0
var _hit_pending := false           # golpe disparado, aguardando o quadro de impacto da anim
var _pending_step := 0              # passo do combo do golpe pendente (define finisher/knockback)
var _attack_move_lock := 0.0        # trava a locomoção (fica parado) enquanto a anim de ataque não termina
var _dodge_time := 0.0              # >0 enquanto esquiva (concede i-frames)
var _dodge_cd := 0.0
var _dodge_buffered := false       # intenção de esquiva apertada durante o cooldown (1 comando só)
var _dodge_dir := Vector2.RIGHT    # direção do dash (input atual, ou facing)
var _combo := 0                    # passo atual do combo (0..COMBO_MAX-1)
var _combo_timer := 0.0            # tempo restante para encadear o próximo golpe
var _contact_cd := 0.0             # cooldown do hit por colisão (>0 = imune a colisão)
var _knockback := Vector2.ZERO     # empurrão horizontal (decai); somado à velocidade
var _attack_cost := 20.0           # custo de stamina por golpe (data-driven via balance.json)
var _dodge_cost := 30.0            # custo de stamina por esquiva
var box_w := SIZE                  # hitbox efetiva (px); resolvida em _build do manifesto player.json
var box_h := SIZE                  # (ou SIZE × SIZE se o manifesto não definir "hitbox")
var _body: ColorRect
var _sprite: AnimatedSprite2D      # arte (null = usa o placeholder _body)
var _faces_left := false           # true se a arte foi desenhada virada p/ esquerda (manifesto)
var _anim_lock := 0.0              # trava a anim de locomoção enquanto toca ataque

func setup(player: Player) -> void:
	data = player
	_attack_cost = float(BalanceConfig.stamina.get("ATTACK_COST", 20.0))
	_dodge_cost = float(BalanceConfig.stamina.get("DODGE_COST", 30.0))

func is_dodging() -> bool:
	return _dodge_time > 0.0

## Há stamina para iniciar uma ação? (sem stamina configurada = sempre permite, à prova de falha).
func _has_stamina() -> bool:
	return data.stamina == null or data.stamina.can_act()

func _spend_stamina(cost: float) -> void:
	if data.stamina != null:
		data.stamina.consume(cost)

func _ready() -> void:
	z_index = 200             # player sempre desenhado na frente de tudo (inimigos < 100)
	collision_layer = 1
	# Colide APENAS com o cenário/chão (camada 4). Não há body-block entre entidades:
	# o player atravessa inimigos livremente (atacar/esquivar no meio da horda sem travar).
	# O acerto da espada é resolvido por query à camada 2, não por colisão física.
	collision_mask = 4
	_build()

func _build() -> void:
	# Hitbox: "hitbox": [w, h] do manifesto player.json (ou SIZE), × "scale" do manifesto —
	# a hitbox cresce junto com a arte (mesmo fator → proporção mantida).
	var s := SpriteLoader.scale_for(SPRITE_ID)
	var hb := SpriteLoader.hitbox_for(SPRITE_ID)
	if hb != Vector2.ZERO:
		box_w = hb.x * s
		box_h = hb.y * s
	else:
		box_w = SIZE * s
		box_h = SIZE * s
	var box := Vector2(box_w, box_h)

	_body = ColorRect.new()
	_body.color = BASE_COLOR
	_body.size = box
	_body.position = -0.5 * box
	add_child(_body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box
	col.shape = rect
	add_child(col)

	# Arte: se houver spritesheet+manifesto, usa-o e esconde o placeholder ColorRect.
	_sprite = SpriteLoader.build(SPRITE_ID, "player")
	if _sprite != null:
		_sprite.position.y = box_h * 0.5   # âncora nos pés: base do sprite = base da hitbox (chão)
		_faces_left = bool(_sprite.get_meta("faces_left", false))
		add_child(_sprite)
		_body.visible = false

func _physics_process(delta: float) -> void:
	if data == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_attack_move_lock = maxf(0.0, _attack_move_lock - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	if data.stamina != null:
		data.stamina.tick(delta)      # stamina regenera (após o atraso desde o último gasto)
	if _combo_timer <= 0.0:
		_combo = 0                    # combo expira fora da janela

	# Golpe sincronizado com a anim: o dano só cai quando a lâmina chega no quadro de impacto
	# (ATTACK_CONTACT_FRAME), não no início do windup — assim o hit bate junto com o talho na tela.
	if _hit_pending and _sprite != null and _sprite.animation == "attack" and _sprite.frame >= ATTACK_CONTACT_FRAME:
		_hit_pending = false
		_resolve_hit(_pending_step)

	# Buffer de esquiva: se o jogador apertar DENTRO do cooldown (inclusive durante o dash em
	# curso, antes do early-return abaixo), guarda a intenção — um único comando. Ela dispara
	# sozinha assim que o cooldown liberar (mais abaixo). Cliques repetidos não empilham.
	if Input.is_action_just_pressed("dodge") and _dodge_cd > 0.0:
		_dodge_buffered = true

	# Dano por COLISÃO: encostar num inimigo (fora dos i-frames) fere, empurra e pisca de branco.
	_check_contact_damage()

	# Gravidade contínua; o chão (StaticBody2D) segura o player via is_on_floor().
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Esquiva: dash na direção escolhida, mantém a gravidade, ignora dano (i-frames = DODGE_TIME,
	# 200 ms a partir do frame 0). A anim do rolamento segue além disso, travando o ataque via _anim_lock.
	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity.x = _dodge_dir.x * DODGE_SPEED
		_flip(_dodge_dir)
		_play_anim("dodge")
		move_and_slide()
		return

	var ix := Input.get_axis("move_left", "move_right")
	# Durante o ataque o facing fica congelado (o golpe fica comprometido com a direção do talho),
	# no chão OU no ar. A trava de POSIÇÃO, porém, só vale no chão: no ar mantém o controle
	# horizontal (drift/pogo). Gravidade e knockback continuam valendo em qualquer caso.
	var locked := _attack_move_lock > 0.0
	if ix != 0.0 and not locked:
		_facing = Vector2.RIGHT if ix > 0.0 else Vector2.LEFT
	var move_x := 0.0 if (locked and is_on_floor()) else ix * float(data.stats.move_speed) * ViewScale.WORLD
	velocity.x = move_x + _knockback.x

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Dispara a esquiva: por clique imediato (fora do cooldown) OU pelo comando guardado no
	# buffer, assim que o cooldown liberar e houver stamina. Consome o buffer aqui — pra
	# encadear outra, é preciso apertar de novo durante o cooldown desta.
	if (_dodge_buffered or Input.is_action_just_pressed("dodge")) and _dodge_cd <= 0.0 and _has_stamina():
		_dodge_buffered = false
		_start_dodge(ix)
		_spend_stamina(_dodge_cost)

	move_and_slide()
	_knockback = _knockback.lerp(Vector2.ZERO, 0.2)   # empurrão do contato decai rápido

	_flip(_facing)
	_update_locomotion(ix)

	# Não pode atacar durante a trava de anim (o próprio ataque ou o rolamento). O cooldown do combo
	# (dur+gap) já é maior que a animação, então isto não atrasa a sequência — só garante que a anim
	# termine e reprotege a esquiva de ser cancelada por ataque.
	if Input.is_action_pressed("attack") and _attack_cd <= 0.0 and _anim_lock <= 0.0 and _has_stamina():
		_attack()
		_spend_stamina(_attack_cost)

## Inicia o dash da esquiva: direção = input atual (permite esquivar pra trás), ou o facing.
func _start_dodge(ix: float) -> void:
	_dodge_time = DODGE_TIME
	_dodge_cd = DODGE_COOLDOWN
	_hit_pending = false            # a esquiva cancela o golpe: nenhum dano pendente vaza pro roll
	_attack_move_lock = 0.0         # e libera a trava de movimento do ataque (o dash tem prioridade)
	_dodge_dir = (Vector2.RIGHT if ix > 0.0 else Vector2.LEFT) if ix != 0.0 else _facing

	# A anim de rolamento costuma ser mais longa que o dash (i-frames). Reinicia do frame 0 e
	# trava a locomoção pela DURAÇÃO da animação (frames ÷ fps), pra o roll tocar inteiro em vez
	# de estalar de volta pra idle no meio quando o dash acaba. Atacar/esquivar de novo corta.
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("dodge"):
		_sprite.play("dodge")
		_sprite.frame = 0
		var fc := _sprite.sprite_frames.get_frame_count("dodge")
		var spd := _sprite.sprite_frames.get_animation_speed("dodge")
		_anim_lock = float(fc) / maxf(spd, 0.1)

## Vira o sprite conforme a direção (no-op sem sprite).
func _flip(dir: Vector2) -> void:
	if _sprite != null and dir.x != 0.0:
		# XOR com a direção em que a arte foi desenhada (_faces_left), igual ao EnemyView.
		_sprite.flip_h = (dir.x < 0.0) != _faces_left

func _play_anim(anim: String) -> void:
	SpriteLoader.play_safe(_sprite, anim)

## Escolhe a animação de locomoção (pulo/corrida/parado), salvo durante o ataque (_anim_lock).
func _update_locomotion(ix: float) -> void:
	if _sprite == null or _anim_lock > 0.0:
		return
	if not is_on_floor():
		_play_anim("jump")
	elif ix != 0.0:
		_play_anim("run")
	else:
		_play_anim("idle")

func _attack() -> void:
	_attack_dir = _current_attack_dir()

	# Combo de 3 golpes: cada ataque dentro da janela avança o passo; o 3º (is_last) é o finisher.
	var step := _combo
	var is_last := step >= COMBO_MAX - 1
	_combo = (step + 1) % COMBO_MAX

	# Anim de ataque (reinicia do frame 0). O player fica PARADO no lugar pela duração da animação
	# (frames ÷ fps): trava a locomoção (_anim_lock) e o movimento (_attack_move_lock) juntos, terminando
	# junto com o talho. O dano é armado como PENDENTE e resolvido no quadro de impacto (ver _physics_process).
	var dur := 0.0
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		_sprite.frame = 0
		var fc := _sprite.sprite_frames.get_frame_count("attack")
		var aspd := _sprite.sprite_frames.get_animation_speed("attack")
		dur = float(fc) / maxf(aspd, 0.1)
		_anim_lock = dur
		_attack_move_lock = dur
		_hit_pending = true
		_pending_step = step
	else:
		_resolve_hit(step)          # sem arte (placeholder): resolve na hora, como antes

	# Cadência: a animação toca INTEIRA e só então corre o gap. Entre golpes do combo o gap é
	# COMBO_HIT_CD (100ms); ao fechar o 3º, COMBO_SEQ_CD (800ms) antes de recomeçar. Como o cooldown
	# (dur+gap) já é maior que a anim, ela nunca é cortada; segurar o ataque encadeia os 3.
	var gap := COMBO_SEQ_CD if is_last else COMBO_HIT_CD
	_attack_cd = dur + gap
	_combo_timer = _attack_cd + COMBO_GRACE

## Resolve o dano do golpe (chamado no quadro de impacto da anim, ou na hora sem spritesheet):
## acerta os inimigos no alcance, aplica roubo de vida e o feedback de impacto (hit-stop, tremor, pogo).
func _resolve_hit(step: int) -> void:
	var is_finisher := step >= COMBO_MAX - 1
	var kb := FINISHER_KNOCKBACK if is_finisher else 1.0
	var total_dmg := 0
	for b in _enemies_in_reach():
		var dmg := int(round(CombatResolver.player_hit(data, b.data.stats)))
		b.apply_damage(dmg, kb)
		total_dmg += dmg
	# Roubo de vida: cura uma fração do dano total causado neste golpe.
	var heal := CombatResolver.lifesteal_heal(data.stats.lifesteal, total_dmg)
	if heal > 0:
		data.heal(heal)
	if total_dmg > 0:                       # impacto: hit-stop + tremor (mais forte no finisher)
		Juice.hit_stop(get_tree(), 0.07 if is_finisher else 0.05)
		_shake(0.32 if is_finisher else 0.2)
		# Pogo: golpe pra baixo no ar que acerta impulsiona o player pra cima.
		if _attack_dir == Vector2.DOWN and not is_on_floor():
			velocity.y = POGO_BOUNCE

## Direção do golpe: pra baixo se estiver no ar segurando ↓/S; senão, o facing horizontal.
func _current_attack_dir() -> Vector2:
	if not is_on_floor() and Input.is_action_pressed("move_down"):
		return Vector2.DOWN
	return _facing

## Dano por COLISÃO: se a hitbox do player encostar na de QUALQUER inimigo (fora dos i-frames e do
## cooldown de contato), toma o golpe daquele inimigo, é empurrado para longe e pisca de branco.
## Um cooldown de CONTACT_CD segura o próximo hit por colisão.
func _check_contact_damage() -> void:
	if god_mode or _dodge_time > 0.0 or _contact_cd > 0.0:
		return
	var enemy := _overlapping_enemy()
	if enemy == null:
		return
	_contact_cd = CONTACT_CD
	var dmg := CombatResolver.enemy_hit(enemy.data.stats, data)
	data.take_damage(int(round(dmg)))
	var dir := signf(global_position.x - enemy.global_position.x)
	if dir == 0.0:
		dir = -signf(_facing.x) if _facing.x != 0.0 else 1.0
	_knockback = Vector2(dir * CONTACT_KNOCKBACK, 0.0)
	_flash_hit()
	_shake(0.2)

## Primeiro inimigo cuja hitbox sobrepõe a do player (query de forma à camada 2). null se nenhum.
func _overlapping_enemy() -> EnemyView:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(box_w, box_h)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var b: Variant = hit.get("collider")
		if b is EnemyView and b.data != null:
			return b
	return null

## Pisca de branco (filtro 60%) na arte, ou flash no placeholder ColorRect quando não há sprite.
func _flash_hit() -> void:
	if _sprite != null:
		Juice.flash_white(_sprite, 0.6)
	else:
		Juice.flash(_body, BASE_COLOR)

## Chamado pelo EnemyView quando o inimigo acerta o jogador.
func apply_enemy_hit(attacker_stats: StatBlock) -> void:
	if god_mode or _dodge_time > 0.0:   # i-frames durante a esquiva
		return
	var dmg := CombatResolver.enemy_hit(attacker_stats, data)
	data.take_damage(int(round(dmg)))
	if _sprite != null:
		Juice.flash_modulate(_sprite)
	else:
		Juice.flash(_body, BASE_COLOR)
	_shake(0.15)

## Dano FIXO (ignora defesa) — usado por habilidades (ex.: AoE do Necromante). Respeita a
## esquiva (i-frames) e o god mode, igual ao golpe comum.
## Retorna true se o dano conectou; false se foi ignorado (esquiva/god) — deixa quem chama
## (ex.: a rocha do ogro) saber se deve sumir ou passar reto pelo player.
func apply_flat_damage(amount: int) -> bool:
	if god_mode or _dodge_time > 0.0:
		return false
	data.take_damage(amount)
	if _sprite != null:
		Juice.flash_modulate(_sprite)
	else:
		Juice.flash(_body, BASE_COLOR)
	_shake(0.25)
	return true

## Tremor de tela via a câmera ativa (GameCamera). Sem câmera, é no-op.
func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam is GameCamera:
		(cam as GameCamera).add_trauma(amount)

func _reach() -> float:
	var base := data.weapon.attack_range if (data and data.weapon and data.weapon.attack_range > 0.0) else 40.0
	return base * ViewScale.WORLD

## Inimigos no alcance AGORA, na direção atual do golpe — consulta síncrona à física (sem o
## atraso de 1 frame do Area2D, que fazia o hit e a animação divergirem ao trocar de direção
## e atacar no mesmo frame). Usa o mesmo _attack_dir da anim de ataque, então os dois concordam.
func _enemies_in_reach() -> Array:
	var reach := _reach()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(reach, HIT_HEIGHT)     # comprido na direção do golpe, altura fixa (talho horizontal)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	# Retângulo rotacionado p/ apontar na direção do golpe (RIGHT/LEFT, ou DOWN no pogo aéreo),
	# centrado a meio alcance à frente — assim o comprimento acompanha a lâmina desenhada.
	query.transform = Transform2D(_attack_dir.angle(), global_position + _attack_dir * (reach * 0.5))
	query.collision_mask = 2
	query.collide_with_bodies = true
	var result: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var b: Variant = hit.get("collider")
		if b is EnemyView and b.data != null:
			result.append(b)
	return result
