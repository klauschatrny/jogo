## Repositório base data-driven: carrega todos os JSON de um diretório e os indexa por "id".
## Na Fase 1 guarda os dados como Dictionary; quando as classes do Core existirem
## (Fase 2+), as subclasses sobrescrevem `_hydrate()` para devolver instâncias tipadas.
class_name BaseRepository
extends RefCounted

var _dir: String
var _items: Dictionary = {}  # id: String -> Dictionary

func _init(dir_path: String) -> void:
	_dir = dir_path

## Recarrega o diretório do zero. Entradas sem "id" são ignoradas com aviso.
func load_all() -> void:
	_items.clear()
	for entry in JsonLoader.load_dir(_dir):
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
			_items[entry["id"]] = entry
		else:
			push_warning("[%s] Entrada sem 'id' ignorada em %s" % [
				get_script().resource_path.get_file(), _dir])

func get_by_id(id: String) -> Dictionary:
	return _items.get(id, {})

func has(id: String) -> bool:
	return _items.has(id)

func all() -> Array:
	return _items.values()

func ids() -> Array:
	return _items.keys()

func count() -> int:
	return _items.size()
