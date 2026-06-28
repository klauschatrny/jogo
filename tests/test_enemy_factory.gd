extends TestCase

const SKELETON := {
	"id": "enm_skeleton", "name": "Esqueleto", "rank": "NORMAL",
	"base_stats": {"max_hp": 40, "attack": 8, "defense": 2, "move_speed": 80},
}

func test_andar_1_igual_ao_base() -> void:
	var e := EnemyFactory.build(SKELETON, 1)
	assert_eq(e.stats.max_hp, 40)
	assert_eq(e.stats.attack, 8)
	assert_eq(e.stats.defense, 2)
	assert_eq(e.stats.current_hp, 40)

func test_escala_com_andar() -> void:
	# andar 10: 40 * 1.09^9 ~= 87
	var e := EnemyFactory.build(SKELETON, 10)
	assert_eq(e.stats.max_hp, 87)

func test_rank_elite_multiplica() -> void:
	var elite := SKELETON.duplicate(true)
	elite["rank"] = "ELITE"
	var e := EnemyFactory.build(elite, 1)
	assert_eq(e.stats.max_hp, 100)  # 40 * 2.5
	assert_eq(e.stats.attack, 11)   # 8 * 1.4 = 11.2 -> 11

func test_move_speed_nao_escala() -> void:
	var e := EnemyFactory.build(SKELETON, 20)
	assert_almost(e.stats.move_speed, 80.0)
