extends TestCase

## As 5 regras matemáticas do Nemesis (§1.4.2). Funções puras — testadas com números explícitos.

func test_nerf_aplica_coeficiente() -> void:
	assert_eq(NemesisRules.nerf(100.0, 0.65), 65)
	assert_eq(NemesisRules.nerf(50.0, 0.5), 25)

func test_ghost_hp_sem_teto_usa_nerf() -> void:
	# snapshot pequeno; jogador atual com HP alto → o teto não morde, vale o nerf.
	var hp := NemesisRules.ghost_hp(200, 0.65, 1000, 2.0)
	assert_eq(hp, 130)  # 200 * 0.65

func test_ghost_hp_com_teto_anti_impossivel() -> void:
	# Regra 2: run lendária (HP gigante), jogador atual fraco → HP limitado a cap× o atual.
	var hp := NemesisRules.ghost_hp(100000, 0.65, 300, 2.0)
	assert_eq(hp, 600)  # min(65000, 300*2) = 600 — sempre derrotável

func test_ghost_hp_com_piso_anti_irrelevante() -> void:
	# snapshot fraco (65) mas piso 300 → não pode ser trivial; teto ainda manda quando aperta.
	assert_eq(NemesisRules.ghost_hp(100, 0.65, 1000, 2.0, 300.0), 300)  # piso vence o nerf
	assert_eq(NemesisRules.ghost_hp(100, 0.65, 100, 2.0, 300.0), 200)   # teto (100*2) vence o piso

func test_ghost_attack_com_piso() -> void:
	assert_eq(NemesisRules.ghost_attack(100.0, 0.65), 65)        # sem piso → nerf puro
	assert_eq(NemesisRules.ghost_attack(10.0, 0.65, 30.0), 30)   # piso evita dano insignificante

func test_inherited_count_faz_clamp() -> void:
	assert_eq(NemesisRules.inherited_count(0, 3, 5), 1)    # piso 1
	assert_eq(NemesisRules.inherited_count(3, 3, 5), 1)
	assert_eq(NemesisRules.inherited_count(9, 3, 5), 3)
	assert_eq(NemesisRules.inherited_count(30, 3, 5), 5)   # teto 5
	assert_eq(NemesisRules.inherited_count(100, 3, 5), 5)

func _augs() -> Array:
	return [
		{"id": "f1", "tier": "FRAGMENT"},
		{"id": "r1", "tier": "RELIC"},
		{"id": "a1", "tier": "ARTIFACT"},
		{"id": "f2", "tier": "FRAGMENT"},
	]

func test_select_prioriza_tier_alto() -> void:
	# death_floor 9, divisor 3 → n=3. Deve pegar ARTIFACT e RELIC primeiro.
	var sel := NemesisRules.select_inherited_augments(_augs(), 9, 3, 5)
	assert_eq(sel.size(), 3)
	assert_eq(sel[0]["tier"], "ARTIFACT")
	assert_eq(sel[1]["tier"], "RELIC")
	# o terceiro é um fragmento (sobra)
	assert_eq(sel[2]["tier"], "FRAGMENT")

func test_select_respeita_n_minimo() -> void:
	var sel := NemesisRules.select_inherited_augments(_augs(), 1, 3, 5)
	assert_eq(sel.size(), 1)
	assert_eq(sel[0]["tier"], "ARTIFACT")  # o mais forte

func _ghost(floor: int, defeated := false) -> GhostData:
	var g := GhostData.new()
	g.death_floor = floor
	g.defeated = defeated
	return g

func test_should_summon() -> void:
	assert_true(NemesisRules.should_summon(_ghost(7), 7), "eco do andar atual deve ser invocado")
	assert_false(NemesisRules.should_summon(_ghost(7), 8), "andar diferente não invoca")
	assert_false(NemesisRules.should_summon(_ghost(7, true), 7), "já derrotado não reaparece")
	assert_false(NemesisRules.should_summon(null, 7), "sem fantasma → não invoca")
