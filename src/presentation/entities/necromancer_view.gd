## Necromante (classe "elite"): NÃO se move — mantém a posição e dispara projéteis no player
## quando ele está na mesma tela. Ao TOMAR DANO, passa a usar uma habilidade AoE a cada 6s
## (windup de 1s com "!" + área roxa no chão; 40 de dano fixo só no player). A revivência da
## horda e o "mata todos ao morrer" são regidos pela cena (floor_scene).
class_name NecromancerView
extends EnemyView

const SHOOT_INTERVAL := 1.4       # cadência de disparo
const PROJECTILE_SPEED := 150.0
const SCREEN_RANGE := 340.0       # dispara quando o player está a ~meia tela (mesma tela)
const Z := 199                    # imediatamente abaixo do player (200), acima dos outros inimigos (~100)

# Habilidade secundária (AoE), destravada ao tomar dano.
const AOE_INTERVAL := 6.0         # cadência (cast a cast)
const AOE_WINDUP := 1.0           # aviso antes de conectar
const AOE_HALF_W := 80.0          # raio horizontal (80 px)
const AOE_HALF_H := 8.0           # 16 px de altura → ±8
const AOE_DAMAGE := 40
const AOE_AFTER_CD := 1.5         # cooldown de QUALQUER ataque depois da habilidade
const AOE_PREFER_WINDOW := 1.0    # dentro de 1s do cast, prefere a AoE e NÃO dispara projétil

var _shoot_cd := 0.0
var _enraged := false             # true depois de tomar dano (habilita a AoE)
var _aoe_cd := 0.0                # tempo até o próximo cast da AoE
var _aoe_windup := 0.0            # >0 = em windup da AoE
var _global_cd := 0.0            # bloqueia qualquer ataque logo após a AoE
var _aoe_fx: Node2D               # área roxa no chão durante o windup

func _ready() -> void:
	super._ready()
	z_index = Z

## Ao tomar o primeiro dano, entra em fúria: começa o ciclo da AoE (primeiro cast em 6s).
func _on_after_damage() -> void:
	if not _enraged:
		_enraged = true
		_aoe_cd = AOE_INTERVAL

## Substitui totalmente a IA do EnemyView: estático, ranged, com a AoE quando em fúria.
func _physics_process(delta: float) -> void:
	if data == null or not is_instance_valid(target):
		return
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0                       # mantém a posição (não persegue, ignora knockback)
	move_and_slide()

	var dx := target.global_position.x - global_position.x
	_update_sprite(dx, false)              # encara o player, idle

	# Dormente: encara o jogador e espera. Este _physics_process substitui o do EnemyView por
	# inteiro, então a checagem precisa existir aqui também — sem ela o Necromante lançaria do
	# outro lado do mapa enquanto todo o resto ainda dorme.
	if dormant:
		return

	_global_cd = maxf(0.0, _global_cd - delta)
	if _enraged:
		_aoe_cd = maxf(0.0, _aoe_cd - delta)

	# AoE em windup: espera o "!" + área terminarem e resolve o dano.
	if _aoe_windup > 0.0:
		_aoe_windup -= delta
		if _aoe_windup <= 0.0:
			_resolve_aoe()
		return

	# Dispara a AoE quando o ciclo zera (fora do cooldown global).
	if _enraged and _aoe_cd <= 0.0 and _global_cd <= 0.0:
		_start_aoe()
		return

	# Projétil — a menos que a AoE esteja próxima (janela de 2s) ou em cooldown global.
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if _global_cd <= 0.0 and _shoot_cd <= 0.0 and absf(dx) <= SCREEN_RANGE:
		if _enraged and _aoe_cd <= AOE_PREFER_WINDOW:
			return                         # prefere a habilidade: não dispara
		_shoot_cd = SHOOT_INTERVAL
		_fire()

func _fire() -> void:
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		_sprite.frame = 0
		_anim_lock = SHOOT_INTERVAL * 0.5
	var origin := global_position + Vector2(0.0, -box_h * 0.5)   # altura do "peito"
	var proj := NecroProjectile.new()
	proj.setup(target.global_position - origin, PROJECTILE_SPEED, data.stats, target)
	proj.global_position = origin
	get_parent().add_child(proj)

# --- Habilidade AoE ---

func _start_aoe() -> void:
	_aoe_windup = AOE_WINDUP
	_aoe_cd = AOE_INTERVAL      # próximo cast 6s após este (o cd conta durante o windup)
	_show_warn()                # "!" (reusa o do EnemyView)
	_show_aoe_fx()              # área roxa brilhante no chão

## Fim do windup: some o aviso, aplica 40 de dano fixo SÓ no player se ele estiver na área
## (elipse 24×8). Outros inimigos não são afetados. Entra o cooldown global de 1.5s.
func _resolve_aoe() -> void:
	_hide_warn()
	_clear_aoe_fx()
	_global_cd = AOE_AFTER_CD
	if is_instance_valid(target):
		var rel := target.global_position - global_position
		var nx := rel.x / AOE_HALF_W
		var ny := rel.y / AOE_HALF_H
		if nx * nx + ny * ny <= 1.0 and target.has_method("apply_flat_damage"):
			target.apply_flat_damage(AOE_DAMAGE)
	Juice.burst(get_parent(), global_position, Palette.BOSS, 14, 130.0)

## Área roxa brilhante no chão (elipse) durante o windup, pulsando.
func _show_aoe_fx() -> void:
	_clear_aoe_fx()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * AOE_HALF_W, sin(a) * AOE_HALF_H))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(Palette.BOSS, 0.45)
	poly.z_as_relative = false
	poly.z_index = -3          # no chão, abaixo das entidades
	add_child(poly)
	var outline := Line2D.new()
	var op := pts.duplicate()
	op.append(pts[0])
	outline.points = op
	outline.width = 1.5
	outline.default_color = Color(Palette.BOSS.lightened(0.4), 0.9)
	poly.add_child(outline)
	_aoe_fx = poly
	var tw := poly.create_tween().set_loops()
	tw.tween_property(poly, "modulate:a", 1.0, 0.18)
	tw.tween_property(poly, "modulate:a", 0.5, 0.18)

func _clear_aoe_fx() -> void:
	if _aoe_fx != null and is_instance_valid(_aoe_fx):
		_aoe_fx.queue_free()
	_aoe_fx = null
