## Runner do simulador de balanceamento (§1.2.4). NÃO é teste unitário — é uma ferramenta
## de tuning: para cada andar amostrado calcula os TTKs de um jogador mediano e sinaliza o
## que sai da banda (ttk_targets do balance.json). Re-rode após mudar qualquer constante.
##
## Rodar:
##   godot --headless --path <proj> --script res://tests/sim_balance.gd
##
## Runner fino de propósito: a lógica vive em balance_sim.gd, carregada via load() em runtime,
## porque referencia classes do Core que dependem de autoloads (indisponíveis como nomes
## globais no compile-time do modo --script). Mesmo padrão do test_runner.gd.
extends SceneTree

func _initialize() -> void:
	var ttk: Dictionary = {}
	var bc := root.get_node_or_null("BalanceConfig")
	if bc:
		bc.load_balance()
		ttk = bc.ttk_targets

	var sim: RefCounted = load("res://tests/balance_sim.gd").new()
	var flags: int = sim.run(ttk)
	quit(0 if flags == 0 else 0)   # informativo: sempre 0 (relatório, não pass/fail de CI)
