## Estado de uma run em memória (§2.3 run/). Amarra jogador, andar atual e o pool de
## augments. Core puro: recebe os dados já hidratados (weapon, augments) de quem o cria —
## não acessa data_layer diretamente (respeita a regra de dependência §2.3).
class_name RunState
extends RefCounted

var player: Player
var current_floor: int = 1
var augment_pool: AugmentPool
var seed: int = 0

# --- Fogueiras (soulslike) ---
# A morte NÃO encerra a run: o jogador volta à última fogueira em que descansou, com a vida
# cheia, e o nível é repovoado. O que ele leva consigo é o que já conquistou (nível, augments,
# arma); o que ele perde é o caminho andado. Sem nenhuma fogueira acesa, renasce no começo do
# nível em que caiu.
var checkpoint_floor: int = 0      # 0 = nenhuma fogueira acesa ainda
var checkpoint_x: float = 0.0      # onde, dentro do nível
var lit_bonfires: Array = []       # ids ("nível:x") das fogueiras já acesas — acesas ficam acesas
var cleared_floors: Array = []     # níveis já concluídos: não repovoam ao renascer
var bosses_seen: Array = []        # bosses cuja cutscene de entrada já rodou (não se repete na retentativa)
var opened_gates: Array = []       # portões de mecanismo já abertos (por alavanca): abertos ficam abertos
var deaths: int = 0

# --- O Eco (marca de sangue) ---
# Existe no máximo UM. Ele guarda as almas que você tinha no bolso ao morrer e espera no lugar da
# queda. Vencê-lo devolve tudo. Morrer de novo antes de chegar nele o SUBSTITUI — e as almas
# antigas se perdem para sempre. É a aposta que dá peso à morte.
var echo: GhostData = null

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

# ---------------------------------------------------------------------------
# Fogueiras
# ---------------------------------------------------------------------------

## Id estável de uma fogueira: o nível e o ponto onde ela está.
static func bonfire_id(floor_n: int, x: float) -> String:
	return "%d:%d" % [floor_n, int(round(x))]

## Descansar: vida e stamina cheias, e este vira o ponto de retorno da morte.
func rest_at(floor_n: int, x: float) -> void:
	checkpoint_floor = floor_n
	checkpoint_x = x
	var id := bonfire_id(floor_n, x)
	if not lit_bonfires.has(id):
		lit_bonfires.append(id)
	player.heal(player.stats.max_hp)
	if player.stamina != null:
		player.stamina.refill()
	player.refill_flask()              # descansar reabastece a cura sob demanda
	EventBus.checkpoint_rested.emit(floor_n)

func is_lit(floor_n: int, x: float) -> bool:
	return lit_bonfires.has(bonfire_id(floor_n, x))

func has_checkpoint() -> bool:
	return checkpoint_floor > 0

# ---------------------------------------------------------------------------
# O Eco (marca de sangue)
# ---------------------------------------------------------------------------

## Deixa o Eco no lugar da queda, com TODAS as almas do jogador. Substitui um Eco anterior — as
## almas dele se perdem, como em qualquer soulslike. Sem almas no bolso, não deixa marca nenhuma:
## um Eco vazio seria só um inimigo a mais no caminho.
##
## `floor_n`/`x` já vêm ajustados por quem chama: o Eco NUNCA fica numa arena de chefe (não há como
## voltar lá sem enfrentar o chefe de novo), então uma morte no chefe o deposita na porta do nível
## anterior — ver floor_scene._echo_spot().
func drop_echo(floor_n: int, x: float) -> void:
	var caidas := player.lose_souls()
	if caidas <= 0:
		echo = null
		return
	var coeff := float(BalanceConfig.nemesis.get("NEMESIS_COEFF", 0.65))
	echo = GhostData.from_snapshot(player.snapshot(), floor_n, player.run_id, coeff)
	echo.souls = caidas
	echo.death_x = x

func has_echo_on(floor_n: int) -> bool:
	return echo != null and not echo.defeated and echo.death_floor == floor_n

## Venceu o Eco: as almas voltam para o bolso e a marca some.
func recover_echo() -> int:
	if echo == null:
		return 0
	var recuperadas := echo.souls
	player.gain_souls(recuperadas)
	EventBus.echo_defeated.emit(recuperadas)
	echo = null
	return recuperadas

## Morte: a run continua, mas você NUNCA renasce onde caiu. Ou na última fogueira em que
## descansou, ou — se nunca descansou em nenhuma — no começo do jogo (a vila). Não existe um
## terceiro caso: reaparecer na arena do chefe que acabou de te matar seria de graça.
const START_FLOOR := 1

func respawn() -> void:
	deaths += 1
	clear_vengeance()                  # o buff de Vingança não sobrevive à morte
	current_floor = checkpoint_floor if has_checkpoint() else START_FLOOR
	player.current_floor = current_floor
	player.heal(player.stats.max_hp)
	if player.stamina != null:
		player.stamina.refill()
	player.refill_flask()              # renasce com o frasco cheio
	EventBus.player_respawned.emit(current_floor)

## Onde o player reaparece dentro do nível: a fogueira, se ela for DESTE nível; senão o início.
func respawn_x(default_x: float) -> float:
	return checkpoint_x if (has_checkpoint() and checkpoint_floor == current_floor) else default_x

# ---------------------------------------------------------------------------
# Níveis concluídos / bosses já vistos
# ---------------------------------------------------------------------------

func mark_cleared(floor_n: int) -> void:
	if not cleared_floors.has(floor_n):
		cleared_floors.append(floor_n)

func is_cleared(floor_n: int) -> bool:
	return cleared_floors.has(floor_n)

# ---------------------------------------------------------------------------
# Portões de mecanismo (alavanca). Um portão de madeira fecha a passagem até o jogador puxar a
# alavanca que o abre — e, aberto, fica aberto para sempre (o caminho vira atalho permanente).
# ---------------------------------------------------------------------------

func open_gate(id: String) -> void:
	if id != "" and not opened_gates.has(id):
		opened_gates.append(id)

func is_gate_open(id: String) -> bool:
	return opened_gates.has(id)


## A cutscene de entrada do boss só roda na PRIMEIRA vez. Morrer e voltar não a repete —
## rever 5 segundos de queda a cada tentativa envelhece rápido.
func mark_boss_seen(boss_id: String) -> void:
	if boss_id != "" and not bosses_seen.has(boss_id):
		bosses_seen.append(boss_id)

func boss_seen(boss_id: String) -> bool:
	return bosses_seen.has(boss_id)

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
	return augment_pool.draw(count, player.stats.luck, _excluded_ids())

## Recompensa de catarse (§1.4.3): como offer_augments, mas garante ao menos 1 card de
## Relíquia+ (quando o pool tiver). Usada quando o jogador derrota seu próprio Eco.
func offer_augments_catharsis(n: int = -1) -> Array:
	var count := n if n > 0 else int(BalanceConfig.augments.get("cards_per_reward", 3))
	var exclude := _excluded_ids()
	var guaranteed := augment_pool.draw_min_tier("RELIC", player.stats.luck, exclude)
	if guaranteed == null:
		return augment_pool.draw(count, player.stats.luck, exclude)
	exclude.append(guaranteed.id)
	var rest := augment_pool.draw(count - 1, player.stats.luck, exclude)
	return [guaranteed] + rest

## Ids de augments não-stackable já possuídos (excluídos dos sorteios).
func _excluded_ids() -> Array:
	var exclude: Array = []
	for a in player.augments:
		if not a.stackable:
			exclude.append(a.id)
	return exclude

func choose_augment(aug: Augment) -> void:
	player.add_augment(aug)
