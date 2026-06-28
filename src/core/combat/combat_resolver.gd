## Fonte única de cálculo de combate (§1.2.3). Centraliza dano, DPS, EHP e mitigação
## para que o balanceamento fique num só lugar. Funções estáticas e puras: testáveis
## sem render. As fórmulas-base seguem o GDD ao pé da letra.
class_name CombatResolver
extends RefCounted

# ---------------------------------------------------------------------------
# Fórmulas-base (§1.2.3) — puras, sem dependência de entidades.
# ---------------------------------------------------------------------------

## HIT_DAMAGE = (atk + weapon_damage) * (1 + Σ%dano) * (1 - redução_do_alvo)
static func hit_damage(attacker_atk: float, weapon_damage: float,
		pct_damage_bonus: float, target_damage_reduction: float) -> float:
	return (attacker_atk + weapon_damage) \
		* (1.0 + pct_damage_bonus) \
		* (1.0 - target_damage_reduction)

## DPS = hit_damage * attack_speed * (1 + crit_chance * (crit_damage - 1))
static func dps(hit_dmg: float, attack_speed: float,
		crit_chance: float, crit_damage: float) -> float:
	return hit_dmg * attack_speed * (1.0 + crit_chance * (crit_damage - 1.0))

## EHP = max_hp / (1 - damage_reduction)
static func ehp(max_hp: float, damage_reduction: float) -> float:
	return max_hp / (1.0 - damage_reduction)

## Converte defesa flat em redução percentual com retornos decrescentes: def / (def + K).
## K vem de balance.json (defense_curve.DEFENSE_K). Mantém a defesa relevante sem anular dano.
static func damage_reduction_from_defense(defense: float) -> float:
	if defense <= 0.0:
		return 0.0
	var k := float(BalanceConfig.defense_curve.get("DEFENSE_K", 100.0))
	return defense / (defense + k)

## Redução total de um alvo: damage_reduction explícita + a derivada da defesa flat,
## limitada a 95% para nunca zerar o dano.
static func total_reduction(target: StatBlock) -> float:
	var dr := target.damage_reduction + damage_reduction_from_defense(float(target.defense))
	return clampf(dr, 0.0, 0.95)

# ---------------------------------------------------------------------------
# Conveniência de alto nível — operam sobre as entidades do Core.
# ---------------------------------------------------------------------------

## Dano de um golpe do jogador contra um alvo. Já inclui a mitigação do alvo e o
## multiplicador de dano do jogador (damage_mult = (1 + Σ%dano) e ×MULT de artefatos).
static func player_hit(player: Player, target: StatBlock) -> float:
	var atk := float(player.stats.attack)
	var wdmg := player.weapon.current_damage() if player.weapon else 0.0
	var pct := player.stats.damage_mult - 1.0
	return hit_damage(atk, wdmg, pct, total_reduction(target))

## Dano de um golpe de um inimigo (StatBlock atacante) contra o jogador.
static func enemy_hit(attacker: StatBlock, player: Player) -> float:
	return hit_damage(float(attacker.attack), 0.0, 0.0, total_reduction(player.stats))

## Cura por roubo de vida (§1.3): fração do dano causado convertida em HP, arredondada.
static func lifesteal_heal(lifesteal: float, damage_dealt: int) -> int:
	if lifesteal <= 0.0 or damage_dealt <= 0:
		return 0
	return int(round(float(damage_dealt) * lifesteal))
