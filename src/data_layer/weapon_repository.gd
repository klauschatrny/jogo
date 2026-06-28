## Repositório do arsenal (data/weapons/*.json). Hidrata os JSON em instâncias de Weapon.
class_name WeaponRepository
extends BaseRepository

func _init() -> void:
	super("res://data/weapons")

## Retorna uma nova instância de Weapon a partir do id, ou null se não existir.
func get_weapon(id: String) -> Weapon:
	var d := get_by_id(id)
	return Weapon.from_dict(d) if not d.is_empty() else null
