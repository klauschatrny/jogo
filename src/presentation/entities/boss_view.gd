## Apresentação do boss (§2.3 / §2.2.4). Estende o EnemyView: maior, cor própria, e reage
## às fases via on_damaged() do Core (ex.: "enrage" tinge de vermelho). A invocação do
## Fantasma ("summon_ghost") é tratada na Fase 4 — por ora é ignorada aqui.
class_name BossView
extends EnemyView

## Emitido quando o boss cruza o limiar de invocação do Fantasma (§1.4.2 Regra 5). Quem
## decide se há um eco para invocar (e o cria) é a cena, via NemesisRules/GhostFactory.
signal summon_ghost

func setup(enemy: Enemy, target_node: Node2D) -> void:
	super.setup(enemy, target_node)
	box_size = 102.0   # (= 34 × 3, viewport 1920×1080)
	body_color = Palette.BOSS
	sprite_subdir = "bosses"   # arte de boss vem de assets/sprites/bosses/<id>.png

func _on_after_damage() -> void:
	if data is Boss:
		for ev in (data as Boss).on_damaged():
			match ev:
				"enrage":
					modulate = Color(1.5, 0.6, 0.6)
				"summon_ghost":
					summon_ghost.emit()
