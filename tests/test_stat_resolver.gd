extends TestCase

func _base() -> StatBlock:
	return StatBlock.from_dict({"max_hp": 120, "attack": 5, "lifesteal": 0.0, "damage_mult": 1.0})

func _aug(effects: Array) -> Augment:
	return Augment.from_dict({"id": "a", "effects": effects})

func test_sem_augments_retorna_base() -> void:
	var r := StatResolver.resolve(_base(), [])
	assert_eq(r.max_hp, 120)
	assert_eq(r.attack, 5)

func test_add_flat() -> void:
	# lifesteal base 0 + ADD 0.03 = 0.03
	var r := StatResolver.resolve(_base(), [_aug([{"stat": "lifesteal", "operation": "ADD", "value": 0.03}])])
	assert_almost(r.lifesteal, 0.03)

func test_pct_add_em_max_hp() -> void:
	# 120 * (1 + 0.15) = 138
	var r := StatResolver.resolve(_base(), [_aug([{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.15}])])
	assert_eq(r.max_hp, 138)

func test_pct_add_soma_entre_si() -> void:
	# 120 * (1 + 0.10 + 0.20) = 156  (não 120*1.1*1.2)
	var augs := [
		_aug([{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.10}]),
		_aug([{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.20}]),
	]
	assert_eq(StatResolver.resolve(_base(), augs).max_hp, 156)

func test_mult_multiplica() -> void:
	# damage_mult 1.0 * 2.0 = 2.0  (glass cannon)
	var r := StatResolver.resolve(_base(), [_aug([{"stat": "damage_mult", "operation": "MULT", "value": 2.0}])])
	assert_almost(r.damage_mult, 2.0)

func test_ordem_add_pct_mult() -> void:
	# max_hp: ((120 + 30) * (1 + 0.10)) * 0.5 = 82.5 -> 82 (int)
	var augs := [_aug([
		{"stat": "max_hp", "operation": "ADD", "value": 30},
		{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.10},
		{"stat": "max_hp", "operation": "MULT", "value": 0.5},
	])]
	assert_eq(StatResolver.resolve(_base(), augs).max_hp, 82)

func test_set_sobrescreve() -> void:
	var r := StatResolver.resolve(_base(), [_aug([{"stat": "attack", "operation": "SET", "value": 99}])])
	assert_eq(r.attack, 99)

func test_player_recalcula_com_augment() -> void:
	var p := Player.create_new("X", Weapon.from_dict({"base_damage": 15}))
	p.add_augment(Augment.from_dict({"id": "iron", "effects": [
		{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.5}]}))
	assert_eq(p.stats.max_hp, 135)  # 90 * 1.5
