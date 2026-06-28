## Carta de melhoria (§2.2.3). Três tiers: FRAGMENT < RELIC < ARTIFACT. Aplica seus
## efeitos sobre os stats do jogador via StatResolver, respeitando ADD < PCT_ADD < MULT.
## Tier/category ficam como String (data-driven, espelham o JSON) em vez de enum.
class_name Augment
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var tier: String = "FRAGMENT"       # FRAGMENT | RELIC | ARTIFACT
var category: String = "OFFENSE"    # OFFENSE | DEFENSE | UTILITY | WEAPON
var weight: int = 100
var stackable: bool = false
var max_stacks: int = 1
var effects: Array = []             # Array[AugmentEffect]

static func from_dict(d: Dictionary) -> Augment:
	var a := Augment.new()
	a.id = String(d.get("id", ""))
	a.name = String(d.get("name", ""))
	a.description = String(d.get("description", ""))
	a.tier = String(d.get("tier", "FRAGMENT"))
	a.category = String(d.get("category", "OFFENSE"))
	a.weight = int(d.get("weight", 100))
	a.stackable = bool(d.get("stackable", false))
	a.max_stacks = int(d.get("max_stacks", 1))
	var effs: Array = d.get("effects", [])
	for ed in effs:
		a.effects.append(AugmentEffect.from_dict(ed))
	return a
