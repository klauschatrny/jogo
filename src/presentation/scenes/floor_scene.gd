## Loop de um andar: sala regida por elites (horda reciclada) → boss → recompensa de cards
## → próximo andar. Mantém o RunState vivo entre andares (não troca de cena), recriando os
## inimigos a cada andar. Matar inimigos concede XP (level-up via Leveling).
## Provisório quanto à FSM: a integração com a StateMachine vem na Fase 4.
extends Node2D

# --- DEBUG (desligue pondo DEBUG = false antes de buildar de verdade) ---
const DEBUG := true
const DEBUG_START_FLOOR := 0   # 0 = normal (tutorial); 2 = pula direto para a arena do Ogro
const DEBUG_START_LEVEL := 0   # 0 = normal; nível inicial do jogador

var _run: RunState
var _player_view: PlayerView
var _enemies: Array = []
var _hud: Hud
var _msg: Label
var _layer: CanvasLayer
var _phase := "room"           # tutorial | room | to_chest_door | transition | boss_intro | boss | chest_room | reward | to_exit_door | dead | victory
var _floor_config: Dictionary = {}   # config do nível ATUAL (de levels.json)
var _levels: Dictionary = {}         # nível(int) -> config (data/floors/levels.json)

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
var _dead_pool: Array = []      # tiers de esqueletos eliminados aguardando reinvocação (1 por cast)
var _respawn_running := false   # o loop de cast de respawn está ativo?
var _current_boss_id := ""
var _boss_view: EnemyView
var _intro_token := 0           # invalida cutscenes de entrada antigas ainda no ar (ver _boss_intro)
var _boss_landing_sfx := ""     # som do impacto na cutscene de entrada ("landing_sfx" no JSON do boss)
var _boss_bar: BossHealthBar    # barra de vida grande no rodapé (Dark Souls)
var _ghost_to_summon: GhostData
var _ghost_summoned := false
var _ghost_beaten_this_floor := false
# Nemesis (Fantasma) ligado? Vem de "nemesis"/"ENABLED" no balance.json — hoje FALSE: o eco não
# é gravado na morte nem invocado pelo boss, e a catarse não acontece. O sistema inteiro
# (GhostData/GhostRepository/GhostFactory/NemesisRules + GhostView) segue no lugar, intacto:
# religar é trocar a flag para true.
var _nemesis_on := false

# repositórios carregados uma vez
var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository
var _ghost_repo: GhostRepository
var _crt: CrtOverlay
var _camera: GameCamera
var _bg: BiomeBackground        # fundo ambiental (parallax) por bioma
var _biomes: Array = []         # paletas de bioma (data/biomes.json)
var _parallax_default: Array = []   # camadas de parallax padrão (usadas por biomas sem arte própria)
var _corridor_length := 1920.0  # base 640×360 (3 telas de largura)
var _arena_width := 1920.0      # largura do ambiente atual (corredor ou sala do boss)
var _env: Node2D               # container do cenário atual (reconstruído por andar/sala)
var _fade: ColorRect           # overlay de fade das transições
var _door: Node2D              # porta ativa (nula quando não há)
var _door_x := 0.0
var _chest: Node2D             # baú da sala de recompensa (null fora dela)
var _chest_x := 0.0
var _chest_opened := false

## Linha de topo do chão (eixo Y). Player e inimigos pousam aqui pela gravidade.
const GROUND_Y := 300.0         # base 640×360
const ENV_TILE_SCALE := 2.0     # arte de terreno em texel 2 (mesmo dos personagens)
const SPAWN_EXCLUSION := 180.0  # zona inicial (à esquerda) sem inimigos ao começar o andar
const L1_NECRO_ONLY := false    # TESTE: andar 1 só com o necromante (sem horda/heavies)
const BOSS_ROOM_W := 640.0     # sala do boss = uma tela fechada (base 640×360)
const DOOR_REACH := 30.0       # distância para "entrar" na porta / abrir o baú (base 640×360)
const FADE_TIME := 0.35

# --- Cutscene de entrada do boss (ver _begin_boss_intro) ---
const BOSS_MUSIC := "boss"           # id da faixa em data/audio.json (só toca na sala do boss)
const BOSS_MUSIC_DELAY := 1.5        # a trilha não entra junto com a sala: espera este tanto
const BOSS_INTRO_PAUSE := 0.7        # respiro na sala vazia antes de ele aparecer
const BOSS_INTRO_DROP := 300.0       # altura (px) de onde ele despenca — nasce fora da tela
const BOSS_INTRO_FALL_MAX := 3.0     # segurança: tempo máximo esperando o impacto no chão
const BOSS_INTRO_ROAR_MIN := 1.4     # mínimo encarando o player depois de pousar (boss sem som)

# --- Dungeon ---
# Todo nível é desenhado à mão em data/floors/levels.json; não há mais geração/repetição
# automática. Hoje são 2: 1 = sala do Necromante (esqueletos), 2 = arena do Ogro. Limpar o
# último conclui a run. Ao criar um nível novo, descreva-o no JSON e some 1 aqui.
const TOTAL_LEVELS := 2
const CHEST_ROOM_W := 480.0    # sala do baú (fechada), acessada por uma porta ao fim do nível

# --- Vila de tutorial (fora da dungeon; roda uma vez antes do nível 1) ---
const TUTORIAL_LENGTH := 1920.0
# [x no corredor, texto da placa]. Ensinam as teclas reais (game_manager._setup_input_actions).
const _TUTORIAL_SIGNS := [
	[230.0, "MOVER\nA  /  D"],
	[520.0, "PULAR\nESPACO / W"],
	[880.0, "ATACAR\nJ  /  K\nno boneco ->"],
	[1240.0, "ESQUIVAR\nSHIFT / L\n(gasta stamina)"],
	[1560.0, "Parado, a stamina\nregenera. Sem ela,\nnao ataca nem esquiva."],
	[1820.0, "ENTRADA DA\nDUNGEON ->"],
]

func _ready() -> void:
	randomize()

	# Config por-nível da dungeon (levels.json): 1 = sala do Necromante, 2 = arena do Ogro.
	var lcfg = JsonLoader.load_file("res://data/floors/levels.json")
	if typeof(lcfg) == TYPE_DICTIONARY:
		var lv: Dictionary = lcfg.get("levels", {})
		for k in lv:
			_levels[int(k)] = lv[k]   # chaves JSON vêm como String

	var bcfg = JsonLoader.load_file("res://data/biomes.json")
	_biomes = (bcfg.get("biomes", []) if typeof(bcfg) == TYPE_DICTIONARY else [])
	_parallax_default = (bcfg.get("parallax_default", []) if typeof(bcfg) == TYPE_DICTIONARY else [])

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
		weapon = Weapon.from_dict({"base_damage": 15, "weapon_growth": 1.12, "attack_speed": 1.5, "attack_range": 76})

	var aug_repo := AugmentRepository.new()
	aug_repo.load_all()
	_enemy_repo = EnemyRepository.new()
	_enemy_repo.load_all()
	_boss_repo = BossRepository.new()
	_boss_repo.load_all()
	_ghost_repo = GhostRepository.new()
	_nemesis_on = bool(BalanceConfig.nemesis.get("ENABLED", false))

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

	# Começa na vila de tutorial (fora da dungeon); a porta ao fim leva ao nível 1.
	# Se o debug pular direto para um andar (DEBUG_START_FLOOR > 1), entra na dungeon.
	if _run.current_floor <= 1:
		_start_tutorial()
	else:
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
		# O bioma pode ter camadas próprias ("parallax"); senão usa o conjunto padrão.
		var specs: Array = biome.get("parallax", _parallax_default)
		_bg.apply(biome, dim, specs)
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

## Recoloca o player no início do nível, devolve o controle a ele (caso uma cutscene o tenha
## congelado) e gruda a câmera nele (sem pan da transição).
func _reset_player_to_start() -> void:
	if not is_instance_valid(_player_view):
		return
	_player_view.global_position = Vector2(80, GROUND_Y - 40)
	_player_view.velocity = Vector2.ZERO
	_player_view.frozen = false
	_camera.global_position.x = _player_view.global_position.x

# ---------------------------------------------------------------------------
# Vila de tutorial (fora da dungeon). Área tranquila de 1920 onde o player aprende os
# controles básicos por placas ao longo do caminho + um boneco de treino, com a porta de
# entrada da dungeon ao fim. Roda uma vez no começo (antes do nível 1). Sem inimigos hostis.
# ---------------------------------------------------------------------------

func _start_tutorial() -> void:
	_phase = "tutorial"
	_current_boss_id = ""
	_boss_view = null
	_build_environment(TUTORIAL_LENGTH, false)
	_decorate_village()
	_reset_player_to_start()
	for s in _TUTORIAL_SIGNS:
		_spawn_sign(float(s[0]), String(s[1]))
	_spawn_training_dummy(980.0)
	_spawn_door(_arena_width - 40.0, Palette.ACCENT)
	_msg.text = "Vila — aprenda os controles e vá até a porta da Dungeon ->"

## Placa de madeira com instrução (texto em world-space, rola com a câmera). Filha do _env.
func _spawn_sign(x: float, text: String) -> void:
	var post_node := Node2D.new()
	post_node.position = Vector2(x, GROUND_Y)
	post_node.z_index = -3                       # à frente do chão, atrás das entidades
	var post := ColorRect.new()
	post.color = Color(0.30, 0.20, 0.11)
	post.size = Vector2(4, 40)
	post.position = Vector2(-2, -40)
	post_node.add_child(post)
	var board := ColorRect.new()
	board.color = Color(0.60, 0.45, 0.25)
	board.size = Vector2(104, 46)
	board.position = Vector2(-52, -86)
	post_node.add_child(board)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.07, 0.03))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(104, 46)
	lbl.position = Vector2(-52, -86)
	post_node.add_child(lbl)
	_env.add_child(post_node)

## Boneco de treino: esqueleto blindado passivo (dormant) pra praticar o ataque. Some se
## derrotado. Não dá XP (tier "minion") nem participa da lógica de sala.
func _spawn_training_dummy(x: float) -> void:
	var base := _enemy_repo.get_by_id("enm_skeleton_armored")
	if base.is_empty():
		return
	var enemy := EnemyFactory.build(base, 1)
	var view := EnemyView.new()
	view.set_meta("tier", "minion")
	view.dormant = true
	_add_view(view, enemy, Vector2(x, GROUND_Y - 40.0))

## Casinhas simples ao fundo, só pra dar cara de vila (placeholder, sem arte).
func _decorate_village() -> void:
	for hx in [140.0, 700.0, 1120.0, 1500.0]:
		var house := Node2D.new()
		house.position = Vector2(hx, GROUND_Y)
		house.z_index = -6                       # atrás do chão/entidades, à frente do fundo de bioma
		var wall := ColorRect.new()
		wall.color = Color(0.28, 0.26, 0.34)
		wall.size = Vector2(70, 60)
		wall.position = Vector2(-35, -60)
		house.add_child(wall)
		var roof := Polygon2D.new()
		roof.color = Color(0.20, 0.16, 0.24)
		roof.polygon = PackedVector2Array([Vector2(-42, -60), Vector2(42, -60), Vector2(0, -92)])
		house.add_child(roof)
		var win := ColorRect.new()
		win.color = Color(0.85, 0.72, 0.35)
		win.size = Vector2(14, 14)
		win.position = Vector2(-7, -44)
		house.add_child(win)
		_env.add_child(house)

## Entra na dungeon: limpa o boneco de treino e começa o nível 1.
func _begin_dungeon() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	_run.current_floor = 1
	_start_floor()

## Início de um nível da dungeon. Cada nível é desenhado à mão em levels.json e é de UM tipo:
##   "boss" → arena fechada, direto no chefe.
##   "room" → sala/corredor a limpar (ex.: sala do Necromante). Sem chefe.
## Passar do último nível existente encerra a run (vitória).
func _start_floor() -> void:
	var floor := _run.current_floor
	_ghost_beaten_this_floor = false
	_floor_config = _levels.get(floor, {})
	var ltype := String(_floor_config.get("type", ""))
	if ltype == "":
		push_warning("[floor_scene] nível %d não existe em levels.json — encerrando a run" % floor)
		_on_victory()
		return

	if ltype == "boss":
		_current_boss_id = String(_floor_config.get("boss_id", ""))
		_build_environment(BOSS_ROOM_W, true)
		_reset_player_to_start()
		_begin_boss_intro()   # música + cutscene de entrada; o combate começa depois dela
		return

	Music.stop()          # fora da sala do boss não há trilha (por ora)
	_current_boss_id = ""
	_boss_view = null
	_corridor_length = float(_floor_config.get("corridor_length", _corridor_length))
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
	_dead_pool.clear()
	_respawn_running = false

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

	_msg.text = "Nível %d / %d — o Necromante comanda a horda. Elimine-o!" % [_run.current_floor, TOTAL_LEVELS]
	_start_respawn_cast()   # loop de reinvocação: 1 esqueleto do pool por cast, enquanto o Necromante vive
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
	_add_view(view, enemy, Vector2(_arena_width - 198.0, GROUND_Y - 40.0))   # 150px à esquerda do fim

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
			# Necromante morto: TODOS os esqueletos morrem e o nível é concluído.
			_necro = null
			_kill_all_skeletons()
			_on_floor_cleared()
			return
		"heavy":
			_mark_heavy_dead(view)            # andar 1: destrava o próximo heavy da cadeia
			if _has_necro():
				_dead_pool.append("heavy")    # entra no pool; renasce num cast futuro
		"minion", "normal":
			_first_kill_done = true           # 1º esqueleto da horda → gatilho do heavy 'a'
			if _has_necro():
				_dead_pool.append(tier)
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
	var c := _necro.global_position if _has_necro() else Vector2(_arena_width - 198.0, GROUND_Y - 40.0)
	var ang := randf() * TAU
	var r := sqrt(randf()) * RESPAWN_RADIUS
	return c + Vector2(cos(ang), sin(ang)) * r

## Loop de reinvocação do Necromante: a cada respawn_delay, revive UMA unidade aleatória do pool
## de esqueletos eliminados (se houver). Um cast por vez. Para de reagendar quando o Necromante cai.
func _start_respawn_cast() -> void:
	if _respawn_running or not _has_necro():
		return
	_respawn_running = true
	_queue_next_cast()

func _queue_next_cast() -> void:
	var delay := float(_room.get("respawn_delay", 4.0))
	get_tree().create_timer(delay).timeout.connect(_respawn_cast)

func _respawn_cast() -> void:
	if _phase != "room" or not _has_necro():
		_respawn_running = false
		return   # sala acabou / Necromante morto → encerra o loop
	if not _dead_pool.is_empty():
		var idx := randi() % _dead_pool.size()
		var tier := String(_dead_pool[idx])   # 1 unidade aleatória do pool
		_dead_pool.remove_at(idx)
		var ids: Array = _tier_spec(tier).get("ids", [])
		if not ids.is_empty():
			var v := _spawn_room_enemy(tier, String(ids[randi() % ids.size()]), _necro_spawn_pos())
			if tier == "heavy" and v != null:
				_reassign_heavy(v)
	_queue_next_cast()

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
	_dead_pool.clear()

## Sala limpa: com Necromante vivo, só ao matá-lo (trata direto no _on_room_enemy_died). Sem
## Necromante (fallback), limpa quando não sobra ninguém → conclui o nível.
func _check_room_cleared() -> void:
	if _phase != "room" or _has_necro():
		return
	if _alive["heavy"] <= 0 and _alive["minion"] <= 0 and _alive["normal"] <= 0:
		_on_floor_cleared()

# ---------------------------------------------------------------------------
# Porta de saída (após limpar o nível → próximo nível). Entrar = chegar perto dela.
# ---------------------------------------------------------------------------

func _open_exit_door() -> void:
	_phase = "to_exit_door"
	_spawn_door(_arena_width - 10.0, Palette.ACCENT)
	_msg.text = "A porta para o próximo nível se abriu →"

func _process(_delta: float) -> void:
	# Parallax do fundo segue a câmera (todo frame, em qualquer fase).
	# get_screen_center_position() = centro da VISTA de fato, com os limit_* já aplicados.
	# global_position NÃO é travado pelos limites (só a vista é): usá-lo faria o fundo rolar
	# nas bordas do nível enquanto o mundo está parado, dessincronizando o parallax.
	if _bg != null and _camera != null:
		_bg.update_scroll(_camera.get_screen_center_position().x)

	_update_boss_bar()

	# Nível 1: reavalia os gatilhos de posição dos heavies (sair da exclusão / passar dos spawns).
	if _phase == "room":
		_update_heavy_chain()

	# Vila de tutorial: chegar na porta ao fim entra na dungeon (nível 1).
	if _phase == "tutorial":
		if is_instance_valid(_player_view) and is_instance_valid(_door) \
				and absf(_player_view.global_position.x - _door_x) <= DOOR_REACH:
			_transition(_begin_dungeon)
		return

	# Sala do baú: chegar perto do baú o abre (uma vez).
	if _phase == "chest_room":
		if is_instance_valid(_player_view) and not _chest_opened \
				and absf(_player_view.global_position.x - _chest_x) <= DOOR_REACH:
			_open_chest()
		return

	# Portas: entrar na sala do baú (to_chest_door) ou ir ao próximo nível (to_exit_door).
	if _phase != "to_chest_door" and _phase != "to_exit_door":
		return
	if not is_instance_valid(_player_view):
		return
	if absf(_player_view.global_position.x - _door_x) <= DOOR_REACH:
		if _phase == "to_chest_door":
			_transition(_enter_chest_room)
		else:
			_transition(_next_floor)

## Fade out → executa on_black (troca o cenário) → fade in. Bloqueia re-disparo via fase.
func _transition(on_black: Callable) -> void:
	_phase = "transition"
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(on_black)
	tw.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)

# ---------------------------------------------------------------------------
# Entrada do boss (cutscene). Com o player congelado: a trilha do chefe entra ao pisar na sala →
# o boss DESPENCA na arena (impacto: tremor, poeira e hit-stop) → encara o player → fade out/in.
# Só depois do fade-in ele age, a barra do rodapé aparece e o combate começa de fato.
# ---------------------------------------------------------------------------

func _begin_boss_intro() -> void:
	_phase = "boss_intro"
	_boss_view = null
	# O som do impacto é conhecido ANTES do boss nascer: a cutscene o toca adiantado (ver _boss_intro).
	_boss_landing_sfx = String(_boss_repo.get_by_id(_current_boss_id).get("landing_sfx", ""))
	if is_instance_valid(_player_view):
		_player_view.frozen = true
	_msg.text = "Nível %d — algo desperta na escuridão..." % _run.current_floor
	_intro_token += 1
	_start_boss_music(_intro_token)   # entra atrasada, em paralelo à cutscene
	_boss_intro(_intro_token)

## A trilha é da SALA (fica até a luta acabar), mas não sobe no mesmo instante em que se pisa nela:
## espera BOSS_MUSIC_DELAY. Corrotina à parte, para não atrapalhar o compasso da cutscene.
func _start_boss_music(token: int) -> void:
	if BOSS_MUSIC_DELAY > 0.0:
		await get_tree().create_timer(BOSS_MUSIC_DELAY).timeout
		if not _intro_valid(token):
			return   # a run saiu da sala antes de a música entrar
	Music.play(BOSS_MUSIC)

## A sequência em si (corrotina). `token` invalida uma intro antiga que ainda esteja no ar —
## o debug pode trocar de nível no meio dela, e duas intros vivas spawnariam dois bosses.
func _boss_intro(token: int) -> void:
	await get_tree().create_timer(BOSS_INTRO_PAUSE).timeout   # respiro na sala vazia
	if not _intro_valid(token):
		return

	# O clipe do impacto tem o baque no meio dele (impact_at), não no início. Ele começa a tocar
	# ADIANTADO, ainda com a sala vazia: o trecho antes do baque vira o suspense da queda, e o
	# baque soa no instante exato em que os pés do boss batem no chão.
	Sfx.play(_boss_landing_sfx)
	var lead := maxf(0.0, Sfx.impact_at(_boss_landing_sfx) - _boss_fall_time())
	if lead > 0.0:
		await get_tree().create_timer(lead).timeout
		if not _intro_valid(token):
			return

	_spawn_boss(_boss_spawn_pos() - Vector2(0.0, BOSS_INTRO_DROP))   # nasce acima da tela
	if not is_instance_valid(_boss_view):
		_abort_boss_intro()          # boss ausente no JSON: devolve o controle, não trava a run
		return
	_boss_view.dormant = true        # passivo: a gravidade o traz até o chão

	# Espera o impacto — com teto de tempo, para a cena nunca travar se ele não pousar.
	var falling := 0.0
	while is_instance_valid(_boss_view) and not _boss_view.is_on_floor() and falling < BOSS_INTRO_FALL_MAX:
		falling += get_physics_process_delta_time()
		await get_tree().physics_frame
	if not _intro_valid(token) or not is_instance_valid(_boss_view):
		return
	_boss_landing_fx()

	await get_tree().create_timer(_boss_roar_time()).timeout   # ele encara o player
	if not _intro_valid(token):
		return
	_transition(_begin_boss_fight)   # fade out → põe todos em posição → fade in → luta

## Queda livre de BOSS_INTRO_DROP px sob a gravidade das entidades: t = √(2h/g). Determinística
## (sem arrasto), então dá para saber de antemão QUANDO ele vai tocar o chão — é o que permite
## disparar o som adiantado e cravar o baque no pouso.
func _boss_fall_time() -> float:
	return sqrt(2.0 * BOSS_INTRO_DROP / EnemyView.GRAVITY)

## Quanto tempo o boss encara o player depois de pousar: o que sobra do clipe DEPOIS do baque,
## menos o fade — assim a cutscene fecha exatamente quando o som acaba. Boss sem som (ou com um
## som curto demais) cai no mínimo.
func _boss_roar_time() -> float:
	var after_impact := Sfx.length(_boss_landing_sfx) - Sfx.impact_at(_boss_landing_sfx)
	return maxf(BOSS_INTRO_ROAR_MIN, after_impact - FADE_TIME)

func _intro_valid(token: int) -> bool:
	return _phase == "boss_intro" and token == _intro_token

## Impacto do pouso: tremor forte, estilhaços, poeira do chão e um hit-stop curto (peso).
## O som NÃO entra aqui — ele já está tocando desde antes, cravado para bater neste instante.
func _boss_landing_fx() -> void:
	var at := _boss_view.global_position + Vector2(0.0, _boss_view.box_h * 0.5)
	_camera.add_trauma(1.0)
	Juice.burst(self, at, Palette.BOSS, 24, 200.0)
	Juice.burst(self, at, Color(0.72, 0.66, 0.58), 18, 120.0)   # poeira
	Juice.hit_stop(get_tree(), 0.08, 0.05)

## Fim da cutscene, sob a tela preta: todos em posição de luta e o boss liberado.
func _begin_boss_fight() -> void:
	_phase = "boss"
	_reset_player_to_start()          # também descongela o player
	if is_instance_valid(_boss_view):
		_boss_view.global_position = _boss_spawn_pos()
		_boss_view.velocity = Vector2.ZERO
		_boss_view.dormant = false
		_msg.text = _boss_title(String(_boss_view.data.name))

## Boss inexistente no JSON: sai da cutscene sem travar a run (o nível é dado como limpo).
func _abort_boss_intro() -> void:
	_phase = "boss"
	if is_instance_valid(_player_view):
		_player_view.frozen = false
	_on_floor_cleared()               # já corta a música (ver o topo dele)

func _boss_title(boss_name: String) -> String:
	return "Nível %d — CHEFE: %s" % [_run.current_floor, boss_name]

## Cria o boss do nível em `at`. Quem chama decide se ele já age (a cutscene o deixa dormente).
## Também resolve o eco do Nemesis, que o próprio boss invoca ao cruzar o limiar de HP.
func _spawn_boss(at: Vector2) -> void:
	var floor := _run.current_floor
	var base := _boss_repo.get_by_id(_current_boss_id)
	if base.is_empty():
		push_warning("[floor_scene] boss '%s' não encontrado no andar %d" % [_current_boss_id, floor])
		return
	var boss := EnemyFactory.build_boss(base, floor)

	# Nemesis: este boss invocará o eco se há um fantasma ancorado neste andar (Regra 5).
	# Com o sistema desligado, _ghost_to_summon fica nulo e o sinal do boss vira no-op.
	_ghost_summoned = false
	_ghost_to_summon = null
	if _nemesis_on:
		var g := _ghost_repo.load_active()
		_ghost_to_summon = g if NemesisRules.should_summon(g, floor) else null

	var bv: BossView = OgreView.new() if _current_boss_id == "bss_ogre" else BossView.new()
	bv.summon_ghost.connect(_on_summon_ghost)
	_boss_view = bv
	if _boss_bar != null:
		_boss_bar.setup(boss.name)                     # nome no rodapé; a barra aparece via _process
	_add_view(bv, boss, at)

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
	# Esqueletos da sala (minion/normal/heavy) são reinvocados pelo Necromante sem parar → NÃO
	# dão XP (senão dava pra farmar XP infinita). Só o Necromante (elite) e o boss concedem XP.
	if not (String(view.get_meta("tier", "")) in ["minion", "normal", "heavy"]):
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
	if _phase == "boss":
		Music.stop()   # a trilha é da sala do boss: acabou a luta, ela se despede (fade do audio.json)
	# Vencer o último nível conclui a dungeon.
	if _run.current_floor >= TOTAL_LEVELS:
		_on_victory()
		return
	# Nível limpo: abre a porta (ao fim do nível) que leva à SALA DO BAÚ (recompensa).
	_phase = "to_chest_door"
	_spawn_door(_arena_width - 10.0, Palette.ACCENT)
	_msg.text = "Nível limpo! Vá até a porta →"

## Sob a tela preta: monta a sala fechada do baú (recompensa) e coloca o player nela.
func _enter_chest_room() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	_boss_view = null
	_build_environment(CHEST_ROOM_W, true)
	_reset_player_to_start()
	_chest_opened = false
	_spawn_chest()
	_phase = "chest_room"
	_msg.text = "Abra o baú →"

## Baú no centro da sala do baú (placeholder em ColorRects). Abrir = chegar perto (DOOR_REACH).
func _spawn_chest() -> void:
	var w := 18.0
	var h := 12.0
	var chest := Node2D.new()
	var body := ColorRect.new()
	body.color = Color(0.5, 0.34, 0.18)
	body.size = Vector2(w, h)
	body.position = Vector2(-w * 0.5, -h)
	chest.add_child(body)
	var lid := ColorRect.new()
	lid.color = Color(0.7, 0.52, 0.26)
	lid.size = Vector2(w, 3.0)
	lid.position = Vector2(-w * 0.5, -h)
	chest.add_child(lid)
	var lock := ColorRect.new()
	lock.color = Palette.ACCENT
	lock.size = Vector2(3, 3)
	lock.position = Vector2(-1.5, -h * 0.5)
	chest.add_child(lock)
	chest.z_index = 60
	chest.position = Vector2(CHEST_ROOM_W * 0.5, GROUND_Y)   # centro da sala do baú, base no chão
	_chest = chest
	_chest_x = chest.position.x
	_env.add_child(chest)   # filho do cenário atual: some quando o cenário é reconstruído (não vaza)

## Abre o baú: mostra as opções de augment. Sem augments → abre direto a porta do próximo nível.
func _open_chest() -> void:
	_chest_opened = true
	if is_instance_valid(_chest):
		Juice.burst(self, _chest.global_position + Vector2(0.0, -6.0), Palette.ACCENT, 16, 130.0)
		_chest.modulate = Color(1.3, 1.2, 0.9)   # brilho de "aberto"
	# Catarse (§1.4.3): vencer o próprio Eco garante uma Relíquia+ na recompensa.
	var cards := _run.offer_augments_catharsis() if _ghost_beaten_this_floor else _run.offer_augments()
	if cards.is_empty():
		_open_exit_door()
		return
	_phase = "reward"
	var cs := CardSelect.new()
	cs.setup(cards)
	cs.chosen.connect(_on_card_chosen.bind(cs))
	_layer.add_child(cs)

func _on_card_chosen(aug: Augment, cs: CardSelect) -> void:
	cs.queue_free()
	_run.choose_augment(aug)
	_open_exit_door()      # escolhida a recompensa, abre a porta para o próximo nível

func _next_floor() -> void:
	_run.advance_floor()
	_start_floor()

func _on_player_died(_p: Player) -> void:
	_phase = "dead"
	Music.stop(1.5)
	var lines := [
		"Tombou no nível %d de %d" % [_run.current_floor, TOTAL_LEVELS],
		"Nível %d" % _run.player.level,
	]
	if _nemesis_on:
		# Cria/sobrescreve o fantasma: você sempre enfrenta seu fracasso mais recente (§1.4.4).
		var coeff := float(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0.65))
		_ghost_repo.record_death(_run.player.snapshot(), _run.current_floor, _run.player.run_id, coeff)
		lines.append("Um Eco seu ficou para trás...")
	_show_end_screen("VOCÊ MORREU", lines, Palette.ENEMY)

func _on_victory() -> void:
	_phase = "victory"
	Music.stop()
	_show_end_screen("VITÓRIA!", [
		"Você limpou os %d níveis da dungeon" % TOTAL_LEVELS,
		"Nível %d" % _run.player.level,
		"O resto da dungeon ainda está por vir...",
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
	l.text = "[DEBUG]  K matar  |  M +1 nivel  |  L +nivel do player  |  P 2x dano arma  |  H curar  |  I god mode"
	if _nemesis_on:
		l.text += "  |  G invocar eco"
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
	if not _nemesis_on:
		return   # Nemesis desligado (balance.json): nada a invocar
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
