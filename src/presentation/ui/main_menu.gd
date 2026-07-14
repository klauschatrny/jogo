## Script da cena de menu principal. ENTER começa a run; ESC abre as Opções (volume).
## A navegação definitiva via FSM (CharacterCreation → WeaponSelection) ainda não existe.
extends Control

var _options: OptionsPanel

func _ready() -> void:
	print("[MainMenu] Cena de apresentação pronta")

## ENTER inicia a run (loop de níveis); ESC abre as Opções. O painel consome o próprio ESC de
## fechar (set_input_as_handled), então ele não chega aqui e não reabre no mesmo frame.
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_options):
		return                       # painel aberto: ele manda no input
	if event.is_action_pressed("ui_cancel"):
		_options = OptionsPanel.new()
		add_child(_options)
		return
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://src/presentation/scenes/floor_scene.tscn")
