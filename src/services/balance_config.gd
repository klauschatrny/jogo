## Autoload. Carrega data/balance.json (Apêndice A do GDD) e expõe as constantes
## de tuning em seções tipadas. Mudar balanceamento = editar o JSON, sem tocar em lógica.
extends Node

const BALANCE_PATH := "res://data/balance.json"

var enemy_scaling: Dictionary = {}
var rank_multipliers: Dictionary = {}
var player_scaling: Dictionary = {}
var defense_curve: Dictionary = {}
var stamina: Dictionary = {}
var augments: Dictionary = {}
var nemesis: Dictionary = {}
var ttk_targets: Dictionary = {}

var _raw: Dictionary = {}

func _ready() -> void:
	load_balance()

## Recarrega o balance.json. Útil também para hot-reload em ferramentas de tuning.
func load_balance(path := BALANCE_PATH) -> bool:
	var data: Variant = JsonLoader.load_file(path)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[BalanceConfig] balance.json inválido ou ausente: %s" % path)
		return false
	_raw = data
	enemy_scaling = data.get("enemy_scaling", {})
	rank_multipliers = data.get("rank_multipliers", {})
	player_scaling = data.get("player_scaling", {})
	defense_curve = data.get("defense_curve", {})
	stamina = data.get("stamina", {})
	augments = data.get("augments", {})
	nemesis = data.get("nemesis", {})
	ttk_targets = data.get("ttk_targets", {})
	return true

## Acesso genérico com fallback: BalanceConfig.get_value("nemesis", "NEMESIS_COEFF", 0.65)
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _raw.get(section, {}).get(key, default)
