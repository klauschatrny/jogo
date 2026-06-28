extends TestCase

# --- Curva dos inimigos (§1.2.1) ---

func test_enemy_hp_andar_1() -> void:
	assert_almost(Scaling.enemy_hp(1), 40.0)

func test_enemy_hp_cresce_geometricamente() -> void:
	# andar 10: 40 * 1.09^9 ~= 86.9 (tabela do GDD: 87)
	assert_almost(Scaling.enemy_hp(10), 40.0 * pow(1.09, 9), 0.01)
	assert_eq(int(round(Scaling.enemy_hp(10))), 87)

func test_enemy_atk_andar_1() -> void:
	assert_almost(Scaling.enemy_atk(1), 8.0)

func test_rank_mult() -> void:
	assert_almost(Scaling.rank_mult("NORMAL", "hp"), 1.0)
	assert_almost(Scaling.rank_mult("ELITE", "hp"), 2.5)
	assert_almost(Scaling.rank_mult("KING", "atk"), 3.0)
	assert_almost(Scaling.rank_mult("DESCONHECIDO", "hp"), 1.0)  # fallback

# --- Curva do jogador (§1.2.2) ---

func test_player_max_hp_linear() -> void:
	assert_almost(Scaling.player_max_hp(1), 120.0)   # BASE_PHP
	assert_almost(Scaling.player_max_hp(2), 134.0)   # +14
	assert_almost(Scaling.player_max_hp(10), 120.0 + 9 * 14)

func test_player_atk_linear() -> void:
	assert_almost(Scaling.player_atk(1), 5.0)
	assert_almost(Scaling.player_atk(5), 5.0 + 4 * 2)
