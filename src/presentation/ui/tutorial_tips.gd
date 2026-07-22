## A lista CANÔNICA das mensagens de tutorial. Dois consumidores: a vila (toasts disparados por
## posição, floor_scene) e a aba TUTORIAL das Opções (revisão a qualquer hora). Os nomes de tecla
## vêm do KeyBinds (remapeável), então monte as strings NA HORA de usar — nunca as cacheie.
class_name TutorialTips
extends RefCounted

## Os toasts da vila: [x-gatilho no corredor, texto, entra na revisão?], na ordem do caminho.
## O 3º campo separa LIÇÃO (vale reler nas Opções) de ORIENTAÇÃO do momento ("a porta à frente"),
## que só faz sentido em pé na vila.
static func entries() -> Array:
	return [
		[0.0,    "Ande com  %s / %s" % [KeyBinds.key_name("move_left"), KeyBinds.key_name("move_right")], true],
		[480.0,  "Pule com  %s" % KeyBinds.key_names("jump"), true],
		[840.0,  "Ataque com  %s  e teste no boneco à frente" % KeyBinds.key_name("attack"), true],
		[1200.0, "Esquive com  %s   (gasta stamina)" % KeyBinds.key_names("dodge"), true],
		[1520.0, "Parado, a stamina se recupera.  Sem ela, você não ataca nem esquiva.", true],
		[1760.0, "A porta à frente leva ao Centro da cidade", false],
	]

## A dica do frasco (aba de revisão das Opções). Curta de propósito: uma linha só do toast.
static func flask_tip() -> String:
	return "Frasco de Cura: beba com %s. Recarrega ao despertar no Centro" \
		% KeyBinds.key_name("flask")

## Os textos da aba de revisão: as LIÇÕES da vila + a do frasco (sem as orientações de momento).
static func all_texts() -> Array:
	var out: Array = []
	for e in entries():
		if bool(e[2]):
			out.append(String(e[1]))
	out.append(flask_tip())
	return out
