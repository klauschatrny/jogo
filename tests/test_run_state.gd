extends TestCase

func _augs() -> Array:
	return [
		Augment.from_dict({"id": "a1", "tier": "FRAGMENT", "weight": 100, "stackable": true, "max_stacks": 5,
			"effects": [{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.10}]}),
		Augment.from_dict({"id": "a2", "tier": "FRAGMENT", "weight": 100, "stackable": false}),
		Augment.from_dict({"id": "a3", "tier": "RELIC", "weight": 30, "stackable": true, "max_stacks": 3}),
		Augment.from_dict({"id": "w1", "tier": "RELIC", "category": "WEAPON", "weight": 30, "stackable": true, "max_stacks": 9}),
	]

func _run() -> RunState:
	var w := Weapon.from_dict({"id": "w", "base_damage": 15, "weapon_growth": 1.12})
	return RunState.start_new("Kael", w, _augs(), 123)

func test_start_new() -> void:
	var rs := _run()
	assert_eq(rs.player.name, "Kael")
	assert_eq(rs.current_floor, 1)
	assert_eq(rs.seed, 123)
	assert_eq(rs.augment_pool.size(), 4)

func test_advance_floor() -> void:
	var rs := _run()
	rs.advance_floor()
	assert_eq(rs.current_floor, 2)
	assert_eq(rs.player.current_floor, 2)

func test_advance_floor_cura_hp_cheio() -> void:
	var rs := _run()
	rs.player.take_damage(80)
	assert_true(rs.player.stats.current_hp < rs.player.stats.max_hp)
	rs.advance_floor()
	assert_eq(rs.player.stats.current_hp, rs.player.stats.max_hp)

func test_offer_augments_quantidade_padrao() -> void:
	var rs := _run()
	assert_eq(rs.offer_augments().size(), 3)  # cards_per_reward

func test_choose_augment_aplica_efeito() -> void:
	var rs := _run()
	var base_hp := rs.player.stats.max_hp
	rs.choose_augment(rs.augment_pool._augments[0])  # a1: +10% max_hp
	assert_true(rs.player.stats.max_hp > base_hp)
	assert_eq(rs.player.augments.size(), 1)

func test_weapon_augment_sobe_nivel_da_arma() -> void:
	var rs := _run()
	var lvl := rs.player.weapon.level
	# w1 é category WEAPON
	var w_aug: Augment = null
	for a in rs.augment_pool._augments:
		if a.category == "WEAPON":
			w_aug = a
	rs.choose_augment(w_aug)
	assert_eq(rs.player.weapon.level, lvl + 1)

func test_catarse_garante_reliquia_ou_superior() -> void:
	var rs := _run()  # o pool tem RELICs (a3, w1)
	for _i in 10:
		RNGService.set_seed(_i)
		var cards := rs.offer_augments_catharsis()
		assert_eq(cards.size(), 3, "deve oferecer a quantidade padrão")
		var tem_alto := false
		for c in cards:
			if c.tier == "RELIC" or c.tier == "ARTIFACT":
				tem_alto = true
		assert_true(tem_alto, "catarse deve garantir ao menos 1 Relíquia+")

func test_vinganca_aumenta_dano() -> void:
	var rs := _run()
	var base := rs.player.stats.damage_mult
	rs.apply_vengeance()
	assert_true(rs.has_vengeance())
	assert_true(rs.player.stats.damage_mult > base, "Vingança deve aumentar o dano")

func test_vinganca_nao_empilha() -> void:
	var rs := _run()
	rs.apply_vengeance()
	var dm := rs.player.stats.damage_mult
	rs.apply_vengeance()
	assert_almost(rs.player.stats.damage_mult, dm)

func test_vinganca_acaba_no_proximo_andar() -> void:
	var rs := _run()
	rs.apply_vengeance()
	rs.advance_floor()
	assert_false(rs.has_vengeance(), "o buff dura só até o fim do andar")

func test_offer_exclui_nao_stackable_possuido() -> void:
	var rs := _run()
	# adiciona a2 (não-stackable) e confirma que não reaparece
	var a2: Augment = rs.augment_pool._augments[1]
	rs.choose_augment(a2)
	for _i in 20:
		RNGService.set_seed(_i)
		for card in rs.offer_augments():
			assert_true(card.id != "a2", "não-stackable possuído não pode ser oferecido")
