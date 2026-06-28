## Arma em runtime (§2.2.2). O dano sobe geometricamente com o nível da arma —
## é uma das fontes que mantêm o jogador competitivo contra a curva dos inimigos (§1.2.2).
class_name Weapon
extends RefCounted

var id: String = ""
var name: String = ""
var type: String = ""
var level: int = 1
var base_damage: float = 0.0
var weapon_growth: float = 1.12
var attack_range: float = 0.0
var attack_speed: float = 1.0
var crit_bonus: float = 0.0
var modifiers: Array = []          # efeitos especiais (pierce, lifesteal, elemental) — Fase 3
var special_ability: Dictionary = {}

static func from_dict(d: Dictionary) -> Weapon:
	var w := Weapon.new()
	w.id = String(d.get("id", ""))
	w.name = String(d.get("name", ""))
	w.type = String(d.get("type", ""))
	w.level = int(d.get("level", 1))
	w.base_damage = float(d.get("base_damage", 0.0))
	w.weapon_growth = float(d.get("weapon_growth", 1.12))
	w.attack_range = float(d.get("attack_range", 0.0))
	w.attack_speed = float(d.get("attack_speed", 1.0))
	w.crit_bonus = float(d.get("crit_bonus", 0.0))
	var mods: Array = d.get("modifiers", [])
	w.modifiers = mods.duplicate()
	var ability: Dictionary = d.get("special_ability", {})
	w.special_ability = ability.duplicate(true)
	return w

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "type": type, "level": level,
		"base_damage": base_damage, "weapon_growth": weapon_growth,
		"attack_range": attack_range, "attack_speed": attack_speed,
		"crit_bonus": crit_bonus, "modifiers": modifiers.duplicate(),
		"special_ability": special_ability.duplicate(true),
	}

## WEAPON_DAMAGE(wlvl) = base_damage * (weapon_growth ^ (level - 1))  (§1.2.2)
func current_damage() -> float:
	return base_damage * pow(weapon_growth, level - 1)

func upgrade() -> void:
	level += 1
	EventBus.weapon_upgraded.emit(self)
