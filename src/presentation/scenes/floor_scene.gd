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
var _phase := "room"           # tutorial | room | cleared | transition | boss_intro | boss | dead | victory
var _floor_config: Dictionary = {}   # config do nível ATUAL (de levels.json)
var _levels: Dictionary = {}         # nível(int) -> config (data/floors/levels.json)
var _hazards: Dictionary = {}        # id -> definição de armadilha (data/hazards.json)
var _bonfires: Array = []            # fogueiras (checkpoints) do nível atual — BonfireView
var _fight_width := 1920.0           # largura da ZONA DE COMBATE (só a 1ª parte do corredor de um
                                     # nível de sala; o refúgio — portão, fogueira, névoa — vem depois)
var _gate: GateView                  # portão de madeira que a alavanca abre (nível de sala)
var _lever: LeverView                # alavanca que abre o portão (aparece quando o Necromante cai)
var _fog: FogGateView                # névoa na entrada do chefe (atravessa com INTERAGIR)
var _fade_layer: CanvasLayer         # camada do fade — o letreiro da morte mora nela, por cima do preto
var _death_banner: Label             # letreiro "VOCÊ MORREU" (some quando a tela volta)

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
# O Eco (marca de sangue) está ligado? Vem de "nemesis"/"ENABLED" no balance.json. Desligado, a
# morte ainda tira as almas — elas só não ficam esperando em lugar nenhum.
var _nemesis_on := false

# repositórios carregados uma vez
var _enemy_repo: EnemyRepository
var _boss_repo: BossRepository
var _crt: CrtOverlay
var _camera: GameCamera
var _options_layer: CanvasLayer   # painel de Opções (ESC): pausa o jogo enquanto está aberto
var _bg: SceneryBackground      # fundo do cenário (parallax)
var _scenery: Dictionary = {}   # cenário do jogo (data/environment.json): parallax + chão
var _corridor_length := 1920.0  # base 640×360 (3 telas de largura)
var _arena_width := 1920.0      # largura do ambiente atual (corredor ou sala do boss)
var _env: Node2D               # container do cenário atual (reconstruído por andar/sala)
var _fade: ColorRect           # overlay de fade das transições
var _door: Node2D              # porta ativa (nula quando não há)
var _door_x := 0.0
var _attr_layer: CanvasLayer    # painel de atributos (aberto ao descansar na fogueira)

## Linha de topo do chão (eixo Y). Player e inimigos pousam aqui pela gravidade.
const GROUND_Y := 300.0         # base 640×360
const PLAYER_START_X := 80.0    # entrada do nível (à esquerda), quando não se renasce numa fogueira
const ENV_TILE_SCALE := 2.0     # arte de terreno em texel 2 (mesmo dos personagens)
const SPAWN_EXCLUSION := 180.0  # zona inicial (à esquerda) sem inimigos ao começar o andar
const L1_NECRO_ONLY := false    # TESTE: andar 1 só com o necromante (sem horda/heavies)
const BOSS_ROOM_W := 640.0     # sala do boss = uma tela fechada (base 640×360)
const DOOR_REACH := 30.0       # distância para "entrar" na porta / abrir o baú (base 640×360)
const FADE_TIME := 0.35
const DEATH_FADE_OUT := 0.45   # a tela apaga assim que ele cai (o letreiro entra junto)
const DEATH_HOLD := 1.8        # e FICA preta, com o letreiro, enquanto o mundo se refaz por baixo
const DEATH_FADE_IN := 0.6     # só então clareia — com o jogador já de pé na fogueira

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
# Refúgio (fim de um nível de sala): o corredor tem a ZONA DE COMBATE (corridor_length) e, depois
# dela, um trecho seguro de SANCTUARY_LEN com o portão, a fogueira e a névoa do chefe. Assim a
# sala da fogueira deixou de ser uma tela à parte (com fade) e virou parte contínua do mapa, que o
# jogador percorre indo e voltando.
const SANCTUARY_LEN := 620.0   # comprimento do refúgio, somado à zona de combate
const LEVER_BACK := 96.0       # a alavanca fica este tanto à ESQUERDA do portão (depois do Necromante)
const BONFIRE_IN := 240.0      # a fogueira, este tanto à DIREITA do portão (dentro do refúgio)
const FOG_BACK := 34.0         # a névoa, este tanto antes da parede do fim

# --- Vila de tutorial (fora da dungeon; roda uma vez antes do nível 1) ---
const TUTORIAL_LENGTH := 1920.0
# [x no corredor, texto da placa]. Ensinam as teclas reais (game_manager._setup_input_actions).
const _TUTORIAL_SIGNS := [
	[230.0, "MOVER\nA  /  D"],
	[520.0, "PULAR\nESPACO / W"],
	[880.0, "ATACAR\nJ  /  K\nno boneco ->"],
	[1240.0, "ESQUIVAR\nSHIFT / L\n(gasta stamina)"],
	[1420.0, "BURACO ->\ncair MATA.\npule. rolar\nnao salva."],
	[1700.0, "Parado, a stamina\nregenera. Sem ela,\nnao ataca nem esquiva."],
	[1820.0, "ENTRADA DA\nDUNGEON ->"],
]
# Armadilhas da vila: [id, x, largura]. O que cada uma FAZ está em data/hazards.json — aqui só
# o lugar. É o primeiro obstáculo não-combativo do jogo: ensina que o cenário também machuca.
const _TUTORIAL_HAZARDS := [
	{ "id": "spikes", "x": 1540.0, "width": 56.0 },
]

func _ready() -> void:
	randomize()

	# Config por-nível da dungeon (levels.json): 1 = sala do Necromante, 2 = arena do Ogro.
	var lcfg = JsonLoader.load_file("res://data/floors/levels.json")
	if typeof(lcfg) == TYPE_DICTIONARY:
		var lv: Dictionary = lcfg.get("levels", {})
		for k in lv:
			_levels[int(k)] = lv[k]   # chaves JSON vêm como String

	var ecfg = JsonLoader.load_file("res://data/environment.json")
	_scenery = ecfg if typeof(ecfg) == TYPE_DICTIONARY else {}

	# Armadilhas: o catálogo (o que cada uma É) vive em hazards.json; onde cada uma FICA,
	# no nível que a usa (levels.json → "hazards").
	var hcfg = JsonLoader.load_file("res://data/hazards.json")
	if typeof(hcfg) == TYPE_DICTIONARY:
		_hazards = hcfg.get("hazards", {})

	# Fundo (parallax) atrás de tudo; _build_environment o (re)constrói a cada cenário.
	_bg = SceneryBackground.new()
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
##
## `hazards` (a lista do nível) é lida AQUI porque os poços de espinho são TERRENO: o chão sai
## em lajes, com um vão em cada poço e uma laje mais funda fechando o fundo dele. Quem desenha
## o interior e cobra o dano é o HazardView (_spawn_hazards), depois.
func _build_environment(width: float, is_boss_room: bool, hazards := []) -> void:
	if is_instance_valid(_env):
		# ARRANCA da árvore agora, não só agenda. queue_free() só apaga no FIM do frame, e até lá o
		# cenário velho continua rodando _process — inclusive os poços, cuja lista de sobreposição
		# (Area2D) ainda é a de antes de o player ser teleportado (ela só se atualiza no próximo
		# passo de física). O buraco velho então "via" o player lá dentro e matava o recém-nascido
		# do outro lado do mapa, disparando uma segunda morte em cima da primeira.
		remove_child(_env)
		_env.queue_free()
	_arena_width = width
	_fight_width = width      # por padrão, combate ocupa o nível inteiro; um nível de sala reduz depois
	_door = null
	_gate = null              # refeitos por _spawn_sanctuary; filhos do _env antigo já foram liberados
	_lever = null
	_fog = null
	_env = Node2D.new()
	add_child(_env)

	# Cenário (environment.json): fundo em parallax + terreno. Sala do boss = mais escura.
	var dim := 0.22 if is_boss_room else 0.0
	var ground_cfg: Dictionary = _scenery.get("ground", {})
	if _bg != null:
		_bg.apply(_scenery.get("parallax", []), _scenery.get("fallback", {}), dim)
	var fill_col := Color(String(ground_cfg.get("fill", "2e1f2c"))).darkened(dim)
	var edge_col := Color(String(ground_cfg.get("edge", "6bb053"))).darkened(dim)

	var pits := _pit_rects(hazards)

	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	# Chão em lajes, contornando os poços. O fundo de cada poço é uma laje mais funda (SÓLIDA):
	# cair nele não é queda livre — o player pousa nos espinhos e pula fora.
	var cursor := -100.0
	for p in pits:
		_add_floor_slab(body, cursor, float(p["x0"]), GROUND_Y)
		_add_floor_slab(body, float(p["x0"]), float(p["x1"]), GROUND_Y + float(p["depth"]))
		cursor = float(p["x1"])
	_add_floor_slab(body, cursor, width + 100.0, GROUND_Y)
	for wall_x in [0.0, width]:             # paredes contêm player e inimigos no nível
		var wcol := CollisionShape2D.new()
		var wrect := RectangleShape2D.new()
		wrect.size = Vector2(40, 800)
		wcol.shape = wrect
		wcol.position = Vector2(wall_x + (-20.0 if wall_x == 0.0 else 20.0), 0.0)
		body.add_child(wcol)
	_env.add_child(body)

	# Chão sólido (backing): sempre presente, cobre qualquer vão sob a textura/tremor da câmera.
	# É a cor da BASE do tile (a terra), então a emenda entre um e outro não aparece. Fica ATRÁS
	# do interior do poço (z -6), que o cobre para o buraco não parecer terra pintada.
	var fill := ColorRect.new()
	fill.color = fill_col
	fill.position = Vector2(-40, GROUND_Y)
	fill.size = Vector2(width + 80, 440 - (GROUND_Y + 40))
	fill.z_index = -7
	_env.add_child(fill)

	# Terreno: o tile do chão repetido na horizontal, também em pedaços — sobre um poço não há
	# chão para desenhar. Sem arte, uma linha de borda no lugar.
	var ground_png := String(ground_cfg.get("tex", ""))
	var gtex: Texture2D = load(ground_png) as Texture2D if (ground_png != "" and ResourceLoader.exists(ground_png)) else null
	cursor = -40.0
	var spans: Array = []
	for p in pits:
		spans.append([cursor, float(p["x0"])])
		cursor = float(p["x1"])
	spans.append([cursor, width + 40.0])

	for span in spans:
		var a := float(span[0])
		var b := float(span[1])
		if b - a <= 0.5:
			continue
		if gtex != null:
			var ground := TextureRect.new()
			ground.texture = gtex
			ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ground.stretch_mode = TextureRect.STRETCH_TILE
			ground.scale = Vector2(ENV_TILE_SCALE, ENV_TILE_SCALE)   # tile nativo ampliado ×2 (texel 2)
			ground.position = Vector2(a, GROUND_Y)
			ground.size = Vector2((b - a) / ENV_TILE_SCALE, gtex.get_height())
			ground.z_index = -5
			ground.modulate = Color(1, 1, 1).darkened(dim)
			_env.add_child(ground)
		else:
			var edge := ColorRect.new()
			edge.color = edge_col
			edge.position = Vector2(a, GROUND_Y)
			edge.size = Vector2(b - a, 3)
			edge.z_index = -5
			_env.add_child(edge)

	_camera.setup_corridor(width)

## Uma laje de chão de `a` a `b`, com o TOPO em `top` (o corpo desce 200px a partir dali).
func _add_floor_slab(body: StaticBody2D, a: float, b: float, top: float) -> void:
	if b - a <= 0.5:
		return
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(b - a, 200.0)
	col.shape = rect
	col.position = Vector2((a + b) * 0.5, top + 100.0)
	body.add_child(col)

## Converte a lista de armadilhas do nível nos vãos que o chão precisa abrir, ordenados por x.
## Uma armadilha sem "depth" não abre buraco nenhum (fica na superfície).
func _pit_rects(list: Array) -> Array:
	var pits: Array = []
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var def: Dictionary = _hazards.get(String(item.get("id", "")), {})
		if def.is_empty():
			continue
		var depth := float(def.get("depth", 0.0))
		if depth <= 0.0:
			continue
		var w := float(item.get("width", 0.0))
		if w <= 0.0:
			w = float(def.get("width", 56.0))
		var cx := float(item.get("x", 0.0))
		pits.append({ "x0": cx - w * 0.5, "x1": cx + w * 0.5, "depth": depth })
	pits.sort_custom(func(a, b): return float(a["x0"]) < float(b["x0"]))
	return pits

## Overlay preto em tela cheia (CanvasLayer próprio) para o fade das transições. O letreiro da
## morte entra NESTA mesma camada, depois do retângulo preto — assim ele fica POR CIMA do preto e
## continua legível com a tela apagada (no HUD, lá embaixo, o fade o engoliria).
func _add_fade_overlay() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 95                            # acima do HUD (0), abaixo do CRT (100)
	add_child(fl)
	_fade_layer = fl
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

## Espalha as armadilhas do nível pelo chão. `list` = [{ "id": ..., "x": ..., "width": ... }],
## vinda do nível (levels.json) ou da vila. Filhas do _env: somem junto com o cenário.
## Um id que não exista em hazards.json vira aviso, não crash — o nível segue jogável.
func _spawn_hazards(list: Array) -> void:
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := String(item.get("id", ""))
		var def: Dictionary = _hazards.get(id, {})
		if def.is_empty():
			push_warning("[floor_scene] armadilha '%s' não existe em hazards.json — ignorada" % id)
			continue
		var hz := HazardView.new()
		hz.position = Vector2(float(item.get("x", 0.0)), GROUND_Y)
		_env.add_child(hz)
		hz.setup(def, float(item.get("width", 0.0)))

## Descansou: vida e stamina cheias, esta fogueira vira o ponto de retorno da morte — e abre o
## painel de atributos, que é onde os pontos ganhos subindo de nível viram poder de verdade.
func _on_bonfire_rested(bf: BonfireView) -> void:
	_run.rest_at(_run.current_floor, bf.pos_x)
	Juice.burst(_env, bf.global_position + Vector2(0, -10), Color(1.0, 0.7, 0.25), 14, 90.0)
	_open_attributes()

## Painel de atributos (pausa o jogo enquanto está aberto, como as Opções).
func _open_attributes() -> void:
	if _attr_layer != null:
		return
	_attr_layer = CanvasLayer.new()
	_attr_layer.layer = 96            # acima do HUD e do fade, abaixo do CRT (100)
	_attr_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_attr_layer)
	var panel := AttributePanel.new()
	panel.setup(_run.player)
	panel.closed.connect(_close_attributes)
	_attr_layer.add_child(panel)
	get_tree().paused = true

func _close_attributes() -> void:
	get_tree().paused = false
	if _attr_layer != null:
		_attr_layer.queue_free()
		_attr_layer = null
	_msg.text = "Fogueira acesa — você retorna aqui ao cair.       →  seguir"

## As três interações do refúgio, cada uma disparada por INTERAGIR (E/F) quando o player está perto
## do objeto. Ficam longe umas das outras, então nunca há ambiguidade. Cada uma devolve true se agiu.

func _try_pull_lever() -> bool:
	if is_instance_valid(_lever) and _lever.is_armed() and not _lever.is_pulled() \
			and _lever.in_reach(_player_view):
		_lever.pull()
		return true
	return false

func _try_rest() -> bool:
	if not is_instance_valid(_player_view):
		return false
	for bf in _bonfires:
		if is_instance_valid(bf) and bf.in_reach(_player_view):
			bf.rest()
			return true
	return false

## Atravessa a névoa do chefe: só com o nível vencido (não dá para pular o combate) e perto dela.
## Leva ao próximo nível — a arena do chefe — com o fade de sempre.
func _try_cross_fog() -> bool:
	if _phase == "cleared" and is_instance_valid(_fog) and _fog.in_reach(_player_view):
		_transition(_next_floor)
		return true
	return false

## Recoloca o player no nível, devolve o controle a ele (caso uma cutscene o tenha congelado) e
## gruda a câmera nele (sem pan da transição). `x` = onde: o início do nível por padrão, ou a
## fogueira em que ele descansou, quando está renascendo nela.
func _reset_player_to_start(x := PLAYER_START_X) -> void:
	if not is_instance_valid(_player_view):
		return
	_player_view.global_position = Vector2(x, GROUND_Y - 40)
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
	_clear_entities()          # morrer na vila a remonta: o boneco de treino não pode duplicar
	_build_environment(TUTORIAL_LENGTH, false, _TUTORIAL_HAZARDS)
	_decorate_village()
	# O player vai para o lugar dele ANTES de os poços existirem: uma armadilha criada em cima do
	# corpo nasce "vendo" o player dentro dela, e o mataria de novo assim que ele renascesse.
	_reset_player_to_start()
	_spawn_hazards(_TUTORIAL_HAZARDS)
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
## Desmonta as entidades do nível anterior. Antes isso não existia porque a morte trocava de
## cena — agora a morte REMONTA o nível na mesma cena, e sem esta limpeza os inimigos da vida
## passada continuariam vivos no mundo, somados aos novos.
func _clear_entities() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			# Fora da árvore JÁ (mesmo motivo do cenário em _build_environment): um inimigo só
			# agendado para morrer ainda roda um frame e acertaria o player recém-ressuscitado.
			if v.get_parent() != null:
				v.get_parent().remove_child(v)
			v.queue_free()
	_enemies.clear()

	# Projéteis em voo. O Necromante e o Ogro os penduram na CENA (get_parent()), não em si
	# mesmos, então não morrem junto com quem os atirou: sem isto, um tiro disparado um instante
	# antes de a sala ser demolida continua voando e vai te encontrar na sala da fogueira.
	for c in get_children():
		if c is NecroProjectile or c is OgreRock:
			remove_child(c)
			c.queue_free()
	_boss_view = null
	_necro = null
	_heavy_stage.clear()
	_dead_pool.clear()
	_alive = { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }
	_respawn_running = false
	_first_kill_done = false

func _start_floor() -> void:
	var floor := _run.current_floor
	_clear_entities()
	_floor_config = _levels.get(floor, {})
	var ltype := String(_floor_config.get("type", ""))
	if ltype == "":
		push_warning("[floor_scene] nível %d não existe em levels.json — encerrando a run" % floor)
		_on_victory()
		return

	var hazards: Array = _floor_config.get("hazards", [])

	if ltype == "boss":
		_current_boss_id = String(_floor_config.get("boss_id", ""))
		_build_environment(BOSS_ROOM_W, true, hazards)
		_reset_player_to_start(PLAYER_START_X)   # o player primeiro; os poços depois (ver _start_tutorial)
		_spawn_hazards(hazards)
		# A cutscene de entrada só na PRIMEIRA vez: quem morreu e voltou já sabe quem mora aqui.
		if _run.boss_seen(_current_boss_id):
			_begin_boss_retry()
		else:
			_run.mark_boss_seen(_current_boss_id)
			_begin_boss_intro()   # música + cutscene de entrada; o combate começa depois dela
		return

	Music.stop()          # fora da sala do boss não há trilha (por ora)
	_current_boss_id = ""
	_boss_view = null
	# O corredor tem duas partes: a ZONA DE COMBATE (corridor_length) e, depois dela, o REFÚGIO
	# (SANCTUARY_LEN) com o portão, a fogueira e a névoa do chefe — tudo contínuo, sem fade.
	_corridor_length = float(_floor_config.get("corridor_length", _corridor_length))
	_build_environment(_corridor_length + SANCTUARY_LEN, false, hazards)
	_fight_width = _corridor_length          # combate só na 1ª parte; _build_environment o resetara p/ o total
	_reset_player_to_start(_run.respawn_x(PLAYER_START_X))   # início do nível, ou a fogueira ao renascer
	_spawn_hazards(hazards)
	_spawn_sanctuary(floor)                   # alavanca + portão + fogueira + névoa (o refúgio do nível)

	# Nível já vencido: sem inimigos. A alavanca já nasceu destravada em _spawn_sanctuary (e puxada,
	# se o portão já foi aberto antes); nada a fazer aqui além de marcar a fase e o Eco.
	if _run.is_cleared(floor):
		_phase = "cleared"
		_msg.text = "Nível vencido — a fogueira e a névoa do chefe aguardam adiante →"
		_spawn_echo_if_here()      # ...mas o seu Eco ainda pode estar esperando no caminho
		return

	_phase = "room"
	_start_room()
	_spawn_echo_if_here()

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
	_add_view(view, enemy, Vector2(_fight_width - 198.0, GROUND_Y - 40.0))   # 150px à esquerda do fim do COMBATE

## Andar 1: os heavies a<b<c EM ORDEM de proximidade, um em cada terço da 2ª metade, dormentes.
## Acordam em cadeia — ver _update_heavy_chain.
func _spawn_l1_heavies() -> void:
	var spec: Dictionary = _room.get("heavies", {})
	var ids: Array = spec.get("ids", [])
	var n := int(spec.get("count", 3))
	if ids.is_empty():
		return
	var half := _fight_width * 0.5
	var right := _fight_width - 48.0
	var band := (right - half) / maxf(1.0, float(n))
	for i in n:
		var x := _off_pit(randf_range(half + band * i, half + band * (i + 1)))
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
	var c := _necro.global_position if _has_necro() else Vector2(_fight_width - 198.0, GROUND_Y - 40.0)
	var ang := randf() * TAU
	var r := sqrt(randf()) * RESPAWN_RADIUS
	var p := c + Vector2(cos(ang), sin(ang)) * r
	p.x = _off_pit(p.x)          # o reinvocado não pode brotar dentro de um poço (não sairia)
	return p

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
# Passagens. A entrada da dungeon (vila) ainda é uma PORTA que se cruza andando. Dentro da dungeon,
# o refúgio é aberto por uma ALAVANCA (portão de madeira) e o chefe por uma NÉVOA (INTERAGIR) —
# ver _try_pull_lever / _try_cross_fog. `_spawn_door` segue existindo para a porta da vila.
# ---------------------------------------------------------------------------

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

	# A passagem ao chefe não é mais uma porta que se cruza andando: é a NÉVOA, atravessada com
	# INTERAGIR (ver _try_cross_fog). A fogueira e a alavanca também são por INTERAGIR — nada aqui
	# dispara sozinho ao encostar.

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

## Retentativa: você já viu este boss entrar. Ele já está de pé na arena e a luta começa direto —
## rever a queda inteira a cada morte envelhece rápido, e no soulslike você morre muito.
func _begin_boss_retry() -> void:
	_phase = "boss"
	_boss_view = null
	_boss_landing_sfx = ""
	Music.play(BOSS_MUSIC)
	_spawn_boss(_boss_spawn_pos())
	if not is_instance_valid(_boss_view):
		_abort_boss_intro()    # boss ausente no JSON: não trava a run
		return
	_boss_view.dormant = false
	_msg.text = _boss_title(String(_boss_view.data.name))

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

	# O chefe NÃO invoca mais nada: o Eco deixou de ser um espectro invocado e virou a marca de
	# sangue, que espera no lugar da queda — e nunca numa arena de chefe (ver _echo_spot).
	var bv: BossView = OgreView.new() if _current_boss_id == "bss_ogre" else BossView.new()
	_boss_view = bv
	if _boss_bar != null:
		_boss_bar.setup(boss.name)                     # nome no rodapé; a barra aparece via _process
	_add_view(bv, boss, at)

func _add_view(view: EnemyView, enemy: Enemy, pos: Vector2) -> void:
	view.setup(enemy, _player_view)
	view.position = pos
	view.died.connect(_on_enemy_died.bind(view, enemy))
	_enemies.append(view)
	add_child(view)

func _on_enemy_died(view: EnemyView, enemy: Enemy) -> void:
	_enemies.erase(view)

	# Almas: TODO inimigo morto entrega as suas, direto para o bolso — inclusive os esqueletos que
	# o Necromante reinvoca sem parar. Antes esses não davam XP, para não virar farm infinito de
	# poder; agora o farm se paga sozinho, porque alma no bolso é RISCO: ela só vira poder depois
	# de gasta na fogueira, e morrer com o bolso cheio entrega tudo ao Eco.
	_run.player.gain_souls(int(enemy.loot.get("souls", 0)))

	# O Eco não pertence à sala nem ao chefe: vencê-lo só devolve as almas.
	if view is GhostView:
		_on_echo_defeated()
		return

	match _phase:
		"room":
			_on_room_enemy_died(view)
		"boss":
			if view == _boss_view:
				_on_floor_cleared()

## Venceu o próprio Eco: as almas voltam para o bolso e a marca some.
func _on_echo_defeated() -> void:
	var back := _run.recover_echo()
	Juice.burst(self, _player_view.global_position, Palette.GHOST, 20, 140.0)
	_msg.text = "Eco superado — %d almas recuperadas." % back

func _on_floor_cleared() -> void:
	_run.mark_cleared(_run.current_floor)   # morrer adiante e voltar por aqui não o repovoa
	if _phase == "boss":
		Music.stop()   # a trilha é da sala do boss: acabou a luta, ela se despede (fade do audio.json)
	# Vencer o último nível conclui a dungeon.
	if _run.current_floor >= TOTAL_LEVELS:
		_on_victory()
		return
	# Nível de sala limpo (o Necromante caiu): a ALAVANCA (que já estava lá, travada) DESTRAVA. Puxá-la
	# abre o portão de madeira que fecha o refúgio — e, aberto, ele fica aberto para sempre. Nada de
	# porta com fade: o jogador anda daqui até a fogueira e a névoa do chefe pelo mesmo corredor.
	_phase = "cleared"
	if is_instance_valid(_lever):
		_lever.arm()
	_msg.text = "O Necromante caiu. Puxe a alavanca (E) para abrir o portão →"

## Id estável do portão de mecanismo de um nível (persistido no RunState). Um por nível de sala.
func _gate_id(floor_n: int) -> String:
	return "gate_%d" % floor_n

## O REFÚGIO ao fim de um nível de sala, contínuo com a zona de combate (sem fade): a alavanca (no
## fim do combate), o portão de madeira, a fogueira mais adiante e a névoa do chefe no extremo. O
## portão barra a passagem até a alavanca ser puxada; aberto, fica aberto para sempre.
func _spawn_sanctuary(floor_n: int) -> void:
	_bonfires.clear()

	# A alavanca fica SEMPRE no lugar, já durante a luta — mas só destravada (puxável) quando o
	# nível está vencido. Se o portão já foi aberto nesta run, ela nasce puxada.
	var gate_open := _run.is_gate_open(_gate_id(floor_n))
	var lx := _fight_width - LEVER_BACK
	_lever = LeverView.new()
	_lever.position = Vector2(lx, GROUND_Y)
	_env.add_child(_lever)
	_lever.setup(lx, _player_view, gate_open, _run.is_cleared(floor_n))
	_lever.pulled.connect(_on_lever_pulled)

	var gate_x := _fight_width
	_gate = GateView.new()
	_gate.position = Vector2(gate_x, GROUND_Y)
	_env.add_child(_gate)
	_gate.setup(gate_x, gate_open)

	# A fogueira: a ÚNICA do jogo. Já acesa se o jogador descansou nela antes nesta run.
	var bf_x := _fight_width + BONFIRE_IN
	var bf := BonfireView.new()
	bf.position = Vector2(bf_x, GROUND_Y)
	_env.add_child(bf)
	bf.setup(bf_x, _run.is_lit(floor_n, bf_x), _player_view)
	bf.rested.connect(_on_bonfire_rested)
	_bonfires.append(bf)

	# A névoa do chefe, no extremo do refúgio (encostada na parede do fim). Atravessa com INTERAGIR.
	var fog_x := _arena_width - FOG_BACK
	_fog = FogGateView.new()
	_fog.position = Vector2(fog_x, GROUND_Y)
	_env.add_child(_fog)
	_fog.setup(fog_x, _player_view)

## Alavanca puxada: abre o portão (na hora, com animação) e persiste isso na run — o atalho fica
## aberto para sempre, inclusive depois de morrer e voltar.
func _on_lever_pulled(_l: LeverView) -> void:
	_run.open_gate(_gate_id(_run.current_floor))
	if is_instance_valid(_gate):
		_gate.open()
	_msg.text = "O portão se abriu. A fogueira aguarda adiante →"

func _next_floor() -> void:
	_run.advance_floor()
	_start_floor()

## Morte (soulslike): a run NÃO acaba mais. A tela escurece com "VOCÊ MORREU", o mundo se refaz
## e o jogador levanta na última fogueira em que descansou, com vida e stamina cheias. Ele mantém
## o que conquistou (nível, augments, arma); perde o caminho andado. Sem nenhuma fogueira acesa,
## renasce no começo do nível em que caiu. Só a VITÓRIA ainda tem tela de fim.
func _on_player_died(_p: Player) -> void:
	if _phase == "dead":
		return                          # o dano pode chegar duas vezes no mesmo frame
	_phase = "dead"
	_intro_token += 1                   # mata qualquer cutscene de boss ainda no ar
	Music.stop(1.5)
	if is_instance_valid(_player_view):
		_player_view.frozen = true

	# Todas as almas do bolso caem AQUI, com o Eco. Um Eco anterior é substituído — as almas dele
	# se perdem para sempre. É a aposta que dá peso à morte.
	var souls_perdidas := 0
	if _nemesis_on:
		var spot := _echo_spot()
		souls_perdidas = _run.player.souls
		_run.drop_echo(int(spot["floor"]), float(spot["x"]))
	else:
		souls_perdidas = _run.player.lose_souls()
	_show_death_banner(souls_perdidas)

	# A tela apaga JÁ (não se assiste ao próprio cadáver), fica preta com o letreiro enquanto o
	# mundo se refaz por baixo, e só volta com o jogador de pé e pronto — nunca se vê a remontagem.
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, DEATH_FADE_OUT)
	tw.tween_interval(DEATH_HOLD)                                   # preto + letreiro
	tw.tween_callback(_respawn_at_checkpoint)                       # sob o preto: tira o texto e refaz tudo
	tw.tween_property(_fade, "modulate:a", 0.0, DEATH_FADE_IN)

## Sob a tela preta: o letreiro sai, o mundo volta ao que era e o jogador levanta na fogueira.
## Nada disto é visível — quando a tela clareia, já está tudo em ordem.
func _respawn_at_checkpoint() -> void:
	if is_instance_valid(_death_banner):
		_death_banner.queue_free()
		_death_banner = null
	_run.respawn()
	# Duas saídas, e só duas: a fogueira ou o começo do jogo. Nunca o lugar onde se caiu —
	# renascer na arena do chefe que acabou de te matar seria de graça. Com fogueira, reentra o
	# nível dela pelo _start_floor: ele já vê o nível como vencido e põe o player na fogueira
	# (respawn_x), com o portão aberto e a névoa adiante.
	if _run.has_checkpoint():
		_start_floor()
	else:
		_start_tutorial()

## Onde o Eco fica. A regra: NUNCA numa arena de chefe — de lá não se volta sem enfrentar o chefe
## outra vez, e a marca ficaria inalcançável (ou pior: você teria de vencer o chefe para reaver as
## almas que perdeu PARA ele). Morrer no chefe deposita o Eco no REFÚGIO do nível anterior, entre a
## fogueira e a névoa — exatamente no trecho que a corrida de volta (renascer na fogueira → cruzar
## a névoa) percorre, então você passa por ele obrigatoriamente.
func _echo_spot() -> Dictionary:
	var floor_n := _run.current_floor
	if _is_boss_level(floor_n):
		var anterior := maxi(floor_n - 1, 1)
		return { "floor": anterior, "x": _prev_sanctuary_echo_x(anterior) }
	var x := _player_view.global_position.x if is_instance_valid(_player_view) else PLAYER_START_X
	return { "floor": floor_n, "x": x }

func _is_boss_level(floor_n: int) -> bool:
	return String(_levels.get(floor_n, {}).get("type", "")) == "boss"

## x no refúgio de um nível, entre a fogueira e a névoa — onde o Eco espera a corrida de volta.
func _prev_sanctuary_echo_x(floor_n: int) -> float:
	var fight := float(_levels.get(floor_n, {}).get("corridor_length", _corridor_length))
	var fog_x := fight + SANCTUARY_LEN - FOG_BACK
	return fog_x - 160.0     # um tanto antes da névoa: enfrenta o Eco e então atravessa

## O Eco espera onde você caiu. Por construção ele nunca está num nível de chefe, mas a guarda
## fica: um Eco lá dentro seria inalcançável.
func _spawn_echo_if_here() -> void:
	if not _nemesis_on or not _run.has_echo_on(_run.current_floor):
		return
	if _is_boss_level(_run.current_floor):
		return
	var echo := GhostFactory.build(_run.echo, _run.player)
	_add_view(GhostView.new(), echo, Vector2(_run.echo.death_x, GROUND_Y - 40.0))
	_msg.text = "Seu Eco te espera — vença-o para reaver %d almas." % _run.echo.souls

## O letreiro entra na camada do FADE (não no HUD): ali ele fica por cima do preto, e não debaixo
## dele. Aparece junto com o escurecimento, no mesmo compasso.
func _show_death_banner(souls_perdidas: int) -> void:
	_death_banner = Label.new()
	_death_banner.text = "VOCÊ MORREU"
	if souls_perdidas > 0:
		_death_banner.text += "\n%d almas ficaram com o seu Eco" % souls_perdidas
	_death_banner.add_theme_font_size_override("font_size", 28)
	_death_banner.add_theme_color_override("font_color", Palette.ENEMY)
	_death_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_banner.size = Vector2(640, 60)
	_death_banner.position = Vector2(0, 140)
	_death_banner.modulate.a = 0.0
	_fade_layer.add_child(_death_banner)
	create_tween().tween_property(_death_banner, "modulate:a", 1.0, DEATH_FADE_OUT)

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

## ESC no meio da run: PAUSA o jogo e abre as Opções. O painel roda com a árvore pausada e, ao
## fechar, despausa. A música segue tocando na pausa (o autoload Music é PROCESS_MODE_ALWAYS), o
## que é bom: dá para ajustar o volume dela e ouvir o efeito na hora.
func _open_options() -> void:
	if _options_layer != null:
		return                        # já aberto (o painel trata o ESC de fechar)
	_options_layer = CanvasLayer.new()
	_options_layer.layer = 96         # acima do HUD e do fade, abaixo do CRT (100)
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)
	var panel := OptionsPanel.new()
	panel.closed.connect(_close_options)
	_options_layer.add_child(panel)
	get_tree().paused = true

func _close_options() -> void:
	get_tree().paused = false
	if _options_layer != null:
		_options_layer.queue_free()
		_options_layer = null

## Posição inicial ESPALHADA pelo nível (não na porta). Zona de exclusão dos 180px iniciais;
## se second_half, restringe à metade direita do corredor (usado pelos elites).
func _scatter_pos(second_half: bool) -> Vector2:
	var min_x := SPAWN_EXCLUSION                        # exclusão dos px iniciais (folga do ponto de partida)
	if second_half:
		min_x = maxf(min_x, _fight_width * 0.5)
	var max_x := maxf(min_x, _fight_width - 48.0)      # margem antes do portão (fim do combate)
	return Vector2(_off_pit(randf_range(min_x, max_x)), GROUND_Y - 40.0)

## Empurra um x para fora de qualquer poço, pela borda mais próxima. O sensor de beirada impede
## que um inimigo ANDE para dentro do buraco, mas não o salvaria de NASCER em cima de um — e lá
## dentro ele ficaria preso, sem pulo. Todo spawn sorteado passa por aqui.
func _off_pit(x: float) -> float:
	for p in _pit_rects(_floor_config.get("hazards", [])):
		var x0 := float(p["x0"])
		var x1 := float(p["x1"])
		if x > x0 and x < x1:
			return (x0 - 12.0) if (x - x0) < (x1 - x) else (x1 + 12.0)
	return x

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
	# ESC pausa e abre as Opções (volume). Fechar o painel despausa — ver _open_options.
	if event.is_action_pressed("ui_cancel"):
		_open_options()
		return
	# E/F: as interações do refúgio — puxar a alavanca, descansar na fogueira, atravessar a névoa.
	# Cada uma só age se o player estiver perto do objeto; longe de todos, não faz nada. Bloqueadas
	# durante transição/morte/cutscene, quando o player não tem controle.
	if event.is_action_pressed("interact"):
		if _phase in ["transition", "dead", "boss_intro", "victory"]:
			return
		if _try_pull_lever() or _try_rest() or _try_cross_fog():
			return
		return
	# F9 alterna o overlay CRT (disponível sempre, não só em debug).
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F9:
		_crt.visible = not _crt.visible
	if DEBUG:
		_debug_input(event)
	# Só a VITÓRIA volta ao menu. Morrer não encerra mais nada: você levanta na fogueira.
	if _phase == "victory" and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")

# ---------------------------------------------------------------------------
# DEBUG — atalhos para testar partes específicas sem jogar a run inteira.
# Teclas escolhidas para não colidir com o jogo (mover A/D, pular Espaço/W, atacar J/K, esquivar Shift/L).
# ---------------------------------------------------------------------------

func _apply_debug_start() -> void:
	if DEBUG_START_LEVEL > 1:
		_run.player.level = DEBUG_START_LEVEL
		_run.player.attribute_points += (DEBUG_START_LEVEL - 1) * Attributes.points_per_level()
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

func _debug_skip_floors(n: int) -> void:
	if _phase == "dead" or _phase == "victory":
		return
	_debug_clear_all()
	if n > 1:
		_run.current_floor += (n - 1)
		_run.player.current_floor = _run.current_floor
	_next_floor()

## Dá almas de sobra para testar a fogueira sem precisar farmar.
func _debug_level_up() -> void:
	_run.player.gain_souls(Leveling.level_cost(_run.player.level) * 3)
	_msg.text = "[DEBUG] +almas → %d (nível %d custa %d)" % [
		_run.player.souls, _run.player.level, Leveling.level_cost(_run.player.level)]

## Larga um Eco AQUI mesmo, com as almas do bolso, e o invoca na hora (sem precisar morrer).
func _debug_spawn_ghost() -> void:
	if not _nemesis_on or _is_boss_level(_run.current_floor):
		return
	_run.drop_echo(_run.current_floor, _player_view.global_position.x + 90.0)
	_spawn_echo_if_here()

func _debug_toggle_god() -> void:
	_player_view.god_mode = not _player_view.god_mode
	_msg.text = "[DEBUG] God mode: %s" % ("ON" if _player_view.god_mode else "OFF")

func _debug_double_weapon_damage() -> void:
	if _run.player.weapon == null:
		return
	_run.player.weapon.base_damage *= 2.0   # dobra o dano efetivo (acumulável)
	_msg.text = "[DEBUG] Dano da arma dobrado (golpe atual: %.0f)" % _run.player.weapon.current_damage()
