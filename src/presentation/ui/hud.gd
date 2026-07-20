## HUD básico (§2.3): barra de HP do jogador. Escuta o EventBus (player_damaged) —
## a UI observa o Core, nunca o contrário (§0.2.4).
class_name Hud
extends Control

# As barras CRESCEM com o máximo (estilo Dark Souls): a largura é proporcional ao valor máximo,
# então subir Vigor/Resistência alonga visivelmente a barra. Limitada a [BAR_MIN, BAR_MAX] px.
const PX_PER_HP := 1.4        # px de largura por ponto de vida MÁXIMA
const PX_PER_STAMINA := 1.4   # px de largura por ponto de stamina MÁXIMA
const BAR_MIN := 40.0
const BAR_MAX := 300.0        # teto: base 640×360, a barra não pode invadir o meio da tela
const BAR_W0 := 120.0         # largura provisória na criação (o _refresh recalcula pelo máximo real)
const STAM_Y := 33.0          # barra de stamina logo abaixo da de HP
const STAM_H := 7.0
const OUTLINE := 2.0          # espessura do contorno escuro em volta das barras
const OUTLINE_COLOR := Color(0.03, 0.03, 0.05)

var _player: Player
var _run: RunState            # fonte do contador de mortes (playtest); pode ficar nulo (ex.: combat_test)
var _deaths: Label            # contador de MORTES no canto superior direito (instrumentação de playtest)
var _hp_outline: ColorRect
var _hp_bg: ColorRect
var _bar: ColorRect
var _stam_outline: ColorRect
var _stam_bg: ColorRect
var _stam_bar: ColorRect
var _souls: Label
# Frasco de cura: ícone visual (quadro + frasco âmbar) com o número da carga ATUAL embaixo.
var _flask_icon: Node2D
var _flask_body: Polygon2D
var _flask_core: Polygon2D
var _flask_count: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Contorno escuro (atrás do fundo): um retângulo maior que a barra por OUTLINE em cada lado.
	_hp_outline = ColorRect.new()
	_hp_outline.color = OUTLINE_COLOR
	_hp_outline.position = Vector2(12 - OUTLINE, 12 - OUTLINE)
	_hp_outline.size = Vector2(BAR_W0 + 2 * OUTLINE, 18 + 2 * OUTLINE)
	add_child(_hp_outline)

	_hp_bg = ColorRect.new()
	_hp_bg.color = Palette.HP_BACK
	_hp_bg.position = Vector2(12, 12)
	_hp_bg.size = Vector2(BAR_W0, 18)
	add_child(_hp_bg)

	_bar = ColorRect.new()
	_bar.color = Palette.PLAYER_HP
	_bar.position = Vector2(12, 12)
	_bar.size = Vector2(BAR_W0, 18)
	add_child(_bar)

	_stam_outline = ColorRect.new()
	_stam_outline.color = OUTLINE_COLOR
	_stam_outline.position = Vector2(12 - OUTLINE, STAM_Y - OUTLINE)
	_stam_outline.size = Vector2(BAR_W0 + 2 * OUTLINE, STAM_H + 2 * OUTLINE)
	add_child(_stam_outline)

	_stam_bg = ColorRect.new()
	_stam_bg.color = Color(0.09, 0.12, 0.09)
	_stam_bg.position = Vector2(12, STAM_Y)
	_stam_bg.size = Vector2(BAR_W0, STAM_H)
	add_child(_stam_bg)

	_stam_bar = ColorRect.new()
	_stam_bar.color = Color(0.36, 0.72, 0.32)   # verde de stamina (estilo Dark Souls)
	_stam_bar.position = Vector2(12, STAM_Y)
	_stam_bar.size = Vector2(BAR_W0, STAM_H)
	add_child(_stam_bar)

	# Almas: a moeda. Precisa estar SEMPRE visível — é o que você perde ao morrer, e não dá para
	# decidir se vale a pena avançar ou voltar à fogueira sem ver quanto está em jogo.
	_build_souls()

	# Frasco de cura: a única cura sob demanda. Precisa estar à vista para virar decisão ("bebo a
	# última carga agora?"). Ícone visual (estilo Estus) com o número da carga atual embaixo.
	_build_flask()

	# Contador de mortes (playtest): visível para medir a dificuldade nas sessões de teste.
	_build_deaths()

	_refresh()

## Símbolo de ALMA (placeholder, sem arte) + o número à direita — sem a palavra "almas".
## O símbolo é uma chama espectral azulada com núcleo claro, o desenho clássico do gênero.
func _build_souls() -> void:
	# O centro VERTICAL é um só: símbolo e número se alinham por ele.
	var y_center := STAM_Y + STAM_H + 14
	var icon := Node2D.new()
	icon.position = Vector2(20, y_center)
	add_child(icon)

	var shape := PackedVector2Array([            # a silhueta da chama (reusada no contorno)
		Vector2(0, -8), Vector2(3, -3), Vector2(5, 1), Vector2(4, 5),
		Vector2(0, 8), Vector2(-4, 5), Vector2(-5, 1), Vector2(-3, -3),
	])
	var outline := Polygon2D.new()               # contorno: a mesma silhueta, escura e inflada,
	outline.color = OUTLINE_COLOR                # desenhada ATRÁS (mesmo truque das barras)
	outline.polygon = shape
	outline.scale = Vector2(1.45, 1.3)           # ~2px de sobra em cada eixo (a forma é 10×16)
	icon.add_child(outline)
	var wisp := Polygon2D.new()                  # o corpo da chama (azul espectral)
	wisp.color = Color(0.45, 0.68, 0.92)
	wisp.polygon = shape
	icon.add_child(wisp)
	var core := Polygon2D.new()                  # o miolo brilhante
	core.color = Color(0.88, 0.96, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(0, -2), Vector2(2, 1), Vector2(1, 4), Vector2(-1, 4), Vector2(-2, 1),
	])
	icon.add_child(core)

	_souls = Label.new()                         # o número, à DIREITA do símbolo
	# Caixa com centro vertical explícito = o mesmo y_center do símbolo.
	_souls.position = Vector2(32, y_center - 10)
	_souls.size = Vector2(90, 20)
	_souls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 16 = o nativo da fonte bitmap; menor sai borrado (vale para todo texto do jogo).
	# Azul espectral claro: a mesma família do símbolo (entre o corpo e o miolo da chama).
	_souls.add_theme_color_override("font_color", Color(0.76, 0.88, 1.0))
	_souls.add_theme_color_override("font_outline_color", OUTLINE_COLOR)   # contorno escuro
	_souls.add_theme_constant_override("outline_size", 4)
	add_child(_souls)

## Ícone do frasco (placeholder, sem arte): um quadro estilo Estus com o frasco âmbar dentro e o
## número da carga ATUAL logo abaixo (não "3/3"). O corpo âmbar é recolorido para cinza quando vazio.
func _build_flask() -> void:
	_flask_icon = Node2D.new()
	# Canto INFERIOR DIREITO da tela (base 640×360). A origem é o topo-centro do quadro; o quadro vai
	# de x-15 a x+15 e o número desce até ~y+48, então isto o encaixa perto da borda sem cortar.
	_flask_icon.position = Vector2(608, 300)
	add_child(_flask_icon)

	# Quadro (slot): borda dourada escura + fundo quase preto.
	var border := ColorRect.new()
	border.color = Color(0.42, 0.33, 0.16)
	border.position = Vector2(-15, 0)
	border.size = Vector2(30, 34)
	_flask_icon.add_child(border)
	var inner := ColorRect.new()
	inner.color = Color(0.06, 0.05, 0.04, 0.9)
	inner.position = Vector2(-13, 2)
	inner.size = Vector2(26, 30)
	_flask_icon.add_child(inner)

	# Rolha e gargalo.
	var cork := ColorRect.new()
	cork.color = Color(0.35, 0.22, 0.10)
	cork.position = Vector2(-4, 4)
	cork.size = Vector2(8, 4)
	_flask_icon.add_child(cork)
	var neck := ColorRect.new()
	neck.color = Color(0.72, 0.46, 0.14)
	neck.position = Vector2(-3, 7)
	neck.size = Vector2(6, 5)
	_flask_icon.add_child(neck)

	# Corpo (âmbar) + núcleo brilhante — guardados para recolorir quando o frasco esvazia.
	_flask_body = Polygon2D.new()
	_flask_body.polygon = PackedVector2Array([
		Vector2(-4, 12), Vector2(4, 12), Vector2(8, 18), Vector2(8, 25),
		Vector2(4, 30), Vector2(-4, 30), Vector2(-8, 25), Vector2(-8, 18),
	])
	_flask_icon.add_child(_flask_body)
	_flask_core = Polygon2D.new()
	_flask_core.polygon = PackedVector2Array([
		Vector2(-3, 18), Vector2(3, 18), Vector2(4, 23), Vector2(0, 28), Vector2(-4, 23),
	])
	_flask_icon.add_child(_flask_core)

	# Número da carga ATUAL, centrado logo abaixo do quadro.
	_flask_count = Label.new()
	_flask_count.position = Vector2(-15, 34)
	_flask_count.size = Vector2(30, 14)
	_flask_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flask_count.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
	_flask_count.add_theme_color_override("font_outline_color", OUTLINE_COLOR)   # contorno escuro
	_flask_count.add_theme_constant_override("outline_size", 4)
	_flask_icon.add_child(_flask_count)

## Contador de MORTES (instrumentação de playtest): canto superior direito, alinhado pela
## margem de 12px das barras. Só aparece quando há um RunState (set_run) — no combat_test fica oculto.
func _build_deaths() -> void:
	_deaths = Label.new()
	_deaths.position = Vector2(628.0 - 150.0, 8.0)   # caixa encostada na margem direita (base 640×360)
	_deaths.size = Vector2(150.0, 20.0)
	_deaths.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_deaths.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deaths.add_theme_color_override("font_color", Color(0.88, 0.52, 0.52))   # vermelho apagado, tom de morte
	_deaths.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_deaths.add_theme_constant_override("outline_size", 4)
	_deaths.visible = false
	add_child(_deaths)

func set_player(p: Player) -> void:
	_player = p
	_refresh()

func set_run(r: RunState) -> void:
	_run = r
	_refresh()

## Atualiza todo frame: reflete dano, cura (lifesteal) e level-up sem depender de eventos.
func _process(_delta: float) -> void:
	_refresh()

## Largura da barra em px, proporcional ao MÁXIMO (limitada a [BAR_MIN, BAR_MAX]).
func _bar_width(max_value: float, px_per_unit: float) -> float:
	return clampf(max_value * px_per_unit, BAR_MIN, BAR_MAX)

func _refresh() -> void:
	# Mortes (playtest): antes do guard do player — o contador não depende dele.
	if _deaths != null and _run != null:
		_deaths.visible = true
		_deaths.text = "Mortes: %d" % _run.deaths
	if _player == null or _player.stats == null:
		return
	# Vida: o fundo cresce com a vida MÁXIMA; o preenchimento é a fração atual dessa largura.
	var hp_w := _bar_width(float(_player.stats.max_hp), PX_PER_HP)
	var ratio := clampf(float(_player.stats.current_hp) / float(maxi(_player.stats.max_hp, 1)), 0.0, 1.0)
	_hp_outline.size.x = hp_w + 2 * OUTLINE
	_hp_bg.size.x = hp_w
	_bar.size.x = hp_w * ratio
	# Stamina: idem, com o teto vindo da Resistência (stamina.maximum).
	if _stam_bar != null:
		var st_max := _player.stamina.maximum if _player.stamina != null else 0.0
		var st_w := _bar_width(st_max, PX_PER_STAMINA)
		_stam_outline.size.x = st_w + 2 * OUTLINE
		_stam_bg.size.x = st_w
		_stam_bar.size.x = st_w * (_player.stamina.ratio() if _player.stamina != null else 0.0)
	if _souls != null:
		_souls.text = "%d" % _player.souls
	if _flask_count != null:
		# SEM O FRASCO o slot fica VAZIO — só o quadro, sem vidro e sem número. É diferente de
		# "frasco vazio" (que mostra o vidro apagado e um 0): aqui o jogador ainda nem tem o objeto,
		# e o slot vazio é a pergunta que o leva a falar com o Sir Big T.
		var tem_frasco: bool = _player.has_flask
		_flask_body.visible = tem_frasco
		_flask_core.visible = tem_frasco
		if not tem_frasco:
			_flask_count.text = ""
		else:
			var tem := _player.flask_charges > 0
			_flask_body.color = Color(0.95, 0.62, 0.16) if tem else Color(0.32, 0.32, 0.34)
			_flask_core.color = Color(1.0, 0.85, 0.45) if tem else Color(0.42, 0.42, 0.44)
			_flask_count.text = "%d" % _player.flask_charges
