extends TestCase

func _stam() -> Stamina:
	return Stamina.from_config({"MAX": 100, "REGEN_PER_SEC": 50, "REGEN_DELAY": 0.5})

func test_from_config_comeca_cheia() -> void:
	var s := _stam()
	assert_eq(s.maximum, 100.0)
	assert_eq(s.current, 100.0)
	assert_almost(s.ratio(), 1.0)

func test_consume_gasta_e_limita_em_zero() -> void:
	var s := _stam()
	assert_true(s.consume(30.0))
	assert_almost(s.current, 70.0)
	s.consume(1000.0)
	assert_almost(s.current, 0.0, 0.001, "não passa de zero")

func test_can_act_enquanto_houver_stamina() -> void:
	var s := _stam()
	s.current = 1.0
	assert_true(s.can_act(), "estilo DS: qualquer stamina > 0 permite agir")
	s.current = 0.0
	assert_false(s.can_act())
	assert_false(s.consume(10.0), "vazia não consome")

func test_regen_espera_o_atraso() -> void:
	var s := _stam()
	s.consume(50.0)              # current 50, inicia atraso de 0.5s
	s.tick(0.4)                  # ainda no atraso
	assert_almost(s.current, 50.0, 0.001, "não regenera durante o atraso")
	s.tick(0.2)                  # zera o atraso neste frame (sem regen ainda)
	assert_almost(s.current, 50.0, 0.001, "frame que fecha o atraso não regenera")
	s.tick(0.1)                  # atraso já zerado: regenera 0.1s * 50/s = 5
	assert_almost(s.current, 55.0, 0.001, "regenera após o atraso")

func test_regen_nao_passa_do_maximo() -> void:
	var s := _stam()
	s.consume(10.0)
	s.tick(0.5)                  # zera o atraso
	s.tick(100.0)               # regen enorme
	assert_almost(s.current, 100.0, 0.001, "clampa no máximo")
