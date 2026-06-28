## Tela de recompensa (§3.5): mostra 3 cards de Augment com cor por tier (§1.3.1) e deixa
## o jogador escolher 1 pelas teclas 1/2/3. Emite `chosen` com o augment selecionado.
class_name CardSelect
extends Control

signal chosen(aug: Augment)

var _cards: Array = []

func setup(cards: Array) -> void:
	_cards = cards

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title := Label.new()
	title.text = "ESCOLHA UMA CARTA  (1 / 2 / 3)"
	title.position = Vector2(170, 50)
	add_child(title)

	var card_w := 150
	var card_h := 190
	var gap := 20
	var total := _cards.size() * card_w + (_cards.size() - 1) * gap
	var start_x := (640 - total) / 2

	for i in _cards.size():
		add_child(_make_card(_cards[i], i, start_x + i * (card_w + gap), card_w, card_h))

func _make_card(aug: Augment, index: int, x: int, w: int, h: int) -> Control:
	var panel := Control.new()
	panel.position = Vector2(x, 100)
	panel.size = Vector2(w, h)

	var bg := ColorRect.new()
	bg.size = Vector2(w, h)
	bg.color = _tier_color(aug.tier)
	panel.add_child(bg)

	var name_label := Label.new()
	name_label.text = "%d. %s" % [index + 1, aug.name]
	name_label.position = Vector2(8, 8)
	name_label.size = Vector2(w - 16, 44)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = aug.description
	desc_label.position = Vector2(8, 58)
	desc_label.size = Vector2(w - 16, h - 86)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_label)

	var tier_label := Label.new()
	tier_label.text = aug.tier
	tier_label.position = Vector2(8, h - 24)
	panel.add_child(tier_label)

	return panel

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
		KEY_1:
			idx = 0
		KEY_2:
			idx = 1
		KEY_3:
			idx = 2
	if idx >= 0 and idx < _cards.size():
		accept_event()
		chosen.emit(_cards[idx])
