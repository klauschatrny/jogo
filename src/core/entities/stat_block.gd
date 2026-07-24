## Bloco de stats reutilizado por Player e Enemy (§2.2.6). Core puro, sem render.
class_name StatBlock
extends RefCounted

var max_hp: int = 0
var current_hp: int = 0
var attack: int = 0
var defense: int = 0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var attack_speed: float = 1.0
var move_speed: float = 100.0
var damage_reduction: float = 0.0  # redução de dano FÍSICO (0..1); a defesa flat soma via curva
var magic_resist: float = 0.0      # redução de dano MÁGICO (0..1); só o Necromante causa dano mágico
var lifesteal: float = 0.0
var luck: int = 0
var damage_mult: float = 1.0       # multiplicador de dano global: (1 + Σ%dano) e ×MULT de artefatos (§1.2.3)

## Cria um StatBlock a partir de um dicionário (ex.: base_stats de um inimigo,
## ou o bloco "stats" do save do jogador). Campos ausentes usam os defaults.
static func from_dict(d: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = int(d.get("max_hp", 0))
	s.current_hp = int(d.get("current_hp", d.get("max_hp", 0)))
	s.attack = int(d.get("attack", 0))
	s.defense = int(d.get("defense", 0))
	s.crit_chance = float(d.get("crit_chance", 0.0))
	s.crit_damage = float(d.get("crit_damage", 1.5))
	s.attack_speed = float(d.get("attack_speed", 1.0))
	s.move_speed = float(d.get("move_speed", 100.0))
	s.damage_reduction = float(d.get("damage_reduction", 0.0))
	s.magic_resist = float(d.get("magic_resist", 0.0))
	s.lifesteal = float(d.get("lifesteal", 0.0))
	s.luck = int(d.get("luck", 0))
	s.damage_mult = float(d.get("damage_mult", 1.0))
	return s

func to_dict() -> Dictionary:
	return {
		"max_hp": max_hp, "current_hp": current_hp,
		"attack": attack, "defense": defense,
		"crit_chance": crit_chance, "crit_damage": crit_damage,
		"attack_speed": attack_speed, "move_speed": move_speed,
		"damage_reduction": damage_reduction, "magic_resist": magic_resist, "lifesteal": lifesteal,
		"luck": luck, "damage_mult": damage_mult,
	}

func clone() -> StatBlock:
	return StatBlock.from_dict(to_dict())
