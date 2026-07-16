extends TestCase

func test_carrega_enemy_scaling() -> void:
	assert_almost(BalanceConfig.enemy_scaling.get("BASE_HP", 0), 40.0)
	assert_almost(BalanceConfig.enemy_scaling.get("GROWTH_HP", 0), 1.09)

func test_carrega_player_scaling() -> void:
	assert_almost(BalanceConfig.player_scaling.get("BASE_PHP", 0), 90.0)
	assert_almost(BalanceConfig.player_scaling.get("WEAPON_GROWTH", 0), 1.12)

func test_carrega_nemesis() -> void:
	assert_almost(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0), 0.65)
	assert_almost(BalanceConfig.nemesis.get("GHOST_HP_CAP", 0), 2.0)

func test_rank_multipliers() -> void:
	assert_almost(BalanceConfig.rank_multipliers.get("KING", {}).get("hp", 0), 30.0)
	assert_almost(BalanceConfig.rank_multipliers.get("NORMAL", {}).get("atk", 0), 1.0)

func test_get_value_com_fallback() -> void:
	assert_eq(BalanceConfig.get_value("secao_inexistente", "x", "padrao"), "padrao")
