extends TestCase

func _player() -> Player:
	return Player.create_new("X", Weapon.from_dict({"base_damage": 15}))

func test_comeca_nos_valores_de_partida() -> void:
	var p := _player()
	for s in Attributes.specs():
		var id := String(s["id"])
		assert_eq(p.attribute(id), int(s["start"]), "%s começa no 'start' do JSON" % id)
	assert_eq(p.attribute_points, 0)

## A base do jogador tem de bater com os atributos no ponto de partida: se não batesse, o valor
## inicial estaria sendo contado duas vezes (ou nenhuma).
func test_a_base_bate_com_os_atributos_iniciais() -> void:
	var p := _player()
	assert_eq(p.stats.max_hp, int(Scaling.player_base_hp()))
	assert_eq(p.stats.attack, int(Scaling.player_base_atk()))
	assert_almost(p.stamina.maximum, float(BalanceConfig.stamina.get("MAX", 100.0)))

func test_vigor_da_vida() -> void:
	var p := _player()
	var hp := p.stats.max_hp
	p.attribute_points = 2
	assert_true(p.spend_point("vigor"))
	assert_true(p.spend_point("vigor"))
	var ganho := int(Attributes.spec("vigor").get("gain", {}).get("max_hp", 0))
	assert_eq(p.stats.max_hp, hp + 2 * ganho)
	assert_eq(p.attribute("vigor"), Attributes.start_of("vigor") + 2)
	assert_eq(p.attribute_points, 0)

func test_forca_da_dano() -> void:
	var p := _player()
	var atk := p.stats.attack
	p.attribute_points = 1
	assert_true(p.spend_point("strength"))
	assert_true(p.stats.attack > atk)

func test_resistencia_alarga_a_stamina() -> void:
	var p := _player()
	var max_antes := p.stamina.maximum
	p.attribute_points = 1
	assert_true(p.spend_point("endurance"))
	var ganho := float(Attributes.spec("endurance").get("gain", {}).get("stamina_max", 0))
	assert_almost(p.stamina.maximum, max_antes + ganho)
	assert_almost(p.stamina.current, p.stamina.maximum, 0.01, "o teto novo já vem cheio")

## Subir Vigor com a vida no fim cura de fato — como sentar na fogueira em Dark Souls.
func test_subir_vigor_entrega_o_hp_novo() -> void:
	var p := _player()
	p.take_damage(60)
	var hp_antes := p.stats.current_hp
	p.attribute_points = 1
	p.spend_point("vigor")
	var ganho := int(Attributes.spec("vigor").get("gain", {}).get("max_hp", 0))
	assert_eq(p.stats.current_hp, hp_antes + ganho)

func test_sem_ponto_nao_gasta() -> void:
	var p := _player()
	var hp := p.stats.max_hp
	assert_false(p.spend_point("vigor"), "sem pontos, não sobe nada")
	assert_eq(p.stats.max_hp, hp)
	assert_eq(p.attribute("vigor"), Attributes.start_of("vigor"))

func test_atributo_inexistente_nao_consome_ponto() -> void:
	var p := _player()
	p.attribute_points = 1
	assert_false(p.spend_point("carisma"))
	assert_eq(p.attribute_points, 1, "o ponto continua no bolso")

func test_bonus_ignora_os_pontos_de_partida() -> void:
	# Nos valores iniciais o bônus é ZERO: a base já os embute.
	assert_almost(Attributes.bonus(Attributes.defaults(), "max_hp"), 0.0)
	var attrs := Attributes.defaults()
	attrs["vigor"] = Attributes.start_of("vigor") + 3
	var ganho := float(Attributes.spec("vigor").get("gain", {}).get("max_hp", 0))
	assert_almost(Attributes.bonus(attrs, "max_hp"), 3.0 * ganho)
