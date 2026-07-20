## Define a estrutura de um andar (§2.3 run/): quantas waves, a composição de cada wave
## (ids de inimigos) e qual boss no fim. Core puro: recebe a config (de data/floors) já
## carregada. A escala por andar e o spawn visual ficam por conta de quem consome.
class_name FloorManager
extends RefCounted

var floor: int = 1
var waves: Array = []          # Array de waves; cada wave = Array[String] de enemy_ids
var boss_id: String = ""
var _current_wave: int = 0

## Monta o andar a partir da config. Waves e inimigos por wave crescem suavemente com o
## andar para dar sensação de progressão.
static func build(floor: int, config: Dictionary) -> FloorManager:
	var fm := FloorManager.new()
	fm.floor = maxi(floor, 1)
	fm.boss_id = String(config.get("boss_id", "bss_guardian"))

	var pool: Array = config.get("enemy_pool", ["enm_skeleton_minion"])
	if pool.is_empty():
		pool = ["enm_skeleton_minion"]
	var n_waves := int(config.get("waves_base", 2)) + (fm.floor - 1) / 10
	var per_wave := int(config.get("enemies_per_wave", 3)) + (fm.floor - 1) / 5

	for w in n_waves:
		var wave: Array = []
		for e in per_wave:
			wave.append(pool[(w + e) % pool.size()])
		fm.waves.append(wave)
	return fm

func wave_count() -> int:
	return waves.size()

func current_wave_index() -> int:
	return _current_wave

func has_next_wave() -> bool:
	return _current_wave < waves.size()

## Retorna a próxima wave (lista de enemy_ids) e avança o contador.
func next_wave() -> Array:
	if not has_next_wave():
		return []
	var w: Array = waves[_current_wave]
	_current_wave += 1
	return w

func is_cleared() -> bool:
	return _current_wave >= waves.size()
