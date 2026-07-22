## O plano de uma run: a sequência ordenada de nós (RunNode) e um cursor no nó atual.
## "Linear com escolhas": a ORDEM e a CONTAGEM de nós são fixas para o padrão; o que muda entre
## runs é o conteúdo de cada nó (ver RunGenerator). O `floor_scene` avança o cursor a cada nó
## resolvido (sala limpa, card escolhido, boss morto). Core puro (§2.3).
class_name RunPlan
extends RefCounted

var nodes: Array = []   # Array[RunNode]
var index: int = 0      # cursor: o nó atual

func _init(node_list: Array = []) -> void:
	nodes = node_list

func size() -> int:
	return nodes.size()

func is_empty() -> bool:
	return nodes.is_empty()

## O nó atual, ou null se a run acabou (cursor além do fim).
func current() -> RunNode:
	if index < 0 or index >= nodes.size():
		return null
	return nodes[index]

## O próximo nó sem avançar o cursor (para prever a próxima tela / o mapa). null se este é o último.
func peek_next() -> RunNode:
	var i := index + 1
	if i < 0 or i >= nodes.size():
		return null
	return nodes[i]

## Avança o cursor e devolve o novo nó atual (null quando a run termina).
func advance() -> RunNode:
	index += 1
	return current()

## O cursor passou do último nó — a run foi concluída (chegou ao fim vivo).
func is_complete() -> bool:
	return index >= nodes.size()

func is_last() -> bool:
	return index == nodes.size() - 1

## Quantos nós faltam a partir do atual (inclusive).
func remaining() -> int:
	return maxi(0, nodes.size() - index)

## A lista de tipos, na ordem — útil para testes e para desenhar o traçado da run.
func types() -> Array:
	return nodes.map(func(n: RunNode) -> String: return n.type)
