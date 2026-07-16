## Painel de Opções, em TRÊS ABAS (clique para trocar):
##   ÁUDIO     — volume da música e dos efeitos (sliders de mouse).
##   CONTROLES — remapear as teclas (KeyBinds): MUDAR e aperte a tecla nova; ESC cancela a captura.
##               A lista vive num ScrollContainer: mais ações do que cabem = roda de rolagem.
##   TUTORIAL  — relê as mensagens de tutorial (TutorialTips), para quem as deixou passar.
##
## Mexer num slider aplica na hora (dá para ouvir enquanto ajusta) e grava em disco (AudioSettings);
## remapear uma tecla idem (InputMap + user://keybinds.json). Roda mesmo com a árvore PAUSADA:
## quem o abre no jogo pausa e ouve `closed` para despausar. É o MESMO painel no menu principal
## (que abre direto na aba pedida, via `initial_tab` — lá não existe uma categoria "opções") e na
## pausa. Não há título acima das abas: elas mesmas são o cabeçalho.
class_name OptionsPanel
extends Control

signal closed

const STEP := 0.05                 # granularidade dos sliders de volume
const VIEW := Vector2(640, 360)

## Aba em que o painel abre (0 = ÁUDIO, 1 = CONTROLES, 2 = TUTORIAL). Defina ANTES do add_child.
var initial_tab := 0

var _music: HSlider
var _sfx: HSlider
var _tab := 0                      # 0 = ÁUDIO, 1 = CONTROLES, 2 = TUTORIAL
var _tab_btns: Array = []          # [Button, Button]
var _content: VBoxContainer        # o corpo da aba atual (destruído e refeito ao trocar)
var _bind_rows: Array = []         # [{ action, keys(Label), btn(Button) }]
var _capture := ""                 # ação esperando a tecla nova ("" = nenhuma)
var _status: Label                 # mensagens da captura ("tecla já usada...", etc.)

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
	# Altura com FOLGA: cada Button rende ~31px (fonte 16 + padding do tema), mais que o
	# custom_minimum_size — dimensionar pelo mínimo deixava VOLTAR/MENU PRINCIPAL para fora.
	frame.position = Vector2(110, 22)
	frame.size = Vector2(420, 316)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var edge := ColorRect.new()
	edge.color = Palette.ACCENT
	edge.position = frame.position + Vector2(0, -2)
	edge.size = Vector2(frame.size.x, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(130, 32)
	box.custom_minimum_size = Vector2(380, 0)
	add_child(box)

	box.add_child(_spacer(4))
	box.add_child(_build_tabs())
	box.add_child(_spacer(2))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	box.add_child(_content)

	# VOLTAR fica FORA do fluxo das abas, em posição FIXA no pé da moldura: não sobe nem desce
	# conforme o conteúdo da aba. (MENU PRINCIPAL não vive mais aqui: é do PauseMenu.)
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.custom_minimum_size = Vector2(120, 24)
	voltar.position = Vector2(260, 298)       # centrado na moldura (110..530), rente à base (338)
	voltar.focus_mode = Control.FOCUS_NONE
	voltar.pressed.connect(_close)
	add_child(voltar)

	_show_tab(initial_tab)

## Fecha o painel (o botão VOLTAR e a tecla PAUSAR/FECHAR caem aqui).
func _close() -> void:
	closed.emit()
	queue_free()

## A fileira de abas. A selecionada fica na cor de destaque; trocar de aba refaz o corpo.
func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for i in 3:
		var b := Button.new()
		b.text = ["ÁUDIO", "CONTROLES", "TUTORIAL"][i]
		b.custom_minimum_size = Vector2(112, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_tab.bind(i))
		row.add_child(b)
		_tab_btns.append(b)
	return row

func _show_tab(i: int) -> void:
	_tab = i
	_capture = ""
	_bind_rows.clear()
	_music = null
	_sfx = null
	for c in _content.get_children():
		c.free()                    # free imediato: o rebuild abaixo já adiciona os novos
	for j in _tab_btns.size():
		_tab_btns[j].add_theme_color_override("font_color",
			Palette.ACCENT if j == _tab else Palette.TEXT.darkened(0.3))
	match i:
		0: _build_audio_tab()
		1: _build_controls_tab()
		_: _build_tutorial_tab()

# --- Aba AUDIO ---

func _build_audio_tab() -> void:
	_content.add_child(_spacer(8))
	_music = _add_slider_row("MÚSICA", AudioSettings.music_volume, _on_music)
	_sfx = _add_slider_row("EFEITOS", AudioSettings.sfx_volume, _on_sfx)
	_content.add_child(_spacer(10))

func _on_music(v: float) -> void:
	AudioSettings.set_music_volume(v)
	_refresh_audio()

func _on_sfx(v: float) -> void:
	AudioSettings.set_sfx_volume(v)
	_refresh_audio()

## Uma linha: rótulo + slider + porcentagem. O slider guarda o Label do valor em `_pct` (meta),
## para o _refresh achá-lo sem uma referência a mais.
func _add_slider_row(label: String, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

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
	slider.custom_minimum_size = Vector2(180, 16)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL          # navegável pelo teclado
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

func _refresh_audio() -> void:
	for s in [_music, _sfx]:
		if s == null:
			continue
		var pct: Label = s.get_meta("pct")
		pct.text = _pct_text(s.value)

func _pct_text(v: float) -> String:
	return "MUDO" if v <= 0.0 else "%d%%" % roundi(v * 100.0)

# --- Aba CONTROLES ---

func _build_controls_tab() -> void:
	# A lista rola: quando houver mais ações do que a janela comporta, a roda do mouse (ou a
	# barra) traz o resto — os botões de RESTAURAR e os avisos ficam FIXOS, abaixo da rolagem.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	for item in KeyBinds.ACTIONS:
		_add_bind_row(lista, String(item["action"]), String(item["label"]))

	_status = _make_hint("")
	_status.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	_content.add_child(_status)
	_refresh_binds()

## Aba TUTORIAL: relê as mensagens ensinadas na vila (e a do frasco), na ordem em que aparecem.
## Mesma rolagem da aba de controles — mensagens futuras entram de graça.
func _build_tutorial_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 176)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 8)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	for texto in TutorialTips.all_texts():
		var l := Label.new()
		l.text = "· %s" % texto
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Palette.TEXT)
		lista.add_child(l)

## Uma linha: AÇÃO       tecla(s)       [MUDAR]. O botão entra em modo captura: a próxima tecla
## apertada vira a (única) tecla da ação. `parent` é a lista rolável.
func _add_bind_row(parent: Container, action: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(160, 0)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(name_lbl)

	var keys_lbl := Label.new()
	keys_lbl.custom_minimum_size = Vector2(120, 0)
	keys_lbl.add_theme_color_override("font_color", Palette.ACCENT)
	row.add_child(keys_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_change.bind(action))
	row.add_child(btn)

	_bind_rows.append({ "action": action, "keys": keys_lbl, "btn": btn })

## Clicou em MUDAR: esta ação passa a esperar a tecla nova (clicar noutra MUDAR move a espera).
func _on_change(action: String) -> void:
	_capture = action
	_refresh_binds()

func _refresh_binds() -> void:
	for r in _bind_rows:
		var mine: bool = String(r["action"]) == _capture
		var keys: Label = r["keys"]
		var btn: Button = r["btn"]
		keys.text = "..." if mine else KeyBinds.key_names(String(r["action"]))
		btn.text = "MUDAR"
	if _status != null:
		_status.text = "aperte a tecla nova   (ESC cancela)" if _capture != "" else ""

# --- Input ---

## Capturando: TODA tecla é nossa (ESC cancela; tecla em uso por outra ação é recusada com aviso).
## Fora da captura, PAUSAR/FECHAR fecha o painel — consumimos o evento (set_input_as_handled)
## para quem o abriu não reagir a ele no mesmo frame (senão o fechar reabriria na hora).
func _input(event: InputEvent) -> void:
	if _capture != "":
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		if k.physical_keycode == KEY_ESCAPE:
			_capture = ""
			_refresh_binds()
			return
		var alvo := _capture
		var conflito: String = KeyBinds.rebind(alvo, int(k.physical_keycode))
		if conflito != "":
			_status.text = "tecla já usada por  %s" % conflito
			return
		_capture = ""
		_refresh_binds()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

# --- helpers de UI ---

## Fonte SEMPRE no 16 nativo da Pixel Operator — tamanhos menores saem borrados/ilegíveis.
func _make_hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Palette.TEXT.darkened(0.4))
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
