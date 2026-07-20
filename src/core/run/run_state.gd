## Estado de uma run em memória (§2.3 run/). Amarra jogador, andar atual e o pool de
## augments. Core puro: recebe os dados já hidratados (weapon, augments) de quem o cria —
## não acessa data_layer diretamente (respeita a regra de dependência §2.3).
class_name RunState
extends RefCounted

var player: Player
## Onde o jogador está, como ID de nível — não como número. A dungeon é um GRAFO (ver
## data/floors/levels.json): "o próximo nível" não é uma conta, é uma saída nomeada que aquele
## nível declara. Era um int e somava-se 1; isso tornava atalho e bifurcação inexprimíveis, já
## que ambos são uma SEGUNDA aresta entre lugares que já existem.
var current_level: String = ""
## Onde a dungeon começa (o nível para o qual a vila aponta). Quem monta a run informa, lendo
## do levels.json — o core não acessa o data_layer (§2.3). É o fallback do respawn sem fogueira.
var start_level: String = ""
var augment_pool: AugmentPool
var seed: int = 0

# --- Fogueiras (soulslike) ---
# A morte NÃO encerra a run: o jogador volta à última fogueira em que descansou, com a vida
# cheia, e o nível é repovoado. O que ele leva consigo é o que já conquistou (nível, augments,
# arma); o que ele perde é o caminho andado. Sem nenhuma fogueira acesa, renasce no começo do
# nível em que caiu.
var checkpoint_level: String = ""  # "" = nenhuma fogueira acesa ainda
var checkpoint_x: float = 0.0      # onde, dentro do nível
var lit_bonfires: Array = []       # ids ("nível:x") das fogueiras já acesas — acesas ficam acesas
var cleared_levels: Array = []     # níveis já CONCLUÍDOS: as passagens deles ficam abertas para sempre
# Níveis cujos inimigos estão mortos AGORA. É diferente de "concluído": concluir abre o caminho
# para sempre, mas os inimigos voltam. Descansar numa fogueira (ou morrer) esvazia esta lista e o
# mundo inteiro se repovoa — a regra clássica do soulslike. Sem ela, limpar uma sala a esvaziava
# para o resto da run e o caminho de volta ao chefe virava um corredor vazio.
var emptied_levels: Array = []
var bosses_seen: Array = []        # bosses cuja cutscene de entrada já rodou (não se repete na retentativa)
var opened_gates: Array = []       # portões de mecanismo já abertos (por alavanca): abertos ficam abertos
var deaths: int = 0
var flask_tutorial_seen: bool = false   # a dica do frasco (na área da fogueira) já apareceu nesta run
var knight_line: int = 0                # em que fala do Sir Big T. o jogador está (persiste na run)

# --- A mancha de sangue (bloodstain, à la Dark Souls) ---
# Existe no máximo UMA. Ao morrer, TODAS as almas do bolso ficam numa marca no ponto EXATO da queda
# (inclusive dentro de uma arena de boss). Tocá-la devolve tudo. Morrer de novo antes de chegar nela
# move a marca para o novo ponto e as almas antigas se perdem PARA SEMPRE. É a aposta que dá peso à
# morte — e, ao contrário do antigo Eco, não é um inimigo: é só uma marca que se recolhe.
var bloodstain_level: String = ""  # "" = nenhuma marca ativa
var bloodstain_x: float = 0.0     # onde, dentro do nível (o ponto exato da queda)
var bloodstain_souls: int = 0     # quantas almas esperam nela

## Inicia uma nova run. `available_augments` é a lista (hidratada) de todos os augments
## sorteáveis; `run_seed` semeia o RNG para tornar a run reproduzível.
static func start_new(player_name: String, weapon: Weapon,
		available_augments: Array, run_seed: int) -> RunState:
	var rs := RunState.new()
	rs.seed = run_seed
	RNGService.set_seed(run_seed)
	rs.player = Player.create_new(player_name, weapon)
	rs.augment_pool = AugmentPool.new(available_augments)
	return rs

const VENGEANCE_ID := "_vengeance"

# ---------------------------------------------------------------------------
# Fogueiras
# ---------------------------------------------------------------------------

## Id estável de uma fogueira: o nível e o ponto onde ela está.
static func bonfire_id(level_id: String, x: float) -> String:
	return "%s:%d" % [level_id, int(round(x))]

## Descansar: vida e stamina cheias, e este vira o ponto de retorno da morte.
func rest_at(level_id: String, x: float) -> void:
	checkpoint_level = level_id
	checkpoint_x = x
	var id := bonfire_id(level_id, x)
	if not lit_bonfires.has(id):
		lit_bonfires.append(id)
	player.heal(player.stats.max_hp)
	if player.stamina != null:
		player.stamina.refill()
	player.refill_flask()              # descansar reabastece a cura sob demanda
	EventBus.checkpoint_rested.emit(level_id)

func is_lit(level_id: String, x: float) -> bool:
	return lit_bonfires.has(bonfire_id(level_id, x))

func has_checkpoint() -> bool:
	return checkpoint_level != ""

# ---------------------------------------------------------------------------
# A mancha de sangue (bloodstain)
# ---------------------------------------------------------------------------

## Deixa a marca no ponto EXATO da queda (`floor_n`/`x` vêm de onde o player caiu — sem ajuste
## nenhum: pode ser dentro de uma arena de chefe), com TODAS as almas do bolso. Substitui uma marca
## anterior — as almas dela se perdem, como em qualquer soulslike. Sem almas, não deixa marca.
## Devolve quantas almas caíram (0 se nenhuma).
func drop_bloodstain(level_id: String, x: float) -> int:
	var caidas := player.lose_souls()
	if caidas <= 0:
		bloodstain_level = ""
		bloodstain_souls = 0
		return 0
	bloodstain_level = level_id
	bloodstain_x = x
	bloodstain_souls = caidas
	return caidas

func has_bloodstain() -> bool:
	return bloodstain_souls > 0

func has_bloodstain_on(level_id: String) -> bool:
	return bloodstain_souls > 0 and bloodstain_level == level_id

## Tocou a marca: as almas voltam para o bolso e ela some. Devolve quantas.
func recover_bloodstain() -> int:
	if bloodstain_souls <= 0:
		return 0
	var recuperadas := bloodstain_souls
	player.gain_souls(recuperadas)
	EventBus.bloodstain_recovered.emit(recuperadas)
	bloodstain_level = ""
	bloodstain_souls = 0
	return recuperadas

## Morte: a run continua, mas você NUNCA renasce onde caiu. Ou na última fogueira em que
## descansou, ou — se nunca descansou em nenhuma — no começo do jogo (a vila). Não existe um
## terceiro caso: reaparecer na arena do chefe que acabou de te matar seria de graça.
func respawn() -> void:
	deaths += 1
	clear_vengeance()                  # o buff de Vingança não sobrevive à morte
	current_level = checkpoint_level if has_checkpoint() else start_level
	player.heal(player.stats.max_hp)
	if player.stamina != null:
		player.stamina.refill()
	player.refill_flask()              # renasce com o frasco cheio
	EventBus.player_respawned.emit(current_level)

## Onde o player reaparece dentro do nível: a fogueira, se ela for DESTE nível; senão o início.
func respawn_x(default_x: float) -> float:
	return checkpoint_x if (has_checkpoint() and checkpoint_level == current_level) else default_x

# ---------------------------------------------------------------------------
# Níveis concluídos / bosses já vistos
# ---------------------------------------------------------------------------

func mark_cleared(level_id: String) -> void:
	if level_id != "" and not cleared_levels.has(level_id):
		cleared_levels.append(level_id)

func is_cleared(level_id: String) -> bool:
	return cleared_levels.has(level_id)

# --- Inimigos vivos ou não (renascimento na fogueira) ---

func mark_emptied(level_id: String) -> void:
	if level_id != "" and not emptied_levels.has(level_id):
		emptied_levels.append(level_id)

func is_emptied(level_id: String) -> bool:
	return emptied_levels.has(level_id)

## Repovoa os níveis dados (os que renascem — quem decide isso é quem lê o levels.json, não o
## core). Chamado ao descansar e ao renascer. Um nível fora da lista fica vazio para sempre, que
## é como um nível marcado para NÃO renascer se comporta.
func repopulate(level_ids: Array) -> void:
	emptied_levels = emptied_levels.filter(
		func(id: String) -> bool: return not level_ids.has(id))

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

## Vai para outro nível do grafo. Substituiu advance_floor/retreat_floor: com um mapa, "avançar"
## e "recuar" deixaram de ser direções — são só arestas, e quem sabe para onde levam é o levels.json.
##
## NÃO CURA, em nenhuma direção. Atravessar para o próximo andar com a vida cheia era uma herança
## do roguelike, e desfazia o jogo inteiro: chegar ao chefe com o frasco intacto e a barra cheia
## de graça apaga a conta de recursos que a área anterior acabou de cobrar. Vida só volta pela
## FOGUEIRA e pelo FRASCO — são as duas únicas fontes, de propósito.
func go_to(level_id: String) -> void:
	if level_id == "":
		return
	clear_vengeance()                  # o buff de Vingança dura só até o fim do nível (§1.4.3)
	current_level = level_id
	EventBus.level_changed.emit(current_level)

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
