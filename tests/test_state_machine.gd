extends TestCase

## Estado de teste que registra entradas/saídas num log compartilhado.
class DummyState extends GameState:
	var log_ref: Array
	func _init(n: String, l: Array) -> void:
		state_name = n
		log_ref = l
	func enter() -> void:
		log_ref.append("enter:" + state_name)
	func exit() -> void:
		log_ref.append("exit:" + state_name)

func test_push_empilha() -> void:
	var sm := StateMachine.new()
	var log: Array = []
	sm.push(DummyState.new("A", log))
	assert_eq(sm.size(), 1)
	sm.push(DummyState.new("B", log))
	assert_eq(sm.size(), 2)
	assert_eq(sm.current().state_name, "B")

func test_pop_volta_ao_anterior() -> void:
	var sm := StateMachine.new()
	var log: Array = []
	sm.push(DummyState.new("A", log))
	sm.push(DummyState.new("B", log))
	sm.pop()
	assert_eq(sm.size(), 1)
	assert_eq(sm.current().state_name, "A")
	assert_true(log.has("exit:B"), "B deveria ter saído")

func test_change_troca_o_topo() -> void:
	var sm := StateMachine.new()
	var log: Array = []
	sm.push(DummyState.new("A", log))
	sm.change(DummyState.new("B", log))
	assert_eq(sm.size(), 1, "change não deve aumentar a pilha")
	assert_eq(sm.current().state_name, "B")
	assert_true(log.has("exit:A"), "A deveria ter saído")
	assert_true(log.has("enter:B"), "B deveria ter entrado")

func test_pilha_vazia_e_segura() -> void:
	var sm := StateMachine.new()
	assert_null(sm.current(), "pilha vazia retorna null")
	sm.pop()  # não deve quebrar
	sm.update(0.016)  # não deve quebrar
	assert_eq(sm.size(), 0)

func test_injeta_referencia_da_maquina() -> void:
	var sm := StateMachine.new()
	var state := DummyState.new("A", [])
	sm.push(state)
	assert_eq(state.machine, sm, "push deve injetar a referência da máquina")
