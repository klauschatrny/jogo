extends TestCase

func _frag(id: String) -> Augment:
	return Augment.from_dict({"id": id, "tier": "FRAGMENT", "weight": 100})

func _artifact(id: String) -> Augment:
	return Augment.from_dict({"id": id, "tier": "ARTIFACT", "weight": 6})

func _pool() -> AugmentPool:
	return AugmentPool.new([_frag("a"), _frag("b"), _frag("c"), _frag("d"), _artifact("e")])

func test_draw_retorna_n_distintos() -> void:
	RNGService.set_seed(1)
	var cards := _pool().draw(3)
	assert_eq(cards.size(), 3)
	var ids := {}
	for c in cards:
		ids[c.id] = true
	assert_eq(ids.size(), 3, "cards devem ser distintos")

func test_draw_determinista_com_seed() -> void:
	var p := _pool()
	RNGService.set_seed(42)
	var a := p.draw(3)
	RNGService.set_seed(42)
	var b := p.draw(3)
	assert_eq(a.map(func(x): return x.id), b.map(func(x): return x.id))

func test_draw_pool_menor_que_n() -> void:
	RNGService.set_seed(1)
	var p := AugmentPool.new([_frag("a"), _frag("b")])
	assert_eq(p.draw(5).size(), 2)

func test_exclude_remove_do_sorteio() -> void:
	RNGService.set_seed(1)
	var cards := _pool().draw(4, 0, ["a", "b"])
	for c in cards:
		assert_true(c.id != "a" and c.id != "b", "excluídos não podem sair")

func test_effective_weight_sem_luck() -> void:
	var p := _pool()
	assert_almost(p.effective_weight(_frag("x"), 0), 100.0)
	assert_almost(p.effective_weight(_artifact("y"), 0), 6.0)

func test_luck_aumenta_peso_de_artefato() -> void:
	var p := _pool()
	# ARTIFACT factor 0.05: weight 6 * (1 + 100*0.05) = 6 * 6 = 36
	assert_almost(p.effective_weight(_artifact("y"), 100), 36.0)
	# FRAGMENT factor 0.0: luck não afeta
	assert_almost(p.effective_weight(_frag("x"), 100), 100.0)
