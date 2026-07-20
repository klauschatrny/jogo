## Jogador em runtime (§2.2.1). Core puro: emite eventos via EventBus, nunca toca em render.
##
## Modelo de stats: `stats` é EFETIVO e derivado — recalculado de um bloco BASE (que escala
## com o nível via Scaling) mais os augments (via StatResolver, ordem ADD<PCT_ADD<MULT).
## Chame recalculate_stats() após mudar nível ou augments. current_hp é estado preservado.
##
## take_damage() recebe um valor JÁ MITIGADO pelo CombatResolver (mitigação centralizada lá).
class_name Player
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
## Almas: a moeda ÚNICA. Vêm direto do inimigo morto e compram níveis na fogueira. Morrer as
## derruba TODAS — elas ficam no Eco, no lugar onde você caiu, e só voltam se você o vencer.
## É o que dá peso à morte: sem isto, morrer só custa tempo.
var souls: int = 0
var stats: StatBlock
var stamina: Stamina                # recurso de ações (ataque/esquiva), estilo Dark Souls
var weapon: Weapon
var augments: Array = []            # Array[Augment] — desligado do jogo (ver CLAUDE.md)
var gold: int = 0
## Andar numérico — CONGELADO EM 1. A dungeon virou um grafo de níveis com id (RunState.
## current_level), então não há mais número de andar para escrever aqui. Só o sistema de
## ecos/Nemesis ainda lê este campo, e ele está desligado; quando a torre for redesenhada,
## este campo sai junto.
var current_floor: int = 1
var run_id: String = ""

# --- Atributos (soulslike) ---
# Subir de nível NÃO dá stat nenhuma sozinho: dá pontos, e os pontos só viram poder quando o
# jogador os gasta na fogueira, no atributo que ele escolher.
var attributes: Dictionary = {}     # id -> valor (vigor, resistência, força...)
var attribute_points: int = 0       # pontos por gastar

# --- Frasco de cura (o Estus) ---
# A única cura sob demanda do jogo. Cargas limitadas que só se recarregam na fogueira: é o que
# transforma cada troca de golpes num cálculo de recurso ("curo agora e me exponho, ou aguento?").
var flask_charges: int = 0
var flask_max: int = 0
## O jogador COMEÇA SEM O FRASCO. Ele é um presente do Sir Big T., o cavaleiro ao lado da primeira
## fogueira — até falar com ele, o slot na HUD fica vazio e beber não faz nada. Ganhar o Estus de
## alguém, em vez de já nascer com ele, é o que dá ao objeto o peso de um marco do começo do jogo.
var has_flask: bool = false

static func create_new(player_name: String, chosen_weapon: Weapon) -> Player:
	var p := Player.new()
	p.id = _gen_id()
	p.run_id = _gen_id()
	p.name = player_name
	p.weapon = chosen_weapon
	p.level = 1
	p.attributes = Attributes.defaults()
	p.stamina = Stamina.from_config(BalanceConfig.stamina)
	p.recalculate_stats()             # depois da stamina: recalculate_stats também a redimensiona
	# NÃO enche o frasco: ele nem existe ainda (ver has_flask / receive_flask).
	return p

# --- Frasco de cura (o Estus) ---

## Cargas por descanso (do balance.json).
func flask_capacity() -> int:
	return int(BalanceConfig.get_value("flask", "CHARGES", 3))

## Quanto UM gole cura: uma fração da vida MÁXIMA, então subir Vigor também engorda a cura.
func flask_heal_amount() -> int:
	return int(round(stats.max_hp * float(BalanceConfig.get_value("flask", "HEAL_FRACTION", 0.4))))

## Enche o frasco (fogueira / renascer).
func refill_flask() -> void:
	if not has_flask:
		return                        # sem frasco não há o que reabastecer
	flask_max = flask_capacity()
	flask_charges = flask_max

## Recebe o frasco (do Sir Big T.). Idempotente: falar com ele de novo não dá um segundo.
func receive_flask() -> bool:
	if has_flask:
		return false
	has_flask = true
	refill_flask()
	return true

## Pode beber agora? Precisa de carga e estar vivo. Beber com a vida CHEIA é permitido — a cura
## satura no máximo (não adiciona nada), mas a carga é gasta assim mesmo: a decisão é do jogador.
func can_drink() -> bool:
	return has_flask and flask_charges > 0 and is_alive()

## Compromete uma carga e devolve quanto ela CURARÁ. A cura em si é aplicada por quem chama, ao
## fim da animação de beber (via heal()) — se um golpe interromper antes, a carga já foi: é o preço.
## Devolve 0 se não dava para beber.
func drink_flask() -> int:
	if not can_drink():
		return 0
	flask_charges -= 1
	EventBus.flask_used.emit(flask_charges)
	return flask_heal_amount()

## Derruba TODAS as almas (morte). Devolve quantas caíram — quem chama as deixa na marca de sangue.
func lose_souls() -> int:
	var caidas := souls
	souls = 0
	if caidas > 0:
		EventBus.souls_lost.emit(caidas)
	return caidas

func gain_souls(amount: int) -> void:
	if amount <= 0:
		return
	souls += amount
	EventBus.souls_gained.emit(amount, souls)

## Sobe UM ponto no atributo, se houver ponto para gastar. O HP ganho na hora vem junto (subir
## Vigor com a vida no fim cura de fato — como na fogueira de Dark Souls). Retorna false se não
## havia ponto ou o atributo não existe.
func spend_point(id: String) -> bool:
	if attribute_points <= 0 or not attributes.has(id):
		return false
	attribute_points -= 1
	attributes[id] = int(attributes[id]) + 1
	var hp_antes := stats.max_hp
	recalculate_stats()
	stats.current_hp = min(stats.current_hp + maxi(0, stats.max_hp - hp_antes), stats.max_hp)
	EventBus.attribute_raised.emit(id, int(attributes[id]))
	return true

func attribute(id: String) -> int:
	return int(attributes.get(id, Attributes.start_of(id)))

## Stats BASE, antes dos augments. A base é fixa (player_scaling); o que faz o jogador crescer
## são os ATRIBUTOS — o nível, sozinho, não move nenhum número.
func base_block() -> StatBlock:
	var b := StatBlock.new()
	b.max_hp = int(Scaling.player_base_hp() + Attributes.bonus(attributes, "max_hp"))
	b.attack = int(Scaling.player_base_atk() + Attributes.bonus(attributes, "attack"))
	b.defense = 0
	b.crit_chance = 0.05
	b.crit_damage = 1.5
	b.attack_speed = 1.0
	b.move_speed = 110.0
	b.damage_reduction = 0.0
	b.lifesteal = 0.0
	b.luck = 0
	b.damage_mult = 1.0
	return b

## Recalcula os stats efetivos (base + augments), preservando o HP atual (clampado ao novo máximo).
## A stamina também é redimensionada: o teto dela vem da Resistência, então gastar um ponto ali
## precisa alargar a barra na hora.
func recalculate_stats() -> void:
	var keep := stats.current_hp if stats != null else -1
	stats = StatResolver.resolve(base_block(), augments)
	if keep < 0:
		stats.current_hp = stats.max_hp
	else:
		stats.current_hp = min(keep, stats.max_hp)
	_resize_stamina()

## Teto da stamina = base do balance.json + o que a Resistência somou. O que já estava na barra é
## preservado; ganhar teto novo entrega a sobra de imediato (subir Resistência enche o que cresceu).
func _resize_stamina() -> void:
	if stamina == null:
		return
	var novo_max := float(BalanceConfig.stamina.get("MAX", 100.0)) \
		+ Attributes.bonus(attributes, "stamina_max")
	var ganho := novo_max - stamina.maximum
	stamina.maximum = novo_max
	stamina.current = clampf(stamina.current + maxf(ganho, 0.0), 0.0, novo_max)

func add_augment(aug: Augment) -> void:
	augments.append(aug)
	if aug.category == "WEAPON" and weapon != null:   # §3.7: augment de arma sobe o nível
		weapon.upgrade()
	recalculate_stats()
	EventBus.augment_chosen.emit(aug)

## Aplica dano já final (mitigação feita no CombatResolver). Retorna o dano efetivo.
func take_damage(amount: int) -> int:
	var dmg: int = max(amount, 0)
	stats.current_hp = max(stats.current_hp - dmg, 0)
	EventBus.player_damaged.emit(self, dmg)
	if stats.current_hp <= 0:
		EventBus.player_died.emit(self)
	return dmg

func heal(amount: int) -> void:
	stats.current_hp = min(stats.current_hp + max(amount, 0), stats.max_hp)

func is_alive() -> bool:
	return stats.current_hp > 0

## Snapshot usado para gerar o GhostData ao morrer (Fase 4).
func snapshot() -> Dictionary:
	return {
		"name": name,
		"level": level,
		"stats": stats.to_dict(),
		"weapon": weapon.to_dict() if weapon else {},
		"augments": augments.map(func(a: Augment) -> Dictionary:
			return {"id": a.id, "tier": a.tier, "name": a.name}),
	}

static func _gen_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), Time.get_ticks_msec()]
