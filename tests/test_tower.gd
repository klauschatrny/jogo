extends TestCase

## TowerManager (§2.4 Fase 4): agenda de bosses, classificação de andares e vitória.
## Inclui um teste de integridade do conteúdo real (data/floors/tower.json + data/bosses).

func _cfg() -> Dictionary:
	return {
		"total_floors": 50,
		"king_floor": 51,
		"default_boss": "bss_guardian",
		"boss_schedule": {"10": "gbs_a", "20": "gbs_b", "50": "gbs_e", "51": "king_x"},
	}

func test_from_config_le_campos() -> void:
	var t := TowerManager.from_config(_cfg())
	assert_eq(t.total_floors, 50)
	assert_eq(t.king_floor, 51)
	assert_eq(t.default_boss, "bss_guardian")

func test_boss_for_floor() -> void:
	var t := TowerManager.from_config(_cfg())
	assert_eq(t.boss_for_floor(10), "gbs_a")      # agendado
	assert_eq(t.boss_for_floor(51), "king_x")     # Rei
	assert_eq(t.boss_for_floor(7), "bss_guardian") # comum → padrão

func test_classificacao_de_andares() -> void:
	var t := TowerManager.from_config(_cfg())
	assert_true(t.is_great_boss_floor(10))
	assert_false(t.is_great_boss_floor(51), "Rei não é great boss")
	assert_false(t.is_great_boss_floor(7), "andar comum não é great boss")
	assert_true(t.is_king_floor(51))
	assert_true(t.is_boss_only_floor(51), "arena do Rei é só boss")
	assert_false(t.is_boss_only_floor(10), "great boss mantém waves antes")

func test_vitoria() -> void:
	var t := TowerManager.from_config(_cfg())
	assert_false(t.is_victory_floor(50))
	assert_true(t.is_victory_floor(51))
	assert_true(t.is_victory_floor(52))

func test_defaults_sem_config() -> void:
	var t := TowerManager.from_config({})
	assert_eq(t.total_floors, 50)
	assert_eq(t.king_floor, 51)   # total + 1
	assert_eq(t.boss_for_floor(3), "bss_guardian")

# --- Integridade do conteúdo real ---

func test_todos_os_bosses_agendados_existem() -> void:
	var tcfg: Variant = JsonLoader.load_file("res://data/floors/tower.json")
	assert_eq(typeof(tcfg), TYPE_DICTIONARY, "tower.json deve carregar")
	var t := TowerManager.from_config(tcfg)

	var repo := BossRepository.new()
	repo.load_all()

	# boss padrão dos andares comuns
	assert_true(repo.has(t.default_boss), "boss padrão '%s' deve existir" % t.default_boss)

	for floor in t.boss_schedule:
		var id: String = t.boss_schedule[floor]
		assert_true(repo.has(id), "boss agendado '%s' (andar %d) deve existir" % [id, floor])
		var b := repo.get_boss(id)
		var expected := "KING" if t.is_king_floor(floor) else "GREAT_BOSS"
		assert_eq(b.rank, expected, "rank de '%s' deve ser %s" % [id, expected])

func test_great_bosses_enraivecem_a_50pct() -> void:
	# Regressão: o enrage (transição visível) dos great bosses deve disparar a 50% de HP.
	var tcfg: Variant = JsonLoader.load_file("res://data/floors/tower.json")
	var t := TowerManager.from_config(tcfg)
	var repo := BossRepository.new()
	repo.load_all()
	for floor in t.boss_schedule:
		if not t.is_great_boss_floor(floor):
			continue
		var b := repo.get_boss(t.boss_schedule[floor])
		var enrage_em_meio := false
		for ph in b.phases:
			if ph.on_enter.has("enrage"):
				assert_almost(ph.hp_threshold, 0.5, 0.001,
					"enrage de '%s' deve ser a 50%%" % b.id)
				enrage_em_meio = true
		assert_true(enrage_em_meio, "'%s' deve ter uma fase de enrage" % b.id)

func test_cinco_great_bosses_agendados() -> void:
	var tcfg: Variant = JsonLoader.load_file("res://data/floors/tower.json")
	var t := TowerManager.from_config(tcfg)
	var great := 0
	for floor in t.boss_schedule:
		if t.is_great_boss_floor(floor):
			great += 1
	assert_eq(great, 5, "devem existir 5 great bosses (10/20/30/40/50)")
