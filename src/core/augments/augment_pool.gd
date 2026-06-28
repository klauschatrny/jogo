## Sorteio ponderado de cards de Augment (§1.3). O peso de cada augment é enviesado por
## luck: tiers raros ganham mais peso quanto maior o luck (LUCK_RARITY_FACTOR por tier).
## Usa o RNGService semeado — mesma seed, mesmo sorteio. Core puro (recebe os augments
## já hidratados, não acessa repositórios).
class_name AugmentPool
extends RefCounted

var _augments: Array = []   # Array[Augment]

func _init(augments: Array = []) -> void:
	_augments = augments.duplicate()

func set_augments(augs: Array) -> void:
	_augments = augs.duplicate()

func size() -> int:
	return _augments.size()

## Sorteia `n` cards DISTINTOS, ponderado por weight e enviesado por luck. `exclude` é uma
## lista de ids a ignorar (ex.: augments não-stackable já possuídos). Sorteio sem reposição.
func draw(n: int, luck: int = 0, exclude: Array = []) -> Array:
	var pool: Array = []
	for a in _augments:
		if not (a.id in exclude):
			pool.append(a)

	var result: Array = []
	for i in n:
		if pool.is_empty():
			break
		var weights: Array = []
		for a in pool:
			weights.append(effective_weight(a, luck))
		var idx := RNGService.weighted_index(weights)
		if idx < 0:
			break
		result.append(pool[idx])
		pool.remove_at(idx)
	return result

## Peso efetivo de um augment dado o luck: weight * (1 + luck * fator_do_tier).
func effective_weight(a: Augment, luck: int) -> float:
	var factors: Dictionary = BalanceConfig.augments.get("LUCK_RARITY_FACTOR", {})
	var factor := float(factors.get(a.tier, 0.0))
	return float(a.weight) * (1.0 + float(luck) * factor)
