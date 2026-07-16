## A mancha de sangue (bloodstain, à la Dark Souls). Marcador PASSIVO — não é um inimigo: fica no
## ponto exato da queda com as almas que você tinha, e some quando você a toca (recolhe automático,
## sem tecla, como no Dark Souls). O ESTADO (onde, quantas almas) vive no RunState; este nó só
## desenha e diz se o player está em cima dela.
##
## Visual (placeholder, sem arte): uma poça vermelho-escura no chão com um brilho que pulsa por seno
## e algumas fagulhas de alma pairando — o suficiente para se ler de longe como "suas almas estão ali".
class_name BloodstainView
extends Node2D

const REACH := 22.0              # tem de andar EM CIMA dela para recolher (base 640×360)

var pos_x := 0.0
var souls := 0

var _player: Node2D
var _glow: ColorRect
var _wisps: Array = []           # fagulhas de alma (ColorRect) que sobem e reaparecem
var _prompt: Label
var _t := 0.0

func setup(x: float, soul_count: int, player: Node2D) -> void:
	pos_x = x
	souls = soul_count
	_player = player
	position.x = x
	_build()

func _build() -> void:
	z_index = -2                  # à frente do chão e dos enfeites, atrás das entidades

	# Halo avermelhado fraco, que denuncia a mancha à distância.
	_glow = ColorRect.new()
	_glow.color = Color(0.75, 0.10, 0.12, 0.16)
	_glow.size = Vector2(40.0, 26.0)
	_glow.position = Vector2(-20.0, -20.0)
	add_child(_glow)

	# A poça: um polígono baixo e irregular, vermelho-escuro coagulado.
	var pool := Polygon2D.new()
	pool.color = Color(0.36, 0.05, 0.07)
	pool.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(-12, -5), Vector2(-3, -7),
		Vector2(7, -6), Vector2(15, -2), Vector2(12, 0),
	])
	add_child(pool)
	var pool_hi := Polygon2D.new()
	pool_hi.color = Color(0.58, 0.08, 0.10)
	pool_hi.polygon = PackedVector2Array([
		Vector2(-8, -2), Vector2(-2, -5), Vector2(5, -4), Vector2(3, -1),
	])
	add_child(pool_hi)

	# Fagulhas de alma pairando por cima (as mesmas almas que você perdeu, "reunidas" ali).
	for i in 4:
		var w := ColorRect.new()
		w.color = Color(0.85, 0.92, 1.0, 0.85)
		w.size = Vector2(2.0, 2.0)
		add_child(w)
		_wisps.append(w)

	_prompt = Label.new()
	# fonte 16 (nativa da bitmap — menor sai ilegível)
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(160.0, 18.0)
	_prompt.position = Vector2(-80.0, -48.0)
	_prompt.visible = false
	add_child(_prompt)

func _process(delta: float) -> void:
	_t += delta
	# Halo pulsando devagar.
	if _glow != null:
		_glow.modulate.a = 0.7 + 0.3 * sin(_t * 3.0)
	# Fagulhas sobem e reaparecem embaixo, defasadas — dá a sensação de almas inquietas.
	for i in _wisps.size():
		var w: ColorRect = _wisps[i]
		var phase := _t * 0.8 + float(i) * 0.7
		var up := fposmod(phase, 1.0)               # 0..1 sobe
		w.position = Vector2(-10.0 + float(i) * 6.0 + 2.0 * sin(phase * 4.0), -2.0 - up * 22.0)
		w.modulate.a = 1.0 - up                     # some ao chegar no topo
	# Aviso só quando o player está EM CIMA (o recolhimento é automático — ver floor_scene).
	if _prompt != null and is_instance_valid(_player):
		_prompt.visible = in_reach(_player)
		_prompt.text = "%d almas" % souls

## O player está em cima da marca (o bastante para recolher)?
func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH
