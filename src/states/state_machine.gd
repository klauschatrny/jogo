## Máquina de estados stack-based (§2.1). Estados podem ser empilhados — ex.: Pause
## sobre Combat sem perder o contexto de baixo. Lógica pura, testável sem render.
class_name StateMachine
extends RefCounted

signal state_changed(state_name: String)

var _stack: Array[GameState] = []

## Estado no topo da pilha (o ativo), ou null se vazia.
func current() -> GameState:
	return _stack.back() if not _stack.is_empty() else null

## Troca o topo da pilha por um novo estado.
func change(state: GameState) -> void:
	if not _stack.is_empty():
		_stack.back().exit()
		_stack.pop_back()
	push(state)

## Empilha um novo estado por cima do atual (ex.: Pause).
func push(state: GameState) -> void:
	state.machine = self
	_stack.push_back(state)
	state.enter()
	state_changed.emit(state.state_name)

## Desempilha o estado do topo, voltando ao anterior.
func pop() -> void:
	if not _stack.is_empty():
		_stack.back().exit()
		_stack.pop_back()
	if not _stack.is_empty():
		state_changed.emit(_stack.back().state_name)

func update(delta: float) -> void:
	if not _stack.is_empty():
		_stack.back().update(delta)

func handle_input(event: InputEvent) -> void:
	if not _stack.is_empty():
		_stack.back().handle_input(event)

func size() -> int:
	return _stack.size()
