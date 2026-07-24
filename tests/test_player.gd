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

# --- Augments com stats FORA do StatBlock (fôlego/frasco/cura), interpretados pelo Player. ---

func _repo() -> AugmentRepository:
	var r := AugmentRepository.new()
	r.load_all()
	return r

func test_augment_vigor_soma_hp() -> void:
	var p := _player()
	var hp0 := p.stats.max_hp
	p.add_augment(_repo().get_augment("aug_vigor"))
	assert_eq(p.stats.max_hp, hp0 + 30)

func test_augment_folego_soma_stamina() -> void:
	var p := _player()
	var s0 := int(p.stamina.maximum)
	p.add_augment(_repo().get_augment("aug_folego"))
	assert_eq(int(p.stamina.maximum), s0 + 20)

func test_augment_flask_charge_soma_capacidade_e_enche() -> void:
	var p := _player()
	p.receive_flask()
	var cap0 := p.flask_capacity()
	var ch0 := p.flask_charges
	p.add_augment(_repo().get_augment("aug_flask_charge"))
	assert_eq(p.flask_capacity(), cap0 + 1)
	assert_eq(p.flask_charges, ch0 + 1, "a carga nova entra cheia")

func test_augment_elixir_aumenta_cura() -> void:
	var p := _player()
	var heal0 := p.flask_heal_amount()
	p.add_augment(_repo().get_augment("aug_flask_potency"))
	assert_true(p.flask_heal_amount() > heal0, "cura por gole deve subir")

func test_augment_armadura_reduz_fisico() -> void:
	var p := _player()
	p.add_augment(_repo().get_augment("aug_armor"))
	assert_almost(p.stats.damage_reduction, 0.06)

func test_augment_manto_reduz_magico() -> void:
	var p := _player()
	p.add_augment(_repo().get_augment("aug_magic_cloak"))
	assert_almost(p.stats.magic_resist, 0.12)
