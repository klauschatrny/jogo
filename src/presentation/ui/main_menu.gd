## Menu principal: JOGAR / OPÇÕES empilhados na vertical, navegáveis por MOUSE (ENTER continua
## valendo como atalho para jogar). OPÇÕES abre o painel de abas (ÁUDIO / CONTROLES / TUTORIAL).
## A navegação definitiva via FSM (CharacterCreation → WeaponSelection) ainda não existe.
extends Control

const Backdrop := preload("res://src/presentation/ui/menu_backdrop.gd")

var _options: OptionsPanel

func _ready() -> void:
	print("[MainMenu] Cena de apresentação pronta")
	Music.play("menu")                        # trilha do menu (some no JOGAR — ver _on_play)
	var bg: Control = Backdrop.new()          # arte de fundo procedural (placeholder)
	add_child(bg)
	move_child(bg, 0)                         # atrás do título e dos botões
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(230, 198)          # centrado (base 640×360), abaixo do título
	box.custom_minimum_size = Vector2(180, 0)
	add_child(box)
	_add_button(box, "JOGAR", _on_play)
	_add_button(box, "OPÇÕES", _open_panel.bind(0))

func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_button_pressed.bind(cb))   # clique: som + ação
	box.add_child(b)

## Toca o clique de UI e então dispara a ação do botão (o som primeiro, para valer mesmo quando a
## ação troca de cena — o Sfx é autoload e persiste).
func _on_button_pressed(cb: Callable) -> void:
	Sfx.play("ui_click")
	cb.call()

func _on_play() -> void:
	Music.stop(3.0)                           # a vila é silenciosa: fade gradual de 3s ao entrar
	get_tree().change_scene_to_file("res://src/presentation/scenes/floor_scene.tscn")

func _open_panel(tab: int) -> void:
	if is_instance_valid(_options):
		return                       # já aberto (o painel consome o próprio fechar)
	_options = OptionsPanel.new()
	_options.initial_tab = tab
	add_child(_options)

## ENTER inicia a run. Com o painel aberto, ele manda no input (e fecha com PAUSAR/FECHAR).
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_options):
		return
	if event.is_action_pressed("ui_accept"):
		_on_play()
