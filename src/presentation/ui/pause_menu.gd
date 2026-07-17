## Menu de PAUSA (B no meio da run): a MESMA estética do menu principal — fundo escuro, título
## grande centrado, botões empilhados na vertical, tudo por mouse — para as duas telas se lerem
## como o mesmo jogo. CONTINUAR despausa; OPÇÕES abre o painel de abas (o mesmo do menu);
## MENU PRINCIPAL abandona a run.
##
## Roda com a árvore PAUSADA — quem o abre (floor_scene) pausa e ouve `closed` para despausar.
class_name PauseMenu
extends Control

signal closed

## O fundo do menu principal (main_menu.tscn), quase opaco: a cena fica só sugerida atrás.
const BG := Color(0.0509804, 0.0509804, 0.0784314, 0.92)

var _options: OptionsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Título e coluna de botões NAS MESMAS posições do menu principal (base 640×360).
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(80, 120)
	title.size = Vector2(480, 50)
	add_child(title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(230, 198)
	box.custom_minimum_size = Vector2(180, 0)
	add_child(box)
	_add_button(box, "CONTINUAR", _close)
	_add_button(box, "OPÇÕES", _open_options)
	_add_button(box, "MENU PRINCIPAL", _quit_to_menu)

func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_button_pressed.bind(cb))   # clique: som + ação
	box.add_child(b)

## Toca o clique de UI e então dispara a ação do botão (o som antes — o Sfx é autoload e persiste
## à troca de cena de MENU PRINCIPAL).
func _on_button_pressed(cb: Callable) -> void:
	Sfx.play("ui_click")
	cb.call()

func _close() -> void:
	closed.emit()
	queue_free()

func _open_options() -> void:
	if is_instance_valid(_options):
		return
	_options = OptionsPanel.new()
	add_child(_options)               # fecha com o próprio VOLTAR/B e volta a esta tela

## Abandona a run e volta ao menu principal. A run atual se perde (floor_scene é destruída e a
## próxima JOGAR recomeça na vila) — comportamento assumido; ainda não há save de run.
func _quit_to_menu() -> void:
	get_tree().paused = false
	Music.set_muffled(false)
	Music.stop(0.0)
	Sfx.stop_sustains()               # nenhum loop do mundo (passos etc.) deve soar no menu
	get_tree().change_scene_to_file("res://src/presentation/scenes/main_menu.tscn")

## B fecha a pausa (CONTINUAR). Com o painel de Opções aberto, ele manda no input — o B dele
## fecha só o painel, e esta tela fica.
func _input(event: InputEvent) -> void:
	if is_instance_valid(_options):
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
