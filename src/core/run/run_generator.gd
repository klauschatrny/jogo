## Gera o RunPlan de uma run a partir de um config data-driven (data/run.json) e uma seed.
##
## "Linear com escolhas" (decisão de design, pivô roguelite): o PADRÃO de tipos de nó é fixo
## (`pattern` no JSON, ex.: Combate→Recompensa→Combate→Recompensa→Boss); o que VARIA entre runs é
## o CONTEÚDO de cada nó — qual encontro de combate, qual boss — sorteado sem reposição pelo
## RNGService semeado. Mesma seed → mesmo plano (determinismo §0.2.3).
##
## Core puro (§2.3): recebe o config já carregado (não abre o data_layer). Quem lê o run.json e o
## passa é o floor_scene, do mesmo jeito que ele já passa o start_level para o RunState.
class_name RunGenerator
extends RefCounted

## Monta o plano. `config` = { pattern:[String], reward_cards:int, encounters:[...], bosses:[...] }.
## `encounters`/`bosses` podem ser ids simples (String) ou dicionários com mais campos (ex.:
## { boss, arena }); o payload do nó carrega o dicionário inteiro, ou { encounter: id } / { boss: id }.
static func generate(config: Dictionary, run_seed: int) -> RunPlan:
	RNGService.set_seed(run_seed)
	var pattern: Array = config.get("pattern", [])
	var reward_cards := int(config.get("reward_cards", 3))
	var encounters := _shuffled(config.get("encounters", []))
	var bosses := _shuffled(config.get("bosses", []))
	var enc_i := 0
	var boss_i := 0
	var nodes: Array = []
	for raw in pattern:
		var t := String(raw)
		if t == RunNode.REWARD:
			nodes.append(RunNode.make(t, {"cards": reward_cards}))
		elif t == RunNode.BOSS:
			nodes.append(RunNode.make(t, _payload_de(bosses, boss_i, "boss")))
			boss_i += 1
		elif t == RunNode.COMBAT or t == RunNode.ELITE or t == RunNode.MINIBOSS:
			nodes.append(RunNode.make(t, _payload_de(encounters, enc_i, "encounter")))
			enc_i += 1
		else:
			nodes.append(RunNode.make(t, {}))
	return RunPlan.new(nodes)

## O payload do i-ésimo item de um pool (com wrap se o pool for menor que o número de slots).
## Item já é dicionário → carrega inteiro; item é id simples → { chave: id }.
static func _payload_de(pool: Array, i: int, chave: String) -> Dictionary:
	if pool.is_empty():
		return {}
	var entry: Variant = pool[i % pool.size()]
	if typeof(entry) == TYPE_DICTIONARY:
		return (entry as Dictionary).duplicate(true)
	return { chave: entry }

## Embaralha uma cópia do array pelo RNGService (Fisher-Yates), para o sorteio ser determinístico
## pela seed — Array.shuffle() usa o RNG global, que quebraria a reprodutibilidade da run.
static func _shuffled(arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := RNGService.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
