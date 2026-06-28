## Runner de testes headless. Rode com:
##   godot --headless --script res://tests/test_runner.gd
## Sai com código 0 se tudo passar, 1 se houver falhas (bom para CI).
extends SceneTree

const SUITES := {
	"RNGService": "res://tests/test_rng_service.gd",
	"BalanceConfig": "res://tests/test_balance_config.gd",
	"StateMachine": "res://tests/test_state_machine.gd",
	"JsonLoader": "res://tests/test_json_loader.gd",
}

func _initialize() -> void:
	var total := 0
	var failed := 0
	print("\n===== Rodando testes =====")

	for suite_name in SUITES:
		var script: GDScript = load(SUITES[suite_name])
		var suite: TestCase = script.new()
		for method in suite.get_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			suite._reset()
			suite.call(mname)
			if suite._errors.is_empty():
				print("  [PASS] %s.%s" % [suite_name, mname])
			else:
				failed += 1
				print("  [FAIL] %s.%s" % [suite_name, mname])
				for err in suite._errors:
					print("         -> %s" % err)

	print("\n%d teste(s), %d falha(s)" % [total, failed])
	print("==========================\n")
	quit(1 if failed > 0 else 0)
