## Atributos (progressão soulslike). Core puro — lê o catálogo do balance.json e faz as contas.
##
## A regra que define o gênero: **subir de nível não dá stat nenhuma sozinho**. Dá PONTOS, e os
## pontos só viram poder quando o jogador os gasta, na fogueira, no atributo que ele escolher.
## É a diferença entre uma build que acontece com você (roguelike) e uma que você escolhe.
##
## Cada atributo declara quanto UM ponto acrescenta a quais stats ("gain"). Somar um atributo novo
## (ex.: destreza → attack_speed) é editar o JSON; nada aqui muda.
class_name Attributes
extends RefCounted

static func _cfg() -> Dictionary:
	return BalanceConfig.attributes

## Os atributos declarados, na ordem em que aparecem no JSON (que é a ordem da tela).
static func specs() -> Array:
	return _cfg().get("LIST", [])

static func points_per_level() -> int:
	return int(_cfg().get("POINTS_PER_LEVEL", 1))

static func spec(id: String) -> Dictionary:
	for s in specs():
		if String(s.get("id", "")) == id:
			return s
	return {}

static func has(id: String) -> bool:
	return not spec(id).is_empty()

static func start_of(id: String) -> int:
	return int(spec(id).get("start", 10))

## O mapa inicial: cada atributo no seu valor de partida.
static func defaults() -> Dictionary:
	var d: Dictionary = {}
	for s in specs():
		d[String(s.get("id", ""))] = int(s.get("start", 10))
	return d

## Quanto os atributos somam a um stat (ex.: "max_hp"), acima da base. Só contam os pontos
## GASTOS — o valor de partida já está embutido na base do jogador, e contá-lo de novo dobraria.
static func bonus(attrs: Dictionary, stat: String) -> float:
	var total := 0.0
	for s in specs():
		var gain: Dictionary = s.get("gain", {})
		if not gain.has(stat):
			continue
		var id := String(s.get("id", ""))
		var start := int(s.get("start", 10))
		var pontos_gastos := int(attrs.get(id, start)) - start
		total += float(pontos_gastos) * float(gain[stat])
	return total
