## Autoload. Barramento de sinais globais. O Core emite; a apresentação (UI) escuta.
## Princípio §0.2.4: eventos sobre acoplamento — a UI nunca é referenciada pelo Core.
extends Node

# --- Ciclo de vida do jogador / combate ---
signal player_died(player)
signal player_damaged(player, amount)
signal weapon_upgraded(weapon)

# --- Progressão ---
signal xp_gained(amount)
signal level_up(new_level)
signal floor_changed(floor)

# --- Recompensa ---
signal augment_offered(cards)
signal augment_chosen(augment)

# --- Nemesis (Fantasma) ---
signal summon_ghost_requested(floor)
signal ghost_defeated(ghost)

# --- Estado / UI ---
signal state_changed(state_name)
