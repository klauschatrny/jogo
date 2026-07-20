extends TestCase

## Frasco de cura (o Estus): a única cura sob demanda. Cargas limitadas, gasto comprometido
## (a carga sai no início; a cura é aplicada pela apresentação ao fim do gesto).

func _player() -> Player:
	var w := Weapon.from_dict({"base_damage": 15})
	return Player.create_new("X", w)

func test_comeca_com_o_frasco_cheio() -> void:
	var p := _player()
	assert_eq(p.flask_charges, p.flask_capacity())
	assert_eq(p.flask_max, p.flask_capacity())
	assert_true(p.flask_charges > 0)

func test_beber_gasta_uma_carga_e_devolve_a_cura() -> void:
	var p := _player()
	p.take_damage(p.stats.max_hp - 1)          # quase morto, cabe cura
	var antes := p.flask_charges
	var cura := p.drink_flask()
	assert_eq(p.flask_charges, antes - 1, "uma carga a menos")
	assert_true(cura > 0, "devolve o quanto vai curar")
	assert_almost(float(cura), float(p.stats.max_hp) * 0.4, 1.0)

## O gasto é COMPROMETIDO: drink_flask() não cura por si — quem chama aplica no fim do gesto.
## Isto modela a interrupção: se um golpe cancelar o gole, a carga já foi mas a cura não veio.
func test_beber_nao_cura_por_si_a_cura_e_de_quem_chama() -> void:
	var p := _player()
	var hp := p.stats.max_hp - 50
	p.take_damage(50)
	assert_eq(p.stats.current_hp, hp)
	p.drink_flask()                            # só compromete a carga
	assert_eq(p.stats.current_hp, hp, "a vida não muda até heal() ser chamado")

func test_sem_carga_nao_bebe() -> void:
	var p := _player()
	p.take_damage(p.stats.max_hp - 1)
	for _i in p.flask_max:
		assert_true(p.drink_flask() > 0)
	assert_eq(p.flask_charges, 0)
	assert_false(p.can_drink())
	assert_eq(p.drink_flask(), 0, "frasco vazio não devolve cura")

func test_vida_cheia_bebe_assim_mesmo() -> void:
	var p := _player()                          # nasce com HP cheio
	assert_true(p.can_drink(), "beber com a vida cheia é permitido")
	assert_true(p.drink_flask() > 0, "devolve a cura mesmo cheio (satura ao aplicar)")
	assert_eq(p.flask_charges, p.flask_max - 1, "a carga é gasta assim mesmo — decisão do jogador")

func test_morto_nao_bebe() -> void:
	var p := _player()
	p.take_damage(p.stats.max_hp)
	assert_false(p.is_alive())
	assert_false(p.can_drink())
	assert_eq(p.drink_flask(), 0)

func test_recarregar_enche_de_volta() -> void:
	var p := _player()
	p.take_damage(p.stats.max_hp - 1)
	p.drink_flask()
	p.drink_flask()
	assert_true(p.flask_charges < p.flask_max)
	p.refill_flask()
	assert_eq(p.flask_charges, p.flask_max, "descansar/renascer enche o frasco")

## A cura escala com o Vigor: como é fração da vida MÁXIMA, subir vida engorda o gole.
func test_a_cura_escala_com_a_vida_maxima() -> void:
	var p := _player()
	var cura_base := p.flask_heal_amount()
	p.attribute_points = 5
	for _i in 5:
		p.spend_point("vigor")
	assert_true(p.flask_heal_amount() > cura_base, "mais vida máxima, gole maior")

func test_descansar_recarrega_o_frasco() -> void:
	var w := Weapon.from_dict({"id": "w", "base_damage": 15, "weapon_growth": 1.12})
	var rs := RunState.start_new("Kael", w, [], 1)
	rs.player.take_damage(rs.player.stats.max_hp - 1)
	rs.player.drink_flask()
	assert_true(rs.player.flask_charges < rs.player.flask_max)
	rs.rest_at("cripta", 100.0)
	assert_eq(rs.player.flask_charges, rs.player.flask_max, "a fogueira reabastece a cura")

func test_renascer_recarrega_o_frasco() -> void:
	var w := Weapon.from_dict({"id": "w", "base_damage": 15, "weapon_growth": 1.12})
	var rs := RunState.start_new("Kael", w, [], 1)
	rs.player.take_damage(rs.player.stats.max_hp - 1)
	rs.player.drink_flask()
	rs.player.take_damage(rs.player.stats.max_hp)   # morre
	rs.respawn()
	assert_eq(rs.player.flask_charges, rs.player.flask_max, "renasce com o frasco cheio")
