## Script da cena de menu principal (Fase 1). Apenas confirma que a apresentação subiu;
## botões e navegação real chegam na Fase 2+.
extends Control

func _ready() -> void:
	print("[MainMenu] Cena de apresentação pronta")

## Provisório: Enter/Espaço inicia a run (loop de andares). A navegação definitiva via FSM
## (CharacterCreation → WeaponSelection) chega na Fase 4.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/floor_scene.tscn")
