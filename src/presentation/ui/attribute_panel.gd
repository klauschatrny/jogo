## Painel da fogueira — abre ao descansar. É o único lugar onde as ALMAS viram poder.
##
## Um clique, um efeito: o botão "+" de um atributo o sobe em um. Se você ainda tiver um ponto
## guardado, ele é gasto; se não tiver, o nível é COMPRADO com almas na hora (e o ponto que ele
## gera vai direto para o atributo). O jogador não precisa entender os dois passos — só vê
## "almas entram, atributo sobe".
##
## Gasto é definitivo. E é aqui que a aposta se fecha: alma no bolso é risco (morrer a entrega ao
## Eco); alma gasta é sua para sempre. A decisão de quando voltar à fogueira É o jogo.
##
## Só MOUSE sobe atributo (o "+" de cada linha); o teclado só fecha (B levanta). Roda com a
## árvore PAUSADA — quem o abre pausa e ouve `closed` para despausar.
class_name AttributePanel
extends Control

signal closed

var _player: Player
var _rows: Array = []          # [{ id, name, value, plus }]
var _points_lbl: Label
var _hint_lbl: Label

func setup(player: Player) -> void:
	_player = player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ..._and_offsets_: só as âncoras deixariam o retângulo com tamanho ZERO (o pai é um
	# CanvasLayer, não um Control) e o escurecimento não apareceria.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var frame := ColorRect.new()
	frame.color = Palette.BG.darkened(0.25)
	frame.position = Vector2(60, 52)
	frame.size = Vector2(520, 256)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var edge := ColorRect.new()          # a moldura pega a cor do fogo
	edge.color = Color(1.0, 0.62, 0.2)
	edge.position = frame.position + Vector2(0, -2)
	edge.size = Vector2(frame.size.x, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(80, 64)
	box.custom_minimum_size = Vector2(480, 0)
	add_child(box)

	# Fonte: 32 no título e 16 no resto — o nativo da Pixel Operator (e o dobro dele).
	# Qualquer outro tamanho sai borrado/ilegível na base 640×360.
	var title := Label.new()
	title.text = "FOGUEIRA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	box.add_child(title)

	_points_lbl = Label.new()
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_points_lbl)
	box.add_child(_spacer(8))

	for s in Attributes.specs():
		box.add_child(_build_row(String(s.get("id", "")), String(s.get("name", "")),
			String(s.get("desc", ""))))

	box.add_child(_spacer(8))
	_hint_lbl = Label.new()
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_color_override("font_color", Palette.TEXT.darkened(0.4))
	box.add_child(_hint_lbl)

	_refresh()

## Uma linha: NOME  valor  [+]  (o que faz). O botão "+" sobe ESTE atributo com o mouse.
func _build_row(id: String, nome: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = nome
	name_lbl.custom_minimum_size = Vector2(130, 0)
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(52, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(value_lbl)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 22)
	plus.focus_mode = Control.FOCUS_NONE          # sem foco de teclado: o "+" é só do mouse
	plus.process_mode = Node.PROCESS_MODE_ALWAYS  # o painel roda com a árvore pausada
	plus.add_theme_font_size_override("font_size", 16)
	plus.pressed.connect(_raise.bind(id))
	row.add_child(plus)

	var gain_lbl := Label.new()
	gain_lbl.text = desc
	gain_lbl.add_theme_color_override("font_color", Palette.TEXT.darkened(0.45))
	gain_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gain_lbl)

	_rows.append({ "id": id, "name": name_lbl, "value": value_lbl, "plus": plus })
	return row

## Dá para subir um atributo agora? Ou há um ponto guardado, ou há almas para comprar o nível.
func _can_raise() -> bool:
	return _player.attribute_points > 0 or Leveling.can_level_up(_player)

func _refresh() -> void:
	# Texto curto: na fonte 16, cada caractere tem ~8px — a linha precisa caber nos 404px do box.
	var pts := _player.attribute_points
	var custo := Leveling.level_cost(_player.level)
	_points_lbl.text = "NÍVEL %d    ALMAS %d    PRÓXIMO %d" % [
		_player.level, _player.souls, custo]
	if pts > 0:
		_points_lbl.text += "    PONTOS %d" % pts
	_points_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.72, 0.28) if _can_raise() else Palette.TEXT.darkened(0.4))

	var pode := _can_raise()
	for r in _rows:
		var value_lbl: Label = r["value"]
		var plus: Button = r["plus"]
		value_lbl.text = str(_player.attribute(String(r["id"])))
		plus.disabled = not pode                 # sem almas/ponto, o "+" fica inerte e apagado

	# Sem almas/ponto o "+" já aparece desabilitado — não precisa de aviso em texto.
	_hint_lbl.text = "clique no  +  para subir     %s  levantar" % KeyBinds.key_name("ui_cancel")

## Teclado só FECHA o painel (B) — subir atributo é exclusivo do mouse (o "+" de cada linha).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Consumimos o evento para quem abriu o painel não reagir a ele no mesmo frame.
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

## Sobe um atributo. Sem ponto guardado, compra o nível com almas primeiro — para quem joga, é uma
## tecla só: as almas saem e o atributo sobe.
func _raise(id: String) -> void:
	if _player.attribute_points <= 0 and not Leveling.level_up(_player):
		return                                  # nem ponto, nem almas
	if _player.spend_point(id):
		Sfx.play(SPEND_SFX)
		_refresh()

const SPEND_SFX := ""      # id em data/audio.json quando houver um som de "subir atributo"

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
