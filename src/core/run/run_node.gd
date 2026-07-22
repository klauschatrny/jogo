## Um nó da run (roguelite). Uma run é uma SEQUÊNCIA de nós tipados — combate, recompensa, boss,
## etc. — e o `floor_scene` monta a tela certa para cada tipo. O `payload` carrega os ids que
## aquele nó precisa (qual encontro, qual boss, quantos cards), sem que o core saiba desenhá-los.
## Core puro (§2.3): é só dado; quem resolve o conteúdo é a apresentação.
class_name RunNode
extends RefCounted

# Tipos de nó. O mínimo da fatia vertical usa COMBAT/REWARD/BOSS; os demais já existem como
# rótulo para o gerador crescer (loja, ferreiro, descanso, evento, tesouro, elite, miniboss).
const COMBAT := "COMBAT"
const ELITE := "ELITE"
const MINIBOSS := "MINIBOSS"
const BOSS := "BOSS"
const REWARD := "REWARD"
const REST := "REST"
const EVENT := "EVENT"
const MERCHANT := "MERCHANT"
const BLACKSMITH := "BLACKSMITH"
const TREASURE := "TREASURE"

var type: String = COMBAT
var payload: Dictionary = {}

static func make(node_type: String, node_payload: Dictionary = {}) -> RunNode:
	var n := RunNode.new()
	n.type = node_type
	n.payload = node_payload.duplicate(true)
	return n

## Combate em qualquer forma (comum, elite, miniboss): o `floor_scene` os trata pela mesma
## maquinaria de sala, só mudando a dificuldade/inimigos.
func is_combat() -> bool:
	return type == COMBAT or type == ELITE or type == MINIBOSS

func is_boss() -> bool:
	return type == BOSS

func get_value(key: String, default: Variant = null) -> Variant:
	return payload.get(key, default)
