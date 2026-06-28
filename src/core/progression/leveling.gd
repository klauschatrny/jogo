## Sistema de XP e level-up (§1.2.2). Core puro. O XP necessário cresce geometricamente;
## as stats base do jogador (max_hp, attack) crescem linearmente via Scaling.
class_name Leveling
extends RefCounted

## XP necessário para sair do nível informado: XP_BASE * XP_GROWTH^(level-1).
static func xp_to_next(level: int) -> float:
	var ps: Dictionary = BalanceConfig.player_scaling
	return float(ps.get("XP_BASE", 100)) * pow(float(ps.get("XP_GROWTH", 1.15)), maxi(level, 1) - 1)

## Concede XP ao jogador, sobe de nível quantas vezes for preciso, e cura o HP ganho a
## cada nível. Retorna quantos níveis subiu. Emite eventos no EventBus.
static func add_xp(player: Player, amount: int) -> int:
	var levels_gained := 0
	player.experience += max(amount, 0)
	EventBus.xp_gained.emit(amount)
	while player.experience >= player.xp_to_next:
		player.experience -= player.xp_to_next
		var old_max := player.stats.max_hp
		player.level += 1
		player.xp_to_next = int(xp_to_next(player.level))
		player.recalculate_stats()
		# ganha o HP novo do nível (sem ultrapassar o novo máximo)
		var delta := player.stats.max_hp - old_max
		player.stats.current_hp = min(player.stats.current_hp + delta, player.stats.max_hp)
		levels_gained += 1
		EventBus.level_up.emit(player.level)
	return levels_gained
