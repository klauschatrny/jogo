## Curvas de escalonamento (§1.2.1, §1.2.2). Core puro, lê constantes do balance.json.
class_name Scaling
extends RefCounted

# --- Curva dos inimigos (geométrica, §1.2.1) — NÃO GOVERNA MAIS O JOGO ---
# Era a assimetria do roguelike: inimigos geométricos por andar, jogador linear. O pivô
# soulslike a aposentou — hoje o inimigo vale o que o JSON dele diz (ver EnemyFactory) e o
# jogador cresce por atributos. Estas funções (e rank_mult) sobrevivem só para o sistema de
# ecos/Nemesis e o simulador de balanceamento, ambos desligados/parados. Nada que você mudar
# nos GROWTH_* do balance.json afeta um inimigo em jogo: mude o JSON do inimigo.

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

# --- Base do jogador ---
# É daqui que ele PARTE. O crescimento não vem mais do nível: vem dos ATRIBUTOS, gastos na
# fogueira (ver Attributes). Estes dois valores casam com o atributo no seu ponto de partida —
# vigor 10 = 120 de vida, força 10 = 5 de ataque.

static func player_base_hp() -> float:
	return float(BalanceConfig.player_scaling.get("BASE_PHP", 120))

static func player_base_atk() -> float:
	return float(BalanceConfig.player_scaling.get("BASE_PATK", 5))

# --- Curva linear antiga do jogador (§1.2.2) ---
# NÃO alimenta mais o Player: ele cresce por atributos. Seguem aqui porque o simulador de
# balanceamento (tests/balance_sim.gd) ainda modela o "jogador mediano" por nível.

static func player_max_hp(level: int) -> float:
	var ps: Dictionary = BalanceConfig.player_scaling
	return float(ps.get("BASE_PHP", 120)) + (maxi(level, 1) - 1) * float(ps.get("HP_PER_LEVEL", 14))

static func player_atk(level: int) -> float:
	var ps: Dictionary = BalanceConfig.player_scaling
	return float(ps.get("BASE_PATK", 5)) + (maxi(level, 1) - 1) * float(ps.get("ATK_PER_LEVEL", 2))
