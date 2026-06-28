## Carrega e valida arquivos JSON de `data/`, convertendo-os em Variant (Dictionary/Array).
## Camada pura: não depende de render. Usado por BalanceConfig e pelos repositórios.
class_name JsonLoader
extends RefCounted

## Lê e parseia um único arquivo JSON. Retorna o dado (geralmente Dictionary) ou null em erro.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[JsonLoader] Arquivo não encontrado: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[JsonLoader] Falha ao abrir (%d): %s" % [FileAccess.get_open_error(), path])
		return null
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[JsonLoader] JSON inválido em %s (linha %d): %s" % [
			path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

## Carrega todos os arquivos *.json de um diretório. Retorna um Array dos dados parseados.
static func load_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[JsonLoader] Diretório não encontrado: %s" % dir_path)
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "json":
			var data: Variant = load_file(dir_path.path_join(fname))
			if data != null:
				out.append(data)
		fname = dir.get_next()
	dir.list_dir_end()
	return out
