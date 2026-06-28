extends TestCase

# --- Fórmulas-base (§1.2.3) ---

func test_hit_damage_basico() -> void:
	# (5 + 15) * (1 + 0) * (1 - 0) = 20
	assert_almost(CombatResolver.hit_damage(5, 15, 0.0, 0.0), 20.0)

func test_hit_damage_com_bonus_percentual() -> void:
	# 20 * 1.5 = 30
	assert_almost(CombatResolver.hit_damage(5, 15, 0.5, 0.0), 30.0)

func test_hit_damage_com_reducao_do_alvo() -> void:
	# 20 * (1 - 0.25) = 15
	assert_almost(CombatResolver.hit_damage(5, 15, 0.0, 0.25), 15.0)

func test_dps_sem_crit() -> void:
	# 20 * 1.0 * (1 + 0) = 20
	assert_almost(CombatResolver.dps(20, 1.0, 0.0, 1.5), 20.0)

func test_dps_com_crit() -> void:
	# 20 * 1.0 * (1 + 0.5 * (2.0 - 1)) = 30
	assert_almost(CombatResolver.dps(20, 1.0, 0.5, 2.0), 30.0)

func test_ehp() -> void:
	assert_almost(CombatResolver.ehp(100, 0.0), 100.0)
	assert_almost(CombatResolver.ehp(100, 0.5), 200.0)

# --- Mitigação por defesa ---

func test_defesa_zero_nao_reduz() -> void:
	assert_almost(CombatResolver.damage_reduction_from_defense(0.0), 0.0)

func test_defesa_curva_retornos_decrescentes() -> void:
	# def=100, K=100 -> 100/200 = 0.5
	assert_almost(CombatResolver.damage_reduction_from_defense(100.0), 0.5)

func test_total_reduction_limita_em_95pct() -> void:
	var s := StatBlock.from_dict({"defense": 1000000, "damage_reduction": 0.9})
	assert_almost(CombatResolver.total_reduction(s), 0.95)

# --- Conveniência de alto nível ---

func test_player_hit_inclui_dano_da_arma() -> void:
	var w := Weapon.from_dict({"base_damage": 15, "weapon_growth": 1.12, "level": 1})
	var p := Player.create_new("X", w)  # attack = 5
	var alvo := StatBlock.from_dict({"max_hp": 40, "defense": 0})
	# (5 + 15) * 1 * (1 - 0) = 20
	assert_almost(CombatResolver.player_hit(p, alvo), 20.0)

func test_enemy_hit_usa_reducao_do_player() -> void:
	var w := Weapon.from_dict({"base_damage": 15})
	var p := Player.create_new("X", w)  # defesa 0, dr 0
	var inimigo := StatBlock.from_dict({"attack": 8})
	assert_almost(CombatResolver.enemy_hit(inimigo, p), 8.0)
