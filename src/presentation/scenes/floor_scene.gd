## Loop de um andar (§2.4 Fase 3): waves de inimigos comuns → boss → recompensa de cards
## → próximo andar. Mantém o RunState vivo entre andares (não troca de cena), recriando os
## inimigos a cada andar. Matar inimigos concede XP (level-up via Leveling).
## Provisório quanto à FSM: a integração com a StateMachine vem na Fase 4.
extends Node2D

var _run: RunState
var _floor_mgr: FloorManager
var _tower: TowerManager
var _player_view: PlayerView
var _enemies: Array = []
var _hud: Hud
var _msg: Label
var _layer: CanvasLayer
var _phase := "waves"          # waves | boss | reward | dead | victory
var _floor_config: Dictionary = {}
var _current_boss_id := ""
var _boss_view: EnemyView
var _ghost_to_summon: GhostData
var _ghost_summoned := false

# repositórios carregados uma vez
var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository
var _ghost_repo: GhostRepository

func _ready() -> void:
	randomize()
	_add_background()

	_layer = CanvasLayer.new()
	add_child(_layer)
	_hud = Hud.new()
	_layer.add_child(_hud)
	_msg = Label.new()
	_msg.position = Vector2(16, 36)
	_layer.add_child(_msg)

	var weapons := WeaponRepository.new()
	weapons.load_all()
	var weapon := weapons.get_weapon("wpn_sword_mourning")
	if weapon == null:
		weapon = Weapon.from_dict({"base_damage": 15, "weapon_growth": 1.12, "attack_speed": 1.2, "attack_range": 55})

	var aug_repo := AugmentRepository.new()
	aug_repo.load_all()
	_enemy_repo = EnemyRepository.new()
	_enemy_repo.load_all()
	_boss_repo = BossRepository.new()
	_boss_repo.load_all()
	_ghost_repo = GhostRepository.new()

	var cfg = JsonLoader.load_file("res://data/floors/floor_default.json")
	_floor_config = cfg if typeof(cfg) == TYPE_DICTIONARY else {}

	var tcfg = JsonLoader.load_file("res://data/floors/tower.json")
	_tower = TowerManager.from_config(tcfg if typeof(tcfg) == TYPE_DICTIONARY else {})

	_run = RunState.start_new("Kael", weapon, aug_repo.all_augments(), randi())
	_player_view = PlayerView.new()
	_player_view.setup(_run.player)
	_player_view.position = Vector2(320, 200)
	add_child(_player_view)
	_hud.set_player(_run.player)

	EventBus.player_died.connect(_on_player_died)
	_start_floor()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.size = Vector2(640, 360)
	bg.z_index = -10
	add_child(bg)

func _start_floor() -> void:
	var floor := _run.current_floor
	_current_boss_id = _tower.boss_for_floor(floor)

	# Arena do Rei (andar final): sem waves de trash, direto para o boss.
	if _tower.is_boss_only_floor(floor):
		_phase = "boss"
		_spawn_boss()
		return

	_phase = "waves"
	var cfg := _floor_config.duplicate()
	cfg["boss_id"] = _current_boss_id
	_floor_mgr = FloorManager.build(floor, cfg)
	_msg.text = "Andar %d / %d" % [floor, _tower.total_floors]
	_spawn_next_wave()

func _spawn_next_wave() -> void:
	if not _floor_mgr.has_next_wave():
		_spawn_boss()
		return
	for enemy_id in _floor_mgr.next_wave():
		var base := _enemy_repo.get_by_id(enemy_id)
		if base.is_empty():
			continue
		var enemy := EnemyFactory.build(base, _run.current_floor)
		_add_view(EnemyView.new(), enemy, _random_spawn_pos())

func _spawn_boss() -> void:
	_phase = "boss"
	var floor := _run.current_floor
	var base := _boss_repo.get_by_id(_current_boss_id)
	if base.is_empty():
		push_warning("[floor_scene] boss '%s' não encontrado no andar %d" % [_current_boss_id, floor])
		_on_floor_cleared()
		return
	var boss := EnemyFactory.build_boss(base, floor)

	# Nemesis: este boss invocará o eco se há um fantasma ancorado neste andar (Regra 5).
	_ghost_summoned = false
	var g := _ghost_repo.load_active()
	_ghost_to_summon = g if NemesisRules.should_summon(g, floor) else null

	if _tower.is_king_floor(floor):
		_msg.text = "Andar %d — O REI DA TORRE!" % floor
	elif _tower.is_great_boss_floor(floor):
		_msg.text = "Andar %d — GRANDE CHEFE: %s" % [floor, boss.name]
	else:
		_msg.text = "Andar %d — CHEFE!" % floor

	var bv := BossView.new()
	bv.summon_ghost.connect(_on_summon_ghost)
	_boss_view = bv
	_add_view(bv, boss, Vector2(320, 70))

func _on_summon_ghost() -> void:
	if _ghost_to_summon == null or _ghost_summoned:
		return
	_ghost_summoned = true
	var ghost := GhostFactory.build(_ghost_to_summon, _run.player)
	_add_view(GhostView.new(), ghost, Vector2(360, 120))
	_msg.text = "%s foi invocado para te enfrentar!" % ghost.name

func _add_view(view: EnemyView, enemy: Enemy, pos: Vector2) -> void:
	view.setup(enemy, _player_view)
	view.position = pos
	view.died.connect(_on_enemy_died.bind(view, enemy))
	_enemies.append(view)
	add_child(view)

func _on_enemy_died(view: EnemyView, enemy: Enemy) -> void:
	_enemies.erase(view)
	Leveling.add_xp(_run.player, int(enemy.loot.get("xp", 0)))

	if view is GhostView:
		_on_ghost_defeated()   # catarse — não encerra o andar (o boss segue)

	match _phase:
		"waves":
			if _enemies.is_empty():
				_spawn_next_wave()
		"boss":
			# Derrotar o eco NÃO é obrigatório (§1.4.2): o andar termina quando o boss cai,
			# mesmo que o fantasma ainda esteja vivo.
			if view == _boss_view:
				_clear_remaining_ghost()
				_on_floor_cleared()

## Catarse / Vingança (§1.4.3): cura imediata + buff de dano até o fim do andar.
func _on_ghost_defeated() -> void:
	_ghost_repo.mark_defeated()
	var pct := float(BalanceConfig.nemesis.get("VENGEANCE_HEAL_PCT", 0.25))
	_run.player.heal(int(_run.player.stats.max_hp * pct))
	_run.apply_vengeance()
	EventBus.ghost_defeated.emit(_ghost_to_summon)
	_msg.text = "Você superou seu Eco! Vingança ativada."

## Boss caiu com o eco ainda vivo: encerra a luta removendo o fantasma restante.
func _clear_remaining_ghost() -> void:
	for v in _enemies.duplicate():
		if v is GhostView:
			_enemies.erase(v)
			v.queue_free()

func _on_floor_cleared() -> void:
	# Derrotar o boss do andar final (Rei) conclui a torre.
	if _tower.is_victory_floor(_run.current_floor):
		_on_victory()
		return
	_phase = "reward"
	var cards := _run.offer_augments()
	if cards.is_empty():
		_next_floor()
		return
	var cs := CardSelect.new()
	cs.setup(cards)
	cs.chosen.connect(_on_card_chosen.bind(cs))
	_layer.add_child(cs)

func _on_card_chosen(aug: Augment, cs: CardSelect) -> void:
	cs.queue_free()
	_run.choose_augment(aug)
	_next_floor()

func _next_floor() -> void:
	_run.advance_floor()
	_start_floor()

func _on_player_died(_p: Player) -> void:
	_phase = "dead"
	# Cria/sobrescreve o fantasma: você sempre enfrenta seu fracasso mais recente (§1.4.4).
	var coeff := float(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0.65))
	_ghost_repo.record_death(_run.player.snapshot(), _run.current_floor, _run.player.run_id, coeff)
	_msg.text = "VOCÊ MORREU no andar %d — um Eco ficou para trás. Enter p/ menu" % _run.current_floor

## Provisório (Leva 2): a tela de Vitória de verdade entra na Leva 3.
func _on_victory() -> void:
	_phase = "victory"
	_msg.text = "VITÓRIA! Você conquistou a Torre — Enter p/ menu"

func _random_spawn_pos() -> Vector2:
	# borda aleatória, longe do centro onde o jogador começa
	var margin := 40.0
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(margin, 600), margin)
		1: return Vector2(randf_range(margin, 600), 320)
		2: return Vector2(margin, randf_range(margin, 320))
		_: return Vector2(600, randf_range(margin, 320))

func _unhandled_input(event: InputEvent) -> void:
	if (_phase == "dead" or _phase == "victory") and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")
