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

# --- Fogueiras / morte (soulslike): a run não acaba mais ao morrer ---

func test_descansar_acende_cura_e_marca_o_retorno() -> void:
	var rs := _run()
	rs.player.take_damage(80)
	rs.rest_at(1, 260.0)
	assert_eq(rs.player.stats.current_hp, rs.player.stats.max_hp, "descansar cura por completo")
	assert_true(rs.has_checkpoint())
	assert_eq(rs.checkpoint_floor, 1)
	assert_true(rs.is_lit(1, 260.0), "a fogueira fica acesa")
	assert_false(rs.is_lit(1, 999.0), "só a que ele tocou")

func test_descansar_enche_a_stamina() -> void:
	var rs := _run()
	rs.player.stamina.consume(rs.player.stamina.maximum)
	assert_false(rs.player.stamina.can_act())
	rs.rest_at(1, 260.0)
	assert_true(rs.player.stamina.can_act(), "levantar da fogueira já podendo agir")

func test_morrer_devolve_a_run_a_ultima_fogueira() -> void:
	var rs := _run()
	rs.rest_at(1, 260.0)
	rs.advance_floor()                       # foi para o nível 2 (boss)
	rs.player.take_damage(rs.player.stats.max_hp)
	assert_false(rs.player.is_alive())
	rs.respawn()
	assert_eq(rs.current_floor, 1, "volta ao nível da fogueira, não ao começo do jogo")
	assert_eq(rs.respawn_x(80.0), 260.0, "e ao ponto exato dela")
	assert_eq(rs.player.stats.current_hp, rs.player.stats.max_hp)
	assert_eq(rs.deaths, 1)

func test_morrer_sem_fogueira_volta_ao_comeco_do_jogo() -> void:
	var rs := _run()
	rs.advance_floor()                       # está no nível 2 (a arena do chefe)
	assert_eq(rs.current_floor, 2)
	rs.player.take_damage(rs.player.stats.max_hp)
	rs.respawn()
	assert_eq(rs.current_floor, 1, "sem fogueira, volta ao COMEÇO — nunca à sala onde morreu")
	assert_eq(rs.respawn_x(80.0), 80.0)

func test_nunca_se_renasce_onde_se_morreu() -> void:
	# A regra, em qualquer combinação: ou a fogueira, ou o começo. Nunca o lugar da queda.
	for morte_no_nivel in [1, 2]:
		var rs := _run()
		rs.current_floor = morte_no_nivel
		rs.player.take_damage(rs.player.stats.max_hp)
		rs.respawn()
		assert_eq(rs.current_floor, 1, "sem fogueira: começo do jogo")

		var rs2 := _run()
		rs2.rest_at(1, 150.0)                # descansou na sala do baú do nível 1
		rs2.current_floor = morte_no_nivel
		rs2.player.take_damage(rs2.player.stats.max_hp)
		rs2.respawn()
		assert_eq(rs2.current_floor, 1, "com fogueira: o nível DELA")
		assert_eq(rs2.respawn_x(80.0), 150.0, "e o ponto exato dela")


func test_a_morte_preserva_o_que_foi_conquistado() -> void:
	var rs := _run()
	rs.choose_augment(rs.augment_pool._augments[0])   # a1: +10% max_hp
	rs.player.level = 4
	rs.player.recalculate_stats()
	var lvl := rs.player.level
	var augs := rs.player.augments.size()
	var hp_max := rs.player.stats.max_hp
	rs.player.take_damage(rs.player.stats.max_hp)
	rs.respawn()
	assert_eq(rs.player.level, lvl, "o nível não se perde")
	assert_eq(rs.player.augments.size(), augs, "os augments também não")
	assert_eq(rs.player.stats.max_hp, hp_max)

func test_a_morte_leva_o_buff_de_vinganca() -> void:
	var rs := _run()
	rs.apply_vengeance()
	rs.respawn()
	assert_false(rs.has_vengeance(), "o buff temporário não sobrevive à morte")

func test_respawn_x_ignora_fogueira_de_outro_nivel() -> void:
	var rs := _run()
	rs.rest_at(1, 260.0)
	rs.current_floor = 2                     # sem passar pela fogueira do 2
	assert_eq(rs.respawn_x(80.0), 80.0, "a fogueira do nível 1 não posiciona no nível 2")

func test_nivel_vencido_fica_vencido() -> void:
	var rs := _run()
	assert_false(rs.is_cleared(1))
	rs.mark_cleared(1)
	rs.mark_cleared(1)                       # idempotente
	assert_true(rs.is_cleared(1))
	assert_eq(rs.cleared_floors.size(), 1)
	assert_false(rs.is_cleared(2))

# --- O Eco (marca de sangue) ---

func test_morrer_deixa_o_eco_com_as_almas() -> void:
	var rs := _run()
	rs.player.gain_souls(240)
	rs.drop_echo(1, 900.0)
	assert_eq(rs.player.souls, 0, "o bolso esvazia")
	assert_true(rs.echo != null)
	assert_eq(rs.echo.souls, 240, "e as almas ficam com o Eco")
	assert_almost(rs.echo.death_x, 900.0)
	assert_true(rs.has_echo_on(1))
	assert_false(rs.has_echo_on(2), "só no nível onde caiu")

func test_sem_almas_nao_deixa_eco() -> void:
	var rs := _run()
	rs.drop_echo(1, 900.0)
	assert_true(rs.echo == null, "um Eco vazio seria só um inimigo a mais no caminho")

func test_vencer_o_eco_devolve_as_almas() -> void:
	var rs := _run()
	rs.player.gain_souls(240)
	rs.drop_echo(1, 900.0)
	var back := rs.recover_echo()
	assert_eq(back, 240)
	assert_eq(rs.player.souls, 240)
	assert_true(rs.echo == null)
	assert_false(rs.has_echo_on(1))

## A aposta do gênero: morrer de novo antes de chegar no Eco substitui a marca — as almas
## antigas se perdem PARA SEMPRE.
func test_morrer_de_novo_apaga_o_eco_anterior() -> void:
	var rs := _run()
	rs.player.gain_souls(500)
	rs.drop_echo(1, 900.0)               # 500 almas ficam lá
	rs.player.gain_souls(60)             # juntou umas poucas no caminho de volta
	rs.drop_echo(1, 300.0)               # morreu antes de chegar nelas
	assert_eq(rs.echo.souls, 60, "só as novas — as 500 se perderam")
	assert_almost(rs.echo.death_x, 300.0)
	assert_eq(rs.recover_echo(), 60)

func test_o_eco_e_construido_a_partir_de_voce() -> void:
	var rs := _run()
	rs.player.gain_souls(100)
	rs.drop_echo(1, 500.0)
	var snap: Dictionary = rs.echo.player_snapshot
	assert_eq(String(snap.get("name", "")), rs.player.name)
	assert_eq(int(snap.get("level", 0)), rs.player.level)

func test_cutscene_do_boss_so_na_primeira_vez() -> void:
	var rs := _run()
	assert_false(rs.boss_seen("bss_ogre"))
	rs.mark_boss_seen("bss_ogre")
	assert_true(rs.boss_seen("bss_ogre"))
	assert_false(rs.boss_seen("bss_outro"))

func test_offer_exclui_nao_stackable_possuido() -> void:
	var rs := _run()
	# adiciona a2 (não-stackable) e confirma que não reaparece
	var a2: Augment = rs.augment_pool._augments[1]
	rs.choose_augment(a2)
	for _i in 20:
		RNGService.set_seed(_i)
		for card in rs.offer_augments():
			assert_true(card.id != "a2", "não-stackable possuído não pode ser oferecido")
