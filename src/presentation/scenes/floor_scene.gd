## Loop de um andar: sala regida por elites (horda reciclada) → boss → recompensa de cards
## → próximo andar. Mantém o RunState vivo entre andares (não troca de cena), recriando os
## inimigos a cada andar. Matar inimigos concede XP (level-up via Leveling).
## Provisório quanto à FSM: a integração com a StateMachine vem na Fase 4.
extends Node2D

# --- DEBUG (desligue pondo DEBUG = false antes de buildar de verdade) ---
const DEBUG := true
const DEBUG_START_FLOOR := 0   # 0 = normal; ex.: 10 começa no 1º great boss
const DEBUG_START_LEVEL := 0   # 0 = normal; nível inicial do jogador

var _run: RunState
var _tower: TowerManager
var _player_view: PlayerView
var _enemies: Array = []
var _hud: Hud
var _msg: Label
var _layer: CanvasLayer
var _phase := "room"           # room | to_boss_door | transition | boss | reward | to_exit_door | dead | victory
var _floor_config: Dictionary = {}

# --- Sala (regida pelo Necromante) ---
# O Necromante (classe "elite") nasce no fim da sala, estático e ranged. Enquanto vive, cada
# esqueleto morto (minion/normal/heavy) renasce após respawn_delay num raio ao redor dele. Ao
# morrer, TODOS os esqueletos morrem e a sala é liberada. Heavies mantêm o encadeamento a/b/c (andar 1).
var _room: Dictionary = {}
var _alive := { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }
# Andar 1: heavies a/b/c em estágio. Cada item: { view, spawn_x, activated, dead }.
var _heavy_stage: Array = []
var _first_kill_done := false   # 1º esqueleto da horda morto (um dos gatilhos do heavy 'a')
var _necro: NecromancerView     # o Necromante (objetivo da sala); null se morto/inexistente
var _current_boss_id := ""
var _boss_view: EnemyView
var _boss_bar: BossHealthBar    # barra de vida grande no rodapé (Dark Souls)
var _ghost_to_summon: GhostData
var _ghost_summoned := false
var _ghost_beaten_this_floor := false

# repositórios carregados uma vez
var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository
var _ghost_repo: GhostRepository
var _crt: CrtOverlay
var _camera: GameCamera
var _bg: BiomeBackground        # fundo ambiental (parallax) por bioma
var _biomes: Array = []         # paletas de bioma (data/biomes.json)
var _corridor_length := 1920.0  # base 640×360 (3 telas de largura)
var _arena_width := 1920.0      # largura do ambiente atual (corredor ou sala do boss)
var _env: Node2D               # container do cenário atual (reconstruído por andar/sala)
var _fade: ColorRect           # overlay de fade das transições
var _door: Node2D              # porta ativa (nula quando não há)
var _door_x := 0.0

## Linha de topo do chão (eixo Y). Player e inimigos pousam aqui pela gravidade.
const GROUND_Y := 300.0         # base 640×360
const ENV_TILE_SCALE := 2.0     # arte de terreno em texel 2 (mesmo dos personagens)
const SPAWN_EXCLUSION := 180.0  # zona inicial (à esquerda) sem inimigos ao começar o andar
const L1_NECRO_ONLY := false    # TESTE: andar 1 só com o necromante (sem horda/heavies)
const BOSS_ROOM_W := 640.0     # sala do boss = uma tela fechada (base 640×360)
const DOOR_REACH := 30.0       # distância para "entrar" na porta (base 640×360)
const FADE_TIME := 0.35

func _ready() -> void:
	randomize()

	# Config do andar carregada cedo: define o comprimento do corredor (cenário + câmera).
	var cfg = JsonLoader.load_file("res://data/floors/floor_default.json")
	_floor_config = cfg if typeof(cfg) == TYPE_DICTIONARY else {}
	_corridor_length = float(_floor_config.get("corridor_length", _corridor_length))

	var bcfg = JsonLoader.load_file("res://data/biomes.json")
	_biomes = (bcfg.get("biomes", []) if typeof(bcfg) == TYPE_DICTIONARY else [])

	# Fundo ambiental (parallax) atrás de tudo; o conteúdo é definido por bioma em _build_environment.
	_bg = BiomeBackground.new()
	add_child(_bg)

	# Câmera que segue o player no eixo X, presa às bordas do nível; permite screen shake.
	# O cenário (corredor/sala) é construído por _start_floor, que ajusta os limites dela.
	_camera = GameCamera.new()
	_camera.position = Vector2(320, 180)
	add_child(_camera)
	_camera.make_current()

	_add_fade_overlay()

	# Overlay CRT/scanline acima de tudo (inclusive HUD). Alterna com F9.
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 100
	add_child(crt_layer)
	_crt = CrtOverlay.new()
	crt_layer.add_child(_crt)

	_layer = CanvasLayer.new()
	add_child(_layer)
	_hud = Hud.new()
	_layer.add_child(_hud)
	_boss_bar = BossHealthBar.new()          # barra grande no rodapé (só visível na luta de boss)
	_boss_bar.visible = false
	_layer.add_child(_boss_bar)
	_msg = Label.new()
	_msg.position = Vector2(16, 36)
	_msg.add_theme_font_size_override("font_size", 8)   # mensagem de seção (andar/avisos)
	_layer.add_child(_msg)

	var weapons := WeaponRepository.new()
	weapons.load_all()
	var weapon := weapons.get_weapon("wpn_sword_mourning")
	if weapon == null:
		weapon = Weapon.from_dict({"base_damage": 15, "weapon_growth": 1.12, "attack_speed": 1.5, "attack_range": 55})

	var aug_repo := AugmentRepository.new()
	aug_repo.load_all()
	_enemy_repo = EnemyRepository.new()
	_enemy_repo.load_all()
	_boss_repo = BossRepository.new()
	_boss_repo.load_all()
	_ghost_repo = GhostRepository.new()

	var tcfg = JsonLoader.load_file("res://data/floors/tower.json")
	_tower = TowerManager.from_config(tcfg if typeof(tcfg) == TYPE_DICTIONARY else {})

	_run = RunState.start_new("Kael", weapon, aug_repo.all_augments(), randi())
	_player_view = PlayerView.new()
	_player_view.setup(_run.player)
	_player_view.position = Vector2(80, GROUND_Y - 40)   # início à esquerda do corredor
	add_child(_player_view)
	_camera.follow_target = _player_view                 # câmera passa a seguir o player
	_hud.set_player(_run.player)

	EventBus.player_died.connect(_on_player_died)

	if DEBUG:
		_apply_debug_start()
		_show_debug_legend()

	_start_floor()

## (Re)constrói o cenário do nível num container próprio (_env), liberando o anterior.
## Corredor longo (waves) ou sala fechada do boss diferem só na largura e no tom do fundo.
## Inclui chão sólido + paredes nas duas pontas (camada 4) e ajusta os limites da câmera.
func _build_environment(width: float, is_boss_room: bool) -> void:
	if is_instance_valid(_env):
		_env.queue_free()
	_arena_width = width
	_door = null
	_env = Node2D.new()
	add_child(_env)

	# Bioma atual define o fundo (parallax) e as cores do chão. Sala do boss = mais escura.
	var biome := _biome_for_floor(_run.current_floor)
	var dim := 0.22 if is_boss_room else 0.0
	if _bg != null:
		_bg.apply(biome, dim)
	var ground_col := Color(String(biome.get("ground", "3b3f54"))).darkened(dim)
	var edge_col := Color(String(biome.get("ground_edge", "29283b"))).darkened(dim)

	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var floor_col := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(width + 200, 200)
	floor_col.shape = floor_rect
	floor_col.position = Vector2(width * 0.5, GROUND_Y + 100)   # topo do retângulo em GROUND_Y
	body.add_child(floor_col)
	for wall_x in [0.0, width]:             # paredes contêm player e inimigos no nível
		var wcol := CollisionShape2D.new()
		var wrect := RectangleShape2D.new()
		wrect.size = Vector2(40, 800)
		wcol.shape = wrect
		wcol.position = Vector2(wall_x + (-20.0 if wall_x == 0.0 else 20.0), 0.0)
		body.add_child(wcol)
	_env.add_child(body)

	# Chão sólido (backing): sempre presente, cobre qualquer vão sob a textura/tremor da câmera.
	var fill := ColorRect.new()
	fill.color = ground_col
	fill.position = Vector2(-40, GROUND_Y)
	fill.size = Vector2(width + 80, 440 - (GROUND_Y + 40))
	fill.z_index = -6
	_env.add_child(fill)

	# Terreno: textura em tile (assets/bg/<id>/ground.png) sobre o backing, ou a linha de
	# borda procedural se não houver arte.
	var ground_png := "res://assets/bg/%s/ground.png" % String(biome.get("id", ""))
	if String(biome.get("id", "")) != "" and ResourceLoader.exists(ground_png):
		var gtex := load(ground_png) as Texture2D
		var ground := TextureRect.new()
		ground.texture = gtex
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.stretch_mode = TextureRect.STRETCH_TILE
		ground.scale = Vector2(ENV_TILE_SCALE, ENV_TILE_SCALE)   # tile nativo ampliado ×2 (texel 2)
		ground.position = Vector2(-40, GROUND_Y)
		ground.size = Vector2((width + 80) / ENV_TILE_SCALE, gtex.get_height())
		ground.z_index = -5
		ground.modulate = Color(1, 1, 1).darkened(dim)
		_env.add_child(ground)
	else:
		var edge := ColorRect.new()
		edge.color = edge_col
		edge.position = Vector2(-40, GROUND_Y)
		edge.size = Vector2(width + 80, 3)
		edge.z_index = -5
		_env.add_child(edge)

	_camera.setup_corridor(width)

## Overlay preto em tela cheia (CanvasLayer próprio) para o fade das transições.
func _add_fade_overlay() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 95                            # acima do HUD (0), abaixo do CRT (100)
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.modulate.a = 0.0
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)   # cobre o viewport (qualquer resolução)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)

## Porta no chão (parte do _env atual, some quando o cenário é reconstruído).
func _spawn_door(x: float, accent: Color) -> void:
	var d := Node2D.new()
	d.position = Vector2(x, GROUND_Y)
	d.z_index = -4                           # à frente do chão, atrás das entidades
	var frame := ColorRect.new()
	frame.color = accent
	frame.size = Vector2(36, 84)          # base 640×360
	frame.position = Vector2(-18, -84)
	d.add_child(frame)
	var inner := ColorRect.new()
	inner.color = Palette.BG.darkened(0.45)
	inner.size = Vector2(26, 74)
	inner.position = Vector2(-13, -78)
	d.add_child(inner)
	_env.add_child(d)
	_door = d
	_door_x = x

## Recoloca o player no início do nível e gruda a câmera nele (sem pan da transição).
func _reset_player_to_start() -> void:
	if not is_instance_valid(_player_view):
		return
	_player_view.global_position = Vector2(80, GROUND_Y - 40)
	_player_view.velocity = Vector2.ZERO
	_camera.global_position.x = _player_view.global_position.x

func _start_floor() -> void:
	var floor := _run.current_floor
	_current_boss_id = _tower.boss_for_floor(floor)
	_ghost_beaten_this_floor = false

	# Arena do Rei (andar final): sem waves de trash, monta a sala e vai direto ao boss.
	if _tower.is_boss_only_floor(floor):
		_build_environment(BOSS_ROOM_W, true)
		_reset_player_to_start()
		_phase = "boss"
		_spawn_boss()
		return

	_build_environment(_corridor_length, false)
	_reset_player_to_start()
	_phase = "room"
	_start_room()

# ---------------------------------------------------------------------------
# Sala regida pelo Necromante. Composição vem de floor_config["room"]:
#   elites   → Necromante(s): estático no fim da sala, ranged, revive a horda, mata todos ao cair.
#   heavies  → esqueletos pesados (andar 1: encadeamento a/b/c dormente).
#   minions/normals → horda espalhada; cada morto renasce perto do Necromante após respawn_delay.
# ---------------------------------------------------------------------------

func _start_room() -> void:
	_room = _floor_config.get("room", {})
	_alive = { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }
	_heavy_stage.clear()
	_first_kill_done = false
	_necro = null

	# Necromante(s): objetivo da sala. Nasce(m) no FIM do corredor, estático(s).
	for spec in _room.get("elites", []):
		for i in maxi(1, int(spec.get("count", 1))):
			_spawn_necromancer(String(spec.get("id", "")))

	# TESTE: andar 1 só com o necromante (pula heavies e horda).
	if not (_run.current_floor == 1 and L1_NECRO_ONLY):
		# Heavies: andar 1 → encadeamento a/b/c dormente; demais → ativos, espalhados na 2ª metade.
		if _run.current_floor == 1:
			_spawn_l1_heavies()
		else:
			_spawn_heavies_simple()

		# Horda inicial espalhada por todo o corredor.
		_fill_pool("minion")
		_fill_pool("normal")

	_msg.text = "Andar %d / %d — o Necromante comanda a horda. Elimine-o!" % [_run.current_floor, _tower.total_floors]
	_check_room_cleared()   # fallback: sem Necromante, a sala limpa por contagem

## Spec de um tier: { "ids": [...], "count": N }.
func _tier_spec(tier: String) -> Dictionary:
	match tier:
		"minion": return _room.get("minions", {})
		"normal": return _room.get("normals", {})
		"heavy": return _room.get("heavies", {})
	return {}

## Spawna até o pool do tier encher. No início do nível a horda nasce espalhada (_scatter_pos).
func _fill_pool(tier: String) -> void:
	var spec := _tier_spec(tier)
	var cap := int(spec.get("count", 0))
	var ids: Array = spec.get("ids", [])
	while _alive[tier] < cap and not ids.is_empty():
		_spawn_room_enemy(tier, String(ids[randi() % ids.size()]), _scatter_pos(false))

func _spawn_room_enemy(tier: String, id: String, pos: Vector2) -> EnemyView:
	if id == "":
		return null
	var base := _enemy_repo.get_by_id(id)
	if base.is_empty():
		return null
	var enemy := EnemyFactory.build(base, _run.current_floor)
	var view := EnemyView.new()
	view.set_meta("tier", tier)
	_alive[tier] += 1
	_add_view(view, enemy, pos)
	return view

## Necromante: estático no fim da sala (extremo direito), rastreado em _necro.
func _spawn_necromancer(id: String) -> void:
	if id == "":
		return
	var base := _enemy_repo.get_by_id(id)
	if base.is_empty():
		return
	var enemy := EnemyFactory.build(base, _run.current_floor)
	var view := NecromancerView.new()
	view.set_meta("tier", "elite")
	_alive["elite"] += 1
	_necro = view
	_add_view(view, enemy, Vector2(_arena_width - 48.0, GROUND_Y - 40.0))

## Andar 1: os heavies a<b<c EM ORDEM de proximidade, um em cada terço da 2ª metade, dormentes.
## Acordam em cadeia — ver _update_heavy_chain.
func _spawn_l1_heavies() -> void:
	var spec: Dictionary = _room.get("heavies", {})
	var ids: Array = spec.get("ids", [])
	var n := int(spec.get("count", 3))
	if ids.is_empty():
		return
	var half := _arena_width * 0.5
	var right := _arena_width - 48.0
	var band := (right - half) / maxf(1.0, float(n))
	for i in n:
		var x := randf_range(half + band * i, half + band * (i + 1))
		var v := _spawn_room_enemy("heavy", String(ids[i % ids.size()]), Vector2(x, GROUND_Y - 40.0))
		if v != null:
			v.dormant = true
		_heavy_stage.append({ "view": v, "spawn_x": x, "activated": false, "dead": false })

## Demais andares: heavies já ativos, espalhados na 2ª metade (sem encadeamento).
func _spawn_heavies_simple() -> void:
	var spec: Dictionary = _room.get("heavies", {})
	var ids: Array = spec.get("ids", [])
	for i in int(spec.get("count", 0)):
		if ids.is_empty():
			break
		_spawn_room_enemy("heavy", String(ids[i % ids.size()]), _scatter_pos(true))

func _on_room_enemy_died(view: EnemyView) -> void:
	var tier := String(view.get_meta("tier", ""))
	if tier == "":
		return
	_alive[tier] = maxi(0, _alive[tier] - 1)
	match tier:
		"elite":
			# Necromante morto: TODOS os esqueletos morrem e a sala é liberada.
			_necro = null
			_kill_all_skeletons()
			_open_boss_door()
			return
		"heavy":
			_mark_heavy_dead(view)            # andar 1: destrava o próximo heavy da cadeia
			if _has_necro():
				_schedule_respawn("heavy")    # renasce perto do Necromante após o delay
		"minion", "normal":
			_first_kill_done = true           # 1º esqueleto da horda → gatilho do heavy 'a'
			if _has_necro():
				_schedule_respawn(tier)
	_update_heavy_chain()
	_check_room_cleared()

# ---------------------------------------------------------------------------
# Andar 1 — ativação encadeada dos heavies a/b/c (dormentes até o gatilho):
#   a: acorda ao matar o 1º esqueleto OU ao sair da zona de exclusão.
#   b: acorda quando a morre OU o player passa do spawn de a.
#   c: acorda quando b morre OU o player passa do spawn de b.
# ---------------------------------------------------------------------------

func _update_heavy_chain() -> void:
	if _heavy_stage.is_empty() or not is_instance_valid(_player_view):
		return
	var px := _player_view.global_position.x
	for i in _heavy_stage.size():
		var st: Dictionary = _heavy_stage[i]
		if st["activated"]:
			continue
		var trigger := false
		if i == 0:
			trigger = _first_kill_done or px > SPAWN_EXCLUSION
		else:
			var prev: Dictionary = _heavy_stage[i - 1]
			trigger = bool(prev["dead"]) or px > float(prev["spawn_x"])
		if trigger:
			st["activated"] = true
			if is_instance_valid(st["view"]):
				(st["view"] as EnemyView).dormant = false

func _mark_heavy_dead(view: EnemyView) -> void:
	for st in _heavy_stage:
		if st["view"] == view:
			st["dead"] = true
			return

# --- Respawn automático por morte (perto do Necromante) ---
# Ao morrer um esqueleto (minion/normal/heavy) com o Necromante vivo, ele renasce após
# respawn_delay dentro de um raio ao redor do Necromante. Matar o Necromante encerra tudo.

const RESPAWN_RADIUS := 24.0

func _has_necro() -> bool:
	return is_instance_valid(_necro)

## Ponto aleatório uniforme num disco de RESPAWN_RADIUS ao redor do Necromante.
func _necro_spawn_pos() -> Vector2:
	var c := _necro.global_position if _has_necro() else Vector2(_arena_width - 48.0, GROUND_Y - 40.0)
	var ang := randf() * TAU
	var r := sqrt(randf()) * RESPAWN_RADIUS
	return c + Vector2(cos(ang), sin(ang)) * r

func _schedule_respawn(tier: String) -> void:
	var delay := float(_room.get("respawn_delay", 4.0))
	var ids: Array = _tier_spec(tier).get("ids", [])
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if _phase != "room" or not _has_necro() or ids.is_empty():
			return
		var v := _spawn_room_enemy(tier, String(ids[randi() % ids.size()]), _necro_spawn_pos())
		if tier == "heavy" and v != null:
			_reassign_heavy(v))

## Reassocia um heavy renascido (já ativo) ao primeiro estágio morto, para o encadeamento seguir.
func _reassign_heavy(v: EnemyView) -> void:
	for st in _heavy_stage:
		if bool(st["dead"]):
			st["view"] = v
			st["dead"] = false
			st["activated"] = true
			return

## Necromante caiu → todos os esqueletos morrem. Libera o resto da sala.
func _kill_all_skeletons() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	for c in get_children():
		if c is NecroProjectile:
			c.queue_free()
	_alive = { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }

## Sala limpa: com Necromante vivo, só ao matá-lo (trata direto no _on_room_enemy_died). Sem
## Necromante (fallback), limpa quando não sobra ninguém.
func _check_room_cleared() -> void:
	if _phase != "room" or _has_necro():
		return
	if _alive["heavy"] <= 0 and _alive["minion"] <= 0 and _alive["normal"] <= 0:
		_open_boss_door()

# ---------------------------------------------------------------------------
# Portas & transições (Leva 2): porta do boss (após as waves) e porta de saída
# (após o boss → andar superior). Entrar numa porta = chegar perto dela.
# ---------------------------------------------------------------------------

func _open_boss_door() -> void:
	_phase = "to_boss_door"
	_spawn_door(_arena_width - 10.0, Palette.ENEMY)
	_msg.text = "Caminho liberado — vá até a porta →"

func _open_exit_door() -> void:
	_phase = "to_exit_door"
	_spawn_door(_arena_width - 10.0, Palette.ACCENT)
	_msg.text = "A porta para o andar superior se abriu →"

func _process(_delta: float) -> void:
	# Parallax do fundo segue a câmera (todo frame, em qualquer fase).
	if _bg != null and _camera != null:
		_bg.update_scroll(_camera.global_position.x)

	_update_boss_bar()

	# Andar 1: reavalia os gatilhos de posição dos heavies (sair da exclusão / passar dos spawns).
	if _phase == "room":
		_update_heavy_chain()

	# Detecta o player chegando à porta ativa.
	if _phase != "to_boss_door" and _phase != "to_exit_door":
		return
	if not is_instance_valid(_player_view):
		return
	if absf(_player_view.global_position.x - _door_x) <= DOOR_REACH:
		if _phase == "to_boss_door":
			_transition(_enter_boss_room)
		else:
			_transition(_next_floor)

## Fade out → executa on_black (troca o cenário) → fade in. Bloqueia re-disparo via fase.
func _transition(on_black: Callable) -> void:
	_phase = "transition"
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(on_black)
	tw.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)

## Sob a tela preta: limpa o corredor, monta a sala fechada e invoca o boss.
func _enter_boss_room() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	_build_environment(BOSS_ROOM_W, true)
	_reset_player_to_start()
	_spawn_boss()

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

	var bv: BossView = OgreView.new() if _current_boss_id == "bss_ogre" else BossView.new()
	bv.summon_ghost.connect(_on_summon_ghost)
	_boss_view = bv
	if _boss_bar != null:
		_boss_bar.setup(boss.name)                     # nome no rodapé; a barra aparece via _process
	_add_view(bv, boss, _boss_spawn_pos())             # entra pela direita, no chão

func _on_summon_ghost() -> void:
	if _ghost_to_summon == null or _ghost_summoned:
		return
	_ghost_summoned = true
	var ghost := GhostFactory.build(_ghost_to_summon, _run.player)
	_add_view(GhostView.new(), ghost, _boss_spawn_pos() + Vector2(-80, 0))
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
		"room":
			_on_room_enemy_died(view)
		"boss":
			# Derrotar o eco NÃO é obrigatório (§1.4.2): o andar termina quando o boss cai,
			# mesmo que o fantasma ainda esteja vivo.
			if view == _boss_view:
				_clear_remaining_ghost()
				_on_floor_cleared()

## Catarse / Vingança (§1.4.3): cura imediata + buff de dano até o fim do andar.
func _on_ghost_defeated() -> void:
	_ghost_repo.mark_defeated()
	_ghost_beaten_this_floor = true
	var pct := float(BalanceConfig.nemesis.get("VENGEANCE_HEAL_PCT", 0.25))
	_run.player.heal(int(_run.player.stats.max_hp * pct))
	_run.apply_vengeance()
	EventBus.ghost_defeated.emit(_ghost_to_summon)
	_msg.text = "Você superou seu Eco! Vingança ativada (+Relíquia garantida)."

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
	# Catarse (§1.4.3): vencer o próprio Eco garante uma Relíquia+ na recompensa do andar.
	var cards := _run.offer_augments_catharsis() if _ghost_beaten_this_floor else _run.offer_augments()
	if cards.is_empty():
		_open_exit_door()
		return
	var cs := CardSelect.new()
	cs.setup(cards)
	cs.chosen.connect(_on_card_chosen.bind(cs))
	_layer.add_child(cs)

func _on_card_chosen(aug: Augment, cs: CardSelect) -> void:
	cs.queue_free()
	_run.choose_augment(aug)
	_open_exit_door()      # escolhida a recompensa, abre a porta para subir de andar

func _next_floor() -> void:
	_run.advance_floor()
	_start_floor()

func _on_player_died(_p: Player) -> void:
	_phase = "dead"
	# Cria/sobrescreve o fantasma: você sempre enfrenta seu fracasso mais recente (§1.4.4).
	var coeff := float(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0.65))
	_ghost_repo.record_death(_run.player.snapshot(), _run.current_floor, _run.player.run_id, coeff)
	_show_end_screen("VOCÊ MORREU", [
		"Tombou no andar %d de %d" % [_run.current_floor, _tower.total_floors],
		"Nível %d" % _run.player.level,
		"Um Eco seu ficou para trás...",
	], Palette.ENEMY)

func _on_victory() -> void:
	_phase = "victory"
	_show_end_screen("VITÓRIA!", [
		"Você conquistou a Torre da Vingança",
		"Nível %d" % _run.player.level,
		"O Rei caiu. A vingança está completa.",
	], Palette.ACCENT)

func _show_end_screen(title: String, lines: Array, accent: Color) -> void:
	var es := EndScreen.new()
	es.setup(title, lines, accent)
	_layer.add_child(es)

## Posição inicial ESPALHADA pelo nível (não na porta). Zona de exclusão dos 180px iniciais;
## se second_half, restringe à metade direita do corredor (usado pelos elites).
func _scatter_pos(second_half: bool) -> Vector2:
	var min_x := SPAWN_EXCLUSION                        # exclusão dos px iniciais (folga do ponto de partida)
	if second_half:
		min_x = maxf(min_x, _arena_width * 0.5)
	var max_x := maxf(min_x, _arena_width - 48.0)      # margem antes da parede direita
	return Vector2(randf_range(min_x, max_x), GROUND_Y - 40.0)

## Bioma do andar: 10 andares por zona (1–10, 11–20, …), preso ao último.
func _biome_for_floor(floor: int) -> Dictionary:
	if _biomes.is_empty():
		return {}
	var idx := clampi((floor - 1) / 10, 0, _biomes.size() - 1)
	return _biomes[idx]

## Boss aparece no lado direito da sala do boss (arena fechada).
func _boss_spawn_pos() -> Vector2:
	return Vector2(_arena_width - 120.0, GROUND_Y - 60.0)

## Barra de boss (rodapé): visível só na fase do boss, com o HP atual. Some ao sair da luta.
func _update_boss_bar() -> void:
	if _boss_bar == null:
		return
	if _phase == "boss" and is_instance_valid(_boss_view) and _boss_view.data != null:
		var st := _boss_view.data.stats
		_boss_bar.set_ratio(float(st.current_hp) / float(maxi(st.max_hp, 1)))
		_boss_bar.visible = true
	else:
		_boss_bar.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# F9 alterna o overlay CRT (disponível sempre, não só em debug).
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F9:
		_crt.visible = not _crt.visible
	if DEBUG:
		_debug_input(event)
	if (_phase == "dead" or _phase == "victory") and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")

# ---------------------------------------------------------------------------
# DEBUG — atalhos para testar partes específicas sem jogar a run inteira.
# Teclas escolhidas para não colidir com o jogo (mover A/D, pular Espaço/W, atacar J/K, esquivar Shift/L).
# ---------------------------------------------------------------------------

func _apply_debug_start() -> void:
	if DEBUG_START_LEVEL > 1:
		_run.player.level = DEBUG_START_LEVEL
		_run.player.xp_to_next = int(Leveling.xp_to_next(DEBUG_START_LEVEL))
		_run.player.recalculate_stats()
		_run.player.stats.current_hp = _run.player.stats.max_hp
	if DEBUG_START_FLOOR > 1:
		_run.current_floor = DEBUG_START_FLOOR
		_run.player.current_floor = DEBUG_START_FLOOR

func _show_debug_legend() -> void:
	var l := Label.new()
	l.text = "[DEBUG]  K matar  |  M +1 andar  |  B +10  |  L +nivel  |  P 2x dano arma  |  H curar  |  G invocar eco  |  I god mode"
	l.position = Vector2(8, 342)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_layer.add_child(l)

func _debug_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_K: _debug_kill_enemies()
		KEY_M: _debug_skip_floors(1)
		KEY_B: _debug_skip_floors(10)
		KEY_L: _debug_level_up()
		KEY_H: _run.player.heal(_run.player.stats.max_hp)
		KEY_G: _debug_spawn_ghost()
		KEY_I: _debug_toggle_god()
		KEY_P: _debug_double_weapon_damage()

func _debug_kill_enemies() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v) and v.data != null:
			v.apply_damage(v.data.stats.current_hp)   # dispara o fluxo normal de morte

func _debug_clear_all() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	for c in _layer.get_children():
		if c is CardSelect:
			c.queue_free()

func _debug_skip_floors(n: int) -> void:
	if _phase == "dead" or _phase == "victory":
		return
	_debug_clear_all()
	if n > 1:
		_run.current_floor += (n - 1)
		_run.player.current_floor = _run.current_floor
	_next_floor()

func _debug_level_up() -> void:
	_run.player.level += 1
	_run.player.xp_to_next = int(Leveling.xp_to_next(_run.player.level))
	_run.player.recalculate_stats()
	_run.player.heal(_run.player.stats.max_hp)
	_msg.text = "[DEBUG] Nível %d" % _run.player.level

func _debug_spawn_ghost() -> void:
	# Grava um eco do estado ATUAL ancorado neste andar e o invoca na hora (não precisa morrer).
	var coeff := float(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0.65))
	_ghost_repo.record_death(_run.player.snapshot(), _run.current_floor, _run.player.run_id, coeff)
	_ghost_summoned = false
	_ghost_to_summon = _ghost_repo.load_active()
	_on_summon_ghost()

func _debug_toggle_god() -> void:
	_player_view.god_mode = not _player_view.god_mode
	_msg.text = "[DEBUG] God mode: %s" % ("ON" if _player_view.god_mode else "OFF")

func _debug_double_weapon_damage() -> void:
	if _run.player.weapon == null:
		return
	_run.player.weapon.base_damage *= 2.0   # dobra o dano efetivo (acumulável)
	_msg.text = "[DEBUG] Dano da arma dobrado (golpe atual: %.0f)" % _run.player.weapon.current_damage()
