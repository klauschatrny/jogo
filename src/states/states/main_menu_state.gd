## Estado inicial após o Boot (§2.1). Na Fase 1 apenas registra entrada/saída;
## a navegação para CharacterCreation será adicionada na Fase 2+.
class_name MainMenuState
extends GameState

func _init() -> void:
	state_name = "MainMenu"

func enter() -> void:
	print("[FSM] Entrou em MainMenu")

func exit() -> void:
	print("[FSM] Saiu de MainMenu")
