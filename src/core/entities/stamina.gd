## Stamina estilo Dark Souls (Core puro, testável — sem render nem RNG de engine).
##
## Recurso que as ações gastam (ataque, esquiva). Regenera com o tempo, mas só APÓS um pequeno
## atraso desde o último gasto (regen_delay) — spam de ações mantém a barra vazia. Estilo DS:
## você pode agir enquanto houver QUALQUER stamina (>0), mesmo que o custo a leve a zero; só fica
## impedido de agir quando ela zera, até regenerar de novo. Tuning vem do balance.json.
class_name Stamina
extends RefCounted

var maximum: float = 100.0
var current: float = 100.0
var regen_per_sec: float = 45.0
var regen_delay: float = 0.5      # segundos sem gastar antes de voltar a regenerar
var _delay: float = 0.0           # tempo restante do atraso de regeneração

static func from_config(cfg: Dictionary) -> Stamina:
	var s := Stamina.new()
	s.maximum = float(cfg.get("MAX", 100.0))
	s.regen_per_sec = float(cfg.get("REGEN_PER_SEC", 45.0))
	s.regen_delay = float(cfg.get("REGEN_DELAY", 0.5))
	s.current = s.maximum
	return s

## Pode iniciar uma ação? (há stamina sobrando). Estilo DS: basta ser > 0.
func can_act() -> bool:
	return current > 0.0

## Gasta a stamina (limitando em 0) e reinicia o atraso de regeneração. Retorna false se já vazia
## (ação não deveria ter sido permitida — cheque can_act() antes).
func consume(cost: float) -> bool:
	if current <= 0.0:
		return false
	current = maxf(0.0, current - cost)
	_delay = regen_delay
	return true

## Avança o tempo: aguarda o atraso e então regenera até o máximo.
func tick(delta: float) -> void:
	if _delay > 0.0:
		_delay = maxf(0.0, _delay - delta)
		return
	current = minf(maximum, current + regen_per_sec * delta)

## Enche a barra na hora (descansar na fogueira, ressuscitar). Zera também o atraso de regen:
## quem levanta da fogueira já pode agir.
func refill() -> void:
	current = maximum
	_delay = 0.0

func ratio() -> float:
	return clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
