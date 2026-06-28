## Repositório de bosses (data/bosses/*.json). Hidrata em instâncias de Boss.
class_name BossRepository
extends BaseRepository

func _init() -> void:
	super("res://data/bosses")

## Retorna uma nova instância de Boss a partir do id, ou null se não existir.
func get_boss(id: String) -> Boss:
	var d := get_by_id(id)
	return Boss.from_dict(d) if not d.is_empty() else null
