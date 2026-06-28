## Persistência do Fantasma (§2.2.5 / §1.4.4). Lê/grava user://saves/ghosts.json — a única
## coisa que sobrevive ao permadeath. Degradação graciosa: sem arquivo → sem fantasma ativo
## (primeira run de todas). O `graveyard` fica preparado para a variante Hardcore (Fase 5).
class_name GhostRepository
extends RefCounted

const DEFAULT_PATH := "user://saves/ghosts.json"

var _path: String

func _init(path := DEFAULT_PATH) -> void:
	_path = path

## Retorna o fantasma ativo ou null (sem fantasma → boss luta normalmente).
func load_active() -> GhostData:
	var root := _read()
	var active: Variant = root.get("active_ghost", null)
	if typeof(active) != TYPE_DICTIONARY or active.is_empty():
		return null
	return GhostData.from_dict(active)

func has_active() -> bool:
	return load_active() != null

## Grava (sobrescreve) o fantasma ativo, preservando o graveyard existente.
func save_active(ghost: GhostData) -> void:
	var root := _read()
	root["active_ghost"] = ghost.to_dict()
	if not root.has("graveyard"):
		root["graveyard"] = []
	_write(root)

## Cria/sobrescreve o fantasma ativo a partir da morte do jogador (§1.4.4: você sempre
## enfrenta seu fracasso MAIS RECENTE). Retorna o GhostData gerado.
func record_death(player_snapshot: Dictionary, death_floor: int,
		origin_run_id: String, nemesis_coeff: float) -> GhostData:
	var ghost := GhostData.from_snapshot(player_snapshot, death_floor, origin_run_id, nemesis_coeff)
	save_active(ghost)
	return ghost

## Marca o fantasma ativo como derrotado (§1.4.4: não some — vira troféu/registro).
func mark_defeated() -> void:
	var root := _read()
	var active: Variant = root.get("active_ghost", null)
	if typeof(active) == TYPE_DICTIONARY and not active.is_empty():
		active["defeated"] = true
		root["active_ghost"] = active
		_write(root)

# --- IO ---

func _read() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		push_error("[GhostRepository] não foi possível abrir %s" % _path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write(root: Dictionary) -> void:
	_ensure_dir()
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_error("[GhostRepository] não foi possível gravar %s" % _path)
		return
	f.store_string(JSON.stringify(root, "\t"))
	f.close()

func _ensure_dir() -> void:
	var dir := _path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
