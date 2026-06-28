## Estrutura macro da torre (§2.4 Fase 4): quantos andares, qual boss em cada andar e onde
## fica o Rei. Core puro e data-driven — recebe a config de data/floors/tower.json. Os great
## bosses ficam em andares-marco (10/20/30/40/50) e o Rei no andar final (51).
class_name TowerManager
extends RefCounted

var total_floors: int = 50
var king_floor: int = 51
var default_boss: String = "bss_guardian"
var boss_schedule: Dictionary = {}   # int(andar) -> String(boss_id)

static func from_config(cfg: Dictionary) -> TowerManager:
	var t := TowerManager.new()
	t.total_floors = int(cfg.get("total_floors", 50))
	t.king_floor = int(cfg.get("king_floor", t.total_floors + 1))
	t.default_boss = String(cfg.get("default_boss", "bss_guardian"))
	var sched: Dictionary = cfg.get("boss_schedule", {})
	for k in sched:                    # chaves de JSON vêm como String
		t.boss_schedule[int(k)] = String(sched[k])
	return t

## Boss que fecha o andar: o agendado (great boss/Rei) ou o boss padrão dos andares comuns.
func boss_for_floor(floor: int) -> String:
	return String(boss_schedule.get(floor, default_boss))

## Andar com boss especial agendado (great boss ou Rei), distinto do boss comum.
func is_scheduled_boss_floor(floor: int) -> bool:
	return boss_schedule.has(floor)

func is_king_floor(floor: int) -> bool:
	return floor == king_floor

## Great boss = andar agendado que NÃO é o Rei (10/20/30/40/50).
func is_great_boss_floor(floor: int) -> bool:
	return is_scheduled_boss_floor(floor) and not is_king_floor(floor)

## Arena só de boss (sem waves de trash antes): por ora, apenas o Rei.
func is_boss_only_floor(floor: int) -> bool:
	return is_king_floor(floor)

## Vencer este andar conclui a torre (vitória).
func is_victory_floor(floor: int) -> bool:
	return floor >= king_floor
