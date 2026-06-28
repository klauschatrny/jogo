extends TestCase

func _player() -> Player:
	var w := Weapon.from_dict({"base_damage": 15})
	return Player.create_new("X", w)

func test_xp_to_next_curva() -> void:
	assert_almost(Leveling.xp_to_next(1), 100.0)        # XP_BASE
	assert_almost(Leveling.xp_to_next(2), 100.0 * 1.15)

func test_add_xp_sem_subir() -> void:
	var p := _player()
	var levels := Leveling.add_xp(p, 50)
	assert_eq(levels, 0)
	assert_eq(p.level, 1)
	assert_eq(p.experience, 50)

func test_add_xp_sobe_um_nivel() -> void:
	var p := _player()
	var levels := Leveling.add_xp(p, 100)
	assert_eq(levels, 1)
	assert_eq(p.level, 2)
	assert_eq(p.experience, 0)

func test_level_up_aumenta_max_hp() -> void:
	var p := _player()
	assert_eq(p.stats.max_hp, 120)
	Leveling.add_xp(p, 100)
	assert_eq(p.stats.max_hp, 134)  # +HP_PER_LEVEL
	assert_eq(p.stats.attack, 7)    # +ATK_PER_LEVEL

func test_level_up_cura_o_hp_ganho() -> void:
	var p := _player()
	p.take_damage(20)               # 100/120
	Leveling.add_xp(p, 100)         # sobe p/ 134 de max, +14 de cura
	assert_eq(p.stats.current_hp, 114)

func test_add_xp_multiplos_niveis() -> void:
	var p := _player()
	# 100 (lvl1->2) + 115 (lvl2->3) = 215 sobe 2 níveis
	var levels := Leveling.add_xp(p, 215)
	assert_eq(levels, 2)
	assert_eq(p.level, 3)
