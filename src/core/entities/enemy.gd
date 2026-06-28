## Inimigo em runtime (§2.2.4). Na Fase 2 os stats vêm direto de base_stats (andar 1);
## a escala geométrica por andar (§1.2.1) entra na Fase 3 via factory.
class_name Enemy
extends RefCounted

var id: String = ""
var name: String = ""
var archetype: String = ""
var rank: String = "NORMAL"
var stats: StatBlock
var ai_profile: String = "aggressive"
var abilities: Array = []
var loot: Dictionary = {}

static func from_dict(d: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.id = String(d.get("id", ""))
	e.name = String(d.get("name", ""))
	e.archetype = String(d.get("archetype", ""))
	e.rank = String(d.get("rank", "NORMAL"))
	e.ai_profile = String(d.get("ai_profile", "aggressive"))
	var abil: Array = d.get("abilities", [])
	e.abilities = abil.duplicate()
	var lt: Dictionary = d.get("loot", {})
	e.loot = lt.duplicate(true)
	e.stats = StatBlock.from_dict(d.get("base_stats", {}))
	return e
