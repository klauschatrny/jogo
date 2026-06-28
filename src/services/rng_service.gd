## Autoload. Toda aleatoriedade do jogo passa por aqui (§0.2.3): RNG semeado e
## determinístico — mesma seed produz a mesma run. Essencial para debug, balanceamento
## e replays do Fantasma. Nunca use randi()/randf() globais no código de jogo.
extends Node

var _rng := RandomNumberGenerator.new()
var _seed: int = 0

func _ready() -> void:
	# Seed inicial aleatória; sobrescreva com set_seed() para reproduzir uma run.
	set_seed(int(Time.get_unix_time_from_system()))

func set_seed(value: int) -> void:
	_seed = value
	_rng.seed = value

func get_seed() -> int:
	return _seed

## Reinicia o gerador para o início da sequência da seed atual.
func reset() -> void:
	_rng.seed = _seed

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## Retorna true com probabilidade `p` (0.0–1.0).
func chance(p: float) -> bool:
	return _rng.randf() < p

## Sorteio ponderado: dado um Array de pesos, retorna o índice escolhido (ou -1 se soma <= 0).
## Base do sorteio de cards de Augment (§1.3).
func weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if roll < acc:
			return i
	return weights.size() - 1

## Escolhe um elemento aleatório de um Array (ou null se vazio).
func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]
