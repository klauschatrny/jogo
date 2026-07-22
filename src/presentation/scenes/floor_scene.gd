## Loop de um andar: sala regida por elites (horda reciclada) → boss → recompensa de cards
## → próximo andar. Mantém o RunState vivo entre andares (não troca de cena), recriando os
## inimigos a cada andar. Matar inimigos concede XP (level-up via Leveling).
## Provisório quanto à FSM: a integração com a StateMachine vem na Fase 4.
extends Node2D

# --- DEBUG (desligue pondo DEBUG = false antes de buildar de verdade) ---
const DEBUG := true
const DEBUG_START_AT := ""     # "" = normal (tutorial); um id de levels.json pula direto p/ lá
const DEBUG_START_LEVEL := 0   # 0 = normal; nível inicial do jogador

var _run: RunState
# --- PIVÔ roguelite (data/run.json): a run é uma SEQUÊNCIA de nós tipados, não um passeio pelo
# grafo de lugares. Enquanto _roguelite, o RunPlan dirige o que vem a seguir e a morte encerra a run.
var _roguelite := true
var _plan: RunPlan               # a sequência de nós (combate/recompensa/boss)
var _run_cfg: Dictionary = {}    # data/run.json: padrão de nós + pools de conteúdo
var _reward_layer: CanvasLayer   # overlay da carta de recompensa (CardSelect)
var _rl_boss_id := ""            # boss do andar ATUAL da torre (vem do nó, não do levels.json)
var _rl_floor := 0               # andar atual da torre (1..N), para a HUD/toast
# --- Downtown (o HUB entre runs): o centro da cidade, com o mercado. Morrer OU vencer devolve o
# jogador aqui — as almas ficam (são a moeda do mercado), a build de augments da run se perde.
var _hub_fire: BonfireView       # a fogueira decorativa: marca o ponto de renascer, sem função
var _trainer: NpcView            # o Mestre: abre o painel de atributos (níveis + pontos)
var _smith: NpcView              # o Ferreiro: melhora a arma (dano geométrico, custo geométrico)
var _merchant: NpcView           # o Mercador: cacos de frasco (+1 carga máxima)
var _player_view: PlayerView
var _enemies: Array = []
var _hud: Hud
var _msg: Label
var _layer: CanvasLayer
var _phase := "room"           # tutorial | room | cleared | transition | boss_intro | boss | dead
var _floor_config: Dictionary = {}   # config do nível ATUAL (de levels.json)
var _levels: Dictionary = {}         # id(String) -> config (data/floors/levels.json)
var _start_level := ""               # onde a dungeon começa (levels.json → "start")
var _hazards: Dictionary = {}        # id -> definição de armadilha (data/hazards.json)
var _bonfires: Array = []            # fogueiras (checkpoints) do nível atual — BonfireView
var _guard: Array = []               # a GUARDA do refúgio: esqueletos do run-back (nível vencido) — EnemyView
var _ladders: Array = []             # escadas do nível (o PlayerView as consulta para escalar)
var _npc: NpcView                    # o Sir Big T., ao lado da fogueira de renascer do Downtown
var _knight_seq := false             # a sequência de falas base está tocando sozinha?
var _knight_timer := 0.0             # tempo até a próxima fala base
var _knight_card: CanvasLayer        # o card central "Frasco adquirido"
var _knight_card_open := false       # o card está aberto (pausa a sequência até confirmar)
var _bloodstain: BloodstainView      # a marca de sangue na cena, quando presente (passiva, recolhe ao tocar)
# Toast de dica do tutorial (substitui as antigas placas): aparece no HUD conforme o player anda.
var _tip_root: Control               # a caixa da dica (no _layer); invisível quando não há dica
var _tip_label: Label
var _tip_key: Control                # indicador "[E] Avançar" (keycap), à direita do toast
var _tip_key_label: Label            # o nome da tecla dentro do contorno
var _tip_time := 0.0                 # segundos restantes da dica na tela (0 = nenhuma)
var _tip_tween: Tween
var _tips_done := {}                 # índices de _TUTORIAL_TIPS já mostrados nesta visita à vila
var _fight_width := 1920.0           # largura da ZONA DE COMBATE (só a 1ª parte do corredor de um
                                     # nível de sala; o refúgio — portão, fogueira, névoa — vem depois)
var _gate: GateView                  # portão de madeira que a alavanca abre (nível de sala)
var _gate_key := ""                  # id do portão ATUAL em RunState.opened_gates
var _lever: LeverView                # alavanca que abre o portão (aparece quando o Necromante cai)
var _fog: FogGateView                # névoa na entrada do chefe (atravessa com INTERAGIR)
var _fade_layer: CanvasLayer         # camada do fade — o letreiro da morte mora nela, por cima do preto
var _death_banner: Label             # letreiro "VOCÊ MORREU" (some quando a tela volta)

# --- Sala (regida pelo Necromante) ---
# O Necromante (classe "elite") nasce no fim da sala, estático e ranged. Enquanto vive, esqueleto
# nenhum morre: zerada a vida, ele DESABA em ossos onde estava e se remonta inteiro em
# room.reassemble_time segundos. Ao Necromante cair, TODOS caem junto e a sala é liberada.
# Heavies mantêm o encadeamento a/b/c.
var _room: Dictionary = {}
var _alive := { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }
# Andar 1: heavies a/b/c em estágio. Cada item: { view, spawn_x, activated, dead }.
var _heavy_stage: Array = []
var _first_kill_done := false   # 1º esqueleto da horda morto (um dos gatilhos do heavy 'a')
var _necro: NecromancerView     # o Necromante (objetivo da sala); null se morto/inexistente
var _current_boss_id := ""
var _boss_view: EnemyView
var _intro_token := 0           # invalida cutscenes de entrada antigas ainda no ar (ver _boss_intro)
var _boss_landing_sfx := ""     # som do impacto na cutscene de entrada ("landing_sfx" no JSON do boss)
var _boss_bar: BossHealthBar    # barra de vida grande no rodapé (Dark Souls)

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
# As DUAS portas da arena do chefe: atrás (voltar ao nível anterior) e adiante (o próximo nível).
# Cada uma nasce coberta por uma névoa TRAVADA enquanto o chefe vive; vencê-lo as dissipa e as
# portas passam a funcionar como a da vila (cruza andando). Ver _spawn_boss_doors.
var _boss_fogs: Array = []           # FogGateViews sobre as portas (só durante a luta)
var _boss_door_left_x := 0.0
var _boss_door_right_x := 0.0
var _exit_door_x := 0.0              # saída LIVRE no fim do nível (a névoa já se dissipou com o chefe)
var _exit_door_y := 0.0              # y da saída quando ela NÃO está no chão (a escadaria; pode ser NEGATIVO)
var _exit_door_vertical := false     # a saída exige altura? (só a escadaria liga; um valor-sentinela
                                     # não serve: acima da tela base o y legítimo é negativo)
# O ATALHO. Uma segunda aresta do mapa, ligando dois lugares que já se alcançavam — por um caminho
# muito mais curto. Nasce FECHADO e só se destranca do lado de LÁ (o refúgio), o que é o que dá
# sentido à primeira travessia longa: você abre a porta pelas costas dela. Aberto, fica aberto para
# sempre (persiste em RunState.opened_gates, como o portão da alavanca).
var _shortcut: ShortcutView          # a boca do poço no cenário (null onde não há)
var _shortcut_x := 0.0
var _shortcut_id := ""               # id em opened_gates; "" = este nível não tem atalho
var _shortcut_unlocks := false       # esta ponta destranca? (só a de lá, logo antes do chefe)
var _shortcut_to: Dictionary = {}    # destino do atalho: { level, x }
var _entry_x := -1.0                 # x exato pedido pela entrada "x" (o atalho); <0 = não pedido
# Por onde o próximo _start_floor coloca o jogador: "inicio" (padrão), "fim" (extremo direito —
# é assim que se volta por uma porta de trás) ou "fogueira" (desemboca no refúgio; o que torna uma
# passagem um atalho). Quem define é a saída que foi cruzada; consumido em _start_floor.
var _entry_point := "inicio"
var _attr_layer: CanvasLayer    # painel de atributos (aberto ao falar com o Mestre, no Downtown)

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
# Todo nível é desenhado à mão em data/floors/levels.json, que é um GRAFO: cada nível tem id e
# declara para onde se pode ir a partir dele. Não há contagem nem ordem implícita — acrescentar
# um nível é descrevê-lo no JSON e apontar a saída de algum outro para ele.
const BOSS_DOOR_IN := 26.0     # as portas da arena do chefe, este tanto para dentro de cada parede
# Refúgio (fim de um nível de sala): o corredor tem a ZONA DE COMBATE (corridor_length) e, depois
# dela, um trecho seguro de SANCTUARY_LEN com o portão, a fogueira e a névoa do chefe. Assim a
# sala da fogueira deixou de ser uma tela à parte (com fade) e virou parte contínua do mapa, que o
# jogador percorre indo e voltando.
const SANCTUARY_LEN := 980.0   # comprimento PADRÃO do refúgio, somado à zona de combate (folga p/ a guarda)
const RL_ROOM_TAIL := 300.0    # roguelite: folga após a zona de combate para a porta de avanço
const LEVER_BACK := 96.0       # a alavanca fica este tanto à ESQUERDA do portão (depois do Necromante)
const BONFIRE_IN := 160.0      # a fogueira, este tanto à DIREITA do portão (logo depois dele)
const FOG_BACK := 34.0         # a névoa, este tanto antes da parede do fim
# A GUARDA do refúgio (run-back): postada no trecho entre a fogueira e a névoa, com folga dos dois.
const GUARD_AFTER_BONFIRE := 180.0   # começa este tanto DEPOIS da fogueira (bolha segura ao redor do fogo)
const GUARD_BEFORE_FOG := 120.0      # e termina este tanto ANTES da névoa
# O raio de despertar é DE CADA INIMIGO agora (data/enemies/<id>.json → "aggro_range", padrão
# EnemyView.AGGRO_RANGE): um Necromante enxerga muito mais longe que um lacaio, e isso é
# característica dele, não do lugar onde ele está.

# --- Vila de tutorial (fora da dungeon; roda uma vez antes do nível 1) ---
const TUTORIAL_LENGTH := 1920.0

# --- Downtown: o layout, da esquerda para a direita. O portão grande fica no FIM e fecha a torre
# fisicamente (GateView é sólido): a alavanca ao lado o abre — destravada desde o começo, como o
# antigo portão da cidade (é uma saída, não um prêmio) — e aberto fica aberto para sempre.
const DOWNTOWN_LENGTH := 1280.0
const DT_KNIGHT_X := 240.0        # Sir Big T., à esquerda da fogueira (como sempre)
const DT_FIRE_X := 300.0          # a fogueira decorativa = o ponto de renascer
const DT_TRAINER_X := 500.0
const DT_SMITH_X := 680.0
const DT_MERCHANT_X := 860.0
const DT_GATE_X := 1060.0         # portão grande (56×150), estilo o da antiga zona "portao"
const DT_GATE_KEY := "portao_torre"
const DT_DOOR_X := 1210.0         # a porta da torre, depois do portão
# Dicas do tutorial: [x-gatilho no corredor, texto]. Não são mais placas no mundo — aparecem como
# um TOAST no HUD quando o player alcança aquele x (uma vez cada) e somem sozinhas em TIP_SECONDS,
# ou na hora, se ele apertar INTERAGIR. A lista canônica vive em TutorialTips (compartilhada com a
# aba TUTORIAL das Opções); os nomes de tecla vêm do KeyBinds — chame na hora de MOSTRAR, nunca cacheie.
func _tutorial_tips() -> Array:
	return TutorialTips.entries()
const TIP_SECONDS := 10.0     # quanto tempo uma dica fica na tela antes de sumir sozinha
# Armadilhas da vila: [id, x, largura]. O que cada uma FAZ está em data/hazards.json — aqui só o
# lugar. Hoje NÃO há nenhum poço no jogo (removido a pedido); a maquinaria (HazardView, _off_pit,
# _ledge_ahead) fica de pé, esperando um nível que declare "hazards".
const _TUTORIAL_HAZARDS := []

func _ready() -> void:
	randomize()

	# O MAPA da dungeon (levels.json): um grafo de níveis com id, e cada um declara suas saídas.
	var lcfg = JsonLoader.load_file("res://data/floors/levels.json")
	if typeof(lcfg) == TYPE_DICTIONARY:
		var lv: Dictionary = lcfg.get("levels", {})
		for k in lv:
			_levels[String(k)] = lv[k]
		_start_level = String(lcfg.get("start", ""))

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
	# Mensagem de seção (andar/avisos). OCULTA a pedido: o texto branco de instrução ("siga até a
	# porta da Dungeon" etc.) saiu da tela. O nó fica vivo (muitas partes ainda fazem _msg.text = …,
	# inofensivo) — só nunca aparece. Instruções agora só pelo toast de dica e pelos prompts de mundo.
	_msg = Label.new()
	_msg.position = Vector2(16, 36)
	_msg.add_theme_font_size_override("font_size", 8)
	_msg.visible = false
	_layer.add_child(_msg)
	_build_tip_ui()          # o toast de dica do tutorial (oculto até a 1ª dica disparar)

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

	_run = RunState.start_new("Kael", weapon, aug_repo.all_augments(), randi())
	# O core não lê o levels.json (§2.3): quem monta a run é que informa onde a dungeon começa.
	# É o destino do respawn de quem morre sem nunca ter acendido uma fogueira.
	_run.start_level = _start_level
	_player_view = PlayerView.new()
	_player_view.setup(_run.player)
	_player_view.position = Vector2(80, GROUND_Y - 40)   # início à esquerda do corredor
	add_child(_player_view)
	_camera.follow_target = _player_view                 # câmera passa a seguir o player
	_hud.set_player(_run.player)
	_hud.set_run(_run)                                   # liga o contador de mortes (playtest)

	EventBus.player_died.connect(_on_player_died)

	if _roguelite:
		# A run é montada por RunGenerator a partir do run.json e da seed da run (determinística).
		var rc = JsonLoader.load_file("res://data/run.json")
		_run_cfg = rc if typeof(rc) == TYPE_DICTIONARY else {}
		_plan = RunGenerator.generate(_run_cfg, _run.seed)
		# A VILA de tutorial é mantida DE PROPÓSITO: é onde o Sir Big T. entrega o Frasco de Cura (o
		# jogador começa sem ele). A porta ao fim da vila entra na torre — ver _begin_dungeon.
		_start_tutorial()
		return

	if DEBUG:
		_apply_debug_start()
		# A legenda de debug na tela fica DESLIGADA a pedido; os atalhos seguem ativos (ver _debug_input).
		# _show_debug_legend()

	# Começa na vila de tutorial (fora da dungeon); a porta ao fim leva ao primeiro nível.
	# Se o debug apontar para um nível (DEBUG_START_AT), entra direto na dungeon.
	if _run.current_level == "":
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
	_gate = null              # refeitos por _spawn_entrance/_spawn_sanctuary; os antigos morreram com o _env
	_gate_key = ""
	_lever = null
	_fog = null
	_exit_door_x = 0.0        # refeita por _spawn_exit_passage, quando o nível adiante já caiu
	_exit_door_vertical = false   # volta ao chão; a escadaria a põe na superfície do último andar
	_npc = null               # view era filha do _env (demolida); só solta a referência
	_knight_seq = false       # a sequência de falas não sobrevive à remontagem do nível
	_knight_timer = 0.0
	if is_instance_valid(_knight_card):
		_knight_card.queue_free()
	_knight_card = null
	_knight_card_open = false
	_ladders.clear()          # views eram filhas do _env (demolido); só solta as referências
	if is_instance_valid(_player_view):
		_player_view.ladders = _ladders
	_shortcut = null
	_shortcut_x = 0.0
	_shortcut_id = ""
	_shortcut_unlocks = false
	_shortcut_to = {}
	_bloodstain = null        # refeita por _spawn_bloodstain_if_here (filha do _env, já liberada)
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

	_decorate_scenery(width, dim)   # enfeites de fundo (cercas, pedras, ruínas, árvores) — cosmético
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

## Porta no chão (parte do _env atual, some quando o cenário é reconstruído). Devolve o nó —
## quem chama decide o que ela é (a da vila vira `_door`; as da arena do chefe são livres).
## `y` = a linha em que ela se apoia: o padrão é o chão, mas a saída de uma escadaria fica na
## superfície do último andar.
func _spawn_door(x: float, accent: Color, y := GROUND_Y) -> Node2D:
	var d := Node2D.new()
	d.position = Vector2(x, y)
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
	return d

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
	_run.rest_at(_run.current_level, bf.pos_x)
	_repopulate_world()   # descansar RENASCE todo inimigo que não seja chefe (o run-back clássico)
	Juice.burst(_env, bf.global_position + Vector2(0, -10), Color(1.0, 0.7, 0.25), 14, 90.0)
	_open_attributes()

## Sem nenhum inimigo de SALA vivo (a guarda não conta — ela é do refúgio e tem o ciclo dela),
## este nível fica marcado como esvaziado: revisitá-lo não repovoa. Só descansar ou morrer
## repovoa. É o que separa "já limpei isto agora" de "isto está limpo para sempre".
func _marcar_se_esvaziou() -> void:
	if _run == null or String(_floor_config.get("type", "")) != "room":
		return
	for v in _enemies:
		if is_instance_valid(v) and not _guard.has(v):
			return
	_run.mark_emptied(_run.current_level)

## Os níveis cujos inimigos RENASCEM. Todo nível de sala renasce, salvo se declarar
## "respawns": false — a exceção existe para uma sala que deva ficar vazia depois de resolvida
## (um evento único, um guardião que não se repete). Arenas de chefe nunca entram: chefe morto
## fica morto, e é isso que faz a fogueira ser alívio em vez de zerar o progresso.
func _respawning_ids() -> Array:
	var ids: Array = []
	for id in _levels:
		var cfg: Dictionary = _levels[id]
		if String(cfg.get("type", "")) == "boss":
			continue
		if not bool(cfg.get("respawns", true)):
			continue
		ids.append(id)
	return ids

## Repovoa o mundo e traz de volta, JÁ, os inimigos do nível onde se está. Os outros níveis
## renascem sozinhos quando forem revisitados (_start_floor consulta is_emptied).
func _repopulate_world() -> void:
	_run.repopulate(_respawning_ids())
	_reset_guard()
	if String(_floor_config.get("type", "")) != "room":
		return
	if not bool(_floor_config.get("respawns", true)):
		return
	_clear_room_enemies()
	_start_room()          # NÃO mexe em _phase: o caminho aberto continua aberto (ver _start_floor)

## Tira da cena os inimigos de sala (a guarda tem a lista própria e o _reset_guard dela).
func _clear_room_enemies() -> void:
	for v in _enemies.duplicate():
		if is_instance_valid(v) and not _guard.has(v):
			_enemies.erase(v)
			if v.get_parent() != null:
				v.get_parent().remove_child(v)
			v.queue_free()
	_necro = null

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
	Music.set_muffled(true)    # a música recua para "atrás da porta" enquanto o painel está aberto

func _close_attributes() -> void:
	get_tree().paused = false
	Music.set_muffled(false)
	if _attr_layer != null:
		_attr_layer.queue_free()
		_attr_layer = null

## As três interações do refúgio, cada uma disparada por INTERAGIR (E, padrão) quando o player está perto
## do objeto. Ficam longe umas das outras, então nunca há ambiguidade. Cada uma devolve true se agiu.

func _try_pull_lever() -> bool:
	if is_instance_valid(_lever) and _lever.is_armed() and not _lever.is_pulled() \
			and _lever.in_reach(_player_view):
		_lever.pull()
		return true
	return false

## Falar com um NPC. Antes da fogueira e da névoa na ordem do INTERAGIR porque ele fica ao lado
## do fogo — e quem chega ali pela primeira vez veio falar com ele, não descansar. No Downtown a
## mesma tecla serve o mercado inteiro: os NPCs ficam longe uns dos outros, então só um está em
## alcance por vez (a regra de desambiguação por proximidade de sempre).
func _try_npc() -> bool:
	for npc in [_npc, _trainer, _smith, _merchant]:
		if is_instance_valid(npc) and npc.in_reach(_player_view):
			npc.falar()
			return true
	return false

## O Sir Big T. entrega o Estus — e é ele quem ensina a fogueira e o frasco. A lição saiu de um
## toast disparado por proximidade e virou fala de alguém: uma regra dita por um personagem gruda
## melhor do que uma caixa de texto que aparece sozinha quando você pisa no lugar certo.
## As falas base do Sir Big T., em ordem. Uma frase por vez, a cada INTERAGIR. A entrega do
## Frasco acontece na fala de índice KNIGHT_GIFT. Esgotadas, ele passa a repetir as de KNIGHT_LOOP.
const KNIGHT_LINES := [
	"Olá plebeu, vejo que decidiu adotar a espada.",
	"Além deste portão apenas a morte o aguarda.",
	"O quê? Ainda assim quer ir em frente?",
	"Pois bem, tenho um presente que vai ajudá-lo.",
	"Agora, vê essa fogueira?",
	"É ao pé dela que você despertará ao cair na torre.",
	"Gaste suas almas no mercado antes de subir.",
	"Agora vá em frente e encontre o seu fim.",
]
const KNIGHT_LOOP := [
	"O medo é apenas uma escolha...",
	"A luz há de prevalecer...",
]
const KNIGHT_GIFT := 3            # depois desta fala (o "presente") entra o card do Frasco
const KNIGHT_LINE_SECONDS := 5.0 # quanto cada fala base fica na tela antes de a próxima entrar

## Falar com o Sir Big T. As falas BASE tocam em SEQUÊNCIA sozinhas (uma vez iniciada, o resto
## avança pelo tempo — não é preciso apertar INTERAGIR a cada frase). Esgotadas, cada INTERAGIR
## mostra uma fala de loop.
func _on_npc_falado(_n: NpcView) -> void:
	if _knight_seq or _knight_card_open:
		return                          # já está falando: não reinicia nem empilha
	if _run.knight_line >= KNIGHT_LINES.size():
		var j := (_run.knight_line - KNIGHT_LINES.size()) % KNIGHT_LOOP.size()
		_run.knight_line += 1
		_show_tip(KNIGHT_LOOP[j], true)
		return
	# Inicia (ou retoma, se saiu no meio) a sequência base pela fala atual.
	_knight_seq = true
	_show_tip(KNIGHT_LINES[_run.knight_line], true)
	_knight_timer = KNIGHT_LINE_SECONDS

## Chamado pelo _process quando o tempo da fala atual esgota: avança para a próxima. Na virada da
## fala do presente entra o CARD do Frasco (entrega + confirmação); a sequência só continua depois.
func _knight_avancar() -> void:
	# Acabou de exibir a fala do presente e o Frasco ainda não foi dado: o card entra AGORA e
	# pausa a sequência. A confirmação (INTERAGIR) a retoma — ver _fechar_card_frasco.
	if _run.knight_line == KNIGHT_GIFT and not _run.player.has_flask:
		_run.player.receive_flask()
		_run.flask_tutorial_seen = true
		Juice.burst(_env, _npc.global_position + Vector2(0, -30), Color(1.0, 0.72, 0.28), 18, 120.0)
		_abrir_card_frasco()
		return
	_run.knight_line += 1
	if _run.knight_line >= KNIGHT_LINES.size():
		_knight_seq = false             # fim das falas base; a última linger na tela e some sozinha
		return
	_show_tip(KNIGHT_LINES[_run.knight_line], true)
	_knight_timer = KNIGHT_LINE_SECONDS

## O CARD central do Frasco: um painel no meio da tela que o jogador CONFIRMA (INTERAGIR) para
## fechar. Enquanto aberto, a sequência de falas fica pausada (o _process não a avança).
func _abrir_card_frasco() -> void:
	_knight_card_open = true
	_hide_tip()
	var layer := CanvasLayer.new()
	layer.layer = 97                    # acima do HUD e do fade, na faixa dos painéis
	add_child(layer)
	_knight_card = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)

	# Painel centrado (640×360): moldura dourada + fundo escuro.
	var W := 260.0
	var H := 148.0
	var cx := 320.0 - W * 0.5
	var cy := 180.0 - H * 0.5
	var moldura := ColorRect.new()
	moldura.color = Color(0.42, 0.33, 0.16)
	moldura.position = Vector2(cx, cy)
	moldura.size = Vector2(W, H)
	layer.add_child(moldura)
	var fundo := ColorRect.new()
	fundo.color = Color(0.08, 0.07, 0.06)
	fundo.position = Vector2(cx + 3.0, cy + 3.0)
	fundo.size = Vector2(W - 6.0, H - 6.0)
	layer.add_child(fundo)

	var titulo := Label.new()
	titulo.text = "ITEM ADQUIRIDO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(cx, cy + 12.0)
	titulo.size = Vector2(W, 16.0)
	titulo.add_theme_color_override("font_color", Color(0.86, 0.72, 0.34))
	layer.add_child(titulo)

	# O MESMO ícone do slot de item (Hud.draw_flask_icon), só maior — para o card não inventar um
	# frasco próprio que divergiria do da HUD. Origem = topo-centro do quadro do ícone.
	var icone := Node2D.new()
	icone.position = Vector2(320.0, cy + 32.0)
	icone.scale = Vector2(1.5, 1.5)
	layer.add_child(icone)
	Hud.draw_flask_icon(icone, true)

	var nome := Label.new()
	nome.text = "Frasco de Cura"
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.position = Vector2(cx, cy + 98.0)
	nome.size = Vector2(W, 16.0)
	nome.add_theme_color_override("font_color", Palette.TEXT)
	layer.add_child(nome)

	var prompt := Label.new()
	prompt.text = "%s  confirmar" % KeyBinds.key_name("interact")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(cx, cy + H - 22.0)
	prompt.size = Vector2(W, 16.0)
	prompt.add_theme_color_override("font_color", Color(0.66, 0.66, 0.72))
	layer.add_child(prompt)

## Confirmou o card: fecha e o cavaleiro RETOMA as falas base de onde parou.
func _fechar_card_frasco() -> void:
	if is_instance_valid(_knight_card):
		_knight_card.queue_free()
	_knight_card = null
	_knight_card_open = false
	_refresh_market_prompts()           # com o frasco na mão, a vitrine do Mercador passa a dar preço
	_run.knight_line += 1               # passa da fala do presente para a próxima
	if _run.knight_line >= KNIGHT_LINES.size():
		_knight_seq = false
		return
	_show_tip(KNIGHT_LINES[_run.knight_line], true)
	_knight_timer = KNIGHT_LINE_SECONDS

func _try_rest() -> bool:
	if not is_instance_valid(_player_view):
		return false
	for bf in _bonfires:
		if is_instance_valid(bf) and bf.in_reach(_player_view):
			bf.rest()
			return true
	return false

## O ATALHO. Duas bocas de poço em níveis diferentes, com o MESMO id, cada uma apontando para
## onde a outra está: abrir uma abre as duas, para sempre (RunState.opened_gates, sobrevive à
## morte). Só a ponta marcada com "unlocks" destranca — e ela fica do lado LONGE, logo antes do
## chefe. É isso que dá sentido à travessia inteira: você não acha o atalho, você o abre por
## dentro, depois de já ter feito o caminho difícil uma vez.
##
## Nunca é walk-through: a boca fica no caminho obrigatório até a névoa, e cruzá-la andando
## teleportaria o jogador toda vez que ele fosse lutar.
func _try_shortcut() -> bool:
	if _shortcut_id == "" or not is_instance_valid(_player_view) or not is_instance_valid(_shortcut):
		return false
	if not _shortcut.in_reach(_player_view):
		return false
	if not _run.is_gate_open(_shortcut_id):
		if not _shortcut_unlocks:
			_show_tip("O poço está travado — a tranca fica do outro lado.")
			return true
		# Destrancar e atravessar são DOIS gestos. Antes o mesmo aperto que abria o poço já jogava
		# o jogador do outro lado, sem ele pedir — abrir um atalho é uma conquista para saborear,
		# não um teletransporte-surpresa. Abre aqui e para; o próximo INTERAGIR é que desce.
		_run.open_gate(_shortcut_id)
		_shortcut.abrir()                  # as tábuas caem: o poço deixa de ser entulho
		_show_tip("O poço se abriu. Interaja de novo para atravessar.")
		return true
	_transition(_atravessar_atalho)
	return true

## Sai pela boca e entra na outra ponta, no ponto exato que o levels.json manda.
func _atravessar_atalho() -> void:
	var destino := String(_shortcut_to.get("level", ""))
	if destino == "":
		return
	_entry_point = "x"
	_entry_x = float(_shortcut_to.get("x", PLAYER_START_X))
	_run.go_to(destino)
	_start_floor()

## Atravessa a névoa do chefe: só com o nível vencido (não dá para pular o combate) e perto dela.
## Leva ao próximo nível com o fade de sempre — e se o próximo nível ainda não foi desenhado
## (fim do conteúdo atual), a névoa não deixa passar e avisa.
func _try_cross_fog() -> bool:
	if _phase == "cleared" and is_instance_valid(_fog) and _fog.in_reach(_player_view):
		if not _has_exit("frente"):
			_show_tip("O caminho adiante ainda está por vir...")
			return true
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
# Vila de tutorial. Área tranquila de 1920 onde o player aprende os controles básicos por DICAS
# que surgem no HUD conforme ele anda (ver _update_tutorial_tips) + um boneco de treino, com a
# porta ao fim levando ao DOWNTOWN (o HUB). Roda uma vez no começo do jogo. Sem inimigos.
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
	_spawn_training_dummy(980.0)
	# O Sir Big T. NÃO mora mais aqui: ele está no Downtown, ao lado da fogueira de renascer —
	# a vila é só o treino (dicas + espantalho); a porta ao fim leva ao Downtown.
	_door = _spawn_door(_arena_width - 40.0, Palette.ACCENT)
	_door_x = _arena_width - 40.0

	_tips_done.clear()          # as dicas recomeçam a cada visita à vila
	_hide_tip()
	_msg.text = "Cidade: a porta ao fim leva ao Centro →"
	_schedule_first_tip()       # a 1ª dica (mover) só entra 3s depois de começar

## Boneco de treino: esqueleto blindado passivo (dormant) pra praticar o ataque. Some se
## derrotado. Não dá XP (tier "minion") nem participa da lógica de sala.
## Espantalho de treino da Cidade: um boneco de palha que reage ao golpe (balança, pisca) mas não
## é inimigo — não persegue, não ataca, não morre. Trocou o esqueleto dormente que fazia esse papel
## antes: um esqueleto parado na vila sugeria que a Cidade tinha combate, o que ela não tem. Vai
## direto na cena (não em _enemies): não conta para nada, não emite `died`.
func _spawn_training_dummy(x: float) -> void:
	var enemy := Enemy.from_dict({
		"id": "boneco_treino", "name": "Espantalho", "rank": "NORMAL",
		"base_stats": { "max_hp": 99999, "attack": 0, "defense": 0, "move_speed": 0 },
		"hurt_sfx": "dummy_hit",
	})
	var view := ScarecrowView.new()
	view.setup(enemy, _player_view)
	view.position = Vector2(x, GROUND_Y - 40.0)
	_env.add_child(view)

# ---------------------------------------------------------------------------
# Toast de dica (HUD). Uma caixa centrada na parte INFERIOR da tela com uma instrução. Aparece por
# posição no tutorial (_update_tutorial_tips) e some em TIP_SECONDS ou quando o player aperta INTERAGIR.
# ---------------------------------------------------------------------------

func _build_tip_ui() -> void:
	# Fonte 16 (o nativo da Pixel Operator — menor sai borrado). A caixa é JUSTA para uma linha
	# (a dica mais longa tem ~69 caracteres ≈ 552px) — o autowrap fica de rede de segurança.
	# Sem linha de "fechar": INTERAGIR fecha, mas isso não precisa de aviso.
	const W := 584.0
	const H := 30.0
	var x := (640.0 - W) * 0.5
	var y := 318.0          # parte INFERIOR da tela (base 640×360; caixa de 30px com margem do fundo)

	_tip_root = Control.new()
	_tip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_root.visible = false
	_tip_root.modulate.a = 0.0
	_layer.add_child(_tip_root)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.82)
	bg.size = Vector2(W, H)
	bg.position = Vector2(x, y)
	_tip_root.add_child(bg)
	var strip := ColorRect.new()          # faixa de destaque no topo da caixa
	strip.color = Color(Palette.ACCENT, 0.9)
	strip.size = Vector2(W, 2.0)
	strip.position = Vector2(x, y)
	_tip_root.add_child(strip)

	_tip_label = Label.new()
	_tip_label.add_theme_color_override("font_color", Palette.TEXT)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.size = Vector2(W - 16.0, H - 4.0)
	_tip_label.position = Vector2(x + 8.0, y + 2.0)
	_tip_root.add_child(_tip_label)

	# Indicador "[E] Avançar": a TECLA dentro de um contorno (keycap) para ficar claro que é uma
	# tecla, não parte da frase. Fica à direita do toast; quando visível, o texto reserva espaço.
	_tip_key = Control.new()
	_tip_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_key.visible = false
	_tip_root.add_child(_tip_key)
	# ACIMA da caixa, alinhado à direita: assim o texto do toast fica sempre centralizado na
	# largura cheia, sem ter de encolher para caber ao lado do indicador.
	var cap_x := x + W - 90.0
	var cap_y := y - 20.0
	var borda := ColorRect.new()          # contorno claro do keycap
	borda.color = Color(0.80, 0.82, 0.90)
	borda.size = Vector2(18.0, 16.0)
	borda.position = Vector2(cap_x, cap_y)
	_tip_key.add_child(borda)
	var dentro := ColorRect.new()         # fundo escuro dentro do contorno
	dentro.color = Color(0.10, 0.09, 0.14)
	dentro.size = Vector2(14.0, 12.0)
	dentro.position = Vector2(cap_x + 2.0, cap_y + 2.0)
	_tip_key.add_child(dentro)
	_tip_key_label = Label.new()          # a tecla (E), centrada no contorno
	_tip_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_key_label.size = Vector2(18.0, 16.0)
	_tip_key_label.position = Vector2(cap_x, cap_y - 1.0)
	_tip_key_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_tip_key.add_child(_tip_key_label)
	var av := Label.new()                 # o rótulo "Avançar" ao lado da tecla
	av.text = "Avançar"
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.size = Vector2(64.0, 16.0)
	av.position = Vector2(cap_x + 22.0, cap_y - 1.0)
	av.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
	_tip_key.add_child(av)

## Mostra uma dica no HUD por TIP_SECONDS (ou até o player apertar INTERAGIR). Uma nova substitui
## a atual.
func _show_tip(text: String, com_tecla := false) -> void:
	if _tip_label == null:
		return
	_tip_label.text = text
	if _tip_key != null:
		_tip_key.visible = com_tecla
		if com_tecla and _tip_key_label != null:
			_tip_key_label.text = KeyBinds.key_name("interact")
	_tip_time = TIP_SECONDS
	_tip_root.visible = true
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_root, "modulate:a", 1.0, 0.18)

func _hide_tip() -> void:
	_tip_time = 0.0
	if _tip_root == null or not _tip_root.visible:
		return
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_root, "modulate:a", 0.0, 0.18)
	_tip_tween.tween_callback(func(): if _tip_root != null: _tip_root.visible = false)

## A 1ª dica (mover) NÃO aparece de cara: entra 3s depois de a vila carregar. Pré-marca a dica 0
## como "já disparada" para o _process não mostrá-la antes da hora, e só a exibe se, ao fim dos 3s,
## o player ainda estiver no início (nenhuma outra dica disparada por ter andado).
const FIRST_TIP_DELAY := 3.0

func _schedule_first_tip() -> void:
	var tips := _tutorial_tips()
	if tips.is_empty():
		return
	_tips_done[0] = true
	await get_tree().create_timer(FIRST_TIP_DELAY).timeout
	if _phase == "tutorial" and _tips_done.size() == 1:   # ainda no começo, nada mais disparou
		_show_tip(String(_tutorial_tips()[0][1]), true)

## Dica do Frasco de Cura, na ÁREA DA FOGUEIRA: aparece uma única vez por run, quando o player
## chega perto da fogueira (que só é alcançável depois de limpar a sala — o portão abre então).
## Persistida em RunState.flask_tutorial_seen para não repetir a cada morte/run-back.
const FLASK_TIP_REACH := 130.0


## No tutorial, dispara a dica cujo x o player acabou de alcançar (uma vez cada).
func _update_tutorial_tips() -> void:
	if not is_instance_valid(_player_view):
		return
	var px := _player_view.global_position.x
	var tips := _tutorial_tips()
	for i in tips.size():
		if _tips_done.has(i):
			continue
		if px >= float(tips[i][0]):
			_tips_done[i] = true
			_show_tip(String(tips[i][1]), true)

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

# ---------------------------------------------------------------------------
# Enfeites de fundo do cenário (para não ficar cru): cercas, pedras, ruínas e árvores mortas.
# São placeholders em ColorRect/Polygon2D (sem arte ainda), SEM colisão, num z atrás das entidades
# e à frente do chão. Espalhados de forma DETERMINÍSTICA — um RNG semeado pela largura do nível —
# então o cenário fica idêntico a cada morte/reentrada, em vez de embaralhar. É puramente cosmético,
# então usa um RNG local, não o RNGService (reservado à lógica reproduzível da run).
# ---------------------------------------------------------------------------

const DECO_Z := -4              # atrás das entidades (0) e das placas (-3), à frente do chão (-5)

func _decorate_scenery(width: float, dim: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width) * 31 + int(dim * 1000.0)   # estável por nível; muda entre sala e arena do boss
	var x := 70.0
	while x < width - 60.0:
		var node: Node2D
		match rng.randi() % 4:
			0: node = _deco_dead_tree(rng)
			1: node = _deco_rock(rng)
			2: node = _deco_fence(rng)
			_: node = _deco_ruin(rng)
		node.position = Vector2(x, GROUND_Y)
		node.z_index = DECO_Z
		node.modulate = Color(1, 1, 1).darkened(dim)   # acompanha o escurecimento da sala do boss
		_env.add_child(node)
		x += rng.randf_range(150.0, 300.0)

## Árvore morta: tronco fino + alguns galhos tortos (retângulos rotacionados).
func _deco_dead_tree(rng: RandomNumberGenerator) -> Node2D:
	var n := Node2D.new()
	var h := rng.randf_range(48.0, 82.0)
	var bark := Color(0.16, 0.12, 0.11)
	var trunk := ColorRect.new()
	trunk.color = bark
	trunk.size = Vector2(6, h)
	trunk.position = Vector2(-3, -h)
	n.add_child(trunk)
	for i in 3:
		var br := ColorRect.new()
		br.color = bark
		var bl := rng.randf_range(12.0, 22.0)
		br.size = Vector2(bl, 3)
		var dir := 1.0 if rng.randi() % 2 == 0 else -1.0
		br.position = Vector2(0.0 if dir > 0.0 else -bl, -h + rng.randf_range(6.0, h * 0.6))
		br.rotation = dir * rng.randf_range(0.3, 0.7)
		n.add_child(br)
	return n

## Pedra: um polígono irregular baixo, apoiado no chão.
func _deco_rock(rng: RandomNumberGenerator) -> Node2D:
	var n := Node2D.new()
	var w := rng.randf_range(22.0, 46.0)
	var h := rng.randf_range(12.0, 26.0)
	var rock := Polygon2D.new()
	rock.color = Color(0.30, 0.30, 0.35)
	rock.polygon = PackedVector2Array([
		Vector2(-w * 0.5, 0), Vector2(-w * 0.42, -h * 0.7), Vector2(-w * 0.1, -h),
		Vector2(w * 0.28, -h * 0.82), Vector2(w * 0.5, 0),
	])
	n.add_child(rock)
	return n

## Cerca de madeira: postes com dois trilhos; às vezes um poste faltando (quebrada).
func _deco_fence(rng: RandomNumberGenerator) -> Node2D:
	var n := Node2D.new()
	var wood := Color(0.34, 0.25, 0.16)
	var posts := rng.randi_range(3, 5)
	var gap := 18.0
	for i in posts:
		if rng.randf() < 0.2:
			continue                     # poste faltando: cerca meio caída
		var post := ColorRect.new()
		post.color = wood
		post.size = Vector2(4, 28)
		post.position = Vector2(i * gap, -28)
		n.add_child(post)
	for ry in [-22.0, -11.0]:
		var rail := ColorRect.new()
		rail.color = wood
		rail.size = Vector2((posts - 1) * gap + 4, 3)
		rail.position = Vector2(0, ry)
		n.add_child(rail)
	return n

## Construção meio destruída: uma parede com topo irregular (duas colunas desiguais) e uma fresta escura.
func _deco_ruin(rng: RandomNumberGenerator) -> Node2D:
	var n := Node2D.new()
	var w := rng.randf_range(50.0, 92.0)
	var h := rng.randf_range(42.0, 72.0)
	var stone := Color(0.24, 0.22, 0.28)
	var left := ColorRect.new()
	left.color = stone
	left.size = Vector2(w * 0.38, h)
	left.position = Vector2(-w * 0.5, -h)
	n.add_child(left)
	var right := ColorRect.new()
	right.color = stone
	var rh := h * rng.randf_range(0.5, 0.82)
	right.size = Vector2(w * 0.42, rh)
	right.position = Vector2(w * 0.08, -rh)
	n.add_child(right)
	var win := ColorRect.new()
	win.color = Color(0.08, 0.07, 0.10)
	win.size = Vector2(10, 12)
	win.position = Vector2(-w * 0.42, -h * 0.66)
	n.add_child(win)
	return n

## Sai da vila: limpa o boneco de treino e segue — ao Downtown (roguelite) ou ao nível 1 (grafo).
func _begin_dungeon() -> void:
	_hide_tip()                  # sai da vila: qualquer dica na tela some
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	if _roguelite:
		# A porta da vila leva ao DOWNTOWN (o HUB), não direto à torre.
		_start_downtown()
		return
	_run.go_to(_start_level)
	_start_floor()

# ---------------------------------------------------------------------------
# DOWNTOWN — o centro da cidade, o HUB entre runs. É aqui que o jogador renasce ao cair (e volta
# ao vencer), gasta as almas no mercado e entra na torre pelo portão grande. A fogueira ao lado do
# Sir Big T. é DECORATIVA: marca o ponto de renascer, sem menu, sem cura, sem recarga — preparar-se
# é papel do mercado, não dela.
# ---------------------------------------------------------------------------

## Monta o Downtown. `na_fogueira` = o jogador desperta ao pé do fogo (renascer); senão entra
## pela esquerda (chegando da vila).
func _start_downtown(na_fogueira := false) -> void:
	_phase = "downtown"
	_current_boss_id = ""
	_boss_view = null
	_exit_door_x = 0.0
	_bonfires.clear()            # nenhuma fogueira-checkpoint aqui: _try_rest não pode agir
	Music.stop()
	_clear_entities()
	_build_environment(DOWNTOWN_LENGTH, false, [])
	_decorate_village()
	_reset_player_to_start(DT_FIRE_X if na_fogueira else PLAYER_START_X)

	# O Sir Big T. e a fogueira de renascer (cavaleiro à esquerda, fogo à direita — como sempre).
	_npc = NpcView.new()
	_env.add_child(_npc)
	_npc.setup(DT_KNIGHT_X, GROUND_Y, _player_view, "Sir Big T.")
	_npc.falado.connect(_on_npc_falado)
	_hub_fire = BonfireView.new()
	_hub_fire.decorativa = true
	_hub_fire.position = Vector2(DT_FIRE_X, GROUND_Y)
	_env.add_child(_hub_fire)
	_hub_fire.setup(DT_FIRE_X, true, _player_view)   # sempre acesa: é um marco, não um serviço

	# O mercado: Mestre (atributos), Ferreiro (arma), Mercador (frasco).
	_trainer = _spawn_market_npc(DT_TRAINER_X, "Mestre Owyn", "mestre", _on_trainer_falado)
	_smith = _spawn_market_npc(DT_SMITH_X, "Baldo, o Ferreiro", "ferreiro", _on_smith_falado)
	_merchant = _spawn_market_npc(DT_MERCHANT_X, "Mira, a Mercadora", "mercador", _on_merchant_falado)
	_refresh_market_prompts()

	# O portão grande da torre (o estilo do antigo portão da cidade): sólido até a alavanca — que
	# nasce DESTRAVADA (abrir é partida, não prêmio) — ser puxada. Aberto, fica aberto para sempre.
	_gate_key = DT_GATE_KEY
	var aberto := _run.is_gate_open(_gate_key)
	_gate = GateView.new()
	_gate.position = Vector2(DT_GATE_X, GROUND_Y)
	_env.add_child(_gate)
	_gate.setup(DT_GATE_X, aberto, 56.0, 150.0)
	_lever = LeverView.new()
	_lever.position = Vector2(DT_GATE_X - 50.0, GROUND_Y)
	_env.add_child(_lever)
	_lever.setup(DT_GATE_X - 50.0, _player_view, aberto, true)
	_lever.pulled.connect(_on_lever_pulled)

	# A porta da torre, depois do portão. Só se alcança com ele aberto (ele é sólido).
	_door = _spawn_door(DT_DOOR_X, Palette.ACCENT)
	_door_x = DT_DOOR_X

	_hide_tip()
	if na_fogueira:
		_show_tip("Você desperta no Centro. Gaste suas almas antes de subir")
	else:
		_show_tip("O Centro da cidade: o mercado, e a torre adiante")

## Um NPC do mercado: variante visual própria e o handler da compra ligado ao `falado`.
func _spawn_market_npc(x: float, nome: String, tipo: String, handler: Callable) -> NpcView:
	var npc := NpcView.new()
	_env.add_child(npc)
	npc.setup(x, GROUND_Y, _player_view, nome, tipo)
	npc.falado.connect(handler)
	return npc

## Os prompts do mercado são a VITRINE: mostram o serviço e o preço atual, e mudam quando o
## preço muda (toda compra chama isto de novo).
func _refresh_market_prompts() -> void:
	if is_instance_valid(_trainer):
		_trainer.prompt_texto = "treinar (níveis e atributos)"
	if is_instance_valid(_smith):
		_smith.prompt_texto = "melhorar arma (%d almas)" % _run.player.weapon.upgrade_cost()
	if is_instance_valid(_merchant):
		if not _run.player.has_flask:
			_merchant.prompt_texto = "caco de frasco (fale com Sir Big T.)"
		elif not _run.player.can_buy_flask_shard():
			_merchant.prompt_texto = "cacos esgotados"
		else:
			_merchant.prompt_texto = "caco de frasco (%d almas)" % _run.player.flask_shard_cost()

## O Mestre: o painel de atributos de sempre (comprar níveis com almas, gastar pontos). A
## maquinaria já existia — morava na fogueira-checkpoint; agora mora nele.
func _on_trainer_falado(_n: NpcView) -> void:
	_open_attributes()

## O Ferreiro: uma melhoria por conversa, se as almas derem. Dano e custo sobem geometricamente.
func _on_smith_falado(_n: NpcView) -> void:
	var w := _run.player.weapon
	var custo := w.upgrade_cost()
	if _run.player.souls < custo:
		_show_tip("Baldo: \"Volte com %d almas.\"" % custo)
		return
	_run.player.souls -= custo
	w.upgrade()
	_run.player.recalculate_stats()
	_show_tip("Arma no nível %d — dano %d" % [w.level, int(round(w.current_damage()))])
	_refresh_market_prompts()

## O Mercador: um caco de frasco (+1 carga máxima; a carga nova vem cheia), até o limite.
func _on_merchant_falado(_n: NpcView) -> void:
	var p := _run.player
	if not p.has_flask:
		_show_tip("Mira: \"Um caco sem frasco? Fale com o cavaleiro.\"")
		return
	if not p.can_buy_flask_shard():
		_show_tip("Mira: \"Meus cacos acabaram, guerreiro.\"")
		return
	var custo := p.flask_shard_cost()
	if not p.buy_flask_shard():
		_show_tip("Mira: \"Volte com %d almas.\"" % custo)
		return
	_show_tip("Frasco ampliado: %d cargas" % p.flask_capacity())
	_refresh_market_prompts()

## Cruza a porta depois do portão: entra na torre, no primeiro nó do plano.
func _begin_tower() -> void:
	_hide_tip()
	_enter_node(_plan.current())

## Início de um nível da dungeon. Cada nível é desenhado à mão em levels.json e é de UM tipo:
##   "boss" → arena fechada, direto no chefe.
##   "room" → sala/corredor a limpar (ex.: sala do Necromante). Sem chefe.
##   "rest" → área pequena e SEGURA (depois de um chefe): só a fogueira no começo e a névoa no
##            fim — sem inimigos, sem alavanca, sem portão. Um respiro.
## A névoa do último nível existente não deixa passar ("ainda por vir").
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
	_guard.clear()      # as views da guarda estão em _enemies (já liberadas acima); só zera a lista
	_bloodstain = null  # ela é filha do _env, liberada ao remontar o cenário; aqui só solta a referência

	# Projéteis em voo. O Necromante e o Ogro os penduram na CENA (get_parent()), não em si
	# mesmos, então não morrem junto com quem os atirou: sem isto, um tiro disparado um instante
	# antes de a sala ser demolida continua voando e vai te encontrar na sala da fogueira.
	for c in get_children():
		if c is NecroProjectile or c is OgreRock or c is OgreShockwave:
			remove_child(c)
			c.queue_free()
		# Cadáveres ainda tombando: a morte tira o inimigo de _enemies na hora, mas o nó sobrevive
		# meio segundo para a queda ser vista. Sem esta varredura, um cadáver pego no meio de uma
		# troca de nível ficaria órfão na cena nova.
		elif c is EnemyView:
			remove_child(c)
			c.queue_free()
	_boss_view = null
	_necro = null
	_heavy_stage.clear()
	_alive = { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }
	_first_kill_done = false

func _start_floor() -> void:
	var floor := _run.current_level
	# Por onde entrar neste nível. Quem cruzou a passagem definiu; consumido aqui, e a próxima
	# entrada volta ao padrão (o começo do corredor).
	var entry := _entry_point
	var entry_x := _entry_x
	_entry_point = "inicio"
	_entry_x = -1.0
	var from_right := entry == "fim"
	_clear_entities()
	_boss_fogs.clear()   # views eram filhas do _env (demolido abaixo); só solta as referências
	_floor_config = _levels.get(floor, {})
	var ltype := String(_floor_config.get("type", ""))
	if ltype == "":
		# Não deveria acontecer: uma passagem só se abre quando o destino existe no mapa
		# (_has_exit). Se um debug apontar para um id inexistente, cai no começo da dungeon.
		push_warning("[floor_scene] nível '%s' não existe em levels.json — voltando ao início" % floor)
		if floor == _start_level:
			return                 # o próprio início está quebrado: não recursa para sempre
		_run.go_to(_start_level)
		_start_floor()
		return

	var hazards: Array = _floor_config.get("hazards", [])

	# Roguelite: uma sala de combate é SÓ combate. Nada de refúgio, entrada, portão, atalho ou
	# fogueira — o nó de combate resolve-se limpando a sala, e uma porta de avanço nasce ao fim.
	# (O boss segue pelo ramo abaixo, que já monta a arena; só as PORTAS dele mudam — ver _spawn_boss_doors.)
	if _roguelite and ltype == "room":
		_rl_start_room(floor, hazards)
		return

	# A escadaria entre bosses: seção vertical de plataformas + escadas, travessia livre.
	if ltype == "climb":
		_start_climb()
		return

	if ltype == "boss":
		# Roguelite (torre): o boss do andar vem do nó (_rl_boss_id), não do levels.json.
		_current_boss_id = _rl_boss_id if (_roguelite and _rl_boss_id != "") else String(_floor_config.get("boss_id", ""))
		_build_environment(BOSS_ROOM_W, true, hazards)
		var boss_x := (BOSS_ROOM_W - BOSS_DOOR_IN - 34.0) if from_right else PLAYER_START_X
		_reset_player_to_start(boss_x)           # o player primeiro; os poços depois (ver _start_tutorial)
		_spawn_hazards(hazards)
		_spawn_boss_doors(_run.is_cleared(floor))
		_spawn_bloodstain_if_here()              # a marca pode estar AQUI: a queda no chefe fica na arena
		# Chefe já vencido: arena vazia, portas livres (as névoas nem nascem). Só passagem.
		if _run.is_cleared(floor):
			Music.stop()
			_phase = "cleared"
			_msg.text = "A arena está vazia. As portas aguardam →"
			return
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

	# Área de descanso: uma tela pequena, sem perigo. A fogueira logo na entrada e a névoa no fim.
	if ltype == "rest":
		var rest_w := float(_floor_config.get("corridor_length", 640.0))
		_build_environment(rest_w, false, hazards)
		_fight_width = rest_w
		var rx := _run.respawn_x(PLAYER_START_X)      # renascer aqui = levantar na fogueira
		if from_right:
			rx = _arena_width - FOG_BACK - 48.0
		_reset_player_to_start(rx)
		_spawn_rest_area(floor)
		_spawn_bloodstain_if_here()
		_phase = "cleared"                            # nada a limpar: a névoa já responde
		# O toast de chegada só na PRIMEIRA visita (fogueira ainda apagada) — renascer aqui após
		# cada morte repetindo "momento de paz" viraria piada de mau gosto.
		if not _bonfires.is_empty() and not _bonfires[0].lit:
			_show_tip("Um raro momento de paz. A fogueira convida")
		return

	# O corredor tem duas partes: a ZONA DE COMBATE (corridor_length) e, depois dela, o REFÚGIO
	# (SANCTUARY_LEN) com o portão, a fogueira e a névoa do chefe — tudo contínuo, sem fade.
	# O refúgio (o trecho após o combate) tem SANCTUARY_LEN por padrão — espaço para o portão, a
	# fogueira, a guarda e a névoa do chefe. Um nível que não usa nada disso (o Portão: fogueira e
	# portão ficam na ENTRADA, sem guarda e sem chefe adiante) sobra com um vão vazio enorme até a
	# porta de saída; "sanctuary_len" encurta esse trecho por nível.
	_corridor_length = float(_floor_config.get("corridor_length", _corridor_length))
	var sanct := float(_floor_config.get("sanctuary_len", SANCTUARY_LEN))
	_build_environment(_corridor_length + sanct, false, hazards)
	_fight_width = _corridor_length          # combate só na 1ª parte; _build_environment o resetara p/ o total
	var start_x := _run.respawn_x(PLAYER_START_X)   # início do nível, ou a fogueira ao renascer
	if from_right:
		start_x = _arena_width - FOG_BACK - 48.0    # voltou da arena: entra pela névoa do fim
	elif entry == "fogueira":
		start_x = _corridor_length + BONFIRE_IN     # cai ao pé do fogo do refúgio
	elif entry == "x" and entry_x >= 0.0:
		start_x = entry_x                          # ponto exato pedido por quem mandou vir (o atalho)
	_reset_player_to_start(start_x)
	_spawn_hazards(hazards)
	# ORDEM IMPORTA: _spawn_sanctuary zera _bonfires/_lever/_gate no começo, então a ENTRADA tem de
	# ser montada DEPOIS dele — senão o refúgio apagaria a fogueira e o portão da cidade.
	_spawn_sanctuary(floor)                   # alavanca + portão + fogueira + névoa (o refúgio do nível)
	_spawn_entrance(floor)                    # fogueira/portão da ENTRADA (antes do combate)
	_spawn_shortcut(floor)                    # a boca do poço, onde quer que este nível a ponha

	# Nível já vencido: sem inimigos. A alavanca já nasceu destravada em _spawn_sanctuary (e puxada,
	# se o portão já foi aberto antes); nada a fazer aqui além de marcar a fase e o Eco.
	if _run.is_cleared(floor):
		_phase = "cleared"
		_msg.text = "Nível vencido: o caminho adiante está aberto →"
		_spawn_guard()        # a guarda do run-back reocupa o caminho até a névoa
		# VENCIDO não é VAZIO: o caminho fica aberto para sempre, mas os inimigos voltam depois de
		# cada descanso/morte. Só ficam mortos os do nível que ainda está marcado como esvaziado.
		if not _run.is_emptied(floor) and bool(_floor_config.get("respawns", true)):
			_start_room()
		_spawn_bloodstain_if_here()  # ...e a sua marca ainda pode estar esperando no caminho
		return

	_phase = "room"
	_start_room()
	_spawn_bloodstain_if_here()

# ---------------------------------------------------------------------------
# Sala a limpar. Composição vem de floor_config["room"] — todas as partes são OPCIONAIS:
#   elites   → Necromante(s): estático no fim da sala, ranged, revive a horda, mata todos ao cair.
#              (o nível 1 não tem mais — ele vai para outro nível; a maquinaria fica aqui pronta.)
#   heavies  → esqueletos pesados (com Necromante no andar 1: encadeamento a/b/c dormente).
#   minions/normals → esqueletos espalhados. Nascem DORMENTES e acordam por proximidade
#                     (_update_room_wake). Com Necromante, cada morto renasce perto dele.
# Sem Necromante, a sala é só "mate todos": limpa por contagem (_check_room_cleared).
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

	# TESTE: o primeiro nível só com o necromante (pula heavies e horda).
	if not (_run.current_level == _start_level and L1_NECRO_ONLY):
		# Heavies: no primeiro nível → encadeamento a/b/c dormente; nos demais → ativos, espalhados.
		if _run.current_level == _start_level:
			_spawn_l1_heavies()
		else:
			_spawn_heavies_simple()

		# Horda inicial espalhada por todo o corredor.
		_fill_pool("minion")
		_fill_pool("normal")

	if _has_necro():
		_msg.text = "%s: o Necromante comanda a horda. Elimine-o!" % _level_name()
	else:
		_msg.text = "%s: limpe a sala de esqueletos." % _level_name()
	_check_room_cleared()   # fallback: sem Necromante, a sala limpa por contagem

## Spec de um tier: { "ids": [...], "count": N }.
func _tier_spec(tier: String) -> Dictionary:
	match tier:
		"minion": return _room.get("minions", {})
		"normal": return _room.get("normals", {})
		"heavy": return _room.get("heavies", {})
	return {}

## Spawna a horda do tier nas posições FIXAS do nível (_spawn_positions), toda ela DORMENTE:
## imóvel, encarando o player, até ele se aproximar (_update_room_wake). É o mesmo comportamento
## da guarda do refúgio — o esqueleto ganha vida quando você chega perto.
func _fill_pool(tier: String) -> void:
	var spec := _tier_spec(tier)
	var ids: Array = spec.get("ids", [])
	if ids.is_empty():
		return
	# Id por ÍNDICE, não sorteado: com vários ids, a mesma posição traz sempre o mesmo inimigo.
	var pos := _spawn_positions(spec, false)
	for i in pos.size():
		_spawn_room_enemy(tier, String(ids[i % ids.size()]), Vector2(pos[i], GROUND_Y - 40.0))

func _spawn_room_enemy(tier: String, id: String, pos: Vector2) -> EnemyView:
	if id == "":
		return null
	var base := _enemy_repo.get_by_id(id)
	if base.is_empty():
		return null
	var enemy := EnemyFactory.build(base)
	var view := EnemyView.new()
	view.set_meta("tier", tier)
	# REGRA GERAL: todo inimigo que não seja chefe nasce DORMENTE e só se ativa quando o jogador
	# chega perto (_update_room_wake). É o que deixa o jogador escolher a briga em vez de ser
	# arrastado por um corredor inteiro de agressão simultânea — e o que torna possível passar
	# reto por um grupo. Só o chefe age de saída, porque a arena dele já é o compromisso.
	view.dormant = true
	# Sob um Necromante, esqueleto não morre: desaba em ossos e se remonta sozinho (ver
	# EnemyView._collapse). Quem apaga isso é a morte do Necromante — ele é o objetivo real.
	if tier != "elite" and _has_necro():
		view.reassemble_time = float(_room.get("reassemble_time", 2.0))
	_alive[tier] += 1
	_add_view(view, enemy, pos)
	return view

## A TORRE do Necromante: uma plataforma de pedra elevada, acessível SÓ pela escada. Ele fica em
## cima. Muda a luta inteira — de costas para uma parede você trocava golpes com ele; agora ele
## bombardeia de um lugar que custa uma subida (e a subida tira do jogador o ataque e a esquiva).
## Declarada em levels.json → room.tower = { at, altura, largura, escada_em }.
## Devolve o y do TOPO (onde o Necromante pisa), ou 0 se este nível não tem torre.
func _spawn_necro_tower(spec: Dictionary) -> float:
	if spec.is_empty():
		return 0.0
	var tx := float(spec.get("at", _fight_width - 198.0))
	var alt := float(spec.get("altura", 92.0))
	var larg := float(spec.get("largura", 132.0))
	var perna := float(spec.get("perna", 22.0))     # espessura de cada pilar
	var deck := 12.0                                # espessura do tabuleiro
	var topo_y := GROUND_Y - alt

	var torre := Node2D.new()
	torre.position = Vector2(tx, GROUND_Y)
	torre.z_index = DECO_Z + 1        # à frente do cenário de fundo, atrás das entidades
	_env.add_child(torre)

	# DOIS PILARES com um VÃO EM ARCO entre eles. A primeira versão era um bloco maciço do chão ao
	# topo, e virava uma parede que partia o corredor em dois — o jogador (e a horda) simplesmente
	# não passava. A torre tem de ser passagem embaixo e plataforma em cima.
	for lado in [-1.0, 1.0]:
		var pilar := ColorRect.new()
		pilar.color = Color(0.29, 0.28, 0.33)
		pilar.size = Vector2(perna, alt)
		pilar.position = Vector2(lado * (larg * 0.5) - (0.0 if lado < 0.0 else perna), -alt)
		torre.add_child(pilar)

	# A curva do arco, em degraus (pixel-art não pede curva de verdade): blocos que avançam para o
	# centro conforme sobem, desenhando o intradorso.
	var vao := larg - perna * 2.0
	var passos := 5
	for i in passos:
		var t := float(i + 1) / float(passos)
		var av := (vao * 0.5) * (1.0 - sqrt(1.0 - t * t))    # perfil de quarto de círculo
		var h := (alt - deck) / float(passos)
		for lado2 in [-1.0, 1.0]:
			var b := ColorRect.new()
			b.color = Color(0.27, 0.26, 0.31)
			b.size = Vector2(av, h + 1.0)
			b.position = Vector2(
				lado2 * (vao * 0.5) - (av if lado2 > 0.0 else 0.0),
				-alt + deck + (passos - 1 - i) * h)
			torre.add_child(b)

	# Tabuleiro (o piso lá em cima) e as ameias que fazem a silhueta ler como torre de castelo.
	var piso := ColorRect.new()
	piso.color = Color(0.38, 0.37, 0.43)
	piso.size = Vector2(larg, deck)
	piso.position = Vector2(-larg * 0.5, -alt)
	torre.add_child(piso)
	var n_ameias := int(larg / 22.0)
	for i in n_ameias:
		var a := ColorRect.new()
		a.color = Color(0.34, 0.33, 0.38)
		a.size = Vector2(12.0, 10.0)
		a.position = Vector2(-larg * 0.5 + 4.0 + i * 22.0, -alt - 10.0)
		torre.add_child(a)

	var lx := tx + float(spec.get("escada_em", -larg * 0.25))

	# O TABULEIRO é uma PLATAFORMA DE SENTIDO ÚNICO: sólida por cima, atravessável por baixo. É o
	# que deixa a escada terminar de forma natural — sobe-se atravessando a laje e simplesmente
	# pisa-se nela. A versão anterior tinha um alçapão e teleportava o jogador para o lado ao
	# chegar no topo, o que se via na tela como um solavanco.
	# Ela continua barrando o RAYCAST de linha de visada (o sentido único vale para a resolução
	# de colisão, não para consultas), então o golpe segue sem atravessar de baixo.
	_solido(torre, Vector2(0.0, -alt + deck * 0.5), Vector2(larg, deck), true)

	# A CÂMARA: paredes nas duas bordas e teto. Sem isso o jogador pulava ao lado da torre e
	# acertava o Necromante no ar — o pulo alcança 76px e o Necromante fica a ~110, mas a lâmina
	# tem 76 de comprimento e cobria a diferença. Com a câmara fechada, a linha de visada do golpe
	# (ver PlayerView._tem_linha_de_visada) bate na parede e o dano não sai.
	var par_h := float(spec.get("camara_h", 64.0))
	var esp := 6.0
	for lado2 in [-1.0, 1.0]:
		_solido(torre, Vector2(lado2 * (larg * 0.5 - esp * 0.5), -alt - par_h * 0.5), Vector2(esp, par_h))
	_solido(torre, Vector2(0.0, -alt - par_h - esp * 0.5), Vector2(larg, esp))

	# Desenho das paredes/teto (a colisão acima é invisível).
	for lado3 in [-1.0, 1.0]:
		var pr := ColorRect.new()
		pr.color = Color(0.31, 0.30, 0.35)
		pr.size = Vector2(esp, par_h)
		pr.position = Vector2(lado3 * (larg * 0.5) - (0.0 if lado3 < 0.0 else esp), -alt - par_h)
		torre.add_child(pr)
	var teto := ColorRect.new()
	teto.color = Color(0.25, 0.24, 0.29)
	teto.size = Vector2(larg, esp)
	teto.position = Vector2(-larg * 0.5, -alt - par_h - esp)
	torre.add_child(teto)

	var esc := LadderView.new()
	_env.add_child(esc)
	esc.setup(lx, GROUND_Y, alt, _player_view)
	_ladders.append(esc)
	if is_instance_valid(_player_view):
		_player_view.ladders = _ladders
	return topo_y

## Necromante: estático no fim da sala (extremo direito), rastreado em _necro.
func _spawn_necromancer(id: String) -> void:
	if id == "":
		return
	var base := _enemy_repo.get_by_id(id)
	if base.is_empty():
		return
	var enemy := EnemyFactory.build(base)
	var view := NecromancerView.new()
	view.set_meta("tier", "elite")
	view.dormant = true               # também espera: só começa a lançar quando o jogador se aproxima
	_alive["elite"] += 1
	_necro = view
	# Se o nível declara torre, ele nasce EM CIMA dela; senão, no chão como antes.
	var torre: Dictionary = _room.get("tower", {})
	var topo := _spawn_necro_tower(torre)
	var nx := float(torre.get("at", _fight_width - 198.0)) if not torre.is_empty() else _fight_width - 198.0
	var ny := (topo - 40.0) if topo != 0.0 else (GROUND_Y - 40.0)
	_add_view(view, enemy, Vector2(nx, ny))

## Heavies a<b<c EM ORDEM de proximidade, nas posições fixas do nível, dormentes.
## Acordam em cadeia — ver _update_heavy_chain.
func _spawn_l1_heavies() -> void:
	var spec: Dictionary = _room.get("heavies", {})
	var ids: Array = spec.get("ids", [])
	if ids.is_empty():
		return
	var pos := _spawn_positions(spec, true)
	for i in pos.size():
		var x := float(pos[i])
		var v := _spawn_room_enemy("heavy", String(ids[i % ids.size()]), Vector2(x, GROUND_Y - 40.0))
		_heavy_stage.append({ "view": v, "spawn_x": x, "activated": false, "dead": false })

## Demais níveis: heavies sem encadeamento, nas posições fixas que o nível declarar.
func _spawn_heavies_simple() -> void:
	var spec: Dictionary = _room.get("heavies", {})
	var ids: Array = spec.get("ids", [])
	if ids.is_empty():
		return
	var pos := _spawn_positions(spec, true)
	for i in pos.size():
		_spawn_room_enemy("heavy", String(ids[i % ids.size()]), Vector2(float(pos[i]), GROUND_Y - 40.0))

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
			_mark_heavy_dead(view)            # destrava o próximo heavy da cadeia
		"minion", "normal":
			_first_kill_done = true           # 1º esqueleto da horda → gatilho do heavy 'a'
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

## Desperta os esqueletos comuns (minion/normal) DORMENTES da sala por proximidade — o mesmo
## comportamento da guarda do refúgio. Os heavies têm a cadeia própria (_update_heavy_chain) e o
## Necromante é estático, então ambos ficam de fora daqui.
func _update_room_wake() -> void:
	if not is_instance_valid(_player_view):
		return
	var ppos := _player_view.global_position
	for v in _enemies:
		if not is_instance_valid(v) or not v.dormant:
			continue
		if _guard.has(v):
			continue          # a guarda do refúgio tem o passe dela (_update_guard_wake)
		# Distância EUCLIDIANA, não só o x: numa escadaria um esqueleto dois andares acima está
		# longe de verdade — medir só o x o acordaria quando o player passasse lá embaixo, e ele
		# ficaria marchando na borda da plataforma dele. No chão plano (y igual) nada muda.
		if ppos.distance_to(v.global_position) <= v.aggro_range:
			v.dormant = false

# --- A REMONTAGEM (esqueletos sob o Necromante) ---
# Enquanto ele vive, esqueleto nenhum morre: zerou a vida, DESABA em ossos ali mesmo e se remonta
# inteiro alguns segundos depois (EnemyView._collapse/_rise, tempo em room.reassemble_time). Não
# adianta limpar a sala — ela se refaz. Matar o Necromante é a única saída, e aí todos caem juntos.

func _has_necro() -> bool:
	return is_instance_valid(_necro)

## Necromante caiu → todos os esqueletos morrem. Libera o resto da sala.
func _kill_all_skeletons() -> void:
	# Sem quem os remonte, os ossos param de se levantar — os de pé e os caídos caem juntos.
	for v in _enemies.duplicate():
		if is_instance_valid(v):
			v.queue_free()
	_enemies.clear()
	for c in get_children():
		if c is NecroProjectile:
			c.queue_free()
	_alive = { "minion": 0, "normal": 0, "heavy": 0, "elite": 0 }

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

func _process(delta: float) -> void:
	# Parallax do fundo segue a câmera (todo frame, em qualquer fase).
	# get_screen_center_position() = centro da VISTA de fato, com os limit_* já aplicados.
	# global_position NÃO é travado pelos limites (só a vista é): usá-lo faria o fundo rolar
	# nas bordas do nível enquanto o mundo está parado, dessincronizando o parallax.
	if _bg != null and _camera != null:
		_bg.update_scroll(_camera.get_screen_center_position().x)

	_update_boss_bar()

	# Dica do tutorial: conta o tempo na tela e some sozinha ao zerar (E também fecha — _unhandled_input).
	if _tip_time > 0.0:
		_tip_time -= delta
		if _tip_time <= 0.0:
			_hide_tip()

	# Sequência de falas do Sir Big T.: avança sozinha pelo tempo (pausada enquanto o card está aberto).
	if _knight_seq and not _knight_card_open:
		_knight_timer -= delta
		if _knight_timer <= 0.0:
			_knight_avancar()

	# Sala: os heavies seguem a cadeia de posição; os esqueletos comuns dormentes acordam por proximidade.
	if _phase == "room":
		_update_heavy_chain()
		_update_room_wake()

	# Nível vencido: a guarda do refúgio desperta por proximidade; numa ARENA vencida, as duas
	# portas (voltar/seguir) cruzam andando.
	if _phase == "cleared":
		_update_guard_wake()
		# Vencido não é vazio: os inimigos renascidos pela fogueira também nascem dormentes e
		# precisam do mesmo despertar por proximidade, senão ficariam parados para sempre.
		_update_room_wake()
		if String(_floor_config.get("type", "")) == "boss":
			_update_boss_doors()
		else:
			_update_exit_door()

	# A marca de sangue (quando presente, em QUALQUER fase — inclusive na arena do chefe): recolhe
	# automático ao passar por cima dela, como no Dark Souls (sem tecla).
	_update_bloodstain()


	# Vila de tutorial: as dicas surgem conforme o player anda; chegar na porta entra na dungeon.
	if _phase == "tutorial":
		_update_tutorial_tips()
		if is_instance_valid(_player_view) and is_instance_valid(_door) \
				and absf(_player_view.global_position.x - _door_x) <= DOOR_REACH:
			_transition(_begin_dungeon)
		return

	# Downtown: a porta depois do portão grande entra na torre. O portão fechado é sólido, então
	# alcançá-la já significa que a alavanca foi puxada.
	if _phase == "downtown":
		if is_instance_valid(_player_view) and is_instance_valid(_door) \
				and absf(_player_view.global_position.x - _door_x) <= DOOR_REACH:
			_transition(_begin_tower)
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
	_msg.text = "%s: algo desperta na escuridão..." % _level_name()
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

## Nome de exibição do nível atual (levels.json → "name"). Substituiu o "Nível %d / %d": num
## grafo não há numeração nem total, o lugar tem nome.
func _level_name() -> String:
	var n := String(_floor_config.get("name", ""))
	return n if n != "" else _run.current_level

func _boss_title(boss_name: String) -> String:
	return "%s   CHEFE: %s" % [_level_name(), boss_name]

## Cria o boss do nível em `at`. Quem chama decide se ele já age (a cutscene o deixa dormente).
## Também resolve o eco do Nemesis, que o próprio boss invoca ao cruzar o limiar de HP.
func _spawn_boss(at: Vector2) -> void:
	var floor := _run.current_level
	var base := _boss_repo.get_by_id(_current_boss_id)
	if base.is_empty():
		push_warning("[floor_scene] boss '%s' não encontrado no andar %d" % [_current_boss_id, floor])
		return
	var boss := EnemyFactory.build_boss(base)

	# O chefe NÃO invoca nada: a morte deixa uma marca de sangue passiva no ponto exato da queda
	# (inclusive aqui na arena), que se recolhe ao tocar — ver _spawn_bloodstain_if_here.
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
	_guard.erase(view)   # se era da guarda, sai da lista (matou-se um esqueleto do run-back)
	_marcar_se_esvaziou()

	# Almas: TODO inimigo morto entrega as suas, direto para o bolso — inclusive os esqueletos que
	# o Necromante reinvoca sem parar. Antes esses não davam XP, para não virar farm infinito de
	# poder; agora o farm se paga sozinho, porque alma no bolso é RISCO: ela só vira poder depois
	# de gasta na fogueira, e morrer com o bolso cheio entrega tudo ao Eco.
	_run.player.gain_souls(int(enemy.loot.get("souls", 0)))

	match _phase:
		"room":
			_on_room_enemy_died(view)
		"boss":
			if view == _boss_view:
				_on_floor_cleared()

func _on_floor_cleared() -> void:
	# Roguelite: nada de mark_cleared (o mesmo id pode voltar como outro nó de combate), nada de
	# alavanca/guarda. Boss morto → dissipa as névoas e libera a porta de avanço; sala limpa → porta.
	if _roguelite:
		_phase = "cleared"
		if String(_floor_config.get("type", "")) == "boss":
			Music.stop()
			_dismiss_boss_fogs()
			_show_tip("O guardião caiu. Avance →")
		else:
			_rl_spawn_advance_door()
		return
	_run.mark_cleared(_run.current_level)   # morrer adiante e voltar por aqui não o repovoa
	if _phase == "boss":
		# Chefe vencido: a trilha se despede (fade do audio.json) e as DUAS névoas da arena se
		# desmancham — voltar e seguir ficam livres (a porta da direita leva à área nova).
		Music.stop()
		_phase = "cleared"
		_dismiss_boss_fogs()
		_show_tip("O guardião caiu. As névoas se dissipam e as portas se abrem")
		_msg.text = "As portas da arena estão abertas"
		return
	# Nível de sala limpo (o Necromante caiu): a ALAVANCA (que já estava lá, travada) DESTRAVA. Puxá-la
	# abre o portão de madeira que fecha o refúgio — e, aberto, ele fica aberto para sempre. Nada de
	# porta com fade: o jogador anda daqui até a fogueira e a névoa do chefe pelo mesmo corredor.
	_phase = "cleared"
	if is_instance_valid(_lever):
		_lever.arm()
	_spawn_guard()   # o mundo reocupa o caminho ao chefe: a guarda toma o refúgio
	_msg.text = "Sala limpa. Puxe a alavanca (E) para abrir o portão →"

## As duas portas da arena do chefe: atrás (à esquerda, volta ao nível anterior) e adiante (à
## direita, o próximo nível — a área nova, com a outra fogueira). Enquanto o chefe vive, cada uma
## nasce coberta por uma névoa TRAVADA (bloqueio visual, sem convite — as paredes da arena já
## seguram o player); vencê-lo as dissipa (_dismiss_boss_fogs) e as portas passam a cruzar
## andando, como a da vila (_update_boss_doors). Uma porta só existe se o nível dela existe.
func _spawn_boss_doors(cleared: bool) -> void:
	_boss_fogs.clear()
	_boss_door_left_x = 0.0
	_boss_door_right_x = 0.0
	var portas: Array = []
	# Roguelite não tem porta de trás: a run só avança. A da frente sempre existe (leva ao avanço).
	if _has_exit("tras") and not _roguelite:
		_boss_door_left_x = BOSS_DOOR_IN
		portas.append(_boss_door_left_x)
	if _roguelite or _has_exit("frente"):
		_boss_door_right_x = _arena_width - BOSS_DOOR_IN
		portas.append(_boss_door_right_x)
	for x in portas:
		_spawn_door(x, Palette.ACCENT.darkened(0.35))
		if not cleared:
			var fog := FogGateView.new()
			fog.locked = true              # sem prompt: durante a luta ela é só bloqueio
			fog.position = Vector2(x, GROUND_Y)
			_env.add_child(fog)
			fog.setup(x, _player_view)
			# Discreta DURANTE a luta: atrás das entidades (a névoa de travessia fica à frente,
			# z=60, mas aqui ela cobriria o combate) e meio translúcida — presença de cenário,
			# não de cortina. A dissipação da vitória parte deste alfa.
			fog.z_index = -2
			fog.modulate.a = 0.5
			_boss_fogs.append(fog)

## Vencido o chefe, as névoas das portas se desmancham num fade e somem de vez.
func _dismiss_boss_fogs() -> void:
	for fog in _boss_fogs:
		if is_instance_valid(fog):
			var tw := create_tween()
			tw.tween_property(fog, "modulate:a", 0.0, 1.4)
			tw.tween_callback(fog.queue_free)
	_boss_fogs.clear()

## Arena vencida: cruzar uma porta ANDANDO (como a da vila). A esquerda volta ao nível anterior
## (entrando por ele pela direita); a direita segue ao próximo. Só roda na fase "cleared" de uma
## arena — a _transition trava re-disparo mudando a fase.
func _update_boss_doors() -> void:
	if not is_instance_valid(_player_view):
		return
	var px := _player_view.global_position.x
	# Roguelite: só a porta da frente, e ela AVANÇA O PLANO (o boss é o último nó → vitória).
	if _roguelite:
		if _boss_door_right_x > 0.0 and absf(px - _boss_door_right_x) <= DOOR_REACH:
			_transition(_advance_plan)
		return
	if _boss_door_left_x > 0.0 and absf(px - _boss_door_left_x) <= DOOR_REACH:
		_transition(_prev_floor)
	elif _boss_door_right_x > 0.0 and absf(px - _boss_door_right_x) <= DOOR_REACH:
		_transition(_next_floor)

## A porta no fim de um nível de sala/descanso (toda saída que NÃO seja o selo de uma arena de
## chefe — ver _spawn_exit_passage): cruza andando, como as portas da arena e a da Cidade. Só
## responde na fase "cleared", senão daria para sair sem resolver a sala. A _transition trava
## o re-disparo.
func _update_exit_door() -> void:
	if _exit_door_x <= 0.0 or _phase != "cleared" or not is_instance_valid(_player_view):
		return
	if absf(_player_view.global_position.x - _exit_door_x) > DOOR_REACH:
		return
	# Saída fora do chão (o topo de uma escadaria): também exige estar NA ALTURA dela — sem isso,
	# passar no chão sob a porta do último andar já cruzaria o nível inteiro de graça.
	if _exit_door_vertical and absf(_player_view.global_position.y - _exit_door_y) > CLIMB_DOOR_TOL:
		return
	if _roguelite:
		_transition(_advance_plan)   # a porta de avanço resolve o nó
	else:
		_transition(_next_floor)

## A ÁREA DE DESCANSO (nível "rest"): só a fogueira, perto da entrada, e a névoa no fim. Nada de
## alavanca, portão ou guarda — aqui não há o que vencer, e por isso nada tranca a fogueira.
func _spawn_rest_area(level_id: String) -> void:
	_bonfires.clear()
	_lever = null      # nada de mecanismo neste nível (as views antigas morreram com o _env)
	_gate = null

	var bf_x := PLAYER_START_X + 70.0
	var bf := BonfireView.new()
	bf.position = Vector2(bf_x, GROUND_Y)
	_env.add_child(bf)
	bf.setup(bf_x, _run.is_lit(level_id, bf_x), _player_view)
	bf.rested.connect(_on_bonfire_rested)
	_bonfires.append(bf)

	_spawn_exit_passage(level_id)

## A saída no extremo do nível. A NÉVOA é o selo de uma arena de chefe e nada mais: ela existe
## só quando o que vem adiante é um nível "boss" ainda vivo. Névoa em passagem comum diluía o
## sinal — se toda porta é névoa, a névoa deixa de anunciar que há um chefe do outro lado.
## Qualquer outra saída (nível comum adiante, ou chefe já vencido) é porta, cruzada andando.
func _spawn_exit_passage(_level_id: String) -> void:
	var fog_x := _arena_width - FOG_BACK
	var adiante := _exit("frente")
	var alvo := String(adiante["level"]) if not adiante.is_empty() else ""
	if alvo == "":
		return               # fim do conteúdo: o nível simplesmente acaba, sem porta para lugar nenhum
	if _is_boss_level(alvo) and not _run.is_cleared(alvo):
		_fog = FogGateView.new()
		_fog.position = Vector2(fog_x, GROUND_Y)
		_env.add_child(_fog)
		_fog.setup(fog_x, _player_view)
		return
	_spawn_door(fog_x, Palette.ACCENT.darkened(0.35))
	_exit_door_x = fog_x

## Id estável do portão de mecanismo de um nível (persistido no RunState). Um por nível de sala.
func _gate_id(level_id: String) -> String:
	return "gate_%s" % level_id

## Um bloco sólido na camada 4 (a mesma do chão), filho de `pai`, sem desenho. Serve às lajes do
## tabuleiro, às paredes e ao teto da câmara.
func _solido(pai: Node2D, centro: Vector2, tam: Vector2, sentido_unico := false) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 4
	b.collision_mask = 0
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tam
	c.shape = r
	c.position = centro
	c.one_way_collision = sentido_unico   # sólido por cima, atravessável por baixo
	b.add_child(c)
	pai.add_child(b)

## A boca do ATALHO deste nível (levels.json → "shortcut"), em x ABSOLUTO — ela pode estar na
## entrada tanto quanto no fim do refúgio, e as duas pontas de um mesmo atalho são justamente
## isso: dois níveis declarando o mesmo id, cada um apontando para onde o outro está.
func _spawn_shortcut(_level_id: String) -> void:
	var sc: Dictionary = _floor_config.get("shortcut", {})
	if sc.is_empty():
		return
	_shortcut_id = String(sc.get("id", ""))
	_shortcut_unlocks = bool(sc.get("unlocks", false))
	_shortcut_to = sc.get("to", {})
	_shortcut_x = float(sc.get("at", 0.0))
	_shortcut = ShortcutView.new()
	_shortcut.position = Vector2(_shortcut_x, GROUND_Y)
	_env.add_child(_shortcut)
	_shortcut.setup(_shortcut_x, _player_view, _run.is_gate_open(_shortcut_id), _shortcut_unlocks,
		bool(sc.get("oculto_travado", false)))

## A ENTRADA de um nível de sala (levels.json → "entrance"): o que existe ANTES da zona de
## combate. É onde mora a fogueira do Portão — a primeira do jogo, e por isso onde nasce a lição
## do frasco — dita pelo Sir Big T., que nasce ao lado dela. Logo depois dela pode vir
## um portão GRANDE com alavanca: ele não tranca uma recompensa como o do refúgio, ele marca a
## saída de um lugar, então nasce destravado — puxar é um gesto de partida, não um prêmio.
func _spawn_entrance(level_id: String) -> void:
	var ent: Dictionary = _floor_config.get("entrance", {})
	if ent.is_empty():
		return

	if ent.has("bonfire_at"):
		var bx := float(ent["bonfire_at"])
		var bf := BonfireView.new()
		bf.position = Vector2(bx, GROUND_Y)
		_env.add_child(bf)
		bf.setup(bx, _run.is_lit(level_id, bx), _player_view)
		bf.rested.connect(_on_bonfire_rested)
		_bonfires.append(bf)

		# O Sir Big T., à ESQUERDA da fogueira (ela fica à direita dele). Ele SOME quando o atalho
		# deste nível é aberto: a boca do poço estava escondida SOB ele o tempo todo, e abri-la
		# (pela outra ponta, no Cemitério) o dispensa — você desce e chega onde ele estava.
		var sc_id := String(_floor_config.get("shortcut", {}).get("id", ""))
		if sc_id == "" or not _run.is_gate_open(sc_id):
			var nx := bx - float(ent.get("npc_offset", 56.0))
			_npc = NpcView.new()
			_env.add_child(_npc)
			_npc.setup(nx, GROUND_Y, _player_view, "Sir Big T.")
			_npc.falado.connect(_on_npc_falado)

	var g: Dictionary = ent.get("gate", {})
	if g.is_empty():
		return
	_gate_key = String(g.get("id", _gate_id(level_id)))
	var aberto := _run.is_gate_open(_gate_key)
	var gx := float(g.get("at", 300.0))

	_gate = GateView.new()
	_gate.position = Vector2(gx, GROUND_Y)
	_env.add_child(_gate)
	_gate.setup(gx, aberto, float(g.get("w", 52.0)), float(g.get("h", 140.0)))

	var lx := gx - float(g.get("lever_back", 46.0))
	_lever = LeverView.new()
	_lever.position = Vector2(lx, GROUND_Y)
	_env.add_child(_lever)
	_lever.setup(lx, _player_view, aberto, true)   # destravado desde o começo: é uma saída, não um prêmio
	_lever.pulled.connect(_on_lever_pulled)

## O REFÚGIO ao fim de um nível de sala, contínuo com a zona de combate (sem fade): a alavanca (no
## fim do combate), o portão de madeira, a fogueira mais adiante e a névoa do chefe no extremo. O
## portão barra a passagem até a alavanca ser puxada; aberto, fica aberto para sempre.
func _spawn_sanctuary(level_id: String) -> void:
	_bonfires.clear()

	# O portão de madeira (e a alavanca que o abre) é OPCIONAL, por nível: levels.json → "gate".
	# Sem ele, a fogueira não fica trancada atrás da luta — o jogador pode alcançá-la antes de
	# limpar a sala, que é o comportamento soulslike normal. Só faz sentido onde trancar a
	# passagem É o desenho do nível.
	_lever = null
	_gate = null
	if bool(_floor_config.get("gate", false)):
		_gate_key = _gate_id(level_id)
		# A alavanca fica SEMPRE no lugar, já durante a luta — mas só destravada (puxável) quando
		# o nível está vencido. Se o portão já foi aberto nesta run, ela nasce puxada.
		var gate_open := _run.is_gate_open(_gate_id(level_id))
		var lx := _fight_width - LEVER_BACK
		_lever = LeverView.new()
		_lever.position = Vector2(lx, GROUND_Y)
		_env.add_child(_lever)
		_lever.setup(lx, _player_view, gate_open, _run.is_cleared(level_id))
		_lever.pulled.connect(_on_lever_pulled)

		var gate_x := _fight_width
		_gate = GateView.new()
		_gate.position = Vector2(gate_x, GROUND_Y)
		_env.add_child(_gate)
		_gate.setup(gate_x, gate_open)

	# A fogueira do refúgio é OPCIONAL (levels.json → "sanctuary_bonfire", padrão true): um nível
	# cuja fogueira fica na ENTRADA não quer uma segunda no fim.
	if bool(_floor_config.get("sanctuary_bonfire", true)):
		var bf_x := _fight_width + BONFIRE_IN
		var bf := BonfireView.new()
		bf.position = Vector2(bf_x, GROUND_Y)
		_env.add_child(bf)
		bf.setup(bf_x, _run.is_lit(level_id, bf_x), _player_view)
		bf.rested.connect(_on_bonfire_rested)
		_bonfires.append(bf)

	# A saída do refúgio, no extremo (encostada na parede do fim): a névoa do chefe — ou uma porta
	# livre, se o chefe adiante já caiu (_spawn_exit_passage).
	_spawn_exit_passage(level_id)

## Alavanca puxada: abre o portão (na hora, com animação) e persiste isso na run — o atalho fica
## aberto para sempre, inclusive depois de morrer e voltar.
func _on_lever_pulled(_l: LeverView) -> void:
	_run.open_gate(_gate_key)
	if is_instance_valid(_gate):
		_gate.open()
	if _phase == "downtown":
		_show_tip("O portão se abre. A torre o aguarda →")

# ---------------------------------------------------------------------------
# A GUARDA do refúgio (o run-back do soulslike). Depois que o nível é vencido, uma pequena leva de
# esqueletos reocupa o trecho entre a fogueira e a névoa do chefe. Descansar na fogueira os RENASCE
# (ver _reset_guard), então voltar ao chefe custa a mesma corrida a cada morte — é o que dá sentido
# à fogueira "renascer inimigos". Nascem DORMENTES e despertam por proximidade (_update_guard_wake),
# para não marcharem até o portão ainda fechado no instante em que o Necromante cai.
# ---------------------------------------------------------------------------

## Faixa (x_min, x_max) onde a guarda se posta: entre a fogueira e a névoa, com folga dos dois.
## A faixa da guarda, por GEOMETRIA (não pela fogueira em si): vale mesmo num nível que não tem
## fogueira no refúgio — o ponto de referência é onde ela ficaria.
func _guard_zone() -> Vector2:
	var bf_x := _fight_width + BONFIRE_IN
	var fog_x := _arena_width - FOG_BACK
	return Vector2(bf_x + GUARD_AFTER_BONFIRE, fog_x - GUARD_BEFORE_FOG)

## (Re)cria a guarda a partir de floor_config["guard"] = { ids, count }. Espalha os esqueletos pela
## faixa do refúgio, todos dormentes. Sem "guard" no nível (ex.: arena de chefe), não faz nada.
func _spawn_guard() -> void:
	_clear_guard()
	var spec: Dictionary = _floor_config.get("guard", {})
	var ids: Array = spec.get("ids", [])
	var n := int(spec.get("count", 0))
	if ids.is_empty() or n <= 0:
		return
	var zone := _guard_zone()
	var band := (zone.y - zone.x) / maxf(1.0, float(n))
	for i in n:
		var base := _enemy_repo.get_by_id(String(ids[i % ids.size()]))
		if base.is_empty():
			continue
		var enemy := EnemyFactory.build(base)
		var view := EnemyView.new()
		view.set_meta("tier", "guard")
		view.dormant = true                    # imóvel até o player chegar perto (_update_guard_wake)
		# A guarda é posicionada por geometria, não autorada — então ela é justamente quem mais
		# escorrega para dentro da bolha do atalho, que fica no mesmo refúgio.
		var x := _afasta_do_atalho(zone.x + band * (float(i) + 0.5), _aggro_de(String(ids[i % ids.size()])))
		_add_view(view, enemy, Vector2(x, GROUND_Y - 40.0))
		_guard.append(view)

## Remove as views da guarda atual (ao remontar o nível e ao renascê-la na fogueira). As views vivem
## em _enemies (via _add_view): tira de lá também, senão o _clear_entities seguinte mexeria em nós já
## liberados.
func _clear_guard() -> void:
	for v in _guard.duplicate():
		if is_instance_valid(v):
			_enemies.erase(v)
			if v.get_parent() != null:
				v.get_parent().remove_child(v)
			v.queue_free()
	_guard.clear()

## Descansar na fogueira RENASCE a guarda: os que você matou voltam e os vivos recuam ao posto,
## dormentes. Só faz sentido com o nível vencido (a fogueira só se alcança com o portão aberto).
func _reset_guard() -> void:
	if _phase != "cleared":
		return
	_spawn_guard()

## Desperta a guarda por proximidade: um esqueleto dormente ganha vida quando o player chega a
## aggro_range dele. Comportamento soulslike — esperam imóveis e acordam quando você se aproxima.
func _update_guard_wake() -> void:
	if _guard.is_empty() or not is_instance_valid(_player_view):
		return
	var px := _player_view.global_position.x
	for v in _guard:
		if is_instance_valid(v) and v.dormant and absf(px - v.global_position.x) <= v.aggro_range:
			v.dormant = false

# ---------------------------------------------------------------------------
# Navegação pelo GRAFO. Um nível não sabe "qual é o próximo": sabe quais SAÍDAS tem e para onde
# cada uma leva (levels.json → "exits"). Toda travessia passa por aqui, o que torna impossível
# reintroduzir aritmética de andar sem que se veja.
# ---------------------------------------------------------------------------

## Resolve uma saída do nível ATUAL. Devolve {} se ela não existir (o que é a maneira normal de
## dizer "não há caminho por aqui" — a névoa do fim do conteúdo, um beco). O destino aceita as
## duas formas do JSON: o id cru ("bosque_ogro") ou { level, entry }.
func _exit(nome: String) -> Dictionary:
	var alvo: Variant = _floor_config.get("exits", {}).get(nome, null)
	if typeof(alvo) == TYPE_STRING and String(alvo) != "":
		return { "level": String(alvo), "entry": "inicio" }
	if typeof(alvo) == TYPE_DICTIONARY:
		var d: Dictionary = alvo
		var lid := String(d.get("level", ""))
		if lid != "":
			return { "level": lid, "entry": String(d.get("entry", "inicio")) }
	return {}

## A saída existe E o nível de destino está descrito no mapa? É o teste que decide se uma porta
## nasce, se a névoa deixa passar e se a arena ganha porta de trás.
func _has_exit(nome: String) -> bool:
	var e := _exit(nome)
	return not e.is_empty() and _levels.has(e["level"])

## Atravessa uma saída. Nenhuma travessia cura: a vida só volta na fogueira e no frasco.
func _go_through(nome: String) -> void:
	var e := _exit(nome)
	if e.is_empty():
		return
	_entry_point = String(e.get("entry", "inicio"))
	_run.go_to(String(e["level"]))
	_start_floor()

func _next_floor() -> void:
	_go_through("frente")

func _prev_floor() -> void:
	_go_through("tras")

# ---------------------------------------------------------------------------
# PIVÔ roguelite: a run como sequência de nós. O RunPlan diz o que vem; _enter_node monta a tela
# certa para cada tipo, e _advance_plan é chamado quando o nó atual se resolve (sala limpa e porta
# de avanço cruzada, carta escolhida, boss morto). Fim do plano = vitória.
# ---------------------------------------------------------------------------

## Monta a tela do nó dado. null = a run chegou ao fim viva → vitória.
func _enter_node(node: RunNode) -> void:
	if node == null:
		_win_run()
		return
	if node.is_combat():
		_run.go_to(String(node.get_value("encounter", "")))
		_start_floor()
	elif node.is_boss():
		# Torre: cada boss numa ARENA GENÉRICA (levels.json → "arena"); o id do boss vem do nó, não
		# do nível. _start_floor lê _rl_boss_id no modo roguelite.
		_rl_boss_id = String(node.get_value("boss", ""))
		_rl_floor += 1
		_run.go_to("arena")
		_start_floor()
		# O total de andares vem do PLANO (quantos nós BOSS há), nunca de um número fixo — mudar o
		# pattern no run.json muda o letreiro sozinho.
		_show_tip("Andar %d de %d" % [_rl_floor, _rl_total_floors()])
	elif node.type == RunNode.CLIMB:
		# A escadaria entre bosses: um nível "climb" do levels.json, sorteado do pool.
		_run.go_to(String(node.get_value("climb", "")))
		_start_floor()
	elif node.type == RunNode.REWARD:
		_open_reward(int(node.get_value("cards", 3)))
	else:
		# Tipos ainda não implementados (loja, ferreiro, descanso, evento): por ora, pula.
		_advance_plan()

## Avança o cursor e entra no próximo nó (ou vence, se acabou). Chamado sob a tela preta de
## uma _transition, ou direto ao escolher a carta.
func _advance_plan() -> void:
	_enter_node(_plan.advance())

## Quantos andares (nós BOSS) a torre tem, contado do próprio plano.
func _rl_total_floors() -> int:
	var n := 0
	for node in _plan.nodes:
		if node.is_boss():
			n += 1
	return n

## Nó de recompensa: mostra as cartas de augment (o mesmo pool ponderado de sempre) e espera a
## escolha. Sem cartas disponíveis (pool esgotado), pula para o próximo nó.
func _open_reward(n: int) -> void:
	var cards := _run.offer_augments(n)
	if cards.is_empty():
		_advance_plan()
		return
	_phase = "reward"
	if is_instance_valid(_player_view):
		_player_view.frozen = true
	_reward_layer = CanvasLayer.new()
	_reward_layer.layer = 80
	add_child(_reward_layer)
	var cs := CardSelect.new()
	# setup ANTES de add_child: o _ready do CardSelect constrói os painéis a partir de _cards, e
	# add_child o dispara na hora — na ordem invertida a tela nascia só com o título, sem carta
	# nenhuma, e o jogador ficava preso na recompensa vazia.
	cs.setup(cards)
	cs.chosen.connect(_on_reward_chosen)
	_reward_layer.add_child(cs)

func _on_reward_chosen(aug: Augment) -> void:
	_run.choose_augment(aug)
	if is_instance_valid(_reward_layer):
		_reward_layer.queue_free()
		_reward_layer = null
	if is_instance_valid(_player_view):
		_player_view.frozen = false
	_transition(_advance_plan)

## Sala de combate enxuta do roguelite: só a zona de combate + uma folga curta para a porta de
## avanço (nasce ao limpar, em _on_floor_cleared). Sem refúgio/entrada/atalho/fogueira.
func _rl_start_room(floor: String, hazards: Array) -> void:
	Music.stop()
	_current_boss_id = ""
	_boss_view = null
	_exit_door_x = 0.0
	_corridor_length = float(_floor_config.get("corridor_length", _corridor_length))
	_build_environment(_corridor_length + RL_ROOM_TAIL, false, hazards)
	_fight_width = _corridor_length
	_reset_player_to_start(PLAYER_START_X)
	_spawn_hazards(hazards)
	_phase = "room"
	_start_room()

# ---------------------------------------------------------------------------
# A ESCADARIA (nível "climb") — a seção vertical entre salas de boss. Andares de plataformas de
# sentido único ligados por escadas em zigue-zague (110px por andar > o pulo de 76px: a escada é
# obrigatória), com os inimigos normais postados nelas, dormentes. É TRAVESSIA, não sala a limpar:
# a fase já nasce "cleared" e a porta no último andar responde desde o início — dá para passar
# correndo, e matar é opcional (paga almas, como tudo). A câmera abre o teto e sobe junto
# (GameCamera.setup_climb).
# ---------------------------------------------------------------------------

const CLIMB_SLAB := 12.0        # espessura da laje de um andar
const CLIMB_DOOR_TOL := 60.0    # tolerância vertical para cruzar a porta do topo

func _start_climb() -> void:
	Music.stop()
	_current_boss_id = ""
	_boss_view = null
	var w := float(_floor_config.get("width", 640.0))
	_build_environment(w, false, [])
	_reset_player_to_start(PLAYER_START_X)

	var andares: Array = _floor_config.get("andares", [])
	var superficie_anterior := GROUND_Y     # de onde a escada deste andar parte (chão, depois cada laje)
	for a in andares:
		var alt := float(a.get("y", 0.0))
		var surf := GROUND_Y - alt          # a superfície DESTE andar (y do mundo)
		var px := float(a.get("x", 0.0))
		var pw := float(a.get("w", 300.0))

		# A laje: sentido único (sobe-se ATRAVÉS dela pela escada; pousa-se por cima) + o desenho.
		_solido(_env, Vector2(px + pw * 0.5, surf + CLIMB_SLAB * 0.5), Vector2(pw, CLIMB_SLAB), true)
		var laje := ColorRect.new()
		laje.color = Color(0.30, 0.29, 0.34)
		laje.position = Vector2(px, surf)
		laje.size = Vector2(pw, CLIMB_SLAB)
		laje.z_index = DECO_Z + 1
		_env.add_child(laje)
		var borda := ColorRect.new()
		borda.color = Color(0.40, 0.39, 0.45)
		borda.position = Vector2(px, surf)
		borda.size = Vector2(pw, 2.0)
		borda.z_index = DECO_Z + 1
		_env.add_child(borda)

		# A escada que SOBE até este andar, partindo da superfície anterior.
		var ex := float(a.get("escada_x", px + 40.0))
		var esc := LadderView.new()
		_env.add_child(esc)
		esc.setup(ex, superficie_anterior, superficie_anterior - surf, _player_view)
		_ladders.append(esc)

		# Os inimigos do andar, nas posições fixas, dormentes (o padrão de _add_view/dormant).
		for spec in a.get("inimigos", []):
			_spawn_climb_enemy(String(spec.get("id", "")), Vector2(float(spec.get("em", px + pw * 0.5)), surf - 40.0))
		superficie_anterior = surf

	# Os inimigos do chão (antes da primeira escada).
	for spec in _floor_config.get("chao", []):
		_spawn_climb_enemy(String(spec.get("id", "")), Vector2(float(spec.get("em", 300.0)), GROUND_Y - 40.0))

	if is_instance_valid(_player_view):
		_player_view.ladders = _ladders

	# A porta de avanço, no ÚLTIMO andar. _update_exit_door também confere o Y (senão passar no
	# chão sob ela cruzaria o nível). Sem andares (config vazio), a porta cai no chão, no extremo.
	var saida_x := float(_floor_config.get("saida_x", w - 60.0))
	var saida_y := superficie_anterior
	_spawn_door(saida_x, Palette.ACCENT.darkened(0.35), saida_y)
	_exit_door_x = saida_x
	_exit_door_y = saida_y
	_exit_door_vertical = true

	# A câmera abre o teto: do topo da escadaria ainda se vê a porta e um respiro acima dela.
	_camera.setup_climb(w, superficie_anterior - 150.0)

	_phase = "cleared"        # travessia: a porta já responde; os inimigos são o pedágio opcional
	_show_tip("A escadaria sobe. O próximo guardião espera no alto")

## Um inimigo da escadaria: normal, dormente, fora da contagem de sala (a escadaria não se
## "limpa" — matar é opcional). Vive em _enemies como todos, então _clear_entities o varre.
func _spawn_climb_enemy(id: String, pos: Vector2) -> void:
	if id == "":
		return
	var base := _enemy_repo.get_by_id(id)
	if base.is_empty():
		return
	var enemy := EnemyFactory.build(base)
	var view := EnemyView.new()
	view.set_meta("tier", "climb")
	view.dormant = true
	_add_view(view, enemy, pos)

## Porta de avanço no fim da sala limpa: cruzá-la (andando) resolve o nó e chama _advance_plan.
func _rl_spawn_advance_door() -> void:
	var x := _corridor_length + RL_ROOM_TAIL * 0.5
	_spawn_door(x, Palette.ACCENT.darkened(0.35))
	_exit_door_x = x
	_show_tip("Sala limpa. Avance →")

## Fim da run — por morte ou vitória. Nada de tela de fim com Enter: o letreiro sobe com o fade,
## e o jogador DESPERTA NO DOWNTOWN, ao pé da fogueira, com as almas no bolso (são a meta-moeda) e
## sem os augments (a build era da run). O mundo se refaz sob o preto, como a morte soulslike fazia.
func _finish_run(victory: bool) -> void:
	if _phase == "dead":
		return
	_phase = "dead"
	_intro_token += 1              # mata qualquer cutscene de boss ainda no ar
	Music.stop(1.5)
	if is_instance_valid(_player_view):
		_player_view.frozen = true
	if victory:
		_show_run_banner("VITÓRIA", Palette.ACCENT)
	else:
		_show_run_banner("VOCÊ MORREU", Palette.ENEMY)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, DEATH_FADE_OUT)
	tw.tween_interval(DEATH_HOLD)
	tw.tween_callback(_respawn_downtown.bind(not victory))
	tw.tween_property(_fade, "modulate:a", 0.0, DEATH_FADE_IN)

## Sob o preto: a run anterior é encerrada (augments fora, vida/frasco cheios — RunState.new_attempt),
## um PLANO NOVO é sorteado (seed nova: outra ordem de bosses) e o Downtown se remonta com o
## jogador ao pé da fogueira. Quando a tela clareia, já está tudo em ordem.
func _respawn_downtown(died: bool) -> void:
	if is_instance_valid(_death_banner):
		_death_banner.queue_free()
		_death_banner = null
	_run.new_attempt(died)
	_plan = RunGenerator.generate(_run_cfg, randi())
	_rl_floor = 0
	_rl_boss_id = ""
	_start_downtown(true)

func _win_run() -> void:
	_finish_run(true)

## Morte (soulslike): a run NÃO acaba mais. A tela escurece com "VOCÊ MORREU", o mundo se refaz
## e o jogador levanta na última fogueira em que descansou, com vida e stamina cheias. Ele mantém
## o que conquistou (nível, augments, arma); perde o caminho andado. Sem nenhuma fogueira acesa,
## renasce no começo do nível em que caiu. Só a VITÓRIA ainda tem tela de fim.
func _on_player_died(_p: Player) -> void:
	if _phase == "dead":
		return                          # o dano pode chegar duas vezes no mesmo frame
	# Roguelite: a morte ENCERRA a run (sem mancha, sem fogueira-checkpoint): letreiro, fade, e o
	# jogador desperta no Downtown com as almas — a build de augments se perdeu com a run.
	if _roguelite:
		_finish_run(false)
		return
	_phase = "dead"
	_intro_token += 1                   # mata qualquer cutscene de boss ainda no ar
	Music.stop(1.5)
	if is_instance_valid(_player_view):
		_player_view.frozen = true

	# Todas as almas do bolso ficam numa MARCA no ponto EXATO da queda (inclusive na arena do chefe).
	# Uma marca anterior é substituída — as almas dela se perdem para sempre. É a aposta que dá peso
	# à morte. Sem almas no bolso, não deixa marca (drop_bloodstain devolve 0).
	var death_x := _player_view.global_position.x if is_instance_valid(_player_view) else PLAYER_START_X
	var souls_perdidas := _run.drop_bloodstain(_run.current_level, death_x)
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
	_run.repopulate(_respawning_ids())   # morrer repovoa o mundo, igual a descansar
	# Duas saídas, e só duas: a fogueira ou o começo do jogo. Nunca o lugar onde se caiu —
	# renascer na arena do chefe que acabou de te matar seria de graça. Com fogueira, reentra o
	# nível dela pelo _start_floor: ele já vê o nível como vencido e põe o player na fogueira
	# (respawn_x), com o portão aberto e a névoa adiante.
	if _run.has_checkpoint():
		_start_floor()
	else:
		_start_tutorial()

func _is_boss_level(level_id: String) -> bool:
	return String(_levels.get(level_id, {}).get("type", "")) == "boss"

## A marca de sangue espera no ponto EXATO onde você caiu (inclusive numa arena de chefe). Não é um
## inimigo: é um marcador passivo que se recolhe ao passar por cima (_update_bloodstain).
func _spawn_bloodstain_if_here() -> void:
	if not _run.has_bloodstain_on(_run.current_level):
		return
	var bs := BloodstainView.new()
	bs.position = Vector2(_run.bloodstain_x, GROUND_Y)
	_env.add_child(bs)                # filha do cenário: limpa junto ao remontar o nível
	bs.setup(_run.bloodstain_x, _run.bloodstain_souls, _player_view)
	_bloodstain = bs
	_msg.text = "Sua marca de sangue aguarda: recupere %d almas." % _run.bloodstain_souls

## Recolhe automático (sem tecla, como no Dark Souls) ao passar por cima da marca — em qualquer fase,
## inclusive dentro da arena do chefe.
func _update_bloodstain() -> void:
	if is_instance_valid(_bloodstain) and is_instance_valid(_player_view) \
			and _bloodstain.in_reach(_player_view):
		_recover_bloodstain()

func _recover_bloodstain() -> void:
	var back := _run.recover_bloodstain()
	if is_instance_valid(_bloodstain):
		_bloodstain.queue_free()
	_bloodstain = null
	Juice.burst(self, _player_view.global_position, Color(0.85, 0.92, 1.0), 18, 130.0)
	_msg.text = "Marca recolhida: %d almas de volta." % back

## O letreiro entra na camada do FADE (não no HUD): ali ele fica por cima do preto, e não debaixo
## dele. Aparece junto com o escurecimento, no mesmo compasso.
func _show_death_banner(souls_perdidas: int) -> void:
	var texto := "VOCÊ MORREU"
	if souls_perdidas > 0:
		# Curto de propósito: na fonte 32 cada caractere tem ~16px e a linha precisa caber nos 640.
		texto += "\n%d almas ficaram na sua marca" % souls_perdidas
	_show_run_banner(texto, Palette.ENEMY)

## O letreiro do fim de run, sobre o fade: vermelho na morte, dourado na vitória.
func _show_run_banner(texto: String, cor: Color) -> void:
	_death_banner = Label.new()
	_death_banner.text = texto
	_death_banner.add_theme_font_size_override("font_size", 32)   # 2× o nativo da fonte = nítido
	_death_banner.add_theme_color_override("font_color", cor)
	_death_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_banner.size = Vector2(640, 64)
	_death_banner.position = Vector2(0, 140)
	_death_banner.modulate.a = 0.0
	_fade_layer.add_child(_death_banner)
	create_tween().tween_property(_death_banner, "modulate:a", 1.0, DEATH_FADE_OUT)

## B no meio da run: PAUSA o jogo e abre o menu de pausa (PauseMenu — a mesma estética do menu
## principal; as Opções abrem de dentro dele). Roda com a árvore pausada e, ao fechar, despausa.
## A música segue tocando na pausa (o autoload Music é PROCESS_MODE_ALWAYS), mas ABAFADA
## (Music.set_muffled) — dá para ouvir o slider de volume mesmo assim.
func _open_options() -> void:
	if _options_layer != null:
		return                        # já aberto (o menu trata o próprio B de fechar)
	_options_layer = CanvasLayer.new()
	_options_layer.layer = 96         # acima do HUD e do fade, abaixo do CRT (100)
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)
	var menu := PauseMenu.new()
	menu.closed.connect(_close_options)
	_options_layer.add_child(menu)
	get_tree().paused = true
	Music.set_muffled(true)    # abafa a música na pausa (e volta ao normal em _close_options)

func _close_options() -> void:
	get_tree().paused = false
	Music.set_muffled(false)
	if _options_layer != null:
		_options_layer.queue_free()
		_options_layer = null

## Posição inicial ESPALHADA pelo nível (não na porta). Zona de exclusão dos 180px iniciais;
## se second_half, restringe à metade direita do corredor (usado pelos elites).
## Margem além do aggro, para o inimigo empurrado não ficar exatamente na borda da bolha.
const ATALHO_FOLGA := 12.0

## Empurra um spawn para FORA da bolha de aggro do atalho deste nível. Um atalho existe para
## encurtar o run-back; se o jogador desembocasse nele já com um inimigo desperto em cima, o
## atalho deixaria de ser alívio e viraria emboscada — e, pior, uma emboscada que ele não pode
## ver antes de atravessar. Vale para os inimigos de sala E para a guarda do refúgio.
func _afasta_do_atalho(x: float, aggro: float) -> float:
	if _shortcut_x == 0.0 or absf(x - _shortcut_x) > aggro:
		return x
	var novo := _shortcut_x - aggro - ATALHO_FOLGA if x < _shortcut_x else _shortcut_x + aggro + ATALHO_FOLGA
	push_warning("[floor_scene] spawn em x=%.0f caía a %.0fpx do atalho (aggro %.0f) no nível '%s' — movido para %.0f"
		% [x, absf(x - _shortcut_x), aggro, _run.current_level, novo])
	return novo

## O raio de aggro que um id de inimigo terá (lido do JSON antes de a view existir).
func _aggro_de(id: String) -> float:
	var base := _enemy_repo.get_by_id(id)
	var a := float(base.get("aggro_range", 0.0))
	return a if a > 0.0 else EnemyView.AGGRO_RANGE

## Onde os inimigos de um tier nascem. FIXO, nunca sorteado: ou o nível declara as posições uma a
## uma ("at": [x, x, ...]), ou elas saem de uma divisão igual da faixa permitida. Spawn aleatório é
## de roguelike — num soulslike o nível é uma coisa que se APRENDE, e não dá para aprender o que
## muda de lugar a cada morte. Com posições fixas, saber que há um pesado depois da curva é
## conhecimento que o jogador conquistou e leva consigo.
##
## A faixa começa em "spawn_from" do nível (ou SPAWN_EXCLUSION), que é como o Portão garante que
## nada nasça antes do portão da cidade. Posições declaradas fora da faixa são puxadas para dentro,
## com aviso — melhor corrigir e reclamar do que largar um inimigo em cima do ponto de partida.
func _spawn_positions(spec: Dictionary, second_half: bool) -> Array:
	var min_x := maxf(SPAWN_EXCLUSION, float(_floor_config.get("spawn_from", 0.0)))
	if second_half:
		min_x = maxf(min_x, _fight_width * 0.5)
	var max_x := maxf(min_x, _fight_width - 48.0)      # margem antes do fim do combate
	var out: Array = []

	var aggro := _aggro_de(String((spec.get("ids", []) as Array)[0])) if not (spec.get("ids", []) as Array).is_empty() else EnemyView.AGGRO_RANGE
	var at: Array = spec.get("at", [])
	if not at.is_empty():
		for v in at:
			var x := _afasta_do_atalho(float(v), aggro)
			var dentro := clampf(x, min_x, max_x)
			if not is_equal_approx(x, dentro):
				push_warning("[floor_scene] spawn em x=%.0f fora da faixa [%.0f, %.0f] do nível '%s' — movido para %.0f"
					% [x, min_x, max_x, _run.current_level, dentro])
			out.append(_off_pit(dentro))
		return out

	# Sem posições declaradas: divisão igual da faixa. Continua determinístico — o mesmo nível
	# monta o mesmo layout toda vez.
	var n := int(spec.get("count", 0))
	if n <= 0:
		return out
	var band := (max_x - min_x) / float(n)
	for i in n:
		out.append(_off_pit(_afasta_do_atalho(min_x + band * (float(i) + 0.5), aggro)))
	return out

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
	# INTERAGIR: as interações do refúgio — puxar a alavanca, descansar na fogueira, atravessar a névoa.
	# Cada uma só age se o player estiver perto do objeto; longe de todos, não faz nada. Bloqueadas
	# durante transição/morte/cutscene, quando o player não tem controle.
	if event.is_action_pressed("interact"):
		# O card do Frasco é modal: INTERAGIR confirma e fecha, retomando a fala do cavaleiro.
		if _knight_card_open:
			_fechar_card_frasco()
			return
		# Falas base tocando: E ADIANTA para a próxima (o indicador "[E] Avançar" anuncia isso).
		if _knight_seq:
			_knight_avancar()
			return
		if _tip_time > 0.0:            # há uma dica na tela: E fecha ela antes de qualquer outra coisa
			_hide_tip()
			return
		if _phase in ["transition", "dead", "boss_intro"]:
			return
		if _try_npc() or _try_pull_lever() or _try_rest() or _try_shortcut() or _try_cross_fog():
			return
		return
	# F9 alterna o overlay CRT (disponível sempre, não só em debug).
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F9:
		_crt.visible = not _crt.visible
	if DEBUG:
		_debug_input(event)

# ---------------------------------------------------------------------------
# DEBUG — atalhos para testar partes específicas sem jogar a run inteira.
# Teclas escolhidas para não colidir com o jogo (mover A/D, pular Espaço/W, atacar J, esquivar Shift/L).
# ---------------------------------------------------------------------------

func _apply_debug_start() -> void:
	if DEBUG_START_LEVEL > 1:
		_run.player.level = DEBUG_START_LEVEL
		_run.player.attribute_points += (DEBUG_START_LEVEL - 1) * Attributes.points_per_level()
		_run.player.recalculate_stats()
		_run.player.stats.current_hp = _run.player.stats.max_hp
	if DEBUG_START_AT != "":
		_run.go_to(DEBUG_START_AT)

func _show_debug_legend() -> void:
	var l := Label.new()
	l.text = "[DEBUG]  K matar  |  M proxima sala  |  L +nivel do player  |  P 2x dano arma  |  H curar  |  I god mode  |  G soltar marca"
	l.position = Vector2(8, 342)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_layer.add_child(l)

func _debug_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_K: _debug_kill_enemies()
		KEY_M: _debug_next_room()
		KEY_L: _debug_level_up()
		KEY_H: _run.player.heal(_run.player.stats.max_hp)
		KEY_G: _debug_drop_bloodstain()
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

## Vai para a PRÓXIMA sala, seguindo o grafo (a saída "frente") — num mapa não existe "andar n+1",
## existe o que a saída daqui apontar. Três coisas que a versão anterior errava:
##   - na Cidade não funcionava: o tutorial não preenche _floor_config, então "frente" nunca
##     resolvia. Da Cidade, "próxima sala" é a entrada da dungeon;
##   - deixava cutscene de chefe no ar (o _start_floor novo corria por baixo dela);
##   - no fim do mapa recarregava o nível em silêncio, sem dizer por quê.
func _debug_next_room() -> void:
	if _phase in ["dead", "transition"]:
		return
	_intro_token += 1               # mata qualquer cutscene de chefe ainda rodando
	Music.stop()
	_debug_clear_all()

	# Roguelite: M segue O PLANO, não o grafo antigo (a arena da torre nem tem saída "frente").
	# Vila → Downtown → torre → próximo nó, na ordem em que o jogo mesmo andaria.
	if _roguelite:
		if _phase == "tutorial":
			_begin_dungeon()
		elif _phase == "downtown":
			_begin_tower()
		else:
			_advance_plan()
		return

	if _phase == "tutorial" or _run.current_level == "":
		_begin_dungeon()
		_msg.text = "[DEBUG] → %s" % _level_name()
		return
	if not _has_exit("frente"):
		_msg.text = "[DEBUG] '%s' não tem saída 'frente' — fim do mapa" % _level_name()
		return
	_go_through("frente")
	_msg.text = "[DEBUG] → %s" % _level_name()

## Dá almas de sobra para testar o mercado do Downtown sem precisar farmar.
func _debug_level_up() -> void:
	_run.player.gain_souls(Leveling.level_cost(_run.player.level) * 3)
	_msg.text = "[DEBUG] +almas → %d (nível %d custa %d)" % [
		_run.player.souls, _run.player.level, Leveling.level_cost(_run.player.level)]

## Solta uma marca de sangue um pouco à frente, com as almas do bolso (sem precisar morrer).
func _debug_drop_bloodstain() -> void:
	_run.player.gain_souls(50)   # garante almas para a marca não nascer vazia
	_run.drop_bloodstain(_run.current_level, _player_view.global_position.x + 120.0)
	_spawn_bloodstain_if_here()

func _debug_toggle_god() -> void:
	_player_view.god_mode = not _player_view.god_mode
	_msg.text = "[DEBUG] God mode: %s" % ("ON" if _player_view.god_mode else "OFF")

func _debug_double_weapon_damage() -> void:
	if _run.player.weapon == null:
		return
	_run.player.weapon.base_damage *= 2.0   # dobra o dano efetivo (acumulável)
	_msg.text = "[DEBUG] Dano da arma dobrado (golpe atual: %.0f)" % _run.player.weapon.current_damage()
