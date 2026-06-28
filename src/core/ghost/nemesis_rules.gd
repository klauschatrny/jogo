## As 5 regras matemáticas do Nemesis System (§1.4.2). Funções puras e determinísticas —
## recebem números explícitos (não leem BalanceConfig) para serem trivialmente testáveis.
## Quem injeta os parâmetros de tuning é o GhostFactory (lê do balance.json).
class_name NemesisRules
extends RefCounted

const _TIER_ORDER := {"FRAGMENT": 0, "RELIC": 1, "ARTIFACT": 2}

## Regra 1 — nerf base: stat do snapshot multiplicado pelo coeficiente Nemesis (< 1).
static func nerf(stat_value: float, nemesis_coeff: float) -> int:
	return int(stat_value * nemesis_coeff)

## Regra 2 — teto anti-impossível: o HP do fantasma nunca passa de hp_cap× o HP ATUAL
## do jogador, por mais lendária que tenha sido a run de origem. Sempre derrotável.
static func ghost_hp(snapshot_max_hp: int, nemesis_coeff: float,
		current_player_hp: int, hp_cap: float) -> int:
	var nerfed := float(snapshot_max_hp) * nemesis_coeff
	var cap := float(current_player_hp) * hp_cap
	return int(min(nerfed, cap))

## Regra 3 (quantidade) — n = clamp(floor(death_floor / divisor), 1, max_n).
static func inherited_count(death_floor: int, divisor: int, max_n: int) -> int:
	var n := int(floor(float(death_floor) / float(maxi(divisor, 1))))
	return clampi(n, 1, max_n)

## Regra 3 (seleção) — herda só os augments mais impactantes, priorizando tier
## (Artefato > Relíquia > Fragmento), até `n`. `augments` é uma lista de dicionários
## com ao menos a chave "tier" (vinda de Player.snapshot()).
static func select_inherited_augments(augments: Array, death_floor: int,
		divisor: int, max_n: int) -> Array:
	var n := inherited_count(death_floor, divisor, max_n)
	var ordered := augments.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _tier_rank(a) > _tier_rank(b))
	return ordered.slice(0, n)

static func _tier_rank(aug: Dictionary) -> int:
	return int(_TIER_ORDER.get(String(aug.get("tier", "FRAGMENT")), 0))
