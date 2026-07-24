## Baú do tesouro no fim da sala de boss (diante do trono): guarda a recompensa — os augments da sala.
## Fechado e pulsando um convite dourado até o player chegar perto e apertar INTERAGIR. Ao abrir, a
## tampa levanta, solta um clarão e emite `opened` (o floor_scene então mostra as cartas). Abre UMA vez.
class_name TreasureChestView
extends Node2D

signal opened

const REACH := 46.0

var _player: Node2D
var _prompt: Label
var _lid: Node2D
var _glow: ColorRect
var _open := false
var _t := 0.0

func setup(x: float, player: Node2D) -> void:
	position.x = x
	_player = player
	_build()

func _build() -> void:
	z_index = -2                         # à frente do chão/trono, atrás das entidades
	var madeira := Color(0.42, 0.29, 0.16)
	var madeira_dk := Color(0.27, 0.18, 0.10)
	var ferro := Color(0.72, 0.62, 0.30)   # ferragens douradas

	_glow = ColorRect.new()              # halo dourado (pulsa fechado; clarão ao abrir)
	_glow.color = Color(1.0, 0.85, 0.35, 0.0)
	_glow.size = Vector2(64, 64)
	_glow.position = Vector2(-32, -56)
	add_child(_glow)

	var corpo := ColorRect.new()
	corpo.color = madeira
	corpo.size = Vector2(42, 22)
	corpo.position = Vector2(-21, -22)
	add_child(corpo)
	for rx: float in [-14.0, 0.0, 14.0]:      # ripas verticais
		var ripa := ColorRect.new()
		ripa.color = madeira_dk
		ripa.size = Vector2(3, 22)
		ripa.position = Vector2(rx - 1.5, -22)
		add_child(ripa)
	var fechadura := ColorRect.new()
	fechadura.color = ferro
	fechadura.size = Vector2(6, 7)
	fechadura.position = Vector2(-3, -15)
	add_child(fechadura)

	# Tampa: nó articulado na dobradiça de trás (levanta ao abrir).
	_lid = Node2D.new()
	_lid.position = Vector2(0, -22)
	add_child(_lid)
	var tampa := ColorRect.new()
	tampa.color = madeira.lightened(0.06)
	tampa.size = Vector2(42, 10)
	tampa.position = Vector2(-21, -10)
	_lid.add_child(tampa)
	var borda := ColorRect.new()
	borda.color = ferro
	borda.size = Vector2(42, 3)
	borda.position = Vector2(-21, -10)
	_lid.add_child(borda)

	_prompt = Label.new()
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(140, 18)
	_prompt.position = Vector2(-70, -52)
	_prompt.visible = false
	add_child(_prompt)

func _process(delta: float) -> void:
	if _open:
		return                           # aberto: o tween cuida do clarão; nada a atualizar
	_t += delta
	_glow.color.a = 0.10 + 0.06 * sin(_t * 4.0)   # pulsação de convite (loot beacon)
	if _prompt != null and is_instance_valid(_player):
		var near := absf(_player.global_position.x - global_position.x) <= REACH
		_prompt.visible = near
		if near:
			_prompt.text = "%s  abrir" % KeyBinds.key_name("interact")

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

## Já aberto? (evita reabrir / re-disparar a recompensa)
func is_open() -> bool:
	return _open

func open() -> void:
	if _open:
		return
	_open = true
	if _prompt != null:
		_prompt.visible = false
	var tw := create_tween()             # a tampa levanta com um leve overshoot
	tw.tween_property(_lid, "rotation", deg_to_rad(-74.0), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_glow.color = Color(1.0, 0.88, 0.42, 0.65)   # clarão dourado que decai
	var gw := create_tween()
	gw.tween_property(_glow, "color:a", 0.16, 0.6)
	opened.emit()
