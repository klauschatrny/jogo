## Ogro (boss). Habilidades NORMAIS escolhidas por DISTÂNCIA do player (dx horizontal):
##  - ≤ 140px (zona comum baderna+melee): sorteia golpe melee (que por sua vez é golpe único OU
##    combo de 3, 50/50 — cada golpe dá um passo à frente) ou baderna.
##  - 140–250px: aproxima (nenhuma habilidade nessa faixa).
##  - 250–560px (zona de rochas): arremesso de 3 rochas (25 de dano cada); cooldown próprio de 8s.
##  - > 560px: aproxima.
## Nas zonas exclusivas ele SEMPRE usa a habilidade daquela zona; só sorteia na zona comum.
## O golpe melee persegue o player durante o windup e dá um PASSO à frente ao conectar (avançando
## comprometido); a baderna e as rochas ficam paradas. Entre QUALQUER habilidade normal há um cooldown global de 1s — durante ele o ogro
## anda em direção ao player (só para para castar quando o cooldown zera). Cada instância de dano
## recebida DURANTE o cooldown corta 0.4s dele (quanto mais apanha, mais rápido revida); dano fora
## do cooldown não conta. Detalhes:
##  - Arremesso de rochas — windup inicial 1s e 0.9s entre os arremessos; rocha voa reta até o player.
##    Além do cooldown global, tem cooldown PRÓPRIO de 8s (na faixa de rochas, se em cooldown, aproxima).
##  - Baderna — 6 golpes alternando lados (3 direita / 3 esquerda); windup inicial 1s, 0.3s entre.
##    É longa: tem cooldown PRÓPRIO de 6s (após uma baderna, o sorteio só dá melee até ele zerar).
## Habilidade ESPECIAL: ao cruzar 50%/35%/15% de vida ele entra em fúria e faz uma INVESTIDA
## ÚNICA — no windup rastreia o lado do player e TRAVA a direção a 200 ms do fim; corre cegamente
## (200% da vel. do player) e causa dano UMA vez quando a hitbox toca a do player, SEM parar por
## isso (atravessa); depois fica imóvel e cansado por 3s (encerra ao bater na parede ou por timeout).
class_name OgreView
extends BossView

const THRESHOLDS := [0.5, 0.35, 0.15]   # % de vida que disparam a investida
const CHARGE_SPEED_MULT := 2.0          # 200% da velocidade do player
const LOCK_AT_REMAINING := 0.2          # trava a direção quando faltam 200 ms de windup
const CHARGE_DAMAGE := 50
const CHARGE_MAX_TIME := 2.0            # segurança: encerra a investida
const CHARGE_STEP_EVERY := 0.26         # cadência das passadas CORRENDO (andando é 1 por segundo)
const TIRED_TIME := 3.0                 # stun após a investida (a respiração ofegante dura o mesmo)

const ABILITY_GCD := 1.0                 # cooldown global entre QUALQUER cast de habilidade normal
const GCD_HIT_REDUCTION := 0.4           # cada dano recebido corta isto do cooldown atual

const ROCK_COUNT := 3                    # arremesso de rochas: quantidade
const ROCK_DAMAGE := 25
const ROCK_INITIAL_WINDUP := 1.0        # windup antes do 1º arremesso
const ROCK_BETWEEN_WINDUP := 0.9        # windup entre os arremessos
const ROCK_SPEED := 250.0
const ROCK_CD := 8.0                     # cooldown PRÓPRIO do arremesso de rochas (além do global)

const BADERNA_HITS := 6                  # 3 direita + 3 esquerda, intercalados
const BADERNA_INITIAL_WINDUP := 1.0
const BADERNA_BETWEEN := 0.3            # windup entre os golpes individuais
const BADERNA_CD := 6.0                 # cooldown PRÓPRIO: após uma baderna, só melee por este tempo
                                        # (ela é longa — sem isto, a 50/50, ocupa ~2/3 do tempo de luta)

# Golpe melee: sempre dá um PASSO à frente ao conectar (avança comprometido, na direção do player).
# Tem duas formas, sorteadas 50/50 ao iniciar: golpe ÚNICO ou COMBO de 3 (um passo em cada).
const MELEE_COMBO_HITS := 3             # golpes do combo
const MELEE_BETWEEN := 0.35            # windup (telegrafo) de cada golpe seguinte do combo
const MELEE_STEP_SPEED := 160.0        # velocidade do passo à frente ao golpear
const MELEE_STEP_TIME := 0.15          # duração do passo (≈ 24px por golpe)

const ROCK_MIN_RANGE := 250.0           # distância mínima p/ arremessar rochas
const ROCK_RANGE := 560.0               # distância máxima da zona de rochas
const ROCK_VRANGE := 200.0             # alcance vertical p/ arremessar (arena plana: quase irrestrito)
const BADERNA_RANGE := 140.0            # gatilho da baderna (≤ isto entra no sorteio com o melee) = attack_range

var _special := ""                      # "" | "windup" | "charge" | "tired" | "rocks" | "baderna" | "melee"
var _sp_windup := 0.0
var _charge_dir := 1.0
var _dir_locked := false
var _charge_speed := 0.0
var _charge_time := 0.0
var _charge_hit := false                # já causou o dano único desta investida?
var _tired := 0.0
var _next_threshold := 0

var _ability_timer := 0.0               # rochas/baderna/melee: tempo até o próximo arremesso/golpe
var _rock_left := 0
var _bad_left := 0
var _bad_side := 1.0
var _melee_left := 0                     # golpes restantes do combo melee (1 = golpe único)
var _melee_stepping := false            # true durante o passo à frente (logo após conectar o golpe)
var _lunge_dir := 1.0                    # direção do passo à frente do golpe
var _gcd := 0.0                         # cooldown global: bloqueia novo cast por ABILITY_GCD
var _rock_cd := 0.0                     # cooldown próprio das rochas (ROCK_CD)
var _baderna_cd := 0.0                  # cooldown próprio da baderna (BADERNA_CD) — só melee enquanto ativo
var _walking := false                   # anda NESTE frame? (só p/ o som dos passos — ver _process)
var _charge_step_t := 0.0               # tempo até a próxima passada da corrida
var _charge_step_i := 0                 # qual passada do ciclo (rodízio: não repete a mesma)
var _rage_pending := false              # limiar cruzado durante outra habilidade: fúria a cobrar

## Após cada dano: fases do BossView (enrage/summon) + checa os limiares da investida.
func _on_after_damage() -> void:
	super._on_after_damage()
	if _gcd > 0.0:                                # só encurta se HÁ cooldown ativo; dano fora dele não conta
		_gcd = maxf(0.0, _gcd - GCD_HIT_REDUCTION)   # apanhar acelera o próximo golpe
	if data == null:
		return
	var ratio := float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1))
	if _next_threshold >= THRESHOLDS.size() or ratio > float(THRESHOLDS[_next_threshold]):
		return
	while _next_threshold < THRESHOLDS.size() and ratio <= float(THRESHOLDS[_next_threshold]):
		_next_threshold += 1   # um golpe grande pode cruzar vários limiares de uma vez → UMA fúria

	# Cruzar o limiar NO MEIO de outra habilidade (ou de uma fúria em curso) não anula a fúria: ela
	# fica DEVENDO e entra assim que ele se liberta. Antes era descartada aqui — mas a fase "enrage"
	# do BossView (o tom vermelho) já tinha disparado no super e nunca mais se repete, então o ogro
	# ficava vermelho para sempre sem nunca investir nem gritar.
	if _special == "":
		_start_special()
	else:
		_rage_pending = true

func _physics_process(delta: float) -> void:
	# Passos: parte-se de "não está andando" e só quem ANDA neste frame reafirma (em _update_sprite).
	# Assim um estado novo que não mexa no sprite (a baderna é um) nunca deixa o som de passos preso.
	_walking = false

	# Dormente (cutscene de entrada): nenhuma habilidade, nem as de distância — o super trata
	# o estado passivo (só gravidade/recuo). Sem isto o ogro arremessaria rochas na cutscene.
	if dormant:
		super._physics_process(delta)
		return
	_rock_cd = maxf(0.0, _rock_cd - delta)         # cooldowns próprios (rochas/baderna) correm em qualquer estado
	_baderna_cd = maxf(0.0, _baderna_cd - delta)
	if _special == "":
		_gcd = maxf(0.0, _gcd - delta)   # cooldown global entre habilidades
		# Seleção por DISTÂNCIA: em média distância (zona de rochas) fica parado e arremessa;
		# perto/longe cai no super (aproxima e, ao alcance, sorteia melee/baderna).
		if data != null and is_instance_valid(target) and _handle_ranged(delta):
			return
		super._physics_process(delta)
		return
	if data == null or not is_instance_valid(target):
		return
	match _special:
		"windup": _tick_windup(delta)
		"charge": _tick_charge(delta)
		"tired": _tick_tired(delta)
		"rocks": _tick_rocks(delta)
		"baderna": _tick_baderna(delta)
		"melee": _tick_melee(delta)

func _start_special() -> void:
	_special = "windup"
	_sp_windup = windup_time
	_dir_locked = false
	_windup = 0.0                 # cancela qualquer windup normal em curso
	_show_warn()
	modulate = Color(1.6, 0.5, 0.5)   # enraivecido (vermelho forte)
	if data is Boss:
		Sfx.play((data as Boss).rage_sfx)   # o grito da fúria (id no JSON do boss; "" = mudo)

## Windup: parado, encarando; segue o lado do player até faltarem 200 ms, aí TRAVA a direção.
func _tick_windup(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	var dx := target.global_position.x - global_position.x
	if not _dir_locked:
		if dx != 0.0:
			_charge_dir = signf(dx)
		if _sp_windup <= LOCK_AT_REMAINING:
			_dir_locked = true
	_sp_windup -= delta
	_update_sprite(_charge_dir, false)
	if _sp_windup <= 0.0:
		_hide_warn()
		_begin_charge()

func _begin_charge() -> void:
	_special = "charge"
	_charge_time = 0.0
	_charge_hit = false
	_charge_speed = CHARGE_SPEED_MULT * _player_move_speed()
	_charge_step_t = 0.0     # a 1ª passada sai já no primeiro frame da corrida

## Corre cegamente na direção travada; causa dano (50) UMA vez quando a hitbox toca a do player,
## mas SEM parar por isso — segue atravessando. Só encerra ao bater na parede ou no tempo máximo.
func _tick_charge(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = _charge_dir * _charge_speed
	move_and_slide()
	_update_sprite(_charge_dir, true)
	_charge_time += delta
	_tick_charge_steps(delta)
	if not _charge_hit and _overlaps_player():
		_charge_hit = true
		if target.has_method("apply_flat_damage"):
			target.apply_flat_damage(CHARGE_DAMAGE)
		_spawn_attack_fx(_charge_dir)
		Juice.hit_stop(get_tree(), 0.05)
	# A investida acaba de dois jeitos: se espatifando na PAREDE (tem som e tremor) ou esgotando o
	# tempo no vazio (não bateu em nada — nada de som de impacto).
	if is_on_wall():
		Sfx.play((data as Boss).wall_hit_sfx if data is Boss else "")
		Juice.burst(get_parent(), global_position, Palette.BOSS, 16, 150.0)
		Juice.hit_stop(get_tree(), 0.06)
		_begin_tired()
	elif _charge_time >= CHARGE_MAX_TIME:
		_begin_tired()

func _begin_tired() -> void:
	_special = "tired"
	_tired = TIRED_TIME
	velocity.x = 0.0
	modulate = Color(0.7, 0.7, 0.95)   # cansado (apagado/azulado)
	Juice.burst(get_parent(), global_position, Palette.BOSS, 12, 110.0)
	if data is Boss:
		Sfx.play((data as Boss).tired_sfx)   # respiração ofegante (id no JSON do boss; "" = mudo)

## Imóvel e cansado; ao fim, volta ao normal (com um tom enraivecido persistente).
func _tick_tired(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	_update_sprite(_charge_dir, false)
	_tired -= delta
	if _tired <= 0.0:
		_special = ""
		_attack_cd = attack_interval        # reinicia o cooldown do ataque normal
		_gcd = ABILITY_GCD                   # cooldown global antes da próxima habilidade
		modulate = Color(1.25, 0.8, 0.8)     # segue com aparência enraivecida
		_flush_rage()   # apanhou tanto durante a investida que cruzou o próximo limiar → outra fúria

## Player em MÉDIA distância (zona de rochas): fica parado, encara e arremessa quando o cooldown
## zera. Retorna true se tratou o frame (nem perto p/ melee, nem longe p/ aproximar).
func _handle_ranged(delta: float) -> bool:
	if _gcd > 0.0 or _rock_cd > 0.0:
		return false   # cooldown global ou das rochas: anda até o player (deixa o super cuidar)
	var dx := target.global_position.x - global_position.x
	var dy := target.global_position.y - global_position.y
	var dist := absf(dx)
	if dist < ROCK_MIN_RANGE or dist > ROCK_RANGE or absf(dy) > ROCK_VRANGE:
		return false   # fora da faixa de rochas (perto → melee, ou longe → aproxima): super cuida
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = _knockback.x
	_knockback = _knockback.lerp(Vector2.ZERO, 0.2)
	move_and_slide()
	_update_sprite(dx, false)
	_start_rocks()   # zona de rochas com o cooldown pronto: para e arremessa
	return true

## Ao alcance de gatilho melee (≤ attack_range) e com o cooldown pronto, escolhe a habilidade
## corpo-a-corpo por ZONA: ≤ BADERNA_RANGE é zona comum (sorteia melee/baderna); acima dela,
## até attack_range, é exclusiva do melee. Rochas ficam para a média distância (ver _handle_ranged).
func _start_windup() -> void:
	if _gcd > 0.0:
		return
	var dist := absf(target.global_position.x - global_position.x)
	# Baderna só entra no sorteio se o cooldown próprio dela estiver pronto — senão é melee. Assim
	# ela não se repete em sequência (é longa, e a 50/50 dominava o tempo de luta).
	if dist <= BADERNA_RANGE and _baderna_cd <= 0.0 and randi() % 2 == 1:
		_start_baderna()
	else:
		_start_melee()

## --- Golpe melee: persegue durante o windup, CONECTA, e dá um PASSO à frente (lunge). Sorteia
## entre um golpe ÚNICO e um COMBO de 3 (um passo em cada, cada golpe com seu próprio windup). ---
func _start_melee() -> void:
	_special = "melee"
	_melee_left = MELEE_COMBO_HITS if randi() % 2 == 0 else 1   # 50%: combo de 3; 50%: golpe único
	_melee_stepping = false
	_ability_timer = windup_time
	_show_warn()

func _tick_melee(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var dx := target.global_position.x - global_position.x

	# Passo à frente: logo depois de conectar, avança comprometido na direção travada do golpe.
	if _melee_stepping:
		velocity.x = _lunge_dir * MELEE_STEP_SPEED
		move_and_slide()
		_update_sprite(_lunge_dir, true)
		_ability_timer -= delta
		if _ability_timer <= 0.0:
			_melee_stepping = false
			if _melee_left > 0:
				_ability_timer = MELEE_BETWEEN   # próximo golpe do combo, com seu próprio telegrafo
				_show_warn()
			else:
				_end_normal_ability()
		return

	# Windup: persegue o player, encarando-o, até o golpe conectar.
	velocity.x = signf(dx) * float(data.stats.move_speed)
	move_and_slide()
	_update_sprite(dx, true)
	_ability_timer -= delta
	if _ability_timer <= 0.0:
		_hide_warn()
		_resolve_melee()                         # dano + anim + fx
		_lunge_dir = signf(dx) if dx != 0.0 else _facing()
		_melee_left -= 1
		_melee_stepping = true                   # entra no passo à frente (dura MELEE_STEP_TIME)
		_ability_timer = MELEE_STEP_TIME

## Conecta o golpe se o player estiver no alcance de DANO (_hit_range) horizontal e vertical.
func _resolve_melee() -> void:
	if not is_instance_valid(target):
		return
	var dx := target.global_position.x - global_position.x
	var dy := target.global_position.y - global_position.y
	if absf(dx) <= _hit_range() and absf(dy) <= ATTACK_VRANGE:
		if target.has_method("apply_enemy_hit"):
			target.apply_enemy_hit(data.stats)
	_play_attack_anim()
	_spawn_attack_fx(dx)

func _end_normal_ability() -> void:
	_hide_warn()
	_special = ""
	_attack_cd = attack_interval   # reinicia o cooldown do ataque normal
	_gcd = ABILITY_GCD             # cooldown global antes da próxima habilidade
	_flush_rage()                  # fúria que ficou devendo entra agora

## Cobra a fúria adiada (limiar cruzado no meio de outra habilidade). O cooldown global NÃO a
## segura: a investida é a reação dele a ter apanhado demais, não uma habilidade da rotação.
func _flush_rage() -> void:
	if _rage_pending and _special == "":
		_rage_pending = false
		_start_special()

## --- Arremesso de rochas: parado, 3 rochas na direção do player (windup 1s, depois 0.9s entre) ---
func _start_rocks() -> void:
	_special = "rocks"
	_rock_left = ROCK_COUNT
	_ability_timer = ROCK_INITIAL_WINDUP
	_rock_cd = ROCK_CD   # dispara o cooldown próprio das rochas
	_show_warn()

func _tick_rocks(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	_update_sprite(target.global_position.x - global_position.x, false)
	_ability_timer -= delta
	if _ability_timer > 0.0:
		return
	_hide_warn()
	_throw_rock()
	_rock_left -= 1
	if _rock_left > 0:
		_ability_timer = ROCK_BETWEEN_WINDUP
		_show_warn()
	else:
		_end_normal_ability()

func _throw_rock() -> void:
	if not is_instance_valid(target):
		return
	var origin := global_position + Vector2(0.0, -box_h * 0.5)   # altura do arremesso
	var dir: Vector2 = (target.global_position - origin)
	if dir.length() < 0.001:
		dir = Vector2(_facing(), 0.0)
	var rock := OgreRock.new()
	get_parent().add_child(rock)
	rock.global_position = origin
	rock.setup(dir, ROCK_SPEED, ROCK_DAMAGE, target)
	_play_attack_anim()

## --- Baderna: parado, 6 golpes alternando lados (3 dir / 3 esq); windup 1s, 0.1s entre golpes ---
func _start_baderna() -> void:
	_special = "baderna"
	_bad_left = BADERNA_HITS
	_ability_timer = BADERNA_INITIAL_WINDUP
	_bad_side = signf(target.global_position.x - global_position.x)   # começa no lado do player
	if _bad_side == 0.0:
		_bad_side = 1.0
	_show_warn()

func _tick_baderna(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	_ability_timer -= delta
	if _ability_timer > 0.0:
		return
	_hide_warn()
	_baderna_hit(_bad_side)
	_bad_side = -_bad_side          # intercala o lado
	_bad_left -= 1
	if _bad_left > 0:
		_ability_timer = BADERNA_BETWEEN
	else:
		_baderna_cd = BADERNA_CD   # dispara o cooldown ao FIM: só melee pelos próximos BADERNA_CD s
		_end_normal_ability()

## Um golpe da baderna num lado: acerta o player se ele estiver desse lado e ao alcance.
func _baderna_hit(side: float) -> void:
	_update_sprite(side, false)
	if is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		var dy := target.global_position.y - global_position.y
		var same_side := signf(dx) == signf(side)
		if same_side and absf(dx) <= _hit_range() and absf(dy) <= ATTACK_VRANGE:
			if target.has_method("apply_enemy_hit"):
				target.apply_enemy_hit(data.stats)
	_spawn_attack_fx(side)
	Juice.hit_stop(get_tree(), 0.03)

## Passos: pegam carona no MESMO `moving` que escolhe a animação de andar — assim tocam em toda
## situação em que ele anda (perseguindo, ou avançando durante o windup do melee). Só REGISTRA a
## intenção; quem fala com o áudio é o _process, para o som não depender de este método ser chamado.
## A investida (charge) fica de fora: é corrida, não caminhada.
func _update_sprite(dx: float, moving: bool) -> void:
	super._update_sprite(dx, moving)
	_walking = moving and _special != "charge" and is_on_floor()

## Passadas da CORRIDA: som PRÓPRIO (charge_steps_sfx), mais encorpado que o da caminhada, recortado
## e tocado numa cadência maior. O rodízio pelo índice alterna as batidas do clipe.
func _tick_charge_steps(delta: float) -> void:
	_charge_step_t -= delta
	if _charge_step_t > 0.0:
		return
	_charge_step_t = CHARGE_STEP_EVERY
	Sfx.play_step(_charge_steps_sfx(), _charge_step_i)
	_charge_step_i += 1

## O áudio dos passos ANDANDO é decidido aqui, TODO frame — mesmo nos estados que não tocam no
## sprite (a baderna). `Sfx.sustain` nunca corta uma passada no meio: ao parar, ela soa até o fim.
## A corrida não passa por aqui (tem cadência própria — ver _tick_charge_steps).
func _process(_delta: float) -> void:
	Sfx.sustain(_steps_sfx(), _walking)

## Ao sair da cena (morte do boss, troca de nível): cala os passos, senão o loop ficaria preso.
func _exit_tree() -> void:
	Sfx.sustain(_steps_sfx(), false)

func _steps_sfx() -> String:
	return (data as Boss).steps_sfx if data is Boss else ""

func _charge_steps_sfx() -> String:
	return (data as Boss).charge_steps_sfx if data is Boss else ""

## Direção que o ogro encara (fallback quando não há alvo p/ mirar).
func _facing() -> float:
	if is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if dx != 0.0:
			return signf(dx)
	return 1.0

func _player_move_speed() -> float:
	if is_instance_valid(target) and "data" in target and target.data != null:
		return float(target.data.stats.move_speed)
	return 110.0

## Sobreposição AABB entre a caixa do ogro e a do player.
func _overlaps_player() -> bool:
	if not is_instance_valid(target):
		return false
	var phw := 8.0
	var phh := 13.0
	if "box_w" in target:
		phw = target.box_w * 0.5
		phh = target.box_h * 0.5
	var d: Vector2 = (target.global_position - global_position).abs()
	return d.x <= box_w * 0.5 + phw and d.y <= box_h * 0.5 + phh
