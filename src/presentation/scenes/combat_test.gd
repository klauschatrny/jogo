## Arena de teste da Fase 2 (§2.4, critério: entrar numa sala, matar um inimigo e morrer).
## Monta jogador + inimigos + HUD via código. Não usa ainda a FSM/FloorManager — isso
## chega na Fase 3/4. Provisório: serve para sentir o combate.
extends Node2D

var _player: Player
var _enemies_alive := 0
var _msg: Label

const GROUND_Y := 300.0

func _ready() -> void:
	_add_background()
	_add_ground()

	var weapons := WeaponRepository.new()
	weapons.load_all()
	var weapon := weapons.get_weapon("wpn_sword_mourning")
	if weapon == null:
		weapon = Weapon.from_dict({
			"base_damage": 15, "weapon_growth": 1.12, "attack_speed": 1.5, "attack_range": 55})
	_player = Player.create_new("Kael", weapon)

	var pv := PlayerView.new()
	pv.setup(_player)
	pv.position = Vector2(320, GROUND_Y - 40)
	add_child(pv)

	var enemies := EnemyRepository.new()
	enemies.load_all()
	_spawn(enemies, "enm_skeleton", Vector2(470, GROUND_Y - 40), pv)
	_spawn(enemies, "enm_skeleton", Vector2(560, GROUND_Y - 40), pv)

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Hud.new()
	layer.add_child(hud)
	hud.set_player(_player)

	_msg = Label.new()
	_msg.position = Vector2(230, 150)
	_msg.add_theme_font_size_override("font_size", 22)
	layer.add_child(_msg)

	EventBus.player_died.connect(_on_player_died)

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.size = Vector2(640, 360)
	bg.z_index = -10
	add_child(bg)

func _add_ground() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1280, 200)
	col.shape = rect
	col.position = Vector2(320, GROUND_Y + 100)
	body.add_child(col)
	add_child(body)

	var fill := ColorRect.new()
	fill.color = Palette.GROUND
	fill.position = Vector2(0, GROUND_Y)
	fill.size = Vector2(640, 60)
	fill.z_index = -5
	add_child(fill)

func _spawn(repo: EnemyRepository, id: String, pos: Vector2, target: Node2D) -> void:
	var enemy := repo.get_enemy(id)
	if enemy == null:
		push_warning("[CombatTest] inimigo não encontrado: %s" % id)
		return
	var ev := EnemyView.new()
	ev.setup(enemy, target)
	ev.position = pos
	ev.died.connect(_on_enemy_died)
	_enemies_alive += 1
	add_child(ev)

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_msg.text = "SALA LIMPA!  (Enter p/ menu)"

func _on_player_died(_p: Player) -> void:
	_msg.text = "VOCÊ MORREU  (Enter p/ menu)"

func _unhandled_input(event: InputEvent) -> void:
	var acabou := (_player and not _player.is_alive()) or _enemies_alive <= 0
	if acabou and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")
