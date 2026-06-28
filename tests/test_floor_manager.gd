extends TestCase

const CFG := {
	"waves_base": 2, "enemies_per_wave": 3,
	"enemy_pool": ["enm_skeleton"], "boss_id": "bss_guardian",
}

func test_build_waves() -> void:
	var fm := FloorManager.build(1, CFG)
	assert_eq(fm.wave_count(), 2)
	assert_eq(fm.boss_id, "bss_guardian")
	assert_eq(fm.waves[0].size(), 3)

func test_andar_alto_tem_mais_waves() -> void:
	var fm := FloorManager.build(11, CFG)   # +1 wave a cada 10 andares
	assert_eq(fm.wave_count(), 3)

func test_andar_alto_tem_mais_inimigos() -> void:
	var fm := FloorManager.build(6, CFG)    # +1 inimigo a cada 5 andares
	assert_eq(fm.waves[0].size(), 4)

func test_next_wave_avanca_e_limpa() -> void:
	var fm := FloorManager.build(1, CFG)
	assert_true(fm.has_next_wave())
	fm.next_wave()
	fm.next_wave()
	assert_false(fm.has_next_wave())
	assert_true(fm.is_cleared())
	assert_eq(fm.next_wave().size(), 0)  # sem mais waves

func test_pool_vazio_usa_fallback() -> void:
	var cfg := CFG.duplicate(true)
	cfg["enemy_pool"] = []
	var fm := FloorManager.build(1, cfg)
	assert_eq(fm.waves[0][0], "enm_skeleton")
