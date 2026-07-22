## Tela de recompensa (§3.5): mostra 3 cards de Augment com cor por tier (§1.3.1) e deixa
## o jogador escolher 1 pelas teclas 1/2/3. Emite `chosen` com o augment selecionado.
class_name CardSelect
extends Control

signal chosen(aug: Augment)

var _cards: Array = []

func setup(cards: Array) -> void:
	_cards = cards

func _ready() -> void:
	# anchors E offsets: só as âncoras deixam o retângulo com tamanho ZERO quando o pai é um
	# CanvasLayer (não um Control) — e aí o overlay escuro não aparece (mesma pegadinha do
	# AttributePanel).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title := Label.new()
	title.text = "ESCOLHA UMA CARTA  (1 / 2 / 3)"
	title.position = Vector2(0, 48)
	title.size = Vector2(640, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var card_w := 172       # base 640×360
	var card_h := 200
	var gap := 24
	var total := _cards.size() * card_w + (_cards.size() - 1) * gap
	var start_x := (640 - total) / 2

	for i in _cards.size():
		add_child(_make_card(_cards[i], i, start_x + i * (card_w + gap), card_w, card_h))

func _make_card(aug: Augment, index: int, x: int, w: int, h: int) -> Control:
	const PAD := 10
	var panel := Control.new()
	panel.position = Vector2(x, 100)
	panel.size = Vector2(w, h)
	panel.clip_contents = true        # nada vaza para fora do card
	# CLICAR no card também escolhe — o resto da UI (menu, atributos) já é de mouse, então a
	# recompensa não pode ser a única tela teclado-só.
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(aug))

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = _tier_color(aug.tier)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE   # o clique é do PAINEL: os filhos não o comem
	panel.add_child(bg)

	# Layout por container: adapta-se às métricas da fonte (nome no topo, descrição
	# expandindo no meio com wrap, tier embaixo) — sem posições fixas que desencaixam.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Fonte 16 em tudo: é o tamanho NATIVO da Pixel Operator (só 16 e 32 saem nítidos na base
	# 640×360 — qualquer outro borra; ver AttributePanel). Os antigos 13/11/9 saíam ilegíveis.
	vbox.add_child(_label("%d. %s" % [index + 1, aug.name], 16, false))

	var desc := _label(aug.description, 16, true)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	vbox.add_child(_label(aug.tier, 16, false))
	return panel

## Label centralizado com wrap, para uso dentro do VBox do card.
func _label(text: String, font_size: int, expand: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	if expand:
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l

func _tier_color(tier: String) -> Color:
	match tier:
		"FRAGMENT":
			return Color(0.55, 0.55, 0.6)
		"RELIC":
			return Color(0.28, 0.38, 0.78)
		"ARTIFACT":
			return Color(0.82, 0.6, 0.16)
	return Color(0.4, 0.4, 0.4)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var idx := -1
	match event.physical_keycode:
		KEY_1, KEY_KP_1:
			idx = 0
		KEY_2, KEY_KP_2:
			idx = 1
		KEY_3, KEY_KP_3:
			idx = 2
	if idx >= 0 and idx < _cards.size():
		accept_event()
		chosen.emit(_cards[idx])
