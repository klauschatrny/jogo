## Converte um GhostData (snapshot de uma run anterior) num Enemy jogável (§2.2.5 / §1.4).
## Aplica as 5 regras via NemesisRules; lê o tuning (teto de HP, herança de augments) do
## balance.json. O fantasma é um ELITE nerfado com IA "echo", NÃO um clone perfeito.
class_name GhostFactory
extends RefCounted

## Constrói o eco contra o estado ATUAL do jogador (necessário para a Regra 2, anti-impossível).
static func build(data: GhostData, current_player: Player) -> Enemy:
	var snap := data.player_snapshot
	var snap_stats: Dictionary = snap.get("stats", {})
	var coeff := data.nemesis_coeff

	var nem: Dictionary = BalanceConfig.nemesis
	var hp_cap := float(nem.get("GHOST_HP_CAP", 2.0))
	var divisor := int(nem.get("AUGMENTS_PER_DEATH_FLOOR_DIVISOR", 3))
	var max_n := int(nem.get("MAX_INHERITED_AUGMENTS", 5))

	var ghost := Enemy.new()
	ghost.id = data.ghost_id
	ghost.name = "%s (Eco)" % String(snap.get("name", "Eco"))
	ghost.archetype = "ECHO"
	ghost.rank = "ELITE"
	ghost.ai_profile = "echo"

	var s := StatBlock.new()
	# Regra 1 (nerf) + Regra 2 (teto relativo ao jogador atual).
	s.max_hp = NemesisRules.ghost_hp(int(snap_stats.get("max_hp", 1)), coeff,
		current_player.stats.max_hp, hp_cap)
	s.current_hp = s.max_hp
	s.attack = NemesisRules.nerf(float(snap_stats.get("attack", 0)), coeff)
	s.defense = NemesisRules.nerf(float(snap_stats.get("defense", 0)), coeff)
	# O eco se move como o jogador se movia (mobilidade não é nerfada — é um "eco" do estilo).
	s.move_speed = float(snap_stats.get("move_speed", 100.0))
	ghost.stats = s

	# Regra 3 — herança parcial de augments (kit focado, priorizando tier).
	ghost.abilities = NemesisRules.select_inherited_augments(
		snap.get("augments", []), data.death_floor, divisor, max_n)

	# A arma herdada (id + nível) acompanha o eco para a apresentação (golpe básico, Regra 4).
	ghost.loot = {"weapon": snap.get("weapon", {})}
	return ghost
