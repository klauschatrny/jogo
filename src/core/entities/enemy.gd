## Inimigo em runtime (§2.2.4). Na Fase 2 os stats vêm de base_stats; a partir da Fase 3
## o EnemyFactory os escala pelo andar (§1.2.1). Boss estende esta classe (reusa _populate).
class_name Enemy
extends RefCounted

var id: String = ""
var name: String = ""
var archetype: String = ""
var rank: String = "NORMAL"
var stats: StatBlock
var ai_profile: String = "aggressive"
var abilities: Array = []
var loot: Dictionary = {}
## A que distância ele DESPERTA (px). Todo inimigo que não é chefe nasce dormente e só fica
## agressivo quando o jogador entra neste raio — é o que deixa o jogador escolher a briga.
## 0 = a view usa o padrão dela.
var aggro_range: float = 0.0
var attack_range: float = 0.0       # alcance de ACERTO do golpe melee (px). 0 = a view usa seu padrão
## Fração do alcance que o inimigo AVANÇA ao golpear (o passo à frente). 0 = bate parado —
## é assim que um inimigo pesado e lento se distingue de um que salta para cima do jogador.
## < 0 = a view usa seu padrão.
var attack_step: float = -1.0
## GUARDA: por quantos segundos ele baixa a defesa DEPOIS de atacar. > 0 liga a mecânica —
## fora dessa janela ele bloqueia o dano por completo, e a única forma de feri-lo é puni-lo
## logo depois de um golpe dele. 0 = sem guarda.
var guard_drop: float = 0.0
## COMBO: `combo_hits` estocadas seguidas a cada `combo_every` ataques, `combo_interval` entre
## elas, parado no lugar. 0 = só o golpe único.
var combo_hits: int = 0
var combo_interval: float = 0.28
var combo_every: int = 3
var hit_range: float = 0.0          # alcance de DANO/efeito do golpe (px). 0 = usa attack_range
var attack_style: String = ""       # estilo do efeito melee: "slash" | "thrust". "" = padrão (slash)
var windup: float = -1.0            # tempo de windup do golpe melee (s). < 0 = a view usa seu padrão
var attack_cooldown: float = -1.0   # intervalo entre golpes melee (s). < 0 = a view usa seu padrão
var attack_sfx: String = ""         # id do som do golpe em data/audio.json. "" = golpe silencioso
var hurt_sfx: String = ""           # id do som ao levar dano (e sobreviver). "" = mudo
var death_sfx: String = ""          # id do som do golpe FATAL. "" = mudo

static func from_dict(d: Dictionary) -> Enemy:
	var e := Enemy.new()
	e._populate(d)
	return e

## Popula os campos a partir do dicionário. Protegido para o Boss reusar via super.
func _populate(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	name = String(d.get("name", ""))
	archetype = String(d.get("archetype", ""))
	rank = String(d.get("rank", "NORMAL"))
	ai_profile = String(d.get("ai_profile", "aggressive"))
	var abil: Array = d.get("abilities", [])
	abilities = abil.duplicate()
	var lt: Dictionary = d.get("loot", {})
	loot = lt.duplicate(true)
	aggro_range = float(d.get("aggro_range", 0.0))
	attack_range = float(d.get("attack_range", 0.0))
	attack_step = float(d.get("attack_step", -1.0))
	guard_drop = float(d.get("guard_drop", 0.0))
	var cb: Dictionary = d.get("combo", {})
	combo_hits = int(cb.get("hits", 0))
	combo_interval = float(cb.get("interval", 0.28))
	combo_every = maxi(1, int(cb.get("every", 3)))
	hit_range = float(d.get("hit_range", 0.0))
	attack_style = String(d.get("attack_style", ""))
	windup = float(d.get("windup", -1.0))
	attack_cooldown = float(d.get("attack_cooldown", -1.0))
	attack_sfx = String(d.get("attack_sfx", ""))
	hurt_sfx = String(d.get("hurt_sfx", ""))
	death_sfx = String(d.get("death_sfx", ""))
	stats = StatBlock.from_dict(d.get("base_stats", {}))
