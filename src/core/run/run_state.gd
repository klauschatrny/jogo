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

func advance_floor() -> void:
	current_floor += 1
	player.current_floor = current_floor
	player.heal(player.stats.max_hp)   # cada novo andar começa com HP cheio
	EventBus.floor_changed.emit(current_floor)

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
