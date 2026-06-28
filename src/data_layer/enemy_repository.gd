## Repositório de inimigos e bosses (data/enemies/*.json, data/bosses/*.json).
## Vazio na Fase 1 — populado na Fase 2/3.
class_name EnemyRepository
extends BaseRepository

func _init() -> void:
	super("res://data/enemies")

## Retorna uma nova instância de Enemy a partir do id, ou null se não existir.
func get_enemy(id: String) -> Enemy:
	var d := get_by_id(id)
	return Enemy.from_dict(d) if not d.is_empty() else null
