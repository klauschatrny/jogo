# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Genre pivot in progress: roguelike → soulslike

The GDD (`TDV_Arquitetura.md`) describes a **roguelike**; the game is being steered toward a
**soulslike**, and where the two disagree, *this file wins*. The decision came from noticing the
game already was one: stamina gates every attack and dodge, the dodge roll has i-frames, the Ogre
has a telegraphed charge with a 3-second punish window (a tell you only learn by dying to it), the
levels are hand-authored with no procgen, and the 50-floor tower + Nemesis were both switched off.

**Done so far — bonfires (checkpoints).** Death no longer ends the run: `_on_player_died` shows a
"VOCÊ MORREU" banner, fades to black, and `RunState.respawn()` puts the player back at the last
bonfire he rested at, with HP and stamina full, while the world is rebuilt around him. He keeps
level/augments/weapon and loses only the ground he'd walked. State lives in `RunState`
(`checkpoint_floor`/`checkpoint_x`, `lit_bonfires`, `cleared_floors`, `bosses_seen`, `deaths`) —
never in the scene, which is torn down and remade on every death. `BonfireView` only draws and
signals. Rest with **E** (`interact`).

There are **two bonfires**: one in the **sanctuary** — the safe tail of a room level's corridor,
past the wooden gate (`_spawn_sanctuary`, bonfire at `_fight_width + BONFIRE_IN`) — and one at the
entrance of the level-3 **rest area** (see below). The sanctuary is
**not a separate screen** any more: it is a continuous extension of the same corridor
(`corridor_length` = the fight zone; `+ SANCTUARY_LEN` = the refuge), so the player just **walks in
and out of it** — no fade, no room swap. `BonfireView` only draws and signals; rest with **E**
(`interact`), which `_try_rest()` gates purely by proximity to the fire (no phase check).

**Respawn has exactly two outcomes, never a third:** the bonfire you last rested at, or the start
of the game (the village). *Never where you fell* — reappearing in the boss arena that just killed
you would make death free. `RunState.respawn()` enforces it (`checkpoint_floor` or `START_FLOOR`),
and `_respawn_at_checkpoint()` re-enters that level through `_start_floor()`, which sees it as
**cleared** and drops the player at the bonfire (`respawn_x`), gate already open, fog ahead.

**Respawn ordering is load-bearing.** Put the player in place *before* spawning hazards
(`_reset_player_to_start` then `_spawn_hazards`): an `Area2D` created on top of the corpse is born
already overlapping it, and its overlap list is only rebuilt on the next *physics* step — so the
pit would kill the freshly-respawned player from across the map, in an idle frame, starting a
second death on top of the first. `HazardView._dentro_do_poco()` re-checks the player's actual
position for the same reason; never trust `get_overlapping_bodies()` alone across a teleport.

Three consequences worth knowing before you touch `floor_scene`:
- `_clear_entities()` **must** run at the start of `_start_floor`/`_start_tutorial`. Respawning
  rebuilds the level *in the same scene*, so without it the previous life's enemies stay alive and
  the new ones pile on top.
- A **cleared** floor (`RunState.is_cleared`) is not repopulated if you walk back through it.
- A boss's entrance cutscene runs **once** (`RunState.boss_seen`); retries go straight to
  `_begin_boss_retry()`.

**Done — attribute points replace the chest and the augment cards.** Levelling up no longer moves
a single stat: it grants **points** (`Player.attribute_points`), and points only become power when
the player sits at the bonfire and spends them (`Player.spend_point`, `AttributePanel`). The
attributes themselves are data (`balance.json → attributes`): each declares what one point adds to
which stats, so adding one is a JSON edit. `Player.base_block()` is now a fixed base
(`Scaling.player_base_hp/atk`) plus attribute bonuses — `Scaling.player_max_hp(level)` survives only
for `sim_balance`'s "median player" model. The reward chest is gone; the refuge it lived in is now
the **sanctuary** (see above). `Augment`/`AugmentPool`/`StatResolver`/`CardSelect` still compile and
are still tested, but nothing in gameplay calls them (same treatment as Nemesis and the tower).

**Done — the dungeon is a GRAPH, not a number line.** Levels are keyed by **string id** with a
display `name` and an `exits` block saying where you can go *from here*; `RunState.current_level`
replaced `current_floor`, and `advance_floor`/`retreat_floor` collapsed into
`go_to(level_id, heal)`. There is **no ordering and no count** (`TOTAL_LEVELS` is gone): a level
nothing points at is unreachable. The old `current_floor + 1` made shortcuts and branches
*inexpressible* — both are by definition a **second edge between places that already exist**, and a
number line has nowhere to put one. Two exit names are known to the code: **`frente`** (the fog/door
at the level's end) and **`tras`** (the back door, boss arenas only). A target may be a bare id
(enter at the start) or `{ level, entry }`, where `entry` is one of **`inicio`** / **`fim`** (right
edge — how you come back through a back door) / **`fogueira`** (lands at the sanctuary bonfire).
Entry points replaced the old `_entry_from_right` boolean. The core still never reads `levels.json`:
whoever builds the run passes `start_level`. `Player.current_floor` is **frozen at 1** — only the
parked Nemesis reads it (note left in `ghost_factory`).

**Done — the first shortcut (`levels.json → shortcut`).** A `"room"` level may declare
`{ id, at }`: the mouth of a shaft placed `at` px past the gate, inside the sanctuary. It starts
**locked and only unlocks from the far side** — which is what gives the first long traversal its
point: you open the door from behind it. Unlocked, it links the **village straight to that level's
bonfire** (`entry: "fogueira"`), skipping the whole combat corridor, and stays open forever
(`id` goes into `RunState.opened_gates`, surviving death — same machinery as the lever's gate).
It draws itself through **`ShortcutView`**, which has two visually distinct states — boarded
(crossed planks) and open (a black shaft) — and **always shows a prompt in reach**
(`destrancar / descer / subir o poço`). The first version reused the ordinary door with a dark
`modulate` and no prompt, and it read as a *broken door*: a shortcut that does not announce itself
is not a shortcut, it is scenery the player walks past. Both ends are **`interact`, never
walk-through**: in the sanctuary the mouth sits on the mandatory
path to the boss fog, so crossing it by walking would teleport the player to the village every time
they went to fight. The village end sits **behind** the spawn point (`VILLAGE_SHORTCUT_X`) for the
same reason. Today: `poco_portao` in `portao`.

**Done — traversal never heals.** `go_to()` lost its `heal` flag: walking into the next area used
to restore full HP (a roguelike end-of-floor convention), which erased the resource bill the
previous area had just charged — you reached the boss topped up and with a full flask for free.
**HP now comes from exactly two places: the bonfire and the flask.**

**Done — the Cemetery, and the new reassembly mechanic.** `cemiterio` sits between the
skeleton room and the Ogre arena: armoured skeletons + heavies + the Necromancer. **While the
Necromancer lives, no skeleton dies.** At 0 HP it *collapses into bones where it stood*
(`EnemyView._collapse`), takes no further damage in that state, and **reassembles intact** after
`room.reassemble_time` seconds (2.0). Clearing the room is impossible by force; killing the
Necromancer is the only exit, and it drops every skeleton at once. This **replaced** the older
pool-based revival (`_dead_pool`/`_respawn_cast`, deleted): that one spawned a *new* skeleton near
the Necromancer after a delay, so the room slowly refilled from one point. The new one is the *same*
skeleton getting back up where you left it — you can't create safe ground, only spend the time.

**Passages.** Three kinds, and each says something different — that is the point:
- A **plain door** is any ordinary exit: walk into it (only in phase `cleared`). This is the
  default now.
- A **fog gate** is the **seal of a boss arena, and nothing else**. `_spawn_exit_passage` grows one
  *only* when the `frente` exit leads to a `"boss"` level that is still alive. It used to cover
  every exit, which diluted the signal: if every door is fog, fog stops announcing a boss.
- A **wooden gate + lever** is now **opt-in per level** (`levels.json → "gate": true`). Without it
  the bonfire is not locked behind the fight, which is the normal soulslike arrangement. Only
  `cemiterio` declares it; `portao` deliberately does not.

The village entrance is still a plain door you walk into. The two mechanism passages, both
persisted in `RunState`:
- A **wooden gate** (`GateView`, a solid StaticBody2D on layer 4) closes the sanctuary off during
  the fight. The **lever** (`LeverView`) that opens it is **always present** (spawned in
  `_spawn_sanctuary`, just before the gate) but starts **disarmed** — it's inert scenery until the
  room is cleared, when `_on_floor_cleared` calls `_lever.arm()` (disarmed: no prompt, `pull()` is a
  no-op, and `_try_pull_lever` returns false, so you can't open the gate — and thus can't rest —
  mid-fight). Pulling the armed lever (`interact`) opens the gate and records
  `RunState.open_gate(id)` — **open stays open forever**, across deaths (`opened_gates`,
  `_gate_id(floor)`). Die before pulling it and you have no checkpoint yet (the fire is past the
  gate), so you respawn in the village; the lever is waiting (re-armed, since the floor is cleared).
- The boss is behind a **fog gate** (`FogGateView`) at the sanctuary's end. It does not block
  physically — you press `interact` (`_try_cross_fog`, cleared phase only) to fade into the arena.
  This replaced the old walk-into-a-door transition to the boss.

All three sanctuary interactions (lever, rest, fog) share the `interact` key and are disambiguated
purely by proximity — they sit far enough apart that only one is ever in reach.

**Done — the bonfire respawns enemies (the run-back).** Resting is not free: it **re-arms the
world**. Once a room level is cleared, a small **guard** of skeletons (data-driven,
`levels.json → guard = { ids, count }`, `_spawn_guard`) reoccupies the refuge stretch *between the
bonfire and the fog gate* — so the path back to the boss reads `bonfire → [guard] → fog → boss`, not
an empty corridor. Resting at the fire **respawns the whole guard** (`_on_bonfire_rested →
_reset_guard`, classic soulslike), and so does dying-and-returning (the cleared branch of
`_start_floor` calls `_spawn_guard`). Killing a guard pays souls like any enemy, which is what makes
the run-back worth walking instead of sprinting. The guard is tracked in `_guard` (separate from the
Necromancer's `_alive`/revival loop — these are plain `EnemyView`s, they never touch room-clear
logic), and its views live in `_enemies` too, so `_clear_entities` frees them; `_on_enemy_died`
erases from both lists. To make room, the refuge was widened (`SANCTUARY_LEN` 620→980, `BONFIRE_IN`
240→160). **Guards spawn dormant and wake by proximity** (`_update_guard_wake`, `GUARD_WAKE`): the
instant the room clears, the guard is spawned *behind the still-closed gate* — dormant means
they wait at their posts instead of marching into the gate, and they animate to life only when you
walk up to them (which also keeps a safe bubble around the fire, since the nearest post is >
`GUARD_WAKE` from the bonfire). A boss level has no `guard` key, so `_spawn_guard` is a no-op there.

**Done — souls and the bloodstain.** `Player.souls` is the only currency. Every kill pays straight
into the pocket (`"souls"` in each enemy's `loot`) — including the skeletons the Necromancer revives
(when a level has one), which used to be XP-blocked to stop farming. Farming polices itself now,
because **souls in the pocket are risk**: they buy nothing until spent, and dying drops *all* of
them. Levels are no longer automatic — they're **bought** at the bonfire (`Leveling.level_cost`,
`SOULS_BASE`/`SOULS_GROWTH`), and each level grants an attribute point. `AttributePanel` folds both
steps into one keypress: raise an attribute and, if no point is banked, the level is purchased on
the spot.

On death, `RunState.drop_bloodstain(floor, x)` leaves a **passive marker** (the classic Dark Souls
bloodstain — *not* an enemy) holding every soul you carried, at the **exact spot you fell** — `x` is
the death position with **no adjustment, including inside a boss arena**. Walk onto it and it's
absorbed automatically (`_update_bloodstain` in `_process`, no keypress, works in every phase — the
`BloodstainView.in_reach` check), and `recover_bloodstain()` pays the souls back. **Die again first
and the mark moves to the new spot — the old souls are gone forever.** No souls, no mark. State is
three fields on `RunState` (`bloodstain_floor/x/souls`), the view is `BloodstainView` (a child of
`_env`, respawned by `_spawn_bloodstain_if_here` in every `_start_floor` branch — room, cleared,
*and* boss — so it reappears wherever you left it). This **replaced the old Echo/Nemesis ghost**: the
boss never summoned anything anyway, and the ghost-fight (`GhostData`/`GhostFactory`/`GhostView`/
`NemesisRules`) is now fully unused in gameplay — the classes still compile and are unit-tested, same
treatment as the tower. `balance.json → nemesis.ENABLED` no longer gates anything (the bloodstain is
always on; it's the base death mechanic, not the optional Nemesis).

**Done — the flask (the Estus).** The **only on-demand heal** in the game: `Player.flask_charges`
(capacity + heal fraction are data, `balance.json → flask`). Each gulp heals `HEAL_FRACTION` of
**max** HP — so raising Vigor also fattens the heal (`flask_heal_amount()`). Charges refill **only**
at a bonfire (`RunState.rest_at`) and on respawn (`respawn()`), never mid-level — that scarcity is
what turns every trade of blows into a resource calculation. Drinking is a **committed gesture**:
`drink_flask()` spends the charge *up front* and returns the amount, but the heal is applied by
`PlayerView` only at the **end** of the drink animation (`_drink_time`/`_drink_heal`). Taking any
hit mid-gulp calls `_interrupt_drink()` — the heal is cancelled but the charge is already gone.
There are **no i-frames** while drinking (unlike the dodge): it's a bet that a safe window exists,
and because enemies are telegraphed, one always does. Bound to **R** (`flask`). `can_drink()`
only needs a charge + being alive — **drinking at full HP is allowed** (the heal saturates at max, but
the charge is spent anyway; the player's call). The gulp has an **orange glow** (`PlayerView._drink_glow`,
a `z=-1` aura that builds/pulses over the drink, orange embers, and a bright burst the instant the
heal lands — `_update_drink_glow`/`_drink_finish_fx`); it fades out on finish or interrupt.

**Done — fixed stats, no more per-floor scaling.** `EnemyFactory` used to multiply every enemy by
a geometric per-floor curve (`GROWTH^(f-1)`) plus a rank multiplier; it now returns the enemy
**exactly as the JSON declares it** (`build(base_dict)` / `build_boss(base_dict)` — the `floor`
argument is gone). That curve was a roguelike device: it kept one skeleton relevant across 50
procedural floors. A soulslike has no "floor 12 skeleton" — it has *that area's* skeleton, with
numbers a designer chose. **To make an encounter harder, edit that enemy's JSON, or author a
variant with its own id and use it only where you want it** — there is no global difficulty knob
left, deliberately, because a global knob is what prevents tuning a single fight.

The stats that the old formula produced were **baked into the JSONs** so nothing changed in feel:
`bss_ogre` 180/25/10 → **1177/43/11** (it was fought on level 2, so it carried one step of growth
plus the ×6 BOSS multiplier), `enm_skeleton_heavy` atk 11→15 and `enm_necromancer` atk 12→17 (the
×1.4 ELITE multiplier). The NORMAL-rank skeletons were already at their effective values.
`rank` survives as a **label** (HP bar, tier, AI), never as a multiplier. `Scaling.enemy_hp/atk/def`
and `rank_mult` still exist but feed only the parked Nemesis/ghost code and `sim_balance`; the
`enemy_scaling` GROWTH_* keys in `balance.json` **no longer affect any enemy in gameplay**. The
**parked tower bosses** (`gbs_*`, `king_tyrant`, `bss_guardian`) were deliberately **left at their
authored values** — baking their curve output would have written 133k-HP "tuning" into a file, so
they stay honest placeholders awaiting the tower redesign.

## Project status: Phase 4 implemented (Phases 1–4 done)

The game is called **Fair Despair**. `TDV_Arquitetura.md` is the original GDD + software
architecture, written when it was a roguelike named *A Torre da Vingança* (Tower of Vengeance) —
hence the `TDV_` prefix and the old name still scattered through the design docs, the bestiary and
the unwired 50-floor tower content. **The architecture in it still holds; the genre and the name do
not.** Read it before writing code; each section is self-contained and meant to be pasted as prompt
context when implementing the corresponding phase.

**Phase 1 (Fundação & Esqueleto) is done**: `project.godot` with autoloads, `data/balance.json` +
`BalanceConfig`, `EventBus`, seeded `RNGService`, stack-based `StateMachine`/`GameState`/`MainMenuState`,
`JsonLoader` + repositories, a `main_menu.tscn` scene, and a headless test suite under `tests/`.

**Phase 2 (Combate & Movimento Mínimo) is done** (validated in-editor): Core entities
`StatBlock`/`Weapon`/`Player`/`Enemy` (JSON-hydrated), `CombatResolver` (§1.2.3 formulas, centralized
mitigation via `defense_curve`), keyboard-only `PlayerView` (move + melee), `EnemyView` (aggressive AI
+ HP bar), `Hud`, and `combat_test.tscn`.

**Phase 3 (Progressão, Augments & Bosses Normais) is done**: `Scaling`/`Leveling`, `EnemyFactory`
(geometric per-floor scaling + rank multipliers), `Augment`/`AugmentEffect`/`StatResolver`
(ADD<PCT_ADD<MULT), weighted `AugmentPool`, `Boss`/`BossPhase` (phased), `RunState`/`FloorManager`,
and the playable `floor_scene` (waves → boss → card reward → next floor) with `CardSelect`.

**Area names (2026-07-20)**: the run reads **Cidade → Portão → Cemitério → Bosque do Ogro →
Acampamento**. Ids stay ASCII (`portao`, `cemiterio`, `bosque_ogro`, `acampamento`); the accented
`name` in `levels.json` is what the HUD shows. **Cidade** is the tutorial village and is still
*not* a graph node (`_start_tutorial`). Note the names now promise outdoor places while the levels
are still flat corridors with placeholder scenery — the biome art has not caught up.

**Scope right now**: the playable dungeon is **3 hand-authored levels** — level 1 (a skeleton room:
dormant minions that wake by proximity, cleared by killing them all), level 2 (Ogre boss arena) and
level 3 (a `"rest"` area) — plus the tutorial village. **There is no victory screen any more**
(`EndScreen` is compiled-but-unused, same treatment as the tower): beating the Ogre just opens the
arena. The **boss arena has two doors** (`_spawn_boss_doors`), one on each wall — back (re-enter the
previous level from its far end, `_entry_from_right`/`retreat_floor()`) and forward (the next level)
— each covered by a **locked fog** (`FogGateView.locked`: dim, behind entities, no prompt) while the
boss lives; killing him dissolves both (`_dismiss_boss_fogs`) and the doors become walk-through like
the village door. A `"rest"` level is a small safe screen: a bonfire near the entrance, the fog at
the end, no enemies/lever/gate (`_spawn_rest_area`); the last level's fog refuses to cross ("ainda
por vir"). Controls are **remappable** (autoload `KeyBinds`, persisted in `user://keybinds.json`,
CONTROLES tab in Options); every key name shown in UI comes from `KeyBinds`, never hardcoded. **The Necromancer was pulled out of level 1** (he'll be placed in a later
level); his machinery — the static ranged elite, the revival loop, the heavy a/b/c chain — stays in
`floor_scene` intact and fires only when a level's `room` declares `elites`. A `room` without a
Necromancer is just "kill everything": `_check_room_cleared` clears it by count, and the scattered
minions spawn **dormant**, waking within `MINION_WAKE` of the player (`_update_room_wake`, the same
feel as the refuge guard). `data/floors/levels.json`
is the whole content list and `TOTAL_LEVELS` in `floor_scene.gd` must match it; there is **no
fallback level and no procedural repetition** (passages only open toward levels that exist).
**Environmental hazards** (`HazardView` + `data/hazards.json`) are the first non-combat content:
what a hazard *is* lives in `hazards.json`, where it *sits* in each level's `"hazards"` array.
A spike pit is *terrain*: `_build_environment` reads the level's hazard list and lays the floor as
slabs with a gap at each pit plus a deeper solid slab closing its bottom. **Falling in kills
instantly** (`instakill`) via `PlayerView.kill()`, which deliberately **ignores the dodge i-frames**
— a pit is crossed by *jumping*, not by rolling through it. (Rolling *across* the gap is legitimate
traversal: the dash covers ~86px, wider than a 56px pit. What the i-frames must not do is save you
once you're already inside.) A hazard without `instakill` falls back to the normal
`apply_flat_damage` path, so non-lethal traps stay possible. Enemies don't jump, so
`EnemyView._ledge_ahead()` stops them at the rim (`LEDGE_DEPTH` must stay smaller than any pit's
`depth`) and `_off_pit()` keeps spawns out of the hole — without those two, a skeleton falls in and
is stuck forever. **Right now there is no pit anywhere** (the tutorial's was removed on request):
`_TUTORIAL_HAZARDS` is empty and no level declares `"hazards"`, so the whole hazard machinery
(`HazardView`, `_off_pit`, `_ledge_ahead`) sits idle, ready for a level that places one.

**Scenery decoration** (`_decorate_scenery`, called from `_build_environment`) scatters placeholder
background props — dead trees, rocks, wooden fences, ruined buildings (ColorRect/Polygon2D, no art
yet, no collision, `z = DECO_Z = -4`, behind entities and in front of the ground) — so levels don't
read as bare corridors. Placement is **deterministic** (a local `RandomNumberGenerator` seeded by
level width, *not* `RNGService` — it's purely cosmetic), so the layout is identical every rebuild
and never reshuffles on death/respawn. The tutorial village keeps its houses (`_decorate_village`)
*and* gets the same scatter.

**Tutorial teaching is a HUD toast, not world signs.** The old wooden control signs are gone. The
lessons live in `_TUTORIAL_TIPS` (`[trigger_x, text]`) and surface as a centered bottom-of-screen toast
(`_build_tip_ui`/`_show_tip`, a `Control` in `_layer`) as the player walks past each `x`
(`_update_tutorial_tips`, once each). A tip auto-dismisses after `TIP_SECONDS` (10s) or the instant
the player presses `interact` (E) — that dismissal takes priority over every other `interact`
action, but the village has no lever/bonfire/fog so there's no conflict. The first tip is fired
explicitly at the end of `_start_tutorial` (not left to frame-1 `_process`) so it's up the moment the
village loads; `_tips_done` resets each village visit and `_begin_dungeon` hides any open tip.

The old 50-floor tower (`TowerManager`, `data/floors/tower.json`, the 5 great-boss + King JSONs) is
**no longer wired into gameplay** — it still exists and is still unit-tested, awaiting the redesign.

**Phase 4 (A Torre Completa & Nemesis System) is done**: `TowerManager` + `data/floors/tower.json`
(50 floors, great bosses at 10/20/30/40/50, King at 51), 5 `GREAT_BOSS` + 1 `KING` boss JSONs,
the Nemesis system — `GhostData`/`GhostRepository` (persists to `user://saves/ghosts.json`),
`GhostFactory`/`NemesisRules` (5 rules: nerf, anti-impossible HP cap, anti-irrelevant ELITE floor,
augment inheritance by tier, summon eligibility) — boss summons the echo at 60% HP, catharsis
(heal + Vengeance buff + guaranteed Relic+ reward), `GhostView`, and death/victory `EndScreen`s.
**The Nemesis system is currently switched OFF in gameplay** (`nemesis.ENABLED = false` in
`data/balance.json`): no echo is recorded on death or summoned by bosses. The code and its tests
are untouched — flip the flag to bring it back.
131 tests pass. **Next up is Phase 5 (Balanceamento, Juice & Polimento)** — see roadmap below.

Stack: **Godot 4 + GDScript** (§0.1). Input actions (`move_*`, `attack`) are registered in code by
`GameManager._setup_input_actions()`, not in `project.godot`. Navigation menu↔run is still a
provisional `change_scene_to_file` (the proper FSM↔scene integration is deferred).

## Architecture (planned — from `TDV_Arquitetura.md`)

The defining structural decision is a **rigid Core ↔ Presentation split**. Internalize the dependency
rule before adding files (§2.3):

```
presentation  ──may import──►  core, services, data_layer
states        ──may import──►  core, services, data_layer
core          ──may import──►  (only core + pure services)
core          ──NEVER imports──►  presentation / render / engine APIs
```

`src/core/` holds all game logic (combat, progression, RNG, ghost/nemesis rules) and must remain
render-free and unit-testable without opening a window. Violating this rule is the single most
important thing to avoid — it makes the logic non-portable and untestable.

Four non-negotiable principles (§0.2):
1. **Data-driven** — weapons, enemies, augments, floors, and *all* tuning constants live in JSON
   under `data/` (see `data/balance.json`, Appendix A). Never hardcode game numbers in logic.
2. **Pure core** — see the dependency rule above.
3. **Deterministic RNG** — every random draw goes through a seeded `RNGService`. Same seed → same
   run. Do not call engine/global RNG directly anywhere in core.
4. **Events over coupling** — systems communicate via a global `EventBus` (signals). UI listens to
   core; core never references UI.

### Key systems to understand before editing across files

- **Stack-based FSM** (§2.1): a central `StateMachine` does `push`/`pop`/`change`; each `GameState`
  has `enter/exit/update/handle_input`. `Pause` is pushed *over* `Combat` without destroying it. The
  transition table in §2.1 is the implementation source of truth.
- **Scaling asymmetry** (§1.2): enemies grow geometrically per floor; the player grows linearly and
  only catches up through weapon upgrades + augments. The master formulas (HIT_DAMAGE / DPS / EHP)
  belong in `CombatResolver` so balancing stays centralized. Tune via `balance.json`, never in code.
- **Augment stacking order** (§1.3.2): `final = ((base + ΣADD) * (1 + ΣPCT_ADD)) * ΠMULT`. Implement
  in `StatResolver`; `MULT` is reserved for Artifact-tier effects.
- **Nemesis / Ghost system** (§1.4): the signature mechanic. `GhostData` is the only entity that
  persists across permadeath (`user://saves/ghosts.json`). `GhostFactory` builds a nerfed ELITE-rank
  enemy from a prior run's snapshot, enforcing the 5 math rules (nemesis coeff, HP cap relative to
  current player, partial augment inheritance, simplified "echo" AI, single summon at boss HP
  threshold). The anti-impossible HP cap rule must have tests.

## Planned folder structure

See §2.3 for the authoritative tree. Top level: `data/` (JSON content + `balance.json`),
`src/{core,data_layer,states,presentation,services,autoload}/`, `assets/`, `tests/`, `docs/`.

## Implementation roadmap

Build in the 5-phase order from §2.4 — each phase is a playable/testable milestone and depends on the
previous one. Do not skip ahead:
1. **Foundation** — folder skeleton, `BalanceConfig`, `EventBus`, seeded `RNGService`, FSM + MainMenu,
   JSON loaders.
2. **Combat & movement** — `Player`/`Weapon`/`StatBlock`, `CombatResolver`, one melee weapon, one
   `NORMAL` enemy, basic HUD.
3. **Progression / augments / normal bosses** — leveling + scaling, `WaveSpawner`/`FloorManager`,
   `Augment` + `StatResolver`, weighted `AugmentPool`, card-select UI, phased boss.
4. **Full tower & nemesis** — 50-floor loop, 5 great bosses, `GhostData`/`GhostRepository`,
   `GhostFactory`/`NemesisRules`, ghost summon + catharsis buff, King arena, death/victory screens.
5. **Balance, juice, polish** — `sim_balance` TTK simulator, game feel, audio, retro aesthetic,
   hardcore graveyard variant, accessibility, save edge cases.

## Commands

Requires Godot 4 (the `godot` binary on PATH). The project has no external addons — the test runner
is hand-rolled, not GUT.

```bash
# Run the game (editor)
godot project.godot

# Run the game headless (no window)
godot --headless

# Re-scan & regenerate the global class_name cache (REQUIRED after creating new
# class_name scripts outside the editor — otherwise tests fail with "Identifier
# <Class> not declared in the current scope"). The editor does this automatically
# when focused; headless runs do not.
godot --headless --import

# Run the full test suite (exits 0 on pass, 1 on failure — CI-friendly)
godot --headless --script res://tests/test_runner.gd
```

- Tests live under `tests/`. Each suite extends `TestCase` (`tests/test_case.gd`) and defines
  `test_*()` methods; register new suites in the `SUITES` dict of `tests/test_runner.gd`. There is no
  single-test flag yet — comment out other entries in `SUITES`, or temporarily rename methods, to
  isolate one.
- `tests/sim_balance.gd` is a balance simulator, NOT a unit test: for each sampled floor it builds a
  "median" player and computes the §1.2.4 TTKs (kill / die), flagging values outside the target bands
  (`ttk_targets` in `balance.json`). Re-run after changing any tuning constant. The median-player
  assumptions (weapon upgrades & augments per floor) are constants at the top of `tests/balance_sim.gd`
  — the actual logic lives there and is `load()`-ed at runtime by the thin `sim_balance.gd` runner
  (same autoload-availability workaround as `test_runner.gd`). Run it with:
  `godot --headless --script res://tests/sim_balance.gd` (always exits 0 — it's a report).

## Conventions established in Phase 1

- **Autoloads** (configured in `project.godot`, order matters): `BalanceConfig`, `EventBus`,
  `RNGService` load first; `GameManager` (bootstrap) loads last and depends on them. `Music`
  (one track at a time) and `Sfx` (pooled one-shots + loops, with per-id variation lists) read
  `data/audio.json` — audio paths, volumes, and *which entity has which sound* are data, never
  hardcoded (see `assets/audio/README.md`).
- `GameState` uses `state_name` (not `name`, which collides with `Node`/`Object` members).
- All randomness goes through `RNGService` (seeded). `balance.json` is plain JSON — **no comments**
  (Godot's JSON parser rejects them), despite the JSONC examples in the GDD appendix.
- Data repositories extend `BaseRepository` and index JSON entries by their `"id"` field.
