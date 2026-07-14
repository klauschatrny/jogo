## Painel de Opções: volume da música e dos efeitos. Só-teclado, como o resto do jogo
## (↑↓ escolhem, ←→ ajustam, ESC fecha) — mas o mouse também funciona nos sliders.
##
## Mexer no slider aplica na hora (dá para ouvir enquanto ajusta) e grava em disco (AudioSettings).
## Roda mesmo com a árvore PAUSADA: quem o abre no jogo pausa e ouve `closed` para despausar.
class_name OptionsPanel
extends Control

signal closed

const STEP := 0.05                 # granularidade do ajuste pelas setas
const VIEW := Vector2(640, 360)

var _music: HSlider
var _sfx: HSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # o jogo pausa; o painel continua respondendo
	# ..._and_offsets_: só as âncoras deixariam o retângulo com tamanho ZERO (o pai é um
	# CanvasLayer, não um Control) e o escurecimento não apareceria.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()                # escurece o que está atrás, sem esconder
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var frame := ColorRect.new()              # moldura: destaca o painel do cenário atrás
	frame.color = Palette.BG.darkened(0.25)
	frame.position = Vector2(136, 84)
	frame.size = Vector2(368, 180)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var edge := ColorRect.new()
	edge.color = Palette.ACCENT
	edge.position = frame.position + Vector2(0, -2)
	edge.size = Vector2(frame.size.x, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(160, 100)
	box.custom_minimum_size = Vector2(320, 0)
	add_child(box)

	box.add_child(_title("OPCOES"))
	box.add_child(_spacer(6))
	_music = _add_row(box, "MUSICA", AudioSettings.music_volume, _on_music)
	_sfx = _add_row(box, "EFEITOS", AudioSettings.sfx_volume, _on_sfx)
	box.add_child(_spacer(8))
	box.add_child(_hint("SETAS  ajustar     ESC  voltar"))

	_music.grab_focus()

## ESC fecha. Consumimos o evento (set_input_as_handled) para quem abriu o painel não reagir a ele
## no mesmo frame — senão o ESC que fecha reabriria na hora.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

func _on_music(v: float) -> void:
	AudioSettings.set_music_volume(v)
	_refresh()

func _on_sfx(v: float) -> void:
	AudioSettings.set_sfx_volume(v)
	_refresh()

## Uma linha: rótulo + slider + porcentagem. O slider guarda o Label do valor em `_pct` (meta),
## para o _refresh achá-lo sem uma referência a mais.
func _add_row(box: VBoxContainer, label: String, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(90, 0)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = STEP
	slider.value = value
	slider.custom_minimum_size = Vector2(160, 16)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL          # navegável só pelo teclado
	slider.value_changed.connect(cb)
	row.add_child(slider)

	var pct := Label.new()
	pct.text = _pct_text(value)
	pct.custom_minimum_size = Vector2(48, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", Palette.ACCENT)
	row.add_child(pct)

	slider.set_meta("pct", pct)
	return slider

func _refresh() -> void:
	for s in [_music, _sfx]:
		var pct: Label = s.get_meta("pct")
		pct.text = _pct_text(s.value)

func _pct_text(v: float) -> String:
	return "MUDO" if v <= 0.0 else "%d%%" % roundi(v * 100.0)

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Palette.ACCENT)
	return l

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Palette.TEXT.darkened(0.4))
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
