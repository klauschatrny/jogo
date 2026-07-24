## Necromante (classe "elite"): NÃO se move — mantém a posição e dispara projéteis no player
## quando ele está na mesma tela. Ao TOMAR DANO, passa a usar uma habilidade AoE a cada 6s
## (windup de 1s com "!" + área roxa no chão; 40 de dano fixo só no player). A revivência da
## horda e o "mata todos ao morrer" são regidos pela cena (floor_scene).
class_name NecromancerView
extends EnemyView

const SHOOT_INTERVAL := 3.0       # cadência de disparo (cast a cast)
const SHOOT_WINDUP := 0.35        # aviso antes do tiro sair — era o único ataque do jogo sem
                                  # telegrafo, e um tiro sem aviso não se aprende, só se sofre
const PROJECTILE_SPEED := 150.0
# RANGED não tem alcance de disparo próprio: acordou, atira. Quem decide a que distância ele
# entra na briga é o aggro_range dele (data/enemies/necromancer.json) — dois números para a mesma
# pergunta só criariam uma faixa morta, em que ele está desperto e encarando o jogador sem agir.
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
var _shoot_windup := 0.0          # >0 = conjurando o tiro (aura crescendo, "!" visível)
var _cast_fx: Node2D              # aura de conjuração ao redor dele (tiro e AoE usam a mesma)
var _cast_t := 0.0
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
# Só o comportamento: o cadáver e os guards de existência ficam no template do EnemyView. Sem
# duplicá-los, o Necromante morto se libera sozinho (era o bug que o fazia castar do além).
func _tick_ai(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0                       # mantém a posição (não persegue, ignora knockback)
	move_and_slide()

	var dx := target.global_position.x - global_position.x
	_update_sprite(dx, false)              # encara o player, idle

	# Dormente: encara o jogador e espera — só começa a lançar quando o player se aproxima.
	if dormant:
		return

	_global_cd = maxf(0.0, _global_cd - delta)
	if _enraged:
		_aoe_cd = maxf(0.0, _aoe_cd - delta)

	# AoE em windup: espera o "!" + área terminarem e resolve o dano.
	if _aoe_windup > 0.0:
		_aoe_windup -= delta
		_update_cast_fx(delta)
		if _aoe_windup <= 0.0:
			_resolve_aoe()
		return

	# Dispara a AoE quando o ciclo zera (fora do cooldown global).
	if _enraged and _aoe_cd <= 0.0 and _global_cd <= 0.0:
		_start_aoe()
		return

	# Tiro em windup: a aura cresce e o "!" fica visível; ao zerar, o projétil sai.
	if _shoot_windup > 0.0:
		_shoot_windup -= delta
		_update_cast_fx(delta)
		if _shoot_windup <= 0.0:
			_hide_warn()
			_fire()
		return

	# Projétil — a menos que a AoE esteja próxima (janela de 1s) ou em cooldown global.
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if _global_cd <= 0.0 and _shoot_cd <= 0.0:
		if _enraged and _aoe_cd <= AOE_PREFER_WINDOW:
			return                         # prefere a habilidade: não dispara
		_shoot_cd = SHOOT_INTERVAL         # cadência conta do início do cast
		_shoot_windup = SHOOT_WINDUP
		_show_warn()
		_show_cast_fx()

## Ao morrer: apaga a aura de conjuração e a área da AoE, e zera qualquer windup em curso — sem
## isso, um cast disparado no frame da morte ainda resolveria (dano ou projétil) do além.
func _ao_morrer() -> void:
	_shoot_windup = 0.0
	_aoe_windup = 0.0
	_clear_cast_fx()
	_clear_aoe_fx()

func _fire() -> void:
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		_sprite.frame = 0
		_anim_lock = SHOOT_INTERVAL * 0.5
	var origin := global_position + Vector2(0.0, -box_h * 0.5)   # altura do "peito"
	_clear_cast_fx()
	Juice.burst(get_parent(), origin, Color(0.80, 0.50, 1.0), 12, 120.0)   # estouro na saída
	var proj := NecroProjectile.new()
	proj.setup(target.global_position - origin, PROJECTILE_SPEED, data.stats, target)
	proj.global_position = origin
	get_parent().add_child(proj)

# --- Aura de conjuração ---
# Tiro e AoE compartilham a mesma aura: enquanto ele conjura, um halo roxo pulsa ao redor dele e
# fagulhas sobem do chão. Isso existe porque o Necromante fica PARADO — sem um sinal no corpo
# dele, o único aviso de que algo vem seria o "!", e o jogador que está de costas não o vê. A
# aura é grande e brilha por baixo das entidades, então dá para notá-la pela periferia da tela.

const CAST_RINGS := 3             # anéis concêntricos do halo
const CAST_SPARKS := 5            # fagulhas subindo
const CAST_PULSE := 9.0           # velocidade da pulsação (rad/s)

func _show_cast_fx() -> void:
	_clear_cast_fx()
	_cast_t = 0.0
	_cast_fx = Node2D.new()
	_cast_fx.z_index = -1          # atrás dele: aura, não máscara
	add_child(_cast_fx)

	for i in CAST_RINGS:
		var lado := 26.0 + i * 14.0
		var anel := ColorRect.new()
		anel.color = Color(0.72, 0.42, 1.0, 0.26 - i * 0.06)
		anel.size = Vector2(lado, lado)
		anel.position = Vector2(-lado * 0.5, -box_h * 0.5 - lado * 0.5)
		_cast_fx.add_child(anel)

	for i in CAST_SPARKS:
		var f := ColorRect.new()
		f.color = Color(0.90, 0.70, 1.0)
		f.size = Vector2(3, 3)
		f.position = Vector2(-18.0 + i * 9.0, 0.0)
		f.set_meta("fase", float(i) * 0.7)
		_cast_fx.add_child(f)

## Pulsa os anéis e faz as fagulhas subirem em laço. Chamado a cada frame do windup.
func _update_cast_fx(delta: float) -> void:
	if not is_instance_valid(_cast_fx):
		return
	_cast_t += delta
	var i := 0
	for c in _cast_fx.get_children():
		if c is ColorRect and c.size.x > 6.0:              # anel
			var k := 1.0 + 0.14 * sin(_cast_t * CAST_PULSE - i * 0.6)
			c.scale = Vector2(k, k)
			c.pivot_offset = c.size * 0.5
			i += 1
		elif c is ColorRect:                                # fagulha
			var fase := float(c.get_meta("fase", 0.0))
			var t: float = fmod(_cast_t + fase, 0.9) / 0.9   # 0→1 em laço
			c.position.y = -t * (box_h + 16.0)
			c.modulate.a = 1.0 - t

func _clear_cast_fx() -> void:
	if is_instance_valid(_cast_fx):
		_cast_fx.queue_free()
	_cast_fx = null

# --- Habilidade AoE ---

func _start_aoe() -> void:
	_aoe_windup = AOE_WINDUP
	_aoe_cd = AOE_INTERVAL      # próximo cast 6s após este (o cd conta durante o windup)
	_show_warn()                # "!" (reusa o do EnemyView)
	_show_aoe_fx()              # área roxa brilhante no chão
	_show_cast_fx()             # e a aura de conjuração NELE (mesma do tiro, mais intensa)

## Fim do windup: some o aviso, aplica 40 de dano fixo SÓ no player se ele estiver na área
## (elipse 24×8). Outros inimigos não são afetados. Entra o cooldown global de 1.5s.
func _resolve_aoe() -> void:
	_hide_warn()
	_clear_aoe_fx()
	_clear_cast_fx()
	_global_cd = AOE_AFTER_CD
	if is_instance_valid(target):
		var rel := target.global_position - global_position
		var nx := rel.x / AOE_HALF_W
		var ny := rel.y / AOE_HALF_H
		if nx * nx + ny * ny <= 1.0 and target.has_method("apply_flat_damage"):
			target.apply_flat_damage(AOE_DAMAGE, true)   # dano MÁGICO (mitigado pela magic_resist)
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
