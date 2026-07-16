extends TestCase

func _player() -> Player:
	var w := Weapon.from_dict({"id": "w", "base_damage": 15, "weapon_growth": 1.12})
	return Player.create_new("Kael", w)

func test_create_new_usa_balance() -> void:
	var p := _player()
	assert_eq(p.name, "Kael")
	assert_eq(p.stats.max_hp, 90)    # BASE_PHP
	assert_eq(p.stats.current_hp, 90)
	assert_eq(p.stats.attack, 5)     # BASE_PATK
	assert_true(p.is_alive())

func test_take_damage_subtrai() -> void:
	var p := _player()
	var dealt := p.take_damage(30)
	assert_eq(dealt, 30)
	assert_eq(p.stats.current_hp, 60)
	assert_true(p.is_alive())

func test_take_damage_nao_passa_de_zero() -> void:
	var p := _player()
	p.take_damage(500)
	assert_eq(p.stats.current_hp, 0)
	assert_false(p.is_alive())

func test_take_damage_negativo_e_clampado() -> void:
	var p := _player()
	p.take_damage(-10)
	assert_eq(p.stats.current_hp, 90, "dano negativo não deve curar")

func test_heal_respeita_max() -> void:
	var p := _player()
	p.take_damage(50)   # 40
	p.heal(100)
	assert_eq(p.stats.current_hp, 90, "cura não passa do max_hp")

func test_snapshot_contem_dados() -> void:
	var p := _player()
	var snap := p.snapshot()
	assert_eq(snap["name"], "Kael")
	assert_true(snap.has("stats"))
	assert_true(snap.has("weapon"))
