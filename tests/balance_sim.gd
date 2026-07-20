## Lógica do simulador de balanceamento (§1.2.4). Carregada em RUNTIME por sim_balance.gd
## (via load()), pois referencia classes do Core que dependem dos autoloads — que só existem
## como nomes globais depois que o engine sobe. Ver o mesmo padrão em test_runner.gd.
extends RefCounted

# --- Premissas do jogador mediano (ajuste aqui OU em balance.json e re-rode) ---
const WEAPON_UP_PER_FLOOR := 0.6   # upgrades de arma por andar (geométrico domina o dano)
const AUG_PER_FLOOR := 0.8         # augments acumulados por andar
const ENEMY_ATTACKS_PER_SEC := 1.0 # cadência do inimigo (EnemyView.ATTACK_INTERVAL = 1.0s)

const SAMPLE_FLOORS := [1, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 51]

var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository
var _weapon_repo: WeaponRepository
var _tower: TowerManager
var _ttk: Dictionary
var _flags := 0

func run(ttk: Dictionary) -> int:
	_ttk = ttk
	_flags = 0
	_enemy_repo = EnemyRepository.new(); _enemy_repo.load_all()
	_boss_repo = BossRepository.new(); _boss_repo.load_all()
	_weapon_repo = WeaponRepository.new(); _weapon_repo.load_all()
	var tcfg: Variant = JsonLoader.load_file("res://data/floors/tower.json")
	_tower = TowerManager.from_config(tcfg if typeof(tcfg) == TYPE_DICTIONARY else {})

	print("\n===== SIMULAÇÃO DE BALANCEAMENTO (TTK por andar) =====")
	print("Premissas: nivel=andar, arma=1+%.1f*andar, augments=%.1f*andar\n" % [
		WEAPON_UP_PER_FLOOR, AUG_PER_FLOOR])
	print("%-5s %-22s %-11s %-24s %-24s" % ["And.", "Encontro", "Rank", "TTK matar (s)", "TTK morrer (s)"])
	print("".rpad(90, "-"))

	for floor in SAMPLE_FLOORS:
		var p := _median_player(floor)
		_report_normal(floor, p)
		_report_boss(floor, p)

	print("".rpad(90, "-"))
	print("%d valor(es) fora da banda.\n" % _flags)
	return _flags

# --- Construção do jogador mediano (usa as classes reais do Core) ---

func _median_player(floor: int) -> Player:
	var w := Weapon.from_dict(_weapon_repo.get_by_id("wpn_sword_mourning"))
	var p := Player.create_new("Mediano", w)
	p.level = floor
	for _i in (1 + int(floor * WEAPON_UP_PER_FLOOR)) - 1:
		w.upgrade()
	for i in int(floor * AUG_PER_FLOOR):
		p.augments.append(_iron_skin() if i % 3 == 2 else _sharp())
	p.recalculate_stats()
	p.stats.current_hp = p.stats.max_hp
	return p

func _sharp() -> Augment:   # +8% dano (Lâmina Afiada)
	return Augment.from_dict({"id": "sim_sharp", "tier": "FRAGMENT", "stackable": true, "max_stacks": 999,
		"effects": [{"stat": "damage_mult", "operation": "PCT_ADD", "value": 0.08}]})

func _iron_skin() -> Augment:  # +15% HP (Pele de Ferro)
	return Augment.from_dict({"id": "sim_iron", "tier": "RELIC", "stackable": true, "max_stacks": 999,
		"effects": [{"stat": "max_hp", "operation": "PCT_ADD", "value": 0.15}]})

# --- Métricas (fórmulas mestras §1.2.3) ---

func _player_dps(p: Player, target: StatBlock) -> float:
	var hit := CombatResolver.player_hit(p, target)
	return CombatResolver.dps(hit, p.weapon.attack_speed, p.stats.crit_chance, p.stats.crit_damage)

func _player_ehp(p: Player) -> float:
	return CombatResolver.ehp(float(p.stats.max_hp), CombatResolver.total_reduction(p.stats))

func _enemy_dps(enemy_stats: StatBlock, p: Player) -> float:
	return CombatResolver.enemy_hit(enemy_stats, p) * ENEMY_ATTACKS_PER_SEC

# --- Linhas do relatório ---

## Com o fim da escala geométrica, o inimigo NÃO muda de andar para andar — só o jogador cresce.
## O eixo "andar" virou, portanto, uma pergunta diferente e mais soulslike: por quanto tempo estes
## stats fixos continuam relevantes conforme o jogador sobe? Ver TTK matar caindo é o esperado.
func _report_normal(floor: int, p: Player) -> void:
	var e := EnemyFactory.build(_enemy_repo.get_by_id("enm_skeleton"))
	_emit_row(floor, e.name, e.rank, e.stats, p)

func _report_boss(floor: int, p: Player) -> void:
	var d := _boss_repo.get_by_id(_tower.boss_for_floor(floor))
	if d.is_empty():
		return
	var b := EnemyFactory.build_boss(d)
	_emit_row(floor, b.name, b.rank, b.stats, p)

func _emit_row(floor: int, label: String, rank: String, enemy_stats: StatBlock, p: Player) -> void:
	var pdps := _player_dps(p, enemy_stats)
	var ttk_kill := float(enemy_stats.max_hp) / pdps if pdps > 0.0 else INF
	var edps := _enemy_dps(enemy_stats, p)
	var ttk_die := _player_ehp(p) / edps if edps > 0.0 else INF

	var band: Dictionary = _ttk.get(rank, _ttk.get("GREAT_BOSS", {}))
	var kill_band: Array = band.get("enemy", [0, INF])
	var die_band: Array = band.get("player", [0, INF])

	print("%-5d %-22s %-11s %-24s %-24s" % [
		floor, label.left(22), rank, _fmt(ttk_kill, kill_band), _fmt(ttk_die, die_band)])

func _fmt(value: float, band: Array) -> String:
	var lo := float(band[0])
	var hi := float(band[1])
	var mark := "ok"
	if value < lo:
		mark = "BAIXO"; _flags += 1
	elif value > hi:
		mark = "ALTO"; _flags += 1
	return "%8.1f [%s-%s] %s" % [value, lo, hi, mark]
