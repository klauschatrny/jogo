## Rede de segurança da APRESENTAÇÃO. A suíte cobre o core, mas nunca carregava as views nem a
## floor_scene — então erro de compilação ali (identificador inexistente, função removida,
## ternário virando Variant) passava por todos os testes e só um probe descartável pegava. Isto
## carrega TODO script .gd de src/ e falha se algum não compilar.
##
## Carregar NÃO roda _init/_ready: só compila. Autoloads (Sfx, EventBus...) já estão registrados
## como nomes globais quando os testes rodam, então scripts que os usam compilam normalmente.
extends TestCase

const RAIZ := "res://src"

func test_todo_script_de_src_compila() -> void:
	var arquivos := _gd_recursivo(RAIZ)
	assert_true(arquivos.size() > 0, "nenhum .gd encontrado em %s" % RAIZ)
	for caminho in arquivos:
		var res := load(caminho)
		assert_true(res != null, "FALHOU A COMPILAR: %s" % caminho)
		if res is GDScript:
			assert_true((res as GDScript).can_instantiate() or _e_estatico(res),
				"compilou mas não instancia: %s" % caminho)

## Um script "estático" (só const/static, sem herdar Node/RefCounted instanciável) pode não
## instanciar sem que seja erro. Raro aqui; a checagem acima já pega o essencial (res == null).
func _e_estatico(_res: GDScript) -> bool:
	return false

func _gd_recursivo(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		if nome.begins_with("."):
			nome = d.get_next()
			continue
		var caminho := dir.path_join(nome)
		if d.current_is_dir():
			out.append_array(_gd_recursivo(caminho))
		elif nome.ends_with(".gd"):
			out.append(caminho)
		nome = d.get_next()
	d.list_dir_end()
	return out
