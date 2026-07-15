## Névoa do chefe (fog gate). Parede de bruma na entrada da arena do boss: o jogador chega, aperta
## INTERAGIR (E/F) e atravessa. Não barra fisicamente (a parede do fim do nível segura o player
## ali) — é um limiar: cruzá-la é uma decisão, não um tropeço. Só desenha e diz se está no alcance;
## quem faz a travessia (o fade para a arena) é o floor_scene.
class_name FogGateView
extends Node2D

const REACH := 46.0              # distância para atravessar (base 640×360)
const W := 44.0                  # largura da cortina de névoa
const H := 108.0                 # altura

var _player: Node2D
var _bands: Array = []           # faixas de bruma (alfas animados por seno)
var _prompt: Label
var _t := 0.0

func setup(x: float, player: Node2D) -> void:
	position.x = x
	_player = player
	_build()

func _build() -> void:
	z_index = 60                 # à FRENTE das entidades: a névoa cobre quem entra nela

	# Umbral de pedra dos dois lados (marca que ali há uma passagem).
	for side in [-1.0, 1.0]:
		var jamb := ColorRect.new()
		jamb.color = Color(0.20, 0.19, 0.24)
		jamb.size = Vector2(5.0, H + 6.0)
		jamb.position = Vector2(side * (W * 0.5) - (0.0 if side < 0 else 5.0), -H - 6.0)
		jamb.z_index = -1
		add_child(jamb)

	# Cortina de bruma: várias faixas translúcidas sobrepostas, de larguras e alturas ligeiramente
	# diferentes, cada uma pulsando num ritmo próprio — dá o bruxuleio de fumaça sem shader.
	for i in 5:
		var band := ColorRect.new()
		band.color = Color(0.82, 0.86, 0.95)
		var bw := W - i * 3.0
		band.size = Vector2(bw, H)
		band.position = Vector2(-bw * 0.5, -H)
		add_child(band)
		_bands.append(band)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(96.0, 10.0)
	_prompt.position = Vector2(-48.0, -H - 20.0)
	_prompt.visible = false
	add_child(_prompt)

func _process(delta: float) -> void:
	_t += delta
	# Bruma viva: cada faixa oscila o alfa e desliza de leve na horizontal, em fases distintas.
	for i in _bands.size():
		var band: ColorRect = _bands[i]
		var ph := float(i) * 1.3
		band.modulate.a = 0.18 + 0.12 * sin(_t * (1.6 + i * 0.25) + ph)
		band.position.x = -band.size.x * 0.5 + 2.5 * sin(_t * (0.9 + i * 0.2) + ph)

	if _prompt != null and is_instance_valid(_player):
		_prompt.visible = in_reach(_player)
		_prompt.text = "E  atravessar a névoa"

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH
