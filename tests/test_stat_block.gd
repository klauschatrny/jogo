extends TestCase

func test_defaults() -> void:
	var s := StatBlock.new()
	assert_eq(s.max_hp, 0)
	assert_almost(s.crit_damage, 1.5)
	assert_almost(s.attack_speed, 1.0)
	assert_almost(s.damage_mult, 1.0)

func test_from_dict() -> void:
	var s := StatBlock.from_dict({"max_hp": 40, "attack": 8, "defense": 2})
	assert_eq(s.max_hp, 40)
	assert_eq(s.current_hp, 40)  # current_hp default = max_hp
	assert_eq(s.attack, 8)
	assert_eq(s.defense, 2)

func test_current_hp_explicito() -> void:
	var s := StatBlock.from_dict({"max_hp": 100, "current_hp": 30})
	assert_eq(s.current_hp, 30)

func test_round_trip() -> void:
	var original := StatBlock.from_dict({"max_hp": 120, "attack": 5, "crit_chance": 0.05})
	var copy := StatBlock.from_dict(original.to_dict())
	assert_eq(copy.max_hp, 120)
	assert_eq(copy.attack, 5)
	assert_almost(copy.crit_chance, 0.05)

func test_clone_independente() -> void:
	var s := StatBlock.from_dict({"max_hp": 50})
	var c := s.clone()
	c.max_hp = 999
	assert_eq(s.max_hp, 50, "clone não deve afetar o original")
