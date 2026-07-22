extends TestCase

func _config() -> Dictionary:
	return {
		"pattern": ["COMBAT", "REWARD", "COMBAT", "REWARD", "BOSS"],
		"reward_cards": 3,
		"encounters": ["sala_a", "sala_b", "sala_c"],
		"bosses": [{ "boss": "bss_ogre", "arena": "bosque_ogro" }],
	}

# ---- RunNode ----

func test_node_make_copia_payload() -> void:
	var p := {"encounter": "x"}
	var n := RunNode.make(RunNode.COMBAT, p)
	p["encounter"] = "MUDOU"
	assert_eq(n.type, RunNode.COMBAT)
	assert_eq(n.get_value("encounter"), "x", "payload deve ser cópia, não referência")

func test_node_classificacao() -> void:
	assert_true(RunNode.make(RunNode.COMBAT).is_combat())
	assert_true(RunNode.make(RunNode.ELITE).is_combat())
	assert_false(RunNode.make(RunNode.REWARD).is_combat())
	assert_true(RunNode.make(RunNode.BOSS).is_boss())

# ---- RunPlan (cursor) ----

func test_plan_cursor_anda_ate_o_fim() -> void:
	var plan := RunGenerator.generate(_config(), 1)
	assert_eq(plan.size(), 5)
	assert_eq(plan.current().type, RunNode.COMBAT)
	assert_false(plan.is_complete())
	# avança pelos 5 nós
	for i in 4:
		plan.advance()
	assert_true(plan.is_last())
	assert_eq(plan.current().type, RunNode.BOSS)
	assert_null(plan.advance(), "passar do último devolve null")
	assert_true(plan.is_complete())

func test_plan_peek_next() -> void:
	var plan := RunGenerator.generate(_config(), 1)
	assert_eq(plan.peek_next().type, RunNode.REWARD)

# ---- RunGenerator ----

func test_gerador_respeita_o_padrao() -> void:
	var plan := RunGenerator.generate(_config(), 7)
	assert_eq(plan.types(), ["COMBAT", "REWARD", "COMBAT", "REWARD", "BOSS"])

func test_reward_carrega_contagem_de_cards() -> void:
	var plan := RunGenerator.generate(_config(), 1)
	assert_eq(plan.nodes[1].get_value("cards"), 3)

func test_boss_carrega_arena() -> void:
	var plan := RunGenerator.generate(_config(), 1)
	var boss: RunNode = plan.nodes[4]
	assert_eq(boss.get_value("boss"), "bss_ogre")
	assert_eq(boss.get_value("arena"), "bosque_ogro")

func test_combate_carrega_encontro() -> void:
	var plan := RunGenerator.generate(_config(), 3)
	var enc = plan.nodes[0].get_value("encounter")
	assert_true(enc in ["sala_a", "sala_b", "sala_c"], "encontro deve vir do pool")

func test_determinista_com_seed() -> void:
	var a := RunGenerator.generate(_config(), 99)
	var b := RunGenerator.generate(_config(), 99)
	var ea := a.nodes.map(func(n: RunNode) -> String: return String(n.get_value("encounter", "")))
	var eb := b.nodes.map(func(n: RunNode) -> String: return String(n.get_value("encounter", "")))
	assert_eq(ea, eb, "mesma seed deve produzir os mesmos encontros")

func test_seeds_diferentes_variam_conteudo() -> void:
	# Com 3 encontros e 2 slots de combate, ao menos uma seed em muitas deve diferir de outra.
	var base := RunGenerator.generate(_config(), 1)
	var base_enc := String(base.nodes[0].get_value("encounter"))
	var achou_diferente := false
	for s in range(2, 40):
		var p := RunGenerator.generate(_config(), s)
		if String(p.nodes[0].get_value("encounter")) != base_enc:
			achou_diferente = true
			break
	assert_true(achou_diferente, "seeds diferentes devem variar o conteúdo dos combates")

func test_pool_menor_que_slots_faz_wrap() -> void:
	var cfg := _config()
	cfg["encounters"] = ["so_uma"]
	var plan := RunGenerator.generate(cfg, 5)
	assert_eq(plan.nodes[0].get_value("encounter"), "so_uma")
	assert_eq(plan.nodes[2].get_value("encounter"), "so_uma", "pool de 1 repete nos dois combates")

func test_climb_sorteia_do_pool() -> void:
	var cfg := _config()
	cfg["pattern"] = ["BOSS", "REWARD", "CLIMB", "BOSS"]
	cfg["climbs"] = ["esc_a", "esc_b"]
	var plan := RunGenerator.generate(cfg, 5)
	assert_eq(plan.nodes[2].type, RunNode.CLIMB)
	var c = plan.nodes[2].get_value("climb")
	assert_true(c in ["esc_a", "esc_b"], "escadaria deve vir do pool")

func test_climb_nao_e_combate_nem_boss() -> void:
	var n := RunNode.make(RunNode.CLIMB)
	assert_false(n.is_combat())
	assert_false(n.is_boss())
