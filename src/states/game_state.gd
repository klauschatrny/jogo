## Classe base de todo estado de jogo (§2.1). Subclasses sobrescrevem o ciclo de vida.
## É lógica pura (RefCounted): não conhece cenas nem render diretamente.
class_name GameState
extends RefCounted

## Nome legível do estado (usado em logs e no sinal state_changed).
var state_name: String = "GameState"

## Referência à máquina que gerencia este estado (injetada no push/change).
var machine: StateMachine

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
