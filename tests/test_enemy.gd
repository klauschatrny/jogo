extends TestCase

func _skeleton() -> Enemy:
	return Enemy.from_dict({
		"id": "enm_x", "name": "Esqueleto", "archetype": "MELEE", "rank": "NORMAL",
		"base_stats": {"max_hp": 40, "attack": 8, "defense": 2, "move_speed": 80},
		"abilities": ["abil_basic_slash"],
		"loot": {"gold_min": 4, "gold_max": 10, "xp": 12},
	})

func test_from_dict_basico() -> void:
	var e := _skeleton()
	assert_eq(e.id, "enm_x")
	assert_eq(e.name, "Esqueleto")
	assert_eq(e.rank, "NORMAL")
	assert_eq(e.archetype, "MELEE")

func test_hidrata_stats() -> void:
	var e := _skeleton()
	assert_eq(e.stats.max_hp, 40)
	assert_eq(e.stats.current_hp, 40)
	assert_eq(e.stats.attack, 8)
	assert_eq(e.stats.defense, 2)
	assert_almost(e.stats.move_speed, 80.0)

func test_ai_profile_default() -> void:
	var e := Enemy.from_dict({"id": "x", "base_stats": {"max_hp": 10}})
	assert_eq(e.ai_profile, "aggressive")

func test_loot_e_abilities() -> void:
	var e := _skeleton()
	assert_eq(e.abilities.size(), 1)
	assert_eq(int(e.loot.get("xp", 0)), 12)
