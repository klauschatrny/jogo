## Autoload. Bootstrap do jogo: instancia a StateMachine e encaminha o estado inicial.
## Carregado por último (depende de BalanceConfig, EventBus, RNGService).
extends Node

var state_machine: StateMachine

func _ready() -> void:
	_setup_input_actions()
	# Tema retrô global (fonte bitmap): na janela raiz + no fallback do ThemeDB (este último é o
	# que cobre os Controls sob CanvasLayer — HUD, pausa, painéis; ver RetroTheme.apply). Vale
	# para toda a UI e persiste entre trocas de cena. Em --script/--headless não há janela.
	RetroTheme.apply(get_tree().root)
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
## project.godot à mão). Side-scroller: A/D anda, Espaço/W pula, J ataca, Shift/L
## esquiva. SEM setas: o layout padrão é mão esquerda no WASD, mão direita nos golpes
## (e tudo é remapeável na aba CONTROLES — KeyBinds). move_up/down ficam registradas
## (não usadas no movimento lateral) para não quebrar menus/UI que dependam delas.
func _setup_input_actions() -> void:
	_ensure_action("move_up", [KEY_W])
	_ensure_action("move_down", [KEY_S])
	_ensure_action("move_left", [KEY_A])
	_ensure_action("move_right", [KEY_D])
	_ensure_action("attack", [KEY_J])
	_ensure_action("jump", [KEY_SPACE, KEY_W])
	_ensure_action("dodge", [KEY_SHIFT])
	_ensure_action("interact", [KEY_E])          # descansar na fogueira
	_ensure_action("flask", [KEY_R])             # beber o frasco de cura (o Estus)
	# ui_cancel (pausar/fechar painéis) sai do ESC padrão e passa para B.
	_rebind_action("ui_cancel", [KEY_B])

func _ensure_action(action: String, physical_keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in physical_keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

## Redefine as teclas de uma ação que JÁ existe (ex.: as ui_* embutidas do Godot, criadas antes
## de _setup_input_actions). Limpa os eventos atuais e liga só as teclas pedidas.
func _rebind_action(action: String, physical_keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for k in physical_keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
