## Ogro (boss): além do ataque melee normal (EnemyView), ao cruzar 50%/35%/15% de vida ele
## entra em fúria e faz uma INVESTIDA: durante o windup rastreia o lado do player e TRAVA a
## direção quando faltam 200 ms; então corre cegamente nessa direção (150% da vel. do player)
## desferindo até 3 golpes (50 de dano cada). Depois fica imóvel e cansado por 2s e volta ao normal.
class_name OgreView
extends BossView

const THRESHOLDS := [0.5, 0.35, 0.15]   # % de vida que disparam a investida
const CHARGE_SPEED_MULT := 1.5          # 150% da velocidade do player
const LOCK_AT_REMAINING := 0.2          # trava a direção quando faltam 200 ms de windup
const CHARGE_HITS := 3
const CHARGE_DAMAGE := 50
const CHARGE_HIT_CD := 0.3              # intervalo mínimo entre golpes da investida
const CHARGE_MAX_TIME := 2.0            # segurança: encerra a investida
const TIRED_TIME := 2.0

var _special := ""                      # "" (normal) | "windup" | "charge" | "tired"
var _sp_windup := 0.0
var _charge_dir := 1.0
var _dir_locked := false
var _charge_speed := 0.0
var _charge_hits := 0
var _charge_hit_cd := 0.0
var _charge_time := 0.0
var _tired := 0.0
var _next_threshold := 0

## Após cada dano: fases do BossView (enrage/summon) + checa os limiares da investida.
func _on_after_damage() -> void:
	super._on_after_damage()
	if _special != "" or data == null:
		return
	var ratio := float(data.stats.current_hp) / float(maxi(data.stats.max_hp, 1))
	if _next_threshold < THRESHOLDS.size() and ratio <= float(THRESHOLDS[_next_threshold]):
		_next_threshold += 1
		while _next_threshold < THRESHOLDS.size() and ratio <= float(THRESHOLDS[_next_threshold]):
			_next_threshold += 1   # um golpe grande pode cruzar vários limiares de uma vez
		_start_special()

func _physics_process(delta: float) -> void:
	if _special == "":
		super._physics_process(delta)   # IA melee normal do EnemyView
		return
	if data == null or not is_instance_valid(target):
		return
	match _special:
		"windup": _tick_windup(delta)
		"charge": _tick_charge(delta)
		"tired": _tick_tired(delta)

func _start_special() -> void:
	_special = "windup"
	_sp_windup = windup_time
	_dir_locked = false
	_charge_hits = 0
	_windup = 0.0                 # cancela qualquer windup normal em curso
	_show_warn()
	modulate = Color(1.6, 0.5, 0.5)   # enraivecido (vermelho forte)

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
	_charge_hit_cd = 0.0
	_charge_speed = CHARGE_SPEED_MULT * _player_move_speed()

## Corre cegamente na direção travada; golpeia (50) ao sobrepor o player, até 3 vezes.
## Encerra em 3 golpes, ao bater na parede, ou no tempo máximo.
func _tick_charge(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = _charge_dir * _charge_speed
	move_and_slide()
	_update_sprite(_charge_dir, true)
	_charge_time += delta
	_charge_hit_cd = maxf(0.0, _charge_hit_cd - delta)
	if _charge_hit_cd <= 0.0 and _overlaps_player():
		_charge_hit_cd = CHARGE_HIT_CD
		_charge_hits += 1
		if target.has_method("apply_flat_damage"):
			target.apply_flat_damage(CHARGE_DAMAGE)
		_spawn_attack_fx(_charge_dir)
		Juice.hit_stop(get_tree(), 0.05)
	if _charge_hits >= CHARGE_HITS or is_on_wall() or _charge_time >= CHARGE_MAX_TIME:
		_begin_tired()

func _begin_tired() -> void:
	_special = "tired"
	_tired = TIRED_TIME
	velocity.x = 0.0
	modulate = Color(0.7, 0.7, 0.95)   # cansado (apagado/azulado)
	Juice.burst(get_parent(), global_position, Palette.BOSS, 12, 110.0)

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
		modulate = Color(1.25, 0.8, 0.8)     # segue com aparência enraivecida

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
