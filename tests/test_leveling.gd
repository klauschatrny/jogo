extends TestCase

func _player() -> Player:
	var w := Weapon.from_dict({"base_damage": 15})
	return Player.create_new("X", w)

func test_custo_do_nivel_cresce() -> void:
	assert_eq(Leveling.level_cost(1), 100)              # SOULS_BASE
	assert_eq(Leveling.level_cost(2), int(100 * 1.15))  # * SOULS_GROWTH
	assert_true(Leveling.level_cost(5) > Leveling.level_cost(4))

func test_almas_entram_no_bolso() -> void:
	var p := _player()
	assert_eq(p.souls, 0)
	p.gain_souls(80)
	p.gain_souls(40)
	assert_eq(p.souls, 120)
	assert_eq(p.level, 1, "almas NÃO sobem de nível sozinhas — nível se compra na fogueira")

func test_sem_almas_nao_compra_nivel() -> void:
	var p := _player()
	p.gain_souls(Leveling.level_cost(1) - 1)
	assert_false(Leveling.can_level_up(p))
	assert_false(Leveling.level_up(p))
	assert_eq(p.level, 1)
	assert_eq(p.attribute_points, 0)

func test_comprar_nivel_gasta_almas_e_da_ponto() -> void:
	var p := _player()
	var custo := Leveling.level_cost(1)
	p.gain_souls(custo + 30)
	assert_true(Leveling.can_level_up(p))
	assert_true(Leveling.level_up(p))
	assert_eq(p.level, 2)
	assert_eq(p.souls, 30, "as almas gastas saem do bolso")
	assert_eq(p.attribute_points, Attributes.points_per_level())

## A regra do gênero: o nível comprado ainda não move stat nenhuma. O PONTO é que move.
func test_comprar_nivel_nao_muda_stat_nenhuma() -> void:
	var p := _player()
	var hp := p.stats.max_hp
	var atk := p.stats.attack
	p.gain_souls(Leveling.level_cost(1))
	Leveling.level_up(p)
	assert_eq(p.stats.max_hp, hp)
	assert_eq(p.stats.attack, atk)
	assert_true(p.spend_point("vigor"))
	assert_true(p.stats.max_hp > hp, "só o ponto gasto vira poder")

func test_morrer_derruba_todas_as_almas() -> void:
	var p := _player()
	p.gain_souls(250)
	var caidas := p.lose_souls()
	assert_eq(caidas, 250)
	assert_eq(p.souls, 0, "morrer esvazia o bolso — elas vão para o Eco")

func test_o_que_ja_foi_gasto_nao_se_perde() -> void:
	var p := _player()
	p.gain_souls(Leveling.level_cost(1) + 50)
	Leveling.level_up(p)
	p.spend_point("vigor")
	var hp := p.stats.max_hp
	var lvl := p.level
	p.lose_souls()                       # morre
	assert_eq(p.souls, 0)
	assert_eq(p.level, lvl, "o nível comprado é seu para sempre")
	assert_eq(p.stats.max_hp, hp, "e o atributo subido também")
