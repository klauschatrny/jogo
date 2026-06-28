## Repositório de augments (data/augments/*.json). Vazio na Fase 1 — populado na Fase 3.
class_name AugmentRepository
extends BaseRepository

func _init() -> void:
	super("res://data/augments")

## Retorna uma nova instância de Augment a partir do id, ou null se não existir.
func get_augment(id: String) -> Augment:
	var d := get_by_id(id)
	return Augment.from_dict(d) if not d.is_empty() else null

## Retorna todos os augments hidratados (para alimentar o AugmentPool).
func all_augments() -> Array:
	var out: Array = []
	for d in all():
		out.append(Augment.from_dict(d))
	return out
