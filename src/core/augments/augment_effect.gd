## Um efeito atômico de um Augment (§2.2.6): aplica uma `operation` sobre uma `stat`.
## operation: ADD (flat) | PCT_ADD (soma ao multiplicador) | MULT (multiplica) | SET (define).
class_name AugmentEffect
extends RefCounted

var stat: String = ""
var operation: String = "ADD"
var value: float = 0.0

static func from_dict(d: Dictionary) -> AugmentEffect:
	var e := AugmentEffect.new()
	e.stat = String(d.get("stat", ""))
	e.operation = String(d.get("operation", "ADD"))
	e.value = float(d.get("value", 0.0))
	return e
