extends TestCase

## GhostRepository: roundtrip de leitura/escrita do ghosts.json e ciclo de vida (§1.4.4).
## Usa um caminho temporário em user:// para não tocar no save real.

const TEST_PATH := "user://test_saves/ghosts_test.json"

func _snapshot() -> Dictionary:
	return {
		"name": "Kael",
		"stats": {"max_hp": 400, "attack": 49, "defense": 31},
		"weapon": {"id": "wpn_sword_mourning", "level": 9},
		"augments": [{"id": "a1", "tier": "ARTIFACT"}],
	}

## Repositório com arquivo limpo (remove qualquer resíduo de teste anterior).
func _fresh_repo() -> GhostRepository:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	return GhostRepository.new(TEST_PATH)

func test_sem_arquivo_sem_fantasma() -> void:
	var repo := _fresh_repo()
	assert_null(repo.load_active(), "sem arquivo → sem fantasma (degradação graciosa)")
	assert_false(repo.has_active())

func test_record_death_e_load() -> void:
	var repo := _fresh_repo()
	var g := repo.record_death(_snapshot(), 25, "run-1", 0.65)
	assert_eq(g.death_floor, 25)
	assert_false(g.defeated)

	var loaded := repo.load_active()
	assert_true(loaded != null)
	assert_eq(loaded.death_floor, 25)
	assert_eq(loaded.origin_run_id, "run-1")
	assert_eq(loaded.player_snapshot["name"], "Kael")
	assert_true(repo.has_active())

func test_sobrescreve_fantasma_mais_recente() -> void:
	var repo := _fresh_repo()
	repo.record_death(_snapshot(), 5, "run-1", 0.65)
	repo.record_death(_snapshot(), 12, "run-2", 0.65)
	var loaded := repo.load_active()
	assert_eq(loaded.death_floor, 12, "sempre enfrenta o fracasso mais recente")
	assert_eq(loaded.origin_run_id, "run-2")

func test_mark_defeated() -> void:
	var repo := _fresh_repo()
	repo.record_death(_snapshot(), 10, "run-1", 0.65)
	repo.mark_defeated()
	var loaded := repo.load_active()
	assert_true(loaded.defeated, "derrotado vira troféu — não some, mas fica marcado")
	# limpeza final
	DirAccess.remove_absolute(TEST_PATH)
