## Jogador em runtime (§2.2.1). Core puro: emite eventos via EventBus, nunca toca em render.
##
## Modelo de stats: `stats` é EFETIVO e derivado — recalculado de um bloco BASE (que escala
## com o nível via Scaling) mais os augments (via StatResolver, ordem ADD<PCT_ADD<MULT).
## Chame recalculate_stats() após mudar nível ou augments. current_hp é estado preservado.
##
## take_damage() recebe um valor JÁ MITIGADO pelo CombatResolver (mitigação centralizada lá).
class_name Player
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var experience: int = 0
var xp_to_next: int = 100
var stats: StatBlock
var stamina: Stamina                # recurso de ações (ataque/esquiva), estilo Dark Souls
var weapon: Weapon
var augments: Array = []            # Array[Augment]
var gold: int = 0
var current_floor: int = 1
var run_id: String = ""

static func create_new(player_name: String, chosen_weapon: Weapon) -> Player:
	var p := Player.new()
	p.id = _gen_id()
	p.run_id = _gen_id()
	p.name = player_name
	p.weapon = chosen_weapon
	p.level = 1
	p.recalculate_stats()
	p.stamina = Stamina.from_config(BalanceConfig.stamina)
	p.xp_to_next = int(Leveling.xp_to_next(1))
	return p

## Stats BASE no nível atual, antes dos augments. max_hp/attack escalam linearmente (§1.2.2);
## os demais são os defaults do jogador (do GDD §2.2.1).
func base_block() -> StatBlock:
	var b := StatBlock.new()
	b.max_hp = int(Scaling.player_max_hp(level))
	b.attack = int(Scaling.player_atk(level))
	b.defense = 0
	b.crit_chance = 0.05
	b.crit_damage = 1.5
	b.attack_speed = 1.0
	b.move_speed = 110.0
	b.damage_reduction = 0.0
	b.lifesteal = 0.0
	b.luck = 0
	b.damage_mult = 1.0
	return b

## Recalcula os stats efetivos (base + augments), preservando o HP atual (clampado ao novo máximo).
func recalculate_stats() -> void:
	var keep := stats.current_hp if stats != null else -1
	stats = StatResolver.resolve(base_block(), augments)
	if keep < 0:
		stats.current_hp = stats.max_hp
	else:
		stats.current_hp = min(keep, stats.max_hp)

func add_augment(aug: Augment) -> void:
	augments.append(aug)
	if aug.category == "WEAPON" and weapon != null:   # §3.7: augment de arma sobe o nível
		weapon.upgrade()
	recalculate_stats()
	EventBus.augment_chosen.emit(aug)

## Aplica dano já final (mitigação feita no CombatResolver). Retorna o dano efetivo.
func take_damage(amount: int) -> int:
	var dmg: int = max(amount, 0)
	stats.current_hp = max(stats.current_hp - dmg, 0)
	EventBus.player_damaged.emit(self, dmg)
	if stats.current_hp <= 0:
		EventBus.player_died.emit(self)
	return dmg

func heal(amount: int) -> void:
	stats.current_hp = min(stats.current_hp + max(amount, 0), stats.max_hp)

func is_alive() -> bool:
	return stats.current_hp > 0

## Snapshot usado para gerar o GhostData ao morrer (Fase 4).
func snapshot() -> Dictionary:
	return {
		"name": name,
		"level": level,
		"stats": stats.to_dict(),
		"weapon": weapon.to_dict() if weapon else {},
		"augments": augments.map(func(a: Augment) -> Dictionary:
			return {"id": a.id, "tier": a.tier, "name": a.name}),
	}

static func _gen_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), Time.get_ticks_msec()]
