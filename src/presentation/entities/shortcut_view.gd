## A boca do POÇO: uma das duas pontas de um atalho. Desenha e avisa; quem persiste o estado e
## move o jogador é o floor_scene/RunState.
##
## Ela tem DOIS estados visualmente distintos, e a distinção é o ponto:
##   - TRANCADA: tábuas cruzadas sobre a boca. Ainda assim CONVIDA ("destrancar"), porque um atalho
##     que não se anuncia não é um atalho — é cenário que o jogador passa reto. Foi o que aconteceu
##     na primeira versão, feita com a porta comum escurecida: lia como porta quebrada.
##   - ABERTA: as tábuas somem, o buraco fica preto e fundo, e o convite vira "atravessar".
## Trancada SEM a tranca deste lado (a outra ponta é que destranca), o convite diz isso em vez de
## prometer uma ação que não vai acontecer.
class_name ShortcutView
extends Node2D

const REACH := 34.0              # distância para interagir (base 640×360)

var _player: Node2D
var _aberto := false
var _pode_destrancar := false    # esta ponta tem a tranca? (só uma das duas tem)
var _tabuas: Node2D
var _prompt: Label

func setup(x: float, player: Node2D, aberto: bool, pode_destrancar: bool) -> void:
	position.x = x
	_player = player
	_aberto = aberto
	_pode_destrancar = pode_destrancar
	_build()

func _build() -> void:
	z_index = -2                 # à frente do chão, atrás das entidades

	# A boca em si: um buraco escuro no chão, com batente de pedra.
	var batente := ColorRect.new()
	batente.color = Color(0.34, 0.33, 0.37)
	batente.size = Vector2(30.0, 40.0)
	batente.position = Vector2(-15.0, -40.0)
	add_child(batente)

	var buraco := ColorRect.new()
	buraco.color = Color(0.05, 0.05, 0.08)
	buraco.size = Vector2(22.0, 34.0)
	buraco.position = Vector2(-11.0, -34.0)
	add_child(buraco)

	# Tábuas cruzadas: só enquanto trancado. São elas que dizem "isto abre", em vez de
	# escurecer a coisa toda e fazê-la parecer desligada.
	_tabuas = Node2D.new()
	add_child(_tabuas)
	for ang in [28.0, -28.0]:
		var t := ColorRect.new()
		t.color = Color(0.45, 0.32, 0.20)
		t.size = Vector2(34.0, 6.0)
		t.pivot_offset = Vector2(17.0, 3.0)
		t.position = Vector2(-17.0, -22.0)
		t.rotation = deg_to_rad(ang)
		_tabuas.add_child(t)
	_tabuas.visible = not _aberto

	_prompt = Label.new()
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(180.0, 18.0)
	_prompt.position = Vector2(-90.0, -66.0)
	_prompt.visible = false
	add_child(_prompt)

func _process(_delta: float) -> void:
	if _prompt == null:
		return
	_prompt.visible = in_reach(_player)
	_prompt.text = "%s  %s" % [KeyBinds.key_name("interact"), _verbo()]

func _verbo() -> String:
	if _aberto:
		return "atravessar o poço"
	# Trancado e sem a tranca deste lado: o convite tem de dizer isso, senão promete uma ação
	# que não acontece e o jogador conclui que o botão está quebrado.
	return "destrancar o poço" if _pode_destrancar else "poço travado (do outro lado)"

func in_reach(player: Node2D) -> bool:
	return is_instance_valid(player) and absf(player.global_position.x - global_position.x) <= REACH

## Destrancou: as tábuas caem e a boca fica aberta.
func abrir() -> void:
	if _aberto:
		return
	_aberto = true
	if is_instance_valid(_tabuas):
		var tw := create_tween()
		tw.tween_property(_tabuas, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: _tabuas.visible = false)

func esta_aberto() -> bool:
	return _aberto
