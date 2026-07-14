## Autoload. Barramento de sinais globais. O Core emite; a apresentação (UI) escuta.
## Princípio §0.2.4: eventos sobre acoplamento — a UI nunca é referenciada pelo Core.
extends Node

# --- Ciclo de vida do jogador / combate ---
signal player_died(player)
signal player_damaged(player, amount)
signal weapon_upgraded(weapon)

# --- Progressão (almas: moeda única; nível se COMPRA na fogueira) ---
signal souls_gained(amount, total)
signal souls_lost(amount)           # morreu: tudo foi para o Eco
signal echo_defeated(souls_back)    # venceu o próprio Eco: as almas voltaram
signal level_up(new_level)
signal floor_changed(floor)

# --- Fogueiras / morte (soulslike) ---
signal checkpoint_rested(floor)     # o jogador descansou numa fogueira (vida cheia, ponto salvo)
signal player_respawned(floor)      # morreu e voltou à última fogueira — a run NÃO acaba

# --- Atributos (progressão soulslike: nível dá pontos; a fogueira os gasta) ---
signal attribute_raised(id, new_value)

# --- Recompensa (augments: DESLIGADO do jogo — ver CLAUDE.md) ---
signal augment_offered(cards)
signal augment_chosen(augment)

# --- Nemesis (Fantasma) ---
signal summon_ghost_requested(floor)
signal ghost_defeated(ghost)

# --- Estado / UI ---
signal state_changed(state_name)
