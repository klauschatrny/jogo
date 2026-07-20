## Apresentação do jogador (§2.3). Side-scroller de chão plano: A/D anda, Espaço/W pula,
## J ataca (combo de 3 golpes; pra baixo no ar = pogo), Shift esquiva (dash direcional
## com i-frames + rastro). Monta o próprio visual/colisão via código (placeholder ColorRect
## — spritesheet entra na Leva 4). A lógica de combate vive no Core (CombatResolver).
class_name PlayerView
extends CharacterBody2D

const SIZE := 20.0               # footprint do player (base 640×360)
const BASE_COLOR := Palette.PLAYER
const SPRITE_ID := "player"      # arte: assets/sprites/player/player.png + data/sprites/player.json

# Feel de movimento (constantes de apresentação no espaço base 640×360).
const GRAVITY := 1400.0
const CLIMB_SPEED := 70.0          # velocidade de subida/descida na escada (base 640×360)
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
const ATTACK_SFX := "player_attack"        # 3 sons = os 3 passos do combo, na ordem (ver _attack)
const DODGE_SFX := "player_dodge"          # rolamento
const FOOTSTEPS_SFX := "player_footsteps"  # passadas avulsas, uma por apoio do pé (ver STEP_FRAMES)
const STEP_FRAMES: Array[int] = [0, 5]     # quadros da anim "run" em que um pé APOIA no chão
const HIT_HEIGHT := 56.0         # altura do retângulo de dano; o comprimento vem do attack_range da arma

var data: Player                    # entidade Core
var god_mode := false               # debug: ignora dano recebido
var frozen := false                 # cutscene: sem input, sem ataque, sem dano por colisão
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
var _knockback := Vector2.ZERO     # empurrão horizontal (decai); somado à velocidade
var _attack_cost := 20.0           # custo de stamina por golpe (data-driven via balance.json)
var _dodge_cost := 30.0            # custo de stamina por esquiva
var _drink_time := 0.0             # >0 enquanto bebe o frasco: parado e vulnerável (sem i-frames)
var _drink_heal := 0               # cura pendente, aplicada ao FIM do gesto (0 se interrompido)
var _drink_dur := 0.6              # duração do gesto de beber (data-driven; ou os frames da anim)
var _drink_glow: ColorRect        # aura laranja do gole de cura (Estus): brilha atrás do corpo
var _drink_total := 0.0           # duração total do gole atual (para o progresso da aura)
var _drink_ember_cd := 0.0        # cadência das fagulhas laranja durante o gole
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
	_drink_dur = float(BalanceConfig.get_value("flask", "DRINK_TIME", 0.6))

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

	# Aura do gole de cura (Estus): fica ATRÁS do corpo/sprite (z -1), invisível até beber. A cada
	# gole ela acende e pulsa em laranja, com um clarão no instante em que a cura cai (ver _start_drink).
	# Mais larga que alta: o fator vertical é menor para a aura não estourar acima da cabeça/pés.
	var gsize := Vector2(box.x * 1.8, box.y * 1.15)
	_drink_glow = ColorRect.new()
	_drink_glow.color = Color(1.0, 0.55, 0.12, 0.0)
	_drink_glow.size = gsize
	_drink_glow.position = -0.5 * gsize
	_drink_glow.z_index = -1
	add_child(_drink_glow)

func _physics_process(delta: float) -> void:
	if data == null:
		return

	# Congelado (cutscene, ex.: entrada do boss): ignora input, ataque e dano por colisão.
	# Só a gravidade continua, para não flutuar caso seja congelado no ar.
	if frozen:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_play_anim("idle")
		_update_footsteps()
		return

	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_attack_move_lock = maxf(0.0, _attack_move_lock - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)

	# Aura do gole: fora do gesto (ou após ser interrompido), decai suavemente até sumir. Durante o
	# gole é o próprio bloco de beber que a acende (ver _update_drink_glow).
	if _drink_glow != null and _drink_time <= 0.0 and _drink_glow.color.a > 0.0:
		_drink_glow.color.a = maxf(0.0, _drink_glow.color.a - delta * 4.0)
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

	# (Encostar num inimigo NÃO fere: o dano vem só do golpe telegrafado dele — ver EnemyView.)

	# ESCADA: sobe/desce com cima/baixo, sem gravidade, preso ao eixo dela. Enquanto escala não
	# ataca nem esquiva — é o preço de estar numa escada, e é o que faz uma plataforma elevada
	# ser um lugar que se escolhe ocupar em vez de um atalho de graça.
	if _update_ladder(delta):
		return

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
		_update_footsteps()   # rolamento não são passos (a anim "dodge" já os cala)
		return

	# Frasco de cura (o Estus): beber TRAVA o jogador no lugar, SEM i-frames. A cura só cai no fim
	# do gesto; um golpe no meio zera _drink_heal (via _interrupt_drink) e a carga já era — o preço
	# de beber na hora errada. Fica plantado (velocidade horizontal zero).
	if _drink_time > 0.0:
		_drink_time -= delta
		velocity.x = 0.0
		move_and_slide()
		_update_footsteps()
		_play_anim("drink")
		_update_drink_glow(delta)
		if _drink_time <= 0.0 and _drink_heal > 0:
			data.heal(_drink_heal)
			_drink_heal = 0
			_drink_finish_fx()      # clarão + estouro de partículas laranja no instante da cura
		return

	# Começa a beber: no chão, fora de anim travada, com carga e com vida faltando.
	if Input.is_action_just_pressed("flask") and is_on_floor() and _anim_lock <= 0.0 and data.can_drink():
		_start_drink()
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
	_update_footsteps()

	# Não pode atacar durante a trava de anim (o próprio ataque ou o rolamento). O cooldown do combo
	# (dur+gap) já é maior que a animação, então isto não atrasa a sequência — só garante que a anim
	# termine e reprotege a esquiva de ser cancelada por ataque.
	if Input.is_action_pressed("attack") and _attack_cd <= 0.0 and _anim_lock <= 0.0 and _has_stamina():
		_attack()
		_spend_stamina(_attack_cost)

## Inicia o dash da esquiva: direção = input atual (permite esquivar pra trás), ou o facing.
func _start_dodge(ix: float) -> void:
	Sfx.play(DODGE_SFX)
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

## Começa a beber o frasco: COMPROMETE a carga já (a cura só vem no fim do gesto), trava a
## locomoção e o ataque pela duração, e reinicia a anim. Sem custo de stamina; SEM i-frames — é
## uma aposta de que há uma janela segura. Enemies são telegrafados, então essa janela existe.
func _start_drink() -> void:
	var amount := data.drink_flask()
	if amount <= 0:
		return
	_drink_heal = amount
	_drink_time = _drink_dur
	_hit_pending = false            # cancela qualquer golpe pendente
	_combo = 0
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("drink"):
		_sprite.play("drink")
		_sprite.frame = 0
		var fc := _sprite.sprite_frames.get_frame_count("drink")
		var spd := _sprite.sprite_frames.get_animation_speed("drink")
		_drink_time = float(fc) / maxf(spd, 0.1)
	_anim_lock = _drink_time
	_attack_move_lock = _drink_time
	# Acende a aura do gole: guarda a duração total (para o progresso) e dá um brilho inicial suave.
	_drink_total = _drink_time
	_drink_ember_cd = 0.0
	if _drink_glow != null:
		_drink_glow.color.a = 0.12

## Um golpe recebido no meio do gole CANCELA a cura — a carga já foi gasta. Chamado dos caminhos de
## dano (colisão, golpe de inimigo, dano fixo): a punição por beber na hora errada.
func _interrupt_drink() -> void:
	_drink_time = 0.0
	_drink_heal = 0
	# A aura não é apagada aqui: o decaimento em _physics_process a esvanece sozinho (gole cortado).

## Aura laranja durante o gole: a opacidade cresce com o progresso do gesto e pulsa, e fagulhas
## laranja sobem em cadência. É o "brilho" do Estus.
func _update_drink_glow(delta: float) -> void:
	if _drink_glow == null:
		return
	var prog := 1.0 - clampf(_drink_time / maxf(_drink_total, 0.001), 0.0, 1.0)   # 0→1 ao longo do gole
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.10 * (0.5 + 0.5 * sin(t * 20.0))
	_drink_glow.color.a = clampf(0.14 + 0.48 * prog + pulse, 0.0, 0.82)
	_drink_ember_cd -= delta
	if _drink_ember_cd <= 0.0:
		_drink_ember_cd = 0.14
		Juice.burst(get_parent(), global_position + Vector2(0.0, -box_h * 0.2), Color(1.0, 0.62, 0.18), 3, 55.0)

## Clarão + estouro de partículas laranja no instante em que a cura cai (fim do gole). O decaimento
## em _physics_process apaga o clarão em seguida.
func _drink_finish_fx() -> void:
	if _drink_glow != null:
		_drink_glow.color.a = 0.82
	Juice.burst(get_parent(), global_position + Vector2(0.0, -box_h * 0.25), Color(1.0, 0.70, 0.25), 20, 130.0)

## Vira o sprite conforme a direção (no-op sem sprite).
## Escadas do nível (o floor_scene as entrega ao remontar o cenário).
var ladders: Array = []
var _on_ladder: LadderView = null

## Devolve true se ESTE frame foi consumido pela escada (montado nela).
##
## Contrato: ENTRA com INTERAGIR (E), SOBE/DESCE com cima/baixo, e SÓ SAI pelas duas pontas —
## chegando ao tabuleiro em cima ou pisando o chão embaixo. Não há como pular fora nem escorregar
## para o lado. Isso resolve o conflito de teclas de raiz: montado, o frame inteiro pertence à
## escada, então W não chega ao pulo e não há como soltar sem querer no meio da subida. E também
## é mais honesto — uma escada de que se cai ao encostar em qualquer tecla não é uma escada.
func _update_ladder(delta: float) -> bool:
	if _dodge_time > 0.0 or _drink_time > 0.0:
		return false                      # gestos comprometidos têm prioridade

	# MONTAR: só com INTERAGIR, com os PÉS NO CHÃO e estando na faixa dela. A exigência de estar
	# apoiado é o que impede agarrar a escada no meio de um pulo — o que daria de graça exatamente
	# a subida vertical que a escada deveria cobrar, e permitiria alcançar o tabuleiro pelo ar.
	# Serve para as duas pontas: embaixo o chão, em cima o próprio tabuleiro.
	if _on_ladder == null:
		if not Input.is_action_just_pressed("interact") or not is_on_floor():
			return false
		for l in ladders:
			if is_instance_valid(l) and l.contem(global_position):
				_on_ladder = l
				l.em_uso = true
				break
		if _on_ladder == null:
			return false

	if not is_instance_valid(_on_ladder):
		_on_ladder = null
		return false

	var iy := Input.get_axis("move_up", "move_down")
	global_position.x = _on_ladder.eixo_x()   # alinha ao eixo: nada de subir raspando a parede
	velocity.x = 0.0
	velocity.y = iy * CLIMB_SPEED

	# SAÍDA 1 — o topo: sobe no tabuleiro. Precisa deslocar em X também, porque a escada encosta
	# na borda de FORA da plataforma; terminar a subida no eixo dela deixaria o jogador no ar.
	if iy < 0.0 and global_position.y <= _on_ladder.topo_y():
		global_position = Vector2(_on_ladder.saida_x(), _on_ladder.topo_y() - 6.0)
		_soltar_escada()
		return false

	move_and_slide()

	# SAÍDA 2 — a base: desceu até o chão.
	if iy > 0.0 and is_on_floor():
		_soltar_escada()
		return false

	_play_anim("idle" if iy == 0.0 else "run")
	return true

func _soltar_escada() -> void:
	if is_instance_valid(_on_ladder):
		_on_ladder.em_uso = false
	_on_ladder = null
	velocity = Vector2.ZERO

func _flip(dir: Vector2) -> void:
	if _sprite != null and dir.x != 0.0:
		# XOR com a direção em que a arte foi desenhada (_faces_left), igual ao EnemyView.
		_sprite.flip_h = (dir.x < 0.0) != _faces_left

func _play_anim(anim: String) -> void:
	SpriteLoader.play_safe(_sprite, anim)

var _step_index := 0        # rodízio das passadas do arquivo (1ª, 2ª, 3ª, 1ª...)
var _last_step_frame := -1  # último quadro visto (dispara UMA vez por quadro, não por tick)

## Passos sincronizados com a ANIMAÇÃO: um som de passada dispara no exato quadro em que um pé
## apoia no chão (STEP_FRAMES da anim "run"). `Sfx.play_step` recorta UMA passada do arquivo por
## vez, no tom original, então o som acompanha qualquer fps da animação — mude o fps no manifesto
## e a cadência sonora segue junto. Pular/rolar/atacar/beber trocam a anim, o que já cala os
## passos sem condição extra (por isso a função não precisa mais do move_x).
func _update_footsteps() -> void:
	if _sprite == null or _sprite.animation != "run" or not is_on_floor():
		_last_step_frame = -1
		return
	var f := _sprite.frame
	if f == _last_step_frame:
		return
	_last_step_frame = f
	if f in STEP_FRAMES:
		Sfx.play_step(FOOTSTEPS_SFX, _step_index)
		_step_index += 1

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

	# Som do golpe: a variação É o passo do combo — os 3 sons saem em sequência (1º, 2º, 3º) e a
	# sequência recomeça. Parar deixa o combo expirar (_combo_timer) e o próximo golpe volta ao 1º.
	Sfx.play(ATTACK_SFX, step)

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

## Chamado pelo EnemyView quando o inimigo acerta o jogador.
func apply_enemy_hit(attacker_stats: StatBlock) -> void:
	if god_mode or _dodge_time > 0.0:   # i-frames durante a esquiva
		return
	_interrupt_drink()                  # um golpe no meio do gole cancela a cura
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
	_interrupt_drink()                  # dano fixo (ex.: rocha do ogro) também corta o gole
	data.take_damage(amount)
	if _sprite != null:
		Juice.flash_modulate(_sprite)
	else:
		Juice.flash(_body, BASE_COLOR)
	_shake(0.25)
	return true

## Morte INSTANTÂNEA — cair num poço. Ao contrário de todo o resto do dano, ignora os i-frames da
## esquiva: rolar não salva ninguém de um buraco (você já está lá dentro; a esquiva não é um pulo).
## O god mode (debug) continua valendo. Retorna true se matou.
func kill() -> bool:
	if god_mode or data == null or not data.is_alive():
		return false
	data.take_damage(data.stats.current_hp)   # zera a vida → EventBus.player_died
	_shake(0.6)
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
