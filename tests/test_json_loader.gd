extends TestCase

func test_load_file_balance() -> void:
	var data: Variant = JsonLoader.load_file("res://data/balance.json")
	assert_true(typeof(data) == TYPE_DICTIONARY, "balance.json deve virar Dictionary")
	assert_true(data.has("enemy_scaling"), "deve conter a seção enemy_scaling")

func test_arquivo_inexistente_retorna_null() -> void:
	var data: Variant = JsonLoader.load_file("res://data/__nao_existe__.json")
	assert_null(data, "arquivo inexistente deve retornar null")

func test_load_dir_vazio_retorna_array() -> void:
	# data/weapons está vazio na Fase 1; deve retornar Array (não quebrar).
	var arr := JsonLoader.load_dir("res://data/weapons")
	assert_true(typeof(arr) == TYPE_ARRAY, "load_dir deve retornar Array")
	assert_eq(arr.size(), 0, "pasta sem JSON retorna lista vazia")
