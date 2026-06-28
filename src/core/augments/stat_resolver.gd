## Resolve os stats efetivos aplicando os efeitos dos augments sobre um StatBlock base,
## com a ordem de empilhamento do §1.3.2:
##     final = ((base + Σ ADD) * (1 + Σ PCT_ADD)) * Π MULT
## PCT_ADD soma entre si (evita explosão de poder); MULT multiplica (reservado a Artefatos);
## SET sobrescreve. current_hp é estado (não resolvido aqui). Stats fora do StatBlock são ignorados.
class_name StatResolver
extends RefCounted

static func resolve(base: StatBlock, augments: Array) -> StatBlock:
	var fields := base.to_dict()
	var adds := {}    # stat -> Σ ADD
	var pcts := {}    # stat -> Σ PCT_ADD
	var mults := {}   # stat -> Π MULT
	var sets := {}    # stat -> valor SET

	for aug in augments:
		for e in aug.effects:
			match e.operation:
				"ADD":
					adds[e.stat] = float(adds.get(e.stat, 0.0)) + e.value
				"PCT_ADD":
					pcts[e.stat] = float(pcts.get(e.stat, 0.0)) + e.value
				"MULT":
					mults[e.stat] = float(mults.get(e.stat, 1.0)) * e.value
				"SET":
					sets[e.stat] = e.value
				_:
					push_warning("[StatResolver] operação desconhecida: %s" % e.operation)

	var result := {}
	for stat in fields:
		if stat == "current_hp":
			result[stat] = fields[stat]
			continue
		if sets.has(stat):
			result[stat] = sets[stat]
			continue
		var base_v := float(fields[stat])
		result[stat] = (base_v + float(adds.get(stat, 0.0))) \
			* (1.0 + float(pcts.get(stat, 0.0))) \
			* float(mults.get(stat, 1.0))

	return StatBlock.from_dict(result)
