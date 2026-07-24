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

	# Ícone ilustrativo do upgrade no topo (desenhado por chave — ver _make_icon_control).
	vbox.add_child(_make_icon_control(aug.icon))

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

# --- Ícones ilustrativos dos augments (placeholder desenhado; a chave vem do JSON, campo "icon"). ---
# Um disco escuro de contraste + uma forma simples que remete ao efeito (coração=vida, espada=ataque,
# raio=fôlego, frasco=cura, olho=crítico...). Node2D DENTRO de um Control para o VBox reservar a altura.

func _make_icon_control(key: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 48)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Node2D.new()
	art.position = Vector2(76.0, 26.0)   # 10 (margem) + 76 = 86 = centro do card (172/2)
	holder.add_child(art)
	_icon_disc(art, 0.0, 0.0, 19.0, Color(0.06, 0.05, 0.08, 0.55))
	_draw_icon(art, key)
	return holder

## Um disco cheio (polígono de 16 lados) centrado em (cx,cy).
func _icon_disc(art: Node2D, cx: float, cy: float, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	var disc := Polygon2D.new()
	disc.polygon = pts
	disc.color = color
	art.add_child(disc)

## Um retângulo centrado em (cx,cy), opcionalmente rotacionado em torno do próprio centro.
func _irect(art: Node2D, cx: float, cy: float, w: float, h: float, color: Color, rot := 0.0) -> void:
	var r := ColorRect.new()
	r.color = color
	r.size = Vector2(w, h)
	r.position = Vector2(cx - w * 0.5, cy - h * 0.5)
	if rot != 0.0:
		r.pivot_offset = Vector2(w * 0.5, h * 0.5)
		r.rotation = rot
	art.add_child(r)

func _ipoly(art: Node2D, pts: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	art.add_child(p)

func _draw_icon(art: Node2D, key: String) -> void:
	match key:
		"heart":
			var red := Color(0.87, 0.26, 0.30)
			_irect(art, -4.0, -3.0, 9.0, 9.0, red, deg_to_rad(45.0))
			_irect(art, 4.0, -3.0, 9.0, 9.0, red, deg_to_rad(45.0))
			_ipoly(art, PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(0, 11)]), red)
		"sword":
			var steel := Color(0.80, 0.84, 0.92)
			_irect(art, 0.0, -3.0, 4.0, 22.0, steel)                        # lâmina
			_irect(art, 0.0, 8.0, 15.0, 3.0, Color(0.52, 0.42, 0.24))       # guarda
			_irect(art, 0.0, 12.5, 4.0, 6.0, Color(0.52, 0.42, 0.24))       # cabo
		"bolt":
			_ipoly(art, PackedVector2Array([
				Vector2(3, -14), Vector2(-6, 2), Vector2(0, 2), Vector2(-3, 14),
				Vector2(9, -4), Vector2(2, -4)]), Color(1.0, 0.85, 0.32))
		"flask":
			_draw_flask(art, false)
		"flask_cross":
			_draw_flask(art, true)
		"eye":
			_ipoly(art, PackedVector2Array([
				Vector2(-13, 0), Vector2(0, -7), Vector2(13, 0), Vector2(0, 7)]), Color(0.93, 0.89, 0.80))
			_icon_disc(art, 0.0, 0.0, 5.0, Color(0.22, 0.52, 0.72))
			_icon_disc(art, 0.0, 0.0, 2.2, Color(0.05, 0.05, 0.07))
		"wind":
			for wy in [-6.0, 0.0, 6.0]:
				_irect(art, 0.0, wy, 22.0, 2.5, Color(0.72, 0.86, 0.96))
		"fang":
			_ipoly(art, PackedVector2Array([
				Vector2(-5, -10), Vector2(5, -10), Vector2(0, 10)]), Color(0.91, 0.91, 0.87))
			_icon_disc(art, 0.0, 12.0, 3.0, Color(0.82, 0.20, 0.24))
		"shield":
			var st := Color(0.57, 0.64, 0.80)
			_ipoly(art, PackedVector2Array([
				Vector2(-11, -11), Vector2(11, -11), Vector2(11, 3), Vector2(0, 13), Vector2(-11, 3)]), st)
			_irect(art, 0.0, -1.0, 3.0, 16.0, st.darkened(0.32))
			_irect(art, 0.0, -4.0, 14.0, 3.0, st.darkened(0.32))
		"skull":
			var bone := Color(0.87, 0.85, 0.77)
			_irect(art, 0.0, -3.0, 18.0, 15.0, bone)
			_irect(art, -4.5, -4.0, 5.0, 5.0, Color(0.06, 0.06, 0.08))
			_irect(art, 4.5, -4.0, 5.0, 5.0, Color(0.06, 0.06, 0.08))
			_irect(art, 0.0, 7.0, 10.0, 5.0, bone.darkened(0.12))
		"armor":
			var plate := Color(0.62, 0.68, 0.80)                    # peitoral de aço
			_ipoly(art, PackedVector2Array([
				Vector2(-12, -10), Vector2(-4, -12), Vector2(4, -12), Vector2(12, -10),
				Vector2(9, 10), Vector2(0, 14), Vector2(-9, 10)]), plate)
			_irect(art, 0.0, 0.0, 2.0, 22.0, plate.darkened(0.35))  # emenda central
			_irect(art, -6.0, -6.0, 8.0, 2.0, plate.lightened(0.18), deg_to_rad(-14.0))  # peitoral
			_irect(art, 6.0, -6.0, 8.0, 2.0, plate.lightened(0.18), deg_to_rad(14.0))
		"cloak":
			var pano := Color(0.46, 0.36, 0.72)                     # manto arcano (roxo)
			_ipoly(art, PackedVector2Array([
				Vector2(-7, -12), Vector2(7, -12), Vector2(13, 13), Vector2(0, 8), Vector2(-13, 13)]), pano)
			_ipoly(art, PackedVector2Array([                        # capuz
				Vector2(-8, -9), Vector2(0, -15), Vector2(8, -9), Vector2(0, -6)]), pano.lightened(0.12))
			_icon_disc(art, 0.0, -9.0, 2.2, Color(0.85, 0.80, 0.45))  # fecho dourado
		_:
			_ipoly(art, PackedVector2Array([
				Vector2(0, -13), Vector2(11, 0), Vector2(0, 13), Vector2(-11, 0)]), Color(0.76, 0.71, 0.86))

## Frasco: vidro verde (poção de cura), gargalo e rolha. Com `cross`, uma cruz branca (cura extra).
func _draw_flask(art: Node2D, cross: bool) -> void:
	var vidro := Color(0.55, 0.85, 0.60)
	_ipoly(art, PackedVector2Array([
		Vector2(-8, -2), Vector2(-9, 8), Vector2(-4, 13), Vector2(4, 13), Vector2(9, 8), Vector2(8, -2)]), vidro)
	_irect(art, 0.0, -6.0, 7.0, 9.0, vidro.lightened(0.12))     # gargalo
	_irect(art, 0.0, -11.0, 9.0, 3.0, Color(0.50, 0.40, 0.28))  # rolha
	if cross:
		_irect(art, 0.0, 6.0, 3.0, 9.0, Color(0.96, 0.96, 0.96))
		_irect(art, 0.0, 6.0, 9.0, 3.0, Color(0.96, 0.96, 0.96))

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
