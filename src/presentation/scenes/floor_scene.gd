## Loop de um andar (§2.4 Fase 3): waves de inimigos comuns → boss → recompensa de cards
## → próximo andar. Mantém o RunState vivo entre andares (não troca de cena), recriando os
## inimigos a cada andar. Matar inimigos concede XP (level-up via Leveling).
## Provisório quanto à FSM: a integração com a StateMachine vem na Fase 4.
extends Node2D

var _run: RunState
var _floor_mgr: FloorManager
var _player_view: PlayerView
var _enemies: Array = []
var _hud: Hud
var _msg: Label
var _layer: CanvasLayer
var _phase := "waves"          # waves | boss | reward | dead
var _floor_config: Dictionary = {}

# repositórios carregados uma vez
var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository

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

	var cfg = JsonLoader.load_file("res://data/floors/floor_default.json")
	_floor_config = cfg if typeof(cfg) == TYPE_DICTIONARY else {}

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
	_phase = "waves"
	_floor_mgr = FloorManager.build(_run.current_floor, _floor_config)
	_msg.text = "Andar %d" % _run.current_floor
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
	_msg.text = "Andar %d — CHEFE!" % _run.current_floor
	var base := _boss_repo.get_by_id(_floor_mgr.boss_id)
	if base.is_empty():
		_on_floor_cleared()
		return
	var boss := EnemyFactory.build_boss(base, _run.current_floor)
	_add_view(BossView.new(), boss, Vector2(320, 70))

func _add_view(view: EnemyView, enemy: Enemy, pos: Vector2) -> void:
	view.setup(enemy, _player_view)
	view.position = pos
	view.died.connect(_on_enemy_died.bind(view, enemy))
	_enemies.append(view)
	add_child(view)

func _on_enemy_died(view: EnemyView, enemy: Enemy) -> void:
	_enemies.erase(view)
	Leveling.add_xp(_run.player, int(enemy.loot.get("xp", 0)))
	if not _enemies.is_empty():
		return
	if _phase == "waves":
		_spawn_next_wave()
	elif _phase == "boss":
		_on_floor_cleared()

func _on_floor_cleared() -> void:
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
	_msg.text = "VOCÊ MORREU no andar %d — Enter p/ menu" % _run.current_floor

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
	if _phase == "dead" and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")
