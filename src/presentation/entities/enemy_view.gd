## Apresentação do inimigo (§2.3). IA "aggressive": persegue o alvo e ataca em janelas
## fixas quando ao alcance. Visual e barra de HP montados via código (placeholders).
## BossView estende esta classe: customiza tamanho/cor e usa o hook _on_after_damage().
class_name EnemyView
extends CharacterBody2D

signal died

const ATTACK_RANGE := 30.0         # base 640×360
const AGGRO_RANGE := 250.0         # padrão de despertar (data-driven via "aggro_range" no JSON)
# O passo à frente do golpe: o inimigo AVANÇA ao atacar, em vez de bater parado. É o que dá peso
# ao golpe e o que impede o jogador de ficar seguro parado a um pixel do alcance — para recuar,
# ele tem de recuar de verdade. Fração do alcance de gatilho, então quem tem arma longa avança mais.
# (nome _step_*, e não _lunge_*, porque o Ogro já tem um _lunge_dir próprio para a passada do
# golpe dele — e uma subclasse não pode redeclarar membro do pai.)
const STEP_FRACTION := 0.55       # do attack_range
const STEP_TIME := 0.16           # duração do impulso (s)
const ATTACK_VRANGE := 30.0        # alcance vertical: não acerta quem está acima (pogo)
const ATTACK_INTERVAL := 1.0
const WINDUP := 0.18               # 180 ms de aviso ("!") antes do golpe conectar (janela p/ desviar)
const GRAVITY := 1400.0            # mesma gravidade do player (side-scroller plano)
const LEDGE_AHEAD := 12.0          # o quanto à frente dos pés ele tateia por chão (base 640×360)
const LEDGE_DEPTH := 20.0          # o quanto abaixo dos pés ainda conta como "tem chão".
                                   # Precisa ser MENOR que a fundura dos poços (hazards.json),
                                   # senão o sensor enxerga o fundo do buraco e ele anda pra dentro.

var data: Enemy                     # entidade Core
var target: Node2D                  # quem perseguir (o PlayerView)
var dormant := false                # passivo: não persegue nem ataca até ser ativado (elites em estágio)
# --- Remontagem (esqueletos sob um Necromante) ---
# >0 = este esqueleto NÃO MORRE: ao zerar a vida ele DESABA em ossos ali mesmo e se remonta,
# inteiro, depois deste tanto de segundos. Enquanto está caído é um monte de ossos: não anda, não
# ataca e não recebe dano — bater nele é desperdiçar golpe. Só matando o Necromante ele morre de
# verdade (floor_scene chama final_death). 0 = morte normal, como qualquer inimigo.
var reassemble_time := 0.0
var _downed := 0.0                  # segundos restantes de "monte de ossos" (0 = de pé)
var aggro_range := AGGRO_RANGE      # a que distância desperta (dormente → agressivo)
var attack_step := STEP_FRACTION    # fração do alcance avançada no golpe (0 = bate parado)
var guard_drop := 0.0               # segundos sem guarda depois de atacar (0 = não tem guarda)
var combo_hits := 0                 # estocadas seguidas no ataque em combo (0 = só o golpe único)
var combo_interval := 0.28
var combo_every := 3
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
var _step := 0.0                   # impulso do passo à frente (px/s), decai em STEP_TIME
var _step_dir := 0.0
var _guard_down := 0.0              # >0 = guarda baixada (janela de punição)
var _atk_count := 0                 # ataques resolvidos: decide quando sai o combo
var _combo_left := 0                # estocadas restantes do combo em curso
var _combo_cd := 0.0
var _guard_fx: Node2D               # o escudo erguido, enquanto a guarda está de pé
var _morrendo := 0.0                # >0 = cadáver tombando (sem IA, sem colisão), até sumir
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
	if enemy != null and enemy.aggro_range > 0.0:
		aggro_range = enemy.aggro_range     # a que distância ele desperta (data-driven)
	if enemy != null and enemy.attack_step >= 0.0:
		attack_step = enemy.attack_step     # passo do golpe (0 = bate parado)
	if enemy != null:
		guard_drop = enemy.guard_drop
		combo_hits = enemy.combo_hits
		combo_interval = enemy.combo_interval
		combo_every = enemy.combo_every
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

	# Cadáver: só a queda corre. Nada de perseguir, atacar ou tomar dano.
	if _morrendo > 0.0:
		_morrendo -= delta
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		if _morrendo <= 0.0:
			queue_free()
		return

	_guard_down = maxf(0.0, _guard_down - delta)
	_atualiza_escudo()

	# COMBO em curso: parado, soltando estocada após estocada. Ficar imóvel é o que dá ao jogador
	# a leitura de que este é o golpe LONGO — e a saída, que é sair de perto em vez de trocar.
	if _combo_left > 0 and _downed <= 0.0:
		_combo_cd -= delta
		velocity.x = 0.0
		move_and_slide()
		if _combo_cd <= 0.0:
			_combo_left -= 1
			_golpe(signf(target.global_position.x - global_position.x), false)
			_combo_cd = combo_interval
		_update_sprite(target.global_position.x - global_position.x, false)
		return

	# Monte de ossos: só a gravidade age. Nada de perseguir, atacar ou tomar dano — ele espera.
	if _downed > 0.0:
		_downed -= delta
		velocity.x = 0.0
		move_and_slide()
		if _downed <= 0.0:
			_rise()
		return

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
	if absf(dx) > trigger_range():
		# Beira de buraco: o inimigo não pula. Sem chão adiante ele PARA na borda, em vez de
		# despencar no poço de espinhos e ficar preso lá para sempre. De quebra, o poço vira
		# terreno tático: dá para separar a horda pondo um buraco no meio.
		if is_on_floor() and _ledge_ahead(signf(dx)):
			velocity.x = 0.0
		else:
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
	velocity.x += _knockback.x + _step * _step_dir
	_knockback = _knockback.lerp(Vector2.ZERO, 0.2)   # recuo decai rápido
	_step = maxf(0.0, _step - (_step_v0() / STEP_TIME) * delta)   # decai linear até zerar em STEP_TIME
	move_and_slide()
	_update_sprite(dx, moving)

## Tem um vão logo à frente? Lança um raio curto para baixo, um pouco adiante dos pés: se ele
## não encontrar terreno (camada 4) dentro de LEDGE_DEPTH, ali começa um buraco.
func _ledge_ahead(dir: float) -> bool:
	if dir == 0.0:
		return false
	var feet := global_position.y + box_h * 0.5
	var from := Vector2(global_position.x + dir * (box_w * 0.5 + LEDGE_AHEAD), feet - 4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_DEPTH), 4)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

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
	_atk_count += 1
	# Atacar CUSTA a guarda: é o preço de sair de trás do escudo, e a janela em que se leva dano.
	if guard_drop > 0.0:
		_guard_down = guard_drop
	# A cada `combo_every` ataques sai a sequência longa. Alternância fixa, sem sorteio: num
	# soulslike o padrão do inimigo é para ser APRENDIDO, e o que sorteia não se aprende.
	if combo_hits > 1 and _atk_count % combo_every == 0:
		_combo_left = combo_hits - 1
		_combo_cd = combo_interval
	_golpe(dx, true)

## Uma estocada: o passo à frente, o dano se estiver ao alcance, a animação, o efeito e o som.
## `com_passo` é falso nas estocadas seguintes de um combo — ele já avançou na primeira.
func _golpe(dx: float, com_passo: bool) -> void:
	# O passo à frente: sai JUNTO com o golpe, não no windup — o windup é a janela de fuga, e um
	# inimigo que já avançasse nela tiraria do jogador o tempo que o "!" promete.
	if com_passo and dx != 0.0:
		_step_dir = signf(dx)
		_step = _step_v0()
	if is_instance_valid(target):
		var in_range := absf(dx) <= _effective_hit_range() \
			and absf(target.global_position.y - global_position.y) <= ATTACK_VRANGE
		if in_range and target.has_method("apply_enemy_hit"):
			target.apply_enemy_hit(data.stats)
	_play_attack_anim()
	_spawn_attack_fx(dx)
	# Som do golpe (id no JSON do inimigo; vazio = mudo). Sem variação explícita, o Sfx faz o
	# rodízio das variações — golpes seguidos não repetem o mesmo som.
	if data != null:
		Sfx.play(data.attack_sfx)

## Velocidade inicial do passo à frente. O impulso decai LINEAR até zerar, então a distância
## percorrida é a área do triângulo (v0·t/2) — daí o fator 2, sem o qual o passo cobriria metade
## do que a constante promete.
func _step_v0() -> float:
	return 2.0 * step_distance() / STEP_TIME

## Até onde o golpe ACERTA de fato, contando o passo. O dano é resolvido no instante em que o
## windup acaba, mas o inimigo ainda vai avançar step_distance() com a lâmina no ar — e o arco do
## efeito é filho DELE, então viaja junto. Sem somar o passo aqui, o golpe conectava na tela e
## errava nos números: o alcance de acerto era conferido contra a distância de ANTES do avanço.
func _effective_hit_range() -> float:
	return _hit_range() + step_distance()

## Quanto o inimigo cobre com o passo do golpe. É o que separa o alcance de ACERTO (attack_range)
## do alcance de GATILHO: ele decide atacar de mais longe justamente porque vai avançar.
func step_distance() -> float:
	return attack_step * attack_range

## De onde ele decide golpear: o alcance do golpe MAIS o que o passo cobre. Sem somar o passo, um
## inimigo que avança acertaria de lugares de onde nunca se dispôs a atacar — e um que não avança
## (passo 0) volta a mirar exatamente no próprio alcance.
func trigger_range() -> float:
	return attack_range + step_distance()

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
	if _downed > 0.0 or _morrendo > 0.0:
		return                      # um monte de ossos não sangra: o golpe passa reto
	# GUARDA: de escudo erguido, o golpe não passa. A janela para feri-lo é logo DEPOIS de ele
	# atacar — atacar custa a guarda. É o que transforma este inimigo de "bater até cair" em
	# "esperar o golpe dele e responder", que é a conversa que um soulslike quer ter.
	if esta_em_guarda():
		Juice.burst(get_parent(), global_position, Color(0.92, 0.94, 1.0), 8, 90.0)
		Sfx.play(data.hurt_sfx)
		if is_instance_valid(target):
			var d := signf(global_position.x - target.global_position.x)
			_knockback = Vector2((d if d != 0.0 else 1.0) * KNOCKBACK_FORCE * 0.35, 0.0)
		return
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
		if reassemble_time > 0.0:
			_collapse()             # sob o Necromante: desaba, não morre
			return
		_morrer()

## O escudo erguido, desenhado à frente do corpo. Sem ele o bloqueio seria invisível: o jogador
## veria o golpe conectar e nada acontecer, e concluiria que o jogo está quebrado.
func _atualiza_escudo() -> void:
	if guard_drop <= 0.0:
		return
	var deve := esta_em_guarda()
	if deve and not is_instance_valid(_guard_fx):
		_guard_fx = Node2D.new()
		_guard_fx.z_index = 5
		add_child(_guard_fx)
		var e := ColorRect.new()
		e.color = Color(0.62, 0.66, 0.74)
		e.size = Vector2(4.0, 22.0)
		e.position = Vector2(-2.0, -box_h * 0.5 - 11.0)
		_guard_fx.add_child(e)
		var b := ColorRect.new()
		b.color = Color(0.82, 0.86, 0.92)
		b.size = Vector2(4.0, 5.0)
		b.position = Vector2(0.0, 4.0)
		e.add_child(b)
	elif not deve and is_instance_valid(_guard_fx):
		_guard_fx.queue_free()
		_guard_fx = null
	if is_instance_valid(_guard_fx):
		# Sempre do lado do jogador: um escudo pelas costas não faria sentido.
		var d := 1.0
		if is_instance_valid(target):
			d = signf(target.global_position.x - global_position.x)
		_guard_fx.position.x = (d if d != 0.0 else 1.0) * (box_w * 0.5 + 3.0)

## MORTE. O corpo tomba no chão e some — a mesma leitura do esqueleto que desaba sob o
## Necromante, agora para todo inimigo e para o chefe. Antes o inimigo simplesmente PISCAVA para
## fora da existência no frame do golpe fatal, o que roubava do jogador o instante que ele acabou
## de conquistar.
##
## O sinal `died` sai NA HORA, não no fim da queda: é dele que dependem a contagem da sala, as
## almas e a abertura das portas do chefe. Só o nó sobrevive mais um instante, já sem colisão e
## sem IA — um cadáver, não um inimigo.
const MORTE_QUEDA := 0.55

func _morrer() -> void:
	if _morrendo > 0.0:
		return
	_morrendo = MORTE_QUEDA
	_windup = 0.0
	_combo_left = 0
	_hide_warn()
	if is_instance_valid(_guard_fx):
		_guard_fx.queue_free()
	collision_layer = 0                 # deixa de ser alvo e de empurrar quem passa
	collision_mask = 0
	if _hp_bar != null:
		_hp_bar.visible = false
	Juice.burst(get_parent(), global_position, body_color, 16, 140.0)
	var alvo: CanvasItem = _sprite if _sprite != null else _body
	if alvo != null:
		var tw := create_tween()
		tw.tween_property(alvo, "rotation", PI * 0.5, MORTE_QUEDA * 0.45).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(alvo, "modulate", Color(0.72, 0.70, 0.62, 0.9), MORTE_QUEDA * 0.45)
		tw.tween_property(alvo, "modulate:a", 0.0, MORTE_QUEDA * 0.55)
	died.emit()

## De guarda? Só quem tem a mecânica, está desperto, vivo e fora da janela pós-ataque.
func esta_em_guarda() -> bool:
	return guard_drop > 0.0 and _guard_down <= 0.0 and not dormant and _downed <= 0.0

## Desaba num monte de ossos, no lugar exato onde caiu. Não emite `died`: para a sala, este
## esqueleto continua existindo — é isso que faz o Necromante ser o único objetivo real.
func _collapse() -> void:
	_downed = reassemble_time
	data.stats.current_hp = 0        # zera o excedente: caído é caído, não "-99929 de vida"
	_windup = 0.0
	if is_instance_valid(_warn):
		_warn.queue_free()
	Juice.burst(get_parent(), global_position, body_color, 14, 120.0)
	Sfx.play(data.death_sfx)
	# Achatado no chão e apagado: lê como pilha de ossos, e deixa claro que não é alvo.
	if _sprite != null:
		_sprite.rotation = PI * 0.5
		_sprite.modulate = Color(0.72, 0.70, 0.62, 0.85)
	else:
		_body.rotation = PI * 0.5
	if _hp_bar != null:
		_hp_bar.visible = false

## Remonta: vida cheia, de pé, no mesmo lugar. O jogador que "matou" e seguiu adiante tem um
## inimigo novo pelas costas — é o preço de ignorar o Necromante.
func _rise() -> void:
	_downed = 0.0
	data.stats.current_hp = data.stats.max_hp
	_refresh_hp_bar()
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.modulate = Color.WHITE
	else:
		_body.rotation = 0.0
	if _hp_bar != null:
		_hp_bar.visible = hp_bar_visible
	Juice.burst(get_parent(), global_position, body_color, 12, 110.0)

## O Necromante caiu: acaba a remontagem e este esqueleto morre de verdade, esteja de pé ou caído.
func final_death() -> void:
	reassemble_time = 0.0
	_downed = 0.0
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
