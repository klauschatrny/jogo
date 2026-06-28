## Autoload. Bootstrap do jogo: instancia a StateMachine e encaminha o estado inicial.
## Carregado por último (depende de BalanceConfig, EventBus, RNGService).
extends Node

var state_machine: StateMachine

func _ready() -> void:
	print("[GameManager] Bootstrap iniciado")
	print("[GameManager] Seed do RNG: %d" % RNGService.get_seed())
	print("[GameManager] balance.json carregado (BASE_HP=%s, NEMESIS_COEFF=%s)" % [
		BalanceConfig.enemy_scaling.get("BASE_HP"),
		BalanceConfig.nemesis.get("NEMESIS_COEFF")])

	state_machine = StateMachine.new()
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.push(MainMenuState.new())

func _process(delta: float) -> void:
	if state_machine:
		state_machine.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if state_machine:
		state_machine.handle_input(event)

func _on_state_changed(state_name: String) -> void:
	print("[GameManager] Estado -> %s" % state_name)
	EventBus.state_changed.emit(state_name)
