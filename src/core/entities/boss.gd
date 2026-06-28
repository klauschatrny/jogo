## Boss (§2.2.4): um Enemy com fases por threshold de HP e capacidade de invocar o Fantasma.
## A invocação propriamente dita (EventBus/GhostFactory) é da Fase 4 — aqui on_damaged()
## apenas sinaliza "summon_ghost" entre os eventos retornados, sem efeitos colaterais.
class_name Boss
extends Enemy

var phases: Array = []                  # Array[BossPhase]
var can_summon_ghost: bool = false
var ghost_summon_threshold: float = 0.6
var intro_dialogue: String = ""
var _summoned: bool = false

static func from_dict(d: Dictionary) -> Boss:
	var b := Boss.new()
	b._populate(d)                      # campos de Enemy
	b.can_summon_ghost = bool(d.get("can_summon_ghost", false))
	b.ghost_summon_threshold = float(d.get("ghost_summon_threshold", 0.6))
	b.intro_dialogue = String(d.get("intro_dialogue", ""))
	var phs: Array = d.get("phases", [])
	for pd in phs:
		b.phases.append(BossPhase.from_dict(pd))
	return b

func hp_pct() -> float:
	return float(stats.current_hp) / float(maxi(stats.max_hp, 1))

## Deve ser chamado após o boss tomar dano. Dispara fases cujo threshold foi cruzado
## (cada uma só uma vez) e sinaliza a invocação do fantasma. Retorna a lista de eventos
## ocorridos nesta chamada (ex.: ["summon_ghost", "enrage"]).
func on_damaged() -> Array:
	var events: Array = []
	var pct := hp_pct()

	if can_summon_ghost and not _summoned and pct <= ghost_summon_threshold:
		_summoned = true
		events.append("summon_ghost")

	for phase in phases:
		if not phase.triggered and pct <= phase.hp_threshold:
			phase.triggered = true
			if phase.atk_mult != 1.0:
				stats.attack = int(round(stats.attack * phase.atk_mult))
			for action in phase.on_enter:
				events.append(action)

	return events
