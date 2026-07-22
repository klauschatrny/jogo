extends TestCase

func _sword() -> Weapon:
	return Weapon.from_dict({
		"id": "wpn_test", "name": "Teste", "type": "MELEE_SWORD",
		"level": 1, "base_damage": 15, "weapon_growth": 1.12,
	})

func test_from_dict() -> void:
	var w := _sword()
	assert_eq(w.id, "wpn_test")
	assert_eq(w.level, 1)
	assert_almost(w.base_damage, 15.0)

func test_current_damage_nivel_1() -> void:
	assert_almost(_sword().current_damage(), 15.0)

func test_current_damage_cresce_geometricamente() -> void:
	var w := _sword()
	w.upgrade()  # nível 2
	assert_eq(w.level, 2)
	assert_almost(w.current_damage(), 15.0 * 1.12)
	w.upgrade()  # nível 3
	assert_almost(w.current_damage(), 15.0 * pow(1.12, 2))

func test_round_trip() -> void:
	var w := Weapon.from_dict(_sword().to_dict())
	assert_eq(w.id, "wpn_test")
	assert_almost(w.weapon_growth, 1.12)

func test_upgrade_cost_cresce_geometricamente() -> void:
	var w := _sword()
	var base := w.upgrade_cost()          # nível 1: WEAPON_COST_BASE
	assert_true(base > 0, "custo do nível 1 deve ser positivo")
	w.upgrade()                           # nível 2
	var growth := float(BalanceConfig.get_value("market", "WEAPON_COST_GROWTH", 1.5))
	assert_eq(w.upgrade_cost(), int(round(base * growth)))
