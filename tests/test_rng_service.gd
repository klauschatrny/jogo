extends TestCase

func test_seed_determinista() -> void:
	RNGService.set_seed(12345)
	var first: Array = []
	for i in 8:
		first.append(RNGService.randi_range(0, 1000000))
	RNGService.set_seed(12345)
	var second: Array = []
	for i in 8:
		second.append(RNGService.randi_range(0, 1000000))
	assert_eq(first, second, "mesma seed deve gerar a mesma sequência")

func test_seeds_diferentes() -> void:
	RNGService.set_seed(1)
	var a := RNGService.randi_range(0, 1000000)
	RNGService.set_seed(2)
	var b := RNGService.randi_range(0, 1000000)
	assert_true(a != b, "seeds diferentes deveriam divergir (probabilístico)")

func test_reset_repete_sequencia() -> void:
	RNGService.set_seed(99)
	var a := RNGService.randf()
	RNGService.reset()
	var b := RNGService.randf()
	assert_almost(a, b, 0.0000001, "reset deve voltar ao início da seed")

func test_randi_range_respeita_limites() -> void:
	RNGService.set_seed(7)
	for i in 200:
		var v := RNGService.randi_range(3, 7)
		assert_true(v >= 3 and v <= 7, "valor fora do intervalo: %d" % v)

func test_weighted_index_ignora_peso_zero() -> void:
	RNGService.set_seed(7)
	var counts := [0, 0, 0]
	for i in 300:
		var idx := RNGService.weighted_index([1.0, 0.0, 1.0])
		counts[idx] += 1
	assert_eq(counts[1], 0, "índice com peso 0 nunca deve ser escolhido")
	assert_true(counts[0] > 0 and counts[2] > 0, "índices com peso > 0 devem aparecer")

func test_weighted_index_soma_zero() -> void:
	assert_eq(RNGService.weighted_index([0.0, 0.0]), -1, "soma <= 0 retorna -1")
