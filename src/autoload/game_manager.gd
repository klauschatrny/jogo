## Autoload. Bootstrap do jogo: instancia a StateMachine e encaminha o estado inicial.
## Carregado por último (depende de BalanceConfig, EventBus, RNGService).
extends Node

var state_machine: StateMachine

func _ready() -> void:
	_setup_input_actions()
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

## Registra as ações de input via código (mais robusto que editar o formato do
## project.godot à mão). Só teclado nesta fase: WASD/setas para mover, Espaço/J ataca.
func _setup_input_actions() -> void:
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("attack", [KEY_SPACE, KEY_J])

func _ensure_action(action: String, physical_keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in physical_keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
