extends TestCase

## GhostFactory: monta o Enemy "eco" a partir de um GhostData + jogador atual (§1.4 / §2.2.5).

func _snapshot(max_hp: int) -> Dictionary:
	return {
		"name": "Kael",
		"level": 20,
		"stats": {"max_hp": max_hp, "attack": 100, "defense": 50, "move_speed": 130.0},
		"weapon": {"id": "wpn_sword_mourning", "level": 8},
		"augments": [
			{"id": "a1", "tier": "ARTIFACT"},
			{"id": "r1", "tier": "RELIC"},
			{"id": "f1", "tier": "FRAGMENT"},
			{"id": "f2", "tier": "FRAGMENT"},
		],
	}

func _ghost(max_hp: int, death_floor := 15) -> GhostData:
	return GhostData.from_snapshot(_snapshot(max_hp), death_floor, "run-1", 0.65)

func _player(max_hp_override := -1) -> Player:
	var w := Weapon.from_dict({"id": "w", "base_damage": 15, "weapon_growth": 1.12})
	var p := Player.create_new("Atual", w)
	if max_hp_override > 0:
		p.stats.max_hp = max_hp_override
		p.stats.current_hp = max_hp_override
	return p

func test_eco_e_elite_com_ia_echo() -> void:
	var e := GhostFactory.build(_ghost(1000), _player())
	assert_eq(e.rank, "ELITE")
	assert_eq(e.archetype, "ECHO")
	assert_eq(e.ai_profile, "echo")
	assert_true(e.name.contains("Eco"))

func test_stats_nerfados_pelo_coeficiente() -> void:
	var e := GhostFactory.build(_ghost(200), _player(2000))
	# HP: min(200*0.65, 2000*2.0) = 130 (sem teto). attack/defense nerfados.
	assert_eq(e.stats.max_hp, 130)
	assert_eq(e.stats.attack, 65)   # 100 * 0.65
	assert_eq(e.stats.defense, 32)  # int(50 * 0.65) = 32

func test_anti_impossivel_teto_de_hp() -> void:
	# run lendária (HP gigante) vs jogador atual fraco → fantasma sempre derrotável.
	var player := _player(300)
	var e := GhostFactory.build(_ghost(100000), player)
	var cap := int(player.stats.max_hp * float(BalanceConfig.nemesis.get("GHOST_HP_CAP", 2.0)))
	assert_true(e.stats.max_hp <= cap, "HP do eco não pode passar do teto anti-impossível")
	assert_eq(e.stats.max_hp, 600)  # 300 * 2.0

func test_herda_subconjunto_de_augments() -> void:
	# death_floor 15, divisor 3 → n = min(5, 5) = 5, mas só há 4 augments → herda 4.
	var e := GhostFactory.build(_ghost(1000, 15), _player())
	assert_eq(e.abilities.size(), 4)
	# death_floor 6 → n=2, prioriza ARTIFACT depois RELIC
	var e2 := GhostFactory.build(_ghost(1000, 6), _player())
	assert_eq(e2.abilities.size(), 2)
	assert_eq(e2.abilities[0]["tier"], "ARTIFACT")
