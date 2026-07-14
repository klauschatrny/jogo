## Apresentação do Eco — a marca de sangue. Estende o EnemyView: é um inimigo de IA "echo"
## (persegue + golpe básico) construído a partir de um snapshot SEU no momento da morte
## (GhostFactory: stats nerfados pelas regras Nemesis). Ele guarda as almas que você derrubou.
##
## Visual: a sua própria arte, sob um FILTRO VERMELHO translúcido — você reconhece a silhueta, e
## a cor diz que aquilo ali não é mais você.
class_name GhostView
extends EnemyView

func setup(enemy: Enemy, target_node: Node2D) -> void:
	super.setup(enemy, target_node)
	box_size = 22.0   # footprint do eco/elite (base 640×360)
	body_color = Color(Palette.GHOST, 0.7)   # placeholder (sem arte)
	# O eco é o fantasma do jogador: empresta a arte "player" (id próprio é único, sem PNG).
	sprite_id_override = "player"
	sprite_subdir = "player"
	# O filtro vai no MODULATE DO NÓ (não do sprite): multiplica por cima da arte e sobrevive ao
	# flash de dano, que usa o modulate do próprio sprite e o devolve para branco.
	modulate = Color(Palette.GHOST, 0.7)
