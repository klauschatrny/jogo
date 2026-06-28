## Uma fase de boss (§2.2.4): ao cruzar `hp_threshold` (fração 0..1), dispara uma vez as
## ações em `on_enter` e aplica `atk_mult` ao ataque do boss.
class_name BossPhase
extends RefCounted

var hp_threshold: float = 0.5
var on_enter: Array = []        # nomes de ações/abilities a disparar
var atk_mult: float = 1.0
var triggered: bool = false

static func from_dict(d: Dictionary) -> BossPhase:
	var p := BossPhase.new()
	p.hp_threshold = float(d.get("hp_threshold", 0.5))
	var oe: Array = d.get("on_enter", [])
	p.on_enter = oe.duplicate()
	p.atk_mult = float(d.get("atk_mult", 1.0))
	return p
