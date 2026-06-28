## Jogador em runtime (§2.2.1). Core puro: emite eventos via EventBus, nunca toca em render.
## Nota de design: take_damage() recebe um valor JÁ MITIGADO pelo CombatResolver — a
## redução de dano é centralizada lá (§1.2.3), então aqui apenas subtraímos do HP.
class_name Player
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var experience: int = 0
var xp_to_next: int = 100
var stats: StatBlock
var weapon: Weapon
var augments: Array = []            # Array[Augment] na Fase 3
var gold: int = 0
var current_floor: int = 1
var run_id: String = ""

## Cria um jogador de nível 1 a partir das constantes de player_scaling (balance.json).
static func create_new(player_name: String, chosen_weapon: Weapon) -> Player:
	var p := Player.new()
	p.id = _gen_id()
	p.run_id = _gen_id()
	p.name = player_name
	p.weapon = chosen_weapon

	var ps: Dictionary = BalanceConfig.player_scaling
	var s := StatBlock.new()
	s.max_hp = int(ps.get("BASE_PHP", 120))
	s.current_hp = s.max_hp
	s.attack = int(ps.get("BASE_PATK", 5))
	s.defense = 0
	p.stats = s
	p.xp_to_next = int(ps.get("XP_BASE", 100))
	return p

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
		"augments": augments.duplicate(),
	}

static func _gen_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), Time.get_ticks_msec()]
