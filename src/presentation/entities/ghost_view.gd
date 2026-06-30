## Apresentação do Fantasma/Eco (§1.4 / §2.2.5). Estende o EnemyView: é um inimigo comum
## de IA "echo" (persegue + golpe básico), com visual azulado translúcido para se distinguir
## do boss. A construção do Enemy "eco" (stats nerfados, regras Nemesis) vem do GhostFactory.
class_name GhostView
extends EnemyView

func setup(enemy: Enemy, target_node: Node2D) -> void:
	super.setup(enemy, target_node)
	box_size = 22.0   # footprint do eco/elite (base 640×360)
	body_color = Color(Palette.GHOST, 0.7)   # eco: ciano translúcido (placeholder, sem arte)
	# O eco é o fantasma do jogador: empresta a arte "player" (id próprio é único, sem PNG).
	sprite_id_override = "player"
	sprite_subdir = "player"
	# Tom ciano translúcido no MODULATE DO NÓ (não do sprite): multiplica por cima da arte e
	# sobrevive ao flash de dano (que usa o modulate do próprio sprite e volta pra branco).
	modulate = Color(Palette.GHOST, 0.7)
