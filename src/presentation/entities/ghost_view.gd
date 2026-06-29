## Apresentação do Fantasma/Eco (§1.4 / §2.2.5). Estende o EnemyView: é um inimigo comum
## de IA "echo" (persegue + golpe básico), com visual azulado translúcido para se distinguir
## do boss. A construção do Enemy "eco" (stats nerfados, regras Nemesis) vem do GhostFactory.
class_name GhostView
extends EnemyView

func setup(enemy: Enemy, target_node: Node2D) -> void:
	super.setup(enemy, target_node)
	box_size = 66.0   # (= 22 × 3, viewport 1920×1080)
	body_color = Color(Palette.GHOST, 0.7)   # eco: ciano translúcido
