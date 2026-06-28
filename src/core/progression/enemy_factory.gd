## Cria inimigos/bosses ESCALADOS para um andar (§1.2.1). Trata o base_stats do JSON como
## o baseline do andar 1 e aplica a curva geométrica (GROWTH^(f-1)) e o multiplicador de
## rank. Para um inimigo NORMAL com base = BASE_* global, reproduz a tabela do §1.2.1.
class_name EnemyFactory
extends RefCounted

static func build(base_dict: Dictionary, floor: int) -> Enemy:
	var e := Enemy.from_dict(base_dict)
	_scale(e, floor)
	return e

static func build_boss(base_dict: Dictionary, floor: int) -> Boss:
	var b := Boss.from_dict(base_dict)
	_scale(b, floor)
	return b

## Escala in-place os stats de um Enemy (ou Boss) para o andar.
static func _scale(e: Enemy, floor: int) -> void:
	var f := maxi(floor, 1)
	var es: Dictionary = BalanceConfig.enemy_scaling
	var gh := float(es.get("GROWTH_HP", 1.09))
	var ga := float(es.get("GROWTH_ATK", 1.07))
	var gd := float(es.get("GROWTH_DEF", 1.05))

	var hp := e.stats.max_hp * pow(gh, f - 1) * Scaling.rank_mult(e.rank, "hp")
	var atk := e.stats.attack * pow(ga, f - 1) * Scaling.rank_mult(e.rank, "atk")
	var df := e.stats.defense * pow(gd, f - 1)

	e.stats.max_hp = int(round(hp))
	e.stats.current_hp = e.stats.max_hp
	e.stats.attack = int(round(atk))
	e.stats.defense = int(round(df))
