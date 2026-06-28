## Estado de uma run em memória (§2.3 run/). Amarra jogador, andar atual e o pool de
## augments. Core puro: recebe os dados já hidratados (weapon, augments) de quem o cria —
## não acessa data_layer diretamente (respeita a regra de dependência §2.3).
class_name RunState
extends RefCounted

var player: Player
var current_floor: int = 1
var augment_pool: AugmentPool
var seed: int = 0

## Inicia uma nova run. `available_augments` é a lista (hidratada) de todos os augments
## sorteáveis; `run_seed` semeia o RNG para tornar a run reproduzível.
static func start_new(player_name: String, weapon: Weapon,
		available_augments: Array, run_seed: int) -> RunState:
	var rs := RunState.new()
	rs.seed = run_seed
	RNGService.set_seed(run_seed)
	rs.player = Player.create_new(player_name, weapon)
	rs.current_floor = 1
	rs.player.current_floor = 1
	rs.augment_pool = AugmentPool.new(available_augments)
	return rs

const VENGEANCE_ID := "_vengeance"

func advance_floor() -> void:
	clear_vengeance()                  # o buff de Vingança dura só até o fim do andar (§1.4.3)
	current_floor += 1
	player.current_floor = current_floor
	player.heal(player.stats.max_hp)   # cada novo andar começa com HP cheio
	EventBus.floor_changed.emit(current_floor)

## Buff de Vingança (§1.4.3): +VENGEANCE_DAMAGE_BUFF de dano até o fim do andar. Implementado
## como um augment temporário (sobrevive a level-ups; removido em advance_floor).
func apply_vengeance() -> void:
	if has_vengeance():
		return
	var pct := float(BalanceConfig.nemesis.get("VENGEANCE_DAMAGE_BUFF", 0.2))
	var aug := Augment.from_dict({
		"id": VENGEANCE_ID, "name": "Vingança", "tier": "RELIC", "category": "OFFENSE",
		"stackable": false,
		"effects": [{"stat": "damage_mult", "operation": "MULT", "value": 1.0 + pct}],
	})
	player.augments.append(aug)
	player.recalculate_stats()

func clear_vengeance() -> void:
	var before := player.augments.size()
	player.augments = player.augments.filter(func(a: Augment) -> bool: return a.id != VENGEANCE_ID)
	if player.augments.size() != before:
		player.recalculate_stats()

func has_vengeance() -> bool:
	for a in player.augments:
		if a.id == VENGEANCE_ID:
			return true
	return false

## Sorteia os cards de recompensa, excluindo augments não-stackable já possuídos.
func offer_augments(n: int = -1) -> Array:
	var count := n if n > 0 else int(BalanceConfig.augments.get("cards_per_reward", 3))
	var exclude: Array = []
	for a in player.augments:
		if not a.stackable:
			exclude.append(a.id)
	return augment_pool.draw(count, player.stats.luck, exclude)

func choose_augment(aug: Augment) -> void:
	player.add_augment(aug)
