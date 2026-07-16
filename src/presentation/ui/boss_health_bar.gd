## Barra de vida de boss estilo Dark Souls: barra larga no rodapé da tela, com o nome do boss
## e SEM número de HP. O HP perdido não some — vira a faixa escura ao fundo (o preenchimento
## carmesim encolhe e revela o fundo). Fica num CanvasLayer (espaço de tela 640×360).
class_name BossHealthBar
extends Control

const BAR_W := 420.0
const BAR_H := 9.0
const Y := 332.0          # perto do rodapé (tela = 360 de altura)
const FRAME := 2.0

var _fill: ColorRect
var _name: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := (640.0 - BAR_W) * 0.5

	var frame := ColorRect.new()          # moldura escura
	frame.color = Color(0.04, 0.03, 0.04, 0.92)
	frame.position = Vector2(x - FRAME, Y - FRAME)
	frame.size = Vector2(BAR_W + FRAME * 2.0, BAR_H + FRAME * 2.0)
	add_child(frame)

	var back := ColorRect.new()           # HP perdido = faixa escura
	back.color = Color(0.22, 0.06, 0.07)
	back.position = Vector2(x, Y)
	back.size = Vector2(BAR_W, BAR_H)
	add_child(back)

	_fill = ColorRect.new()               # HP atual = carmesim
	_fill.color = Color(0.66, 0.14, 0.16)
	_fill.position = Vector2(x, Y)
	_fill.size = Vector2(BAR_W, BAR_H)
	add_child(_fill)

	_name = Label.new()                   # nome do boss (sem quantidade de HP)
	_name.add_theme_color_override("font_color", Color(0.90, 0.88, 0.84))
	_name.position = Vector2(x, Y - 20.0)   # fonte 16 (nativa) — o rótulo subiu para não invadir a barra
	add_child(_name)

func setup(boss_name: String) -> void:
	if _name != null:
		_name.text = boss_name

func set_ratio(r: float) -> void:
	if _fill != null:
		_fill.size.x = BAR_W * clampf(r, 0.0, 1.0)
