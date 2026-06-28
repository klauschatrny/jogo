extends TestCase

func _boss() -> Boss:
	return Boss.from_dict({
		"id": "bss_x", "name": "Chefe", "rank": "BOSS",
		"base_stats": {"max_hp": 100, "attack": 10, "defense": 4},
		"phases": [
			{"hp_threshold": 0.5, "on_enter": ["enrage"], "atk_mult": 2.0}
		],
		"can_summon_ghost": true,
		"ghost_summon_threshold": 0.6,
		"intro_dialogue": "Você vai cair.",
	})

func test_from_dict_hidrata_boss() -> void:
	var b := _boss()
	assert_eq(b.name, "Chefe")
	assert_eq(b.rank, "BOSS")
	assert_eq(b.phases.size(), 1)
	assert_true(b.can_summon_ghost)
	assert_eq(b.intro_dialogue, "Você vai cair.")
	assert_eq(b.stats.max_hp, 100)

func test_boss_e_um_enemy() -> void:
	assert_true(_boss() is Enemy, "Boss deve estender Enemy")

func test_fase_dispara_no_threshold() -> void:
	var b := _boss()
	b.stats.current_hp = 70   # 70% -> acima de 0.5, não dispara fase
	var ev1 := b.on_damaged()
	assert_false("enrage" in ev1, "fase não deve disparar a 70%")
	# mas ghost dispara (<= 0.6? 0.7 não). Confirma que nada de ghost ainda:
	assert_false("summon_ghost" in ev1)

	b.stats.current_hp = 40   # 40% -> dispara ghost (<=0.6) e fase (<=0.5)
	var ev2 := b.on_damaged()
	assert_true("summon_ghost" in ev2)
	assert_true("enrage" in ev2)

func test_fase_dispara_so_uma_vez() -> void:
	var b := _boss()
	b.stats.current_hp = 40
	b.on_damaged()
	b.stats.current_hp = 30
	var ev := b.on_damaged()
	assert_false("enrage" in ev, "fase não deve disparar de novo")
	assert_false("summon_ghost" in ev, "ghost só é invocado uma vez")

func test_atk_mult_aplicado() -> void:
	var b := _boss()
	assert_eq(b.stats.attack, 10)
	b.stats.current_hp = 40
	b.on_damaged()
	assert_eq(b.stats.attack, 20, "enrage dobra o ataque")

func test_factory_escala_boss() -> void:
	var b := EnemyFactory.build_boss({
		"id": "b", "rank": "BOSS", "base_stats": {"max_hp": 40, "attack": 8, "defense": 4},
		"phases": [],
	}, 1)
	assert_eq(b.stats.max_hp, 240)   # 40 * 6.0 (rank BOSS)
	assert_true(b is Boss)
