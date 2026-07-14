## Fantasma persistente (§2.2.5 / §1.4). É a ÚNICA entidade que sobrevive ao permadeath —
## fica em disco (user://saves/ghosts.json) entre runs. Core puro: só serialização, sem render.
## As regras matemáticas que o transformam num inimigo vivem em NemesisRules/GhostFactory.
class_name GhostData
extends RefCounted

var ghost_id: String = ""
var origin_run_id: String = ""
var death_floor: int = 0
var timestamp: String = ""
var nemesis_coeff: float = 0.65
var defeated: bool = false
var player_snapshot: Dictionary = {}

# --- Marca de sangue (o Eco como ele funciona HOJE) ---
# O Eco não é mais um espectro de outra run invocado pelo boss: é ONDE VOCÊ CAIU, nesta run, com
# as almas que você tinha no bolso. Ele espera lá. Vencê-lo devolve as almas; morrer de novo antes
# disso o substitui, e as antigas se perdem para sempre.
var souls: int = 0          # as almas que ele guarda
var death_x: float = 0.0    # onde exatamente ele espera, dentro do nível

## Cria um GhostData a partir de um snapshot do jogador (Player.snapshot()) no momento da morte.
static func from_snapshot(snapshot: Dictionary, p_death_floor: int,
		p_origin_run_id: String, p_nemesis_coeff: float) -> GhostData:
	var g := GhostData.new()
	g.ghost_id = _gen_id()
	g.origin_run_id = p_origin_run_id
	g.death_floor = p_death_floor
	g.timestamp = Time.get_datetime_string_from_system(true)
	g.nemesis_coeff = p_nemesis_coeff
	g.defeated = false
	g.player_snapshot = snapshot.duplicate(true)
	return g

static func from_dict(d: Dictionary) -> GhostData:
	var g := GhostData.new()
	g.ghost_id = String(d.get("ghost_id", ""))
	g.origin_run_id = String(d.get("origin_run_id", ""))
	g.death_floor = int(d.get("death_floor", 0))
	g.timestamp = String(d.get("timestamp", ""))
	g.nemesis_coeff = float(d.get("nemesis_coeff", 0.65))
	g.defeated = bool(d.get("defeated", false))
	g.souls = int(d.get("souls", 0))
	g.death_x = float(d.get("death_x", 0.0))
	var snap: Dictionary = d.get("player_snapshot", {})
	g.player_snapshot = snap.duplicate(true)
	return g

func to_dict() -> Dictionary:
	return {
		"ghost_id": ghost_id,
		"origin_run_id": origin_run_id,
		"death_floor": death_floor,
		"timestamp": timestamp,
		"nemesis_coeff": nemesis_coeff,
		"defeated": defeated,
		"souls": souls,
		"death_x": death_x,
		"player_snapshot": player_snapshot.duplicate(true),
	}

static func _gen_id() -> String:
	return "ghost-%d-%d" % [Time.get_ticks_usec(), Time.get_ticks_msec()]
