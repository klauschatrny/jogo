## HUD básico (§2.3): barra de HP do jogador. Escuta o EventBus (player_damaged) —
## a UI observa o Core, nunca o contrário (§0.2.4).
class_name Hud
extends Control

const BAR_WIDTH := 200.0   # base 640×360
const STAM_Y := 33.0       # barra de stamina logo abaixo da de HP
const STAM_H := 7.0

var _player: Player
var _bar: ColorRect
var _label: Label
var _stam_bar: ColorRect
var _souls: Label
var _flask: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Palette.HP_BACK
	bg.position = Vector2(12, 12)
	bg.size = Vector2(BAR_WIDTH, 18)
	add_child(bg)

	_bar = ColorRect.new()
	_bar.color = Palette.PLAYER_HP
	_bar.position = Vector2(12, 12)
	_bar.size = Vector2(BAR_WIDTH, 18)
	add_child(_bar)

	var stam_bg := ColorRect.new()
	stam_bg.color = Color(0.09, 0.12, 0.09)
	stam_bg.position = Vector2(12, STAM_Y)
	stam_bg.size = Vector2(BAR_WIDTH, STAM_H)
	add_child(stam_bg)

	_stam_bar = ColorRect.new()
	_stam_bar.color = Color(0.36, 0.72, 0.32)   # verde de stamina (estilo Dark Souls)
	_stam_bar.position = Vector2(12, STAM_Y)
	_stam_bar.size = Vector2(BAR_WIDTH, STAM_H)
	add_child(_stam_bar)

	# Nível ao LADO da barra (barra de HP fica limpa, sem número de vida).
	_label = Label.new()
	_label.position = Vector2(12 + BAR_WIDTH + 6, 13)
	_label.add_theme_font_size_override("font_size", 11)
	add_child(_label)

	# Almas: a moeda. Precisa estar SEMPRE visível — é o que você perde ao morrer, e não dá para
	# decidir se vale a pena avançar ou voltar à fogueira sem ver quanto está em jogo.
	_souls = Label.new()
	_souls.position = Vector2(12, STAM_Y + STAM_H + 4)
	_souls.add_theme_font_size_override("font_size", 11)
	_souls.add_theme_color_override("font_color", Palette.ACCENT)
	add_child(_souls)

	# Frasco de cura: a única cura sob demanda. Precisa estar à vista para virar decisão ("bebo a
	# última carga agora?"). Cor de vida, para ler como recurso de HP.
	_flask = Label.new()
	_flask.position = Vector2(12, STAM_Y + STAM_H + 18)
	_flask.add_theme_font_size_override("font_size", 11)
	_flask.add_theme_color_override("font_color", Palette.PLAYER_HP)
	add_child(_flask)

	_refresh()

func set_player(p: Player) -> void:
	_player = p
	_refresh()

## Atualiza todo frame: reflete dano, cura (lifesteal) e level-up sem depender de eventos.
func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player == null or _player.stats == null:
		return
	var ratio := clampf(float(_player.stats.current_hp) / float(maxi(_player.stats.max_hp, 1)), 0.0, 1.0)
	_bar.size.x = BAR_WIDTH * ratio
	_label.text = "Nv %d" % _player.level
	if _stam_bar != null:
		_stam_bar.size.x = BAR_WIDTH * (_player.stamina.ratio() if _player.stamina != null else 0.0)
	if _souls != null:
		_souls.text = "%d almas" % _player.souls
	if _flask != null:
		_flask.text = "Frasco  %d/%d" % [_player.flask_charges, _player.flask_max]
