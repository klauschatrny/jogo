extends TestCase

const SKELETON := {
	"id": "enm_skeleton", "name": "Esqueleto", "rank": "NORMAL",
	"base_stats": {"max_hp": 40, "attack": 8, "defense": 2, "move_speed": 80},
}

func test_stats_saem_intactos_do_json() -> void:
	var e := EnemyFactory.build(SKELETON)
	assert_eq(e.stats.max_hp, 40)
	assert_eq(e.stats.attack, 8)
	assert_eq(e.stats.defense, 2)
	assert_eq(e.stats.current_hp, 40)
	assert_almost(e.stats.move_speed, 80.0)

## O ponto do pivô soulslike: o rank passou a ser rótulo (barra de vida, XP, IA), NÃO um
## multiplicador. Se um ELITE deve bater mais forte, quem diz isso é o JSON dele.
func test_rank_nao_multiplica_nada() -> void:
	var elite := SKELETON.duplicate(true)
	elite["rank"] = "ELITE"
	var e := EnemyFactory.build(elite)
	assert_eq(e.stats.max_hp, 40)
	assert_eq(e.stats.attack, 8)

func test_boss_tambem_sai_intacto() -> void:
	var boss := SKELETON.duplicate(true)
	boss["rank"] = "BOSS"
	var b := EnemyFactory.build_boss(boss)
	assert_eq(b.stats.max_hp, 40)
	assert_eq(b.rank, "BOSS")

## Dois inimigos do mesmo JSON não podem compartilhar StatBlock: ferir um mataria o outro.
func test_instancias_independentes() -> void:
	var a := EnemyFactory.build(SKELETON)
	var b := EnemyFactory.build(SKELETON)
	a.stats.current_hp = 1
	assert_eq(b.stats.current_hp, 40)
