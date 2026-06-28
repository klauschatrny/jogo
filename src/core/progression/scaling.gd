## Curvas de escalonamento (§1.2.1, §1.2.2). Core puro, lê constantes do balance.json.
## A tensão do jogo nasce da assimetria: inimigos crescem GEOMETRICAMENTE por andar,
## o jogador cresce LINEARMENTE de base (e fecha a lacuna com arma + augments).
class_name Scaling
extends RefCounted

# --- Curva dos inimigos (geométrica, §1.2.1) ---
# Referência canônica NORMAL (baseada nos BASE_* globais). Usada em testes e no
# simulador de balanceamento; a factory abaixo escala o base_stats de cada inimigo.

static func enemy_hp(floor: int) -> float:
	var es: Dictionary = BalanceConfig.enemy_scaling
	return float(es.get("BASE_HP", 40)) * pow(float(es.get("GROWTH_HP", 1.09)), maxi(floor, 1) - 1)

static func enemy_atk(floor: int) -> float:
	var es: Dictionary = BalanceConfig.enemy_scaling
	return float(es.get("BASE_ATK", 8)) * pow(float(es.get("GROWTH_ATK", 1.07)), maxi(floor, 1) - 1)

static func enemy_def(floor: int) -> float:
	var es: Dictionary = BalanceConfig.enemy_scaling
	return float(es.get("BASE_DEF", 2)) * pow(float(es.get("GROWTH_DEF", 1.05)), maxi(floor, 1) - 1)

## Multiplicador de rank (MINION/NORMAL/ELITE/BOSS/GREAT_BOSS/KING), chave "hp" ou "atk".
static func rank_mult(rank: String, key: String) -> float:
	var rm: Dictionary = BalanceConfig.rank_multipliers.get(rank, {})
	return float(rm.get(key, 1.0))

# --- Curva do jogador (linear de base, §1.2.2) ---

static func player_max_hp(level: int) -> float:
	var ps: Dictionary = BalanceConfig.player_scaling
	return float(ps.get("BASE_PHP", 120)) + (maxi(level, 1) - 1) * float(ps.get("HP_PER_LEVEL", 14))

static func player_atk(level: int) -> float:
	var ps: Dictionary = BalanceConfig.player_scaling
	return float(ps.get("BASE_PATK", 5)) + (maxi(level, 1) - 1) * float(ps.get("ATK_PER_LEVEL", 2))
