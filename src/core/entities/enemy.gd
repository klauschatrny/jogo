## Inimigo em runtime (§2.2.4). Na Fase 2 os stats vêm de base_stats; a partir da Fase 3
## o EnemyFactory os escala pelo andar (§1.2.1). Boss estende esta classe (reusa _populate).
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
	e._populate(d)
	return e

## Popula os campos a partir do dicionário. Protegido para o Boss reusar via super.
func _populate(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	name = String(d.get("name", ""))
	archetype = String(d.get("archetype", ""))
	rank = String(d.get("rank", "NORMAL"))
	ai_profile = String(d.get("ai_profile", "aggressive"))
	var abil: Array = d.get("abilities", [])
	abilities = abil.duplicate()
	var lt: Dictionary = d.get("loot", {})
	loot = lt.duplicate(true)
	stats = StatBlock.from_dict(d.get("base_stats", {}))
