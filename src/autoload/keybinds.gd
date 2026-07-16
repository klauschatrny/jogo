## Controles remapeáveis (autoload "KeyBinds"). O jogador troca as teclas na aba CONTROLES das
## Opções; a escolha vale na hora (reescreve o InputMap) e persiste em `user://keybinds.json`.
##
## Carrega DEPOIS do GameManager (ordem dos autoloads): os padrões já estão no InputMap quando
## este nó nasce, então a "configuração de fábrica" é um snapshot — nada de duplicar a lista de
## teclas do _setup_input_actions aqui.
##
## Regra de conflito: uma tecla só serve UMA ação remapeável. `rebind()` recusa tecla em uso
## (devolve o nome da ação dona) em vez de roubá-la — roubar poderia deixar a outra ação sem
## tecla nenhuma (ex.: PAUSAR sem tecla = painel que não fecha nunca mais).
extends Node

const PATH := "user://keybinds.json"

## As ações que o jogador pode remapear, na ordem em que a aba CONTROLES as lista.
## move_up/move_down (menus) e ui_accept ficam de fora — não são teclas "de jogo".
const ACTIONS := [
	{ "action": "move_left", "label": "ANDAR  ESQUERDA" },
	{ "action": "move_right", "label": "ANDAR  DIREITA" },
	{ "action": "jump", "label": "PULAR" },
	{ "action": "attack", "label": "ATACAR" },
	{ "action": "dodge", "label": "ESQUIVAR" },
	{ "action": "interact", "label": "INTERAGIR" },
	{ "action": "flask", "label": "FRASCO DE CURA" },
	{ "action": "ui_cancel", "label": "PAUSAR / FECHAR" },
]

var _defaults: Dictionary = {}    # action -> Array[int] (physical keycodes de fábrica)

func _ready() -> void:
	for item in ACTIONS:
		var a := String(item["action"])
		if InputMap.has_action(a):
			_defaults[a] = keys_of(a)
	_load()

## Rótulo humano de uma ação (o texto da aba CONTROLES).
func label_of(action: String) -> String:
	for item in ACTIONS:
		if String(item["action"]) == action:
			return String(item["label"])
	return action

## Teclas atuais de uma ação (physical keycodes), na ordem do InputMap.
func keys_of(action: String) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k == null:
			continue
		out.append(int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode))
	return out

## Nome da PRIMEIRA tecla da ação — para prompts curtos ("E  descansar").
func key_name(action: String) -> String:
	var ks := keys_of(action)
	return _key_text(int(ks[0])) if not ks.is_empty() else "?"

## Nomes de TODAS as teclas da ação ("ESPACO / W") — para as dicas do tutorial.
func key_names(action: String) -> String:
	var ks := keys_of(action)
	if ks.is_empty():
		return "?"
	var names := PackedStringArray()
	for k in ks:
		names.append(_key_text(int(k)))
	return " / ".join(names)

## Troca as teclas da ação por UMA só. Devolve "" se deu certo, ou o RÓTULO da ação que já usa
## essa tecla (conflito — nada muda). Remapear para a própria tecla atual é aceito (no-op).
func rebind(action: String, physical_key: int) -> String:
	var dono := _owner_of(physical_key, action)
	if dono != "":
		return label_of(dono)
	_apply(action, [physical_key])
	_save()
	return ""

## Volta TODAS as ações à configuração de fábrica e apaga o arquivo salvo.
func reset_defaults() -> void:
	for a in _defaults:
		_apply(a, _defaults[a])
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

## Alguma tecla mudou em relação à fábrica? (mostra/esconde o aviso de "restaurar padrão")
func is_modified() -> bool:
	for a in _defaults:
		if keys_of(a) != _defaults[a]:
			return true
	return false

# --- internos ---

## Qual ação remapeável (fora `except`) já usa esta tecla? "" = livre.
func _owner_of(physical_key: int, except: String) -> String:
	for item in ACTIONS:
		var a := String(item["action"])
		if a != except and physical_key in keys_of(a):
			return a
	return ""

func _apply(action: String, physical_keys: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for k in physical_keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = int(k)
		InputMap.action_add_event(action, ev)

## Nome exibível de uma tecla física (layout US do keycode físico — bom o bastante no placeholder).
func _key_text(physical_key: int) -> String:
	var txt := OS.get_keycode_string(physical_key)
	return txt.to_upper() if txt != "" else "KEY %d" % physical_key

func _save() -> void:
	var binds := {}
	for item in ACTIONS:
		var a := String(item["action"])
		binds[a] = keys_of(a)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[KeyBinds] não foi possível gravar %s" % PATH)
		return
	f.store_string(JSON.stringify({ "binds": binds }, "  "))
	f.close()

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return                        # 1ª vez: fica na fábrica
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[KeyBinds] %s inválido — usando os padrões" % PATH)
		return
	var binds: Dictionary = (data as Dictionary).get("binds", {})
	for a in binds:
		if typeof(binds[a]) == TYPE_ARRAY and _defaults.has(a):
			_apply(String(a), binds[a])
