# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## The game: Fair Despair — an Action Roguelite

The game is called **Fair Despair**. Its genre has moved twice: it was born a **roguelike**
(*A Torre da Vingança* / Tower of Vengeance — hence the `TDV_` prefix on the old design docs and the
unwired 50-floor tower), was steered into a **soulslike**, and is now being pivoted to an
**Action Roguelite** whose whole focus is *combat*.

**The pivot is described in `docs/Pivot_de_Design.md`. Where the design docs disagree, precedence is:
`docs/Pivot_de_Design.md` → this file → `TDV_Arquitetura.md`.** The architecture in `TDV_Arquitetura.md`
still holds; its genre, its name, and its 50-floor exploration structure do **not**.

**Why the pivot (the reasoning the user accepted):** a plain soulslike with hand-authored exploration
had no differentiator and demanded too much art/level content for a solo dev. An Action Roguelite
reinvests everything into the one thing already strong — the combat — and gets its length and
replay value from *runs* and *builds* instead of from *maps*.

**Identity, held on purpose:** *"An Action Roguelite of technical, Souls-inspired combat."* **Not**
*"a simplified soulslike."* The four design pillars (from the pivot doc) are: **deep combat**
(stamina, i-frame dodges, parry where it fits, readable telegraphs, weighty animations, punish/reward),
**run progression** (a run is a chain of fights; you get stronger within it; death loses the temporary
build but meta-progression persists), **replayability** (each attempt differs through upgrade choices,
encounter/order variety, modifiers, builds, weapons), and **few excellent bosses** over many generic
ones. Scope rule: *less content, more quality* — 10 great enemies beat 40 lookalikes.

**The question to ask before adding anything:** *"Does this improve the core combat experience?"* If
not, reconsider. Deprioritize big maps, exploration, long dialogue, quests, collectables.

## The run loop (LIVE — this is the game now)

A run is a **linear SEQUENCE of typed nodes**, not a walk through a place-graph. **The current shape
(`data/run.json`) is a 10-floor BOSS TOWER:** `Boss → Reward → Boss → Reward → … → Boss` (10 boss
floors, an augment reward between each), preceded by the tutorial **village**. Each floor is a **1v1
unique boss**. There are 8 authored bosses for 10 floors, so 2 repeat until more are authored — and
**only the Ogre (`bss_ogre`) has unique art + behaviour (`OgreView`);** the other 7 fall back to a
generic `BossView` (functional melee placeholder). The `COMBAT` node machinery (flat rooms) still
exists and is wired, just not used by the current all-boss pattern.

**Core run model (pure, unit-tested, `src/core/run/`):**
- **`RunNode`** — a typed node (`COMBAT`/`ELITE`/`MINIBOSS`/`BOSS`/`REWARD`/`REST`/`EVENT`/`MERCHANT`/
  `BLACKSMITH`/`TREASURE`) plus a `payload` dict carrying the ids that node needs (which encounter,
  which boss, how many cards). It is *only data*; the presentation resolves the content.
- **`RunPlan`** — the ordered `nodes` + an `index` cursor (`current`/`peek_next`/`advance`/
  `is_complete`). `floor_scene` advances the cursor when the current node resolves (room cleared and
  advance-door crossed, card chosen, boss dead).
- **`RunGenerator`** — `generate(config, seed) → RunPlan`. **"Linear com escolhas"** (the chosen
  structure): the *pattern* of node types is fixed; what *varies* per run is each node's content —
  which combat encounter, which boss — drawn without replacement via the seeded `RNGService`
  (Fisher-Yates, not `Array.shuffle()` which uses the global RNG). Same seed → same plan. Core-pure:
  it receives the already-loaded `run.json` (whoever builds the run passes it, exactly as the old
  code passed `start_level`).

**The frame around the tower: Village → DOWNTOWN (the HUB) → gate → tower.**
- The tutorial **village** (`_start_tutorial`) is now *only* training: walk-past tips + the scarecrow.
  Its door leads to the **Downtown** (`_start_downtown`), the city centre / market — **the between-runs
  HUB**. Layout left→right (consts `DT_*`): Sir Big T. (240) + the **respawn bonfire** (300, knight
  left / fire right as always), **Mestre Owyn** (500, trainer), **Baldo o Ferreiro** (680, blacksmith),
  **Mira a Mercadora** (860, merchant), the **big gate + lever** (1060, the old city-gate style: solid
  `GateView`, lever born unlocked — opening is a departure, not a prize; stays open forever via
  `RunState.opened_gates`, key `portao_torre`), and the tower door (1210) behind it.
- **The Downtown bonfire is DECORATIVE** (`BonfireView.decorativa`): always lit, no prompt, no menu,
  no heal/refill — it only *marks* where you wake up. Preparing is the market's job. (`_bonfires` stays
  empty there so `_try_rest` can't act.)
- **The market NPCs** reuse `NpcView` with a `variante` ("cavaleiro"/"ferreiro"/"mercador"/"mestre":
  palette + prop — hammer/anvil, sack, staff; placeholder art) and a `prompt_texto` override — the
  prompt is the shop window, showing service + current price (`_refresh_market_prompts` after every
  purchase). One `interact` serves everything, disambiguated by proximity as always (`_try_npc`
  iterates knight + the three).
  - **Mestre** → `_open_attributes()`: the parked `AttributePanel` is LIVE again (souls buy levels,
    levels give attribute points).
  - **Ferreiro** → `Weapon.upgrade()` for `Weapon.upgrade_cost()` souls (geometric:
    `market.WEAPON_COST_BASE/GROWTH` in `balance.json`).
  - **Mercadora** → `Player.buy_flask_shard()`: +1 max flask charge (the new charge comes filled),
    up to `market.FLASK_MAX_BONUS`; cost geometric (`FLASK_SHARD_COST/GROWTH`). Requires the flask
    (talk to the knight first — the prompt says so).
- **Death AND victory both return to Downtown** (`_finish_run(victory)`): banner ("VOCÊ MORREU" red /
  "VITÓRIA" gold, `_show_run_banner`), fade to black, and under it `_respawn_downtown(died)`:
  `RunState.new_attempt(died)` (core) **strips all augments** (the run build is lost), heals fully,
  refills the flask — and **keeps souls** (they're the meta-currency the market spends), weapon
  levels, flask shards, player levels/attributes. A **new plan is generated with a new seed** (new
  boss order), `_rl_floor` resets, and the player wakes at the fire (x=300). No EndScreen, no Enter,
  no scene reload — everything lives in one scene session.
**Plan wiring (`floor_scene`, behind the `_roguelite` flag — currently `true`):**
- `_ready` loads `run.json` and builds the plan from `_run.seed`; the tower door in Downtown
  (`_begin_tower`) enters the first node.
- **`_enter_node(node)`** routes by type: combat → `_run.go_to(<encounter id>)` + `_start_floor()`;
  **boss → the generic `"arena"` level** (`levels.json`) with the boss id taken **from the node**
  (`_rl_boss_id`, read by `_start_floor`'s boss branch instead of the level's `boss_id`), plus an
  `_rl_floor` counter and an "Andar N de M" toast (M counted from the plan, `_rl_total_floors`);
  reward → `_open_reward(n)`; `null` (past the end) → `_win_run()` → `_finish_run(true)`.
- **`_advance_plan()`** = `_enter_node(_plan.advance())`, called under the black of a `_transition`
  when a node resolves.
- **Combat node** → `_rl_start_room`: a **flat room, combat only** — no sanctuary/entrance/shortcut/
  bonfire. Clearing it (`_on_floor_cleared`, roguelite branch) spawns a plain **advance door** at the
  corridor's end; crossing it (`_update_exit_door`) resolves the node.
- **Reward node** → `_open_reward`: the existing **`CardSelect`** over the weighted augment pool
  (`RunState.offer_augments` / `choose_augment`). **Augments are back in gameplay** (they were parked
  since the soulslike pivot). Picking one applies it and calls `_advance_plan`.
- **Boss node** → reuses the arena + entrance cutscene; only the doors change (roguelite spawns *one*
  forward door, `_spawn_boss_doors`/`_update_boss_doors`, which advances the plan → victory, since
  BOSS is last).
- **Death and victory both end in Downtown** — see the HUB section above. No bloodstain, no bonfire
  checkpoint, no EndScreen in roguelite mode.

**Rooms are FLAT right now (2026-07-21):** the Necromancer's raised **tower + ladder** were removed
from the encounters (the `room.tower` key was dropped from `cemiterio`). Without a tower the
Necromancer simply spawns on the ground (`_spawn_necromancer` already handles the empty-tower case).
The tower/ladder/line-of-sight **code stays, parked** — a future encounter can re-declare `room.tower`.

**Sir Big T. lives in the DOWNTOWN now** (beside the respawn fire, knight left / fire right; he left
the village, which keeps only tips + scarecrow). The player **starts with no flask** (empty HUD
slot); talking to him (E) runs his self-advancing dialogue (5s/line, E skips, `[E] Avançar` keycap)
and hands the flask over as a centre-screen card — closing the card also refreshes the market
prompts (the Mercadora's price appears once you own a flask). His lines 6–7 now teach the *new*
loop: the fire is where you wake when you fall, spend your souls at the market before climbing.

**Deferred, on purpose:** **disk persistence of the meta-progression** — souls, weapon levels, flask
shards, attributes all live in one in-memory `RunState`; closing the game loses them (a save file is
the natural next step). Also: node types beyond Combat/Reward/Boss (Merchant/Blacksmith exist as
*NPCs in the HUB*, not as in-run nodes), and unique art/behaviour for the 7 placeholder bosses
(their JSON stats are the old pre-scaling base values, HP 40–60 — fragile but playable; tune each
JSON when giving them identity).

## Two structural rules for the presentation layer (STILL fully apply)

**The test suite loads every `src/**/*.gd` and fails if any won't compile** (`test_scripts_compile.gd`).
The unit tests only exercise the *core*; they never instantiate the views or `floor_scene`, so for a
long time a compile error there (missing identifier, deleted function still called, a `:=` that infers
`Variant` under warnings-as-errors) passed all tests and only a throwaway probe caught it — it bit at
least four times. The compile test closes that gap: a broken script makes `load()` return a
non-instantiable `GDScript`, which the test reports. It does **not** run gameplay; behavioural checks
still need a probe (the suite can't load `floor_scene.tscn`).

**Enemy subclasses override `_tick_ai(delta)`, never `_physics_process`.** `EnemyView._physics_process`
is the one template for the whole hierarchy: it handles the universal frame concerns — the corpse fall
+ `queue_free` (`_tick_cadaver`) and the existence guards — then calls the virtual `_tick_ai`. Default
`_tick_ai` is the melee AI; `NecromancerView` overrides it with casting, `OgreView` with its state
machine, `ScarecrowView` with a wobble. This exists because the old pattern — each subclass replacing
`_physics_process` wholesale — silently dropped every rule the parent added later: a **dead Necromancer
kept casting forever** and a **dead Ogre kept running its state machine** because their overrides never
ran the corpse branch. With the template, a new universal rule is written once and every enemy inherits it.

## Combat systems (LIVE — the pillar; this is what the pivot reinvests in)

All of this transferred intact from the soulslike work and *is* the roguelite's combat.

**No contact damage — damage is only from telegraphed attacks.** Touching an enemy does nothing; every
hit comes from an enemy's windup-`!` swing (`EnemyView`) or a boss ability. You only take damage from
what you could read and dodge.

**Fixed stats, no per-floor scaling.** `EnemyFactory.build(base_dict)` / `build_boss(base_dict)` return
the enemy **exactly as its JSON declares it** — there is no global difficulty knob. To make an encounter
harder, edit that enemy's JSON or author a variant with its own id. (The old geometric `GROWTH^(f-1)`
curve was a roguelike device for keeping one skeleton relevant across 50 floors; its output was baked
into the JSONs so nothing changed in feel — e.g. `bss_ogre` 180/25/10 → 1177/43/11.) `rank` survives
as a label (HP bar, AI), never a multiplier.

**Every non-boss enemy starts `dormant`** (still, facing the player, no chase/attack) and wakes only
within `MINION_WAKE` (150px). Bosses are exempt — their arena is the commitment. This lets the player
pick fights instead of dragging a whole corridor of aggression.

**Enemy spawns are FIXED, never rolled** — each `room` tier declares its positions one by one
(`"at": [x, …]`). Random placement is a roguelike device; a learnable encounter cannot move every death.
Without `at`, positions fall back to an even split of the band (still deterministic). `spawn_from` pushes
the band's start. *(Note: the run's variety comes from **which** encounters/augments appear, not from
shuffling enemies within an encounter — the encounter itself stays learnable.)*

**Per-enemy combat identity (all data-driven in the enemy JSON):**
- `attack_range` = the *hit* distance; `attack_step` = a forward lunge on the hit (`0` = swings planted);
  the distance at which it *decides* to swing is `trigger_range()` = `attack_range + step_distance()`,
  and damage is checked against `_effective_hit_range()` = `_hit_range() + step_distance()` (the step
  rides the slash arc, so checking reach alone made hits land on screen but miss in the numbers).
  `BossView` sets `attack_step = 0` (bosses have hand-written moves).
- `aggro_range` = how far it sees (skeletons 200, Necromancer 300).
- `windup` freezes the cooldown, so the real cycle is their sum — minion 0.2/1.0, armoured 0.225/1.25,
  heavy 0.35/1.5: a ladder from quick harasser to slow hitter.
- **Each skeleton fights differently:** *minion* is the baseline; *armoured* **guards and blocks all
  damage by default**, attacking costs it the guard for `guard_drop` (2s) — the only window to hurt it
  (a metal shield icon floats above its head while guarding); *heavy* has two attacks — the single
  thrust and, every `combo.every` (3rd), a `combo.hits` (5)-thrust chain delivered **standing still**
  (fixed alternation, never rolled — a pattern is meant to be learned).
- **The Necromancer** is a static ranged elite: a telegraphed bolt (0.35s windup, 3s cadence,
  three-layer glowing projectile) and an AoE, both lighting a **cast aura** on his body (he stands
  still, so the tell must be *on* him). **While he lives, no skeleton dies:** at 0 HP a skeleton
  *collapses into bones where it stood* (`EnemyView._collapse`, a purple enchanted halo marks it),
  takes no damage, and **reassembles** after `room.reassemble_time` (2s). Killing the Necromancer is
  the only exit and drops every skeleton at once.

**Everything dies by collapsing** (boss included): it **flattens where it stood** (`_morrer`:
`MORTE_TOMBO` 0.22 + `MORTE_ESPERA` 0.65 + `MORTE_FADE` 0.40), holds so the kill is seen, then fades —
never blinks out or flies off. **Only `collision_layer` is cleared, never `collision_mask`** — the layer
makes the body a *target*, the mask makes it see the *ground*; zeroing both once pulled the floor out
and gravity carried corpses off-screen. `died` fires immediately (room counts / doors depend on it);
only the node lingers, so a corpse is out of `_enemies` and `_clear_entities` sweeps stray `EnemyView`
children too.

**The flask (Estus) — the only on-demand heal.** `Player.flask_charges`; each gulp heals
`HEAL_FRACTION` of *max* HP (so Vigor fattens the heal). A **committed gesture**: the charge is spent up
front, the heal applied only at the end of the drink animation, **no i-frames**; taking a hit mid-gulp
cancels the heal (`_interrupt_drink`) but the charge is gone. Bound to **R**. Refills on every new
attempt (`RunState.new_attempt`, waking in Downtown); capacity = `flask.CHARGES` + the shards bought
from the Mercadora (`Player.flask_bonus`). There is still **no refill inside a run** — ten floors on
one flask is the resource bill, and softening that is a design decision, not an oversight.

**Combat depth already present:** stamina gates every attack and dodge; the dodge roll has i-frames;
the Ogre has a telegraphed charge with a punish window. **The bill the genre charges is paid in
animation frames, not code** — readable combat needs anticipation frames, and the bottleneck is the
solo dev drawing sprites.

## Parked — dormant behind `_roguelite`, like the tower/Nemesis

The entire **exploration / place-based world layer** still compiles and is unit-tested but is **out of
the gameplay loop**. Do not extend it without reviving it deliberately; if you revive a piece, the full
rationale and gotchas are in git history (and in prior CLAUDE.md revisions). One-line map:

- **Graph dungeon** — `data/floors/levels.json` (string-id levels, named `exits` `frente`/`tras`,
  entry points), `RunState.go_to`/`current_level`. Replaced by `RunPlan`. The level *configs* are still
  read by `_start_floor` (a roguelite combat/boss node names a level id), but the graph *navigation* is
  bypassed.
- **Bonfires as checkpoints** + respawn/run-back, the refuge **guard**, `cleared_levels` vs
  `emptied_levels`/`repopulate`, `sanctuary`, wooden **gate + lever**, boss **fog gates**.
- **Souls economy of death** — the **bloodstain** (drop-all-souls-where-you-fell, recover by walking
  over), souls-buy-levels + attribute points at the bonfire, the `AttributePanel`.
- **The shortcut** (two well mouths sharing an id), the **ladder + Necromancer tower** verticality and
  the attack **line-of-sight** veto (`_tem_linha_de_visada`).
- The Portão's **entrance** (bonfire + big city gate + the knight's old spot there) — the knight
  himself moved to the village, which is live.
- **Environmental hazards** (`HazardView`, spike pits) — no level currently declares any.
- **The 50-floor tower** (`TowerManager`, `tower.json`, the great-boss/King JSONs) and the **Nemesis /
  Ghost** system (`GhostData`/`GhostFactory`/`NemesisRules`, `nemesis.ENABLED = false`).
- **`EndScreen`** — parked again: Downtown replaced the end-of-run screen (banner + respawn instead).
- **Souls-drop on death** — in roguelite mode souls are the persistent meta-currency and are *kept*
  through death; the whole lose-souls/bloodstain economy is the parked soulslike one.

## Architecture (unchanged — the Core ↔ Presentation split still governs everything)

Internalize the dependency rule before adding files (§2.3 of `TDV_Arquitetura.md`):

```
presentation  ──may import──►  core, services, data_layer
states        ──may import──►  core, services, data_layer
core          ──may import──►  (only core + pure services)
core          ──NEVER imports──►  presentation / render / engine APIs
```

`src/core/` holds all game logic (combat, progression, RNG, the run model, ghost/nemesis rules) and must
remain render-free and unit-testable without opening a window. **`RunNode`/`RunPlan`/`RunGenerator` live
in `src/core/run/` and obey this** — they receive the loaded `run.json`, never open the data layer.

Four non-negotiable principles (§0.2):
1. **Data-driven** — weapons, enemies, augments, the run structure (`data/run.json`), and *all* tuning
   constants live in JSON under `data/`. Never hardcode game numbers in logic.
2. **Pure core** — see the dependency rule above.
3. **Deterministic RNG** — every random draw goes through the seeded `RNGService`. Same seed → same run.
   Do not call engine/global RNG directly anywhere in core (`RunGenerator` uses a hand-rolled shuffle
   for exactly this reason).
4. **Events over coupling** — systems communicate via a global `EventBus`. UI listens to core; core
   never references UI.

**Augment stacking order** (§1.3.2): `final = ((base + ΣADD) * (1 + ΣPCT_ADD)) * ΠMULT`, implemented in
`StatResolver` (`ADD < PCT_ADD < MULT`; `MULT` reserved for Artifact-tier). This is the math the reward
cards run through — now live again.

## Planned folder structure

See §2.3 for the authoritative tree. Top level: `data/` (JSON content + `balance.json` + `run.json`),
`src/{core,data_layer,states,presentation,services,autoload}/`, `assets/`, `tests/`, `docs/`.

## Commands

Requires Godot 4 (the `godot` binary is **not** on this machine's PATH — it lives at
`C:\Users\klaus\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7.exe`; invoke with
`--path "C:\Users\klaus\Projetos\Jogo"`). No external addons — the test runner is hand-rolled, not GUT.

```bash
# Run the game (editor)
godot project.godot

# Run headless (no window)
godot --headless

# Regenerate the global class_name cache — REQUIRED after creating new class_name scripts outside the
# editor, else tests fail with "Identifier <Class> not declared". Headless runs do not auto-import.
godot --headless --import

# Run the full test suite (exits 0 on pass, 1 on failure — CI-friendly)
godot --headless --script res://tests/test_runner.gd
```

- Tests live under `tests/`. Each suite extends `TestCase` and defines `test_*()` methods; register new
  suites in the `SUITES` dict of `tests/test_runner.gd`. **The run model is covered by `test_run_plan.gd`.**
  There is no single-test flag — comment out entries in `SUITES` to isolate.
- **Verifying gameplay:** the suite never loads `floor_scene.tscn`, so behaviour needs a **disposable
  probe** (`tests/_probe_*.gd` extends `SceneTree`, instantiates `floor_scene.tscn`, drives it, prints
  state, then is deleted). Watch the two typing/timing gotchas: a `:=` inferring `Variant` fails under
  warnings-as-errors (use untyped `=` when the RHS comes off an untyped node), and `Input.action_press`
  takes ~1 frame to register.
- `tests/sim_balance.gd` is a balance report (always exits 0), not a unit test.

## Conventions established in Phase 1

- **Autoloads** (order matters): `BalanceConfig`, `EventBus`, `RNGService` load first; `GameManager`
  loads last. `Music`/`Sfx` read `data/audio.json` — which entity has which sound is data.
- `GameState` uses `state_name` (not `name`, a `Node` member).
- All randomness goes through `RNGService`. `balance.json`/`run.json` are plain JSON — **no comments**.
- Data repositories extend `BaseRepository`, indexed by `"id"`.
- Input actions (`move_*`, `attack`, `dodge`, `flask`, `interact`) are registered in code by
  `GameManager._setup_input_actions()`. Controls are remappable (`KeyBinds` autoload, CONTROLES tab).

## Project status

**Roguelite loop + HUB implemented and green (197 tests, 0 failures).** The playable loop is
`Village (training) → Downtown (knight → flask; market; gate) → 10-floor boss tower (Boss → Reward
× 10) → Victory or Death → wake in Downtown, souls in pocket → spend → climb again`. Combat, bosses,
the flask, dodge/stamina, augments + `CardSelect`, the market (trainer/blacksmith/merchant) and the
`AttributePanel` are all live; the exploration layer is parked (see above). Rooms are flat (the
Necromancer tower platform was removed from `cemiterio`). `EndScreen` is parked again (Downtown
replaced it).

**Next up:** give the 7 placeholder bosses identity (stats first — their JSONs still hold the old
pre-scaling base values — then behaviour/art, one at a time: *few excellent bosses*); then **saving
the meta-progression to disk** (souls, weapon level, shards, attributes — all in-memory today), and
more between-floor variety (in-run node types: Elite, Event, Treasure) — each judged by *"does it
improve the combat experience?"*.

**Prior phases (from the roguelike/soulslike eras, all still compiling/tested):** Phase 1 Foundation,
Phase 2 Combat & Movement, Phase 3 Progression/Augments/Bosses, Phase 4 Tower & Nemesis (switched off).
Stack: **Godot 4 + GDScript**. Navigation menu↔run is still a provisional `change_scene_to_file`.
