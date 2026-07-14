## Progressão soulslike. Core puro.
##
## Não existe mais XP que sobe de nível sozinho. O que os inimigos largam são ALMAS, e almas são
## MOEDA: elas ficam paradas no seu bolso até você sentar na fogueira e COMPRAR um nível. Cada
## nível comprado entrega pontos de atributo (Attributes.points_per_level), e os pontos é que
## viram poder.
##
## Essa distinção é o que faz a morte doer: as almas que você ainda não gastou vão todas para o
## Eco, no lugar onde você caiu. Farmar deixa de ser de graça — enquanto o dinheiro está no bolso,
## ele é risco; só depois de gasto ele é seu.
class_name Leveling
extends RefCounted

## Almas para comprar o PRÓXIMO nível: SOULS_BASE * SOULS_GROWTH^(level-1).
static func level_cost(level: int) -> int:
	var ps: Dictionary = BalanceConfig.player_scaling
	return int(float(ps.get("SOULS_BASE", 100)) \
		* pow(float(ps.get("SOULS_GROWTH", 1.15)), maxi(level, 1) - 1))

static func can_level_up(player: Player) -> bool:
	return player.souls >= level_cost(player.level)

## Compra UM nível, se houver almas. O nível não dá stat nenhuma: dá pontos de atributo, que o
## jogador gasta onde quiser (ainda na fogueira). Retorna false se faltaram almas.
static func level_up(player: Player) -> bool:
	var custo := level_cost(player.level)
	if player.souls < custo:
		return false
	player.souls -= custo
	player.level += 1
	player.attribute_points += Attributes.points_per_level()
	EventBus.level_up.emit(player.level)
	return true
