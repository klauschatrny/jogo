# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status: Phase 4 implemented (Phases 1–4 done)

The canonical spec is **`TDV_Arquitetura.md`** — a full GDD + software architecture for *A Torre da
Vingança* (Tower of Vengeance), a 2D retro roguelike. Read it before writing code; each section is
self-contained and meant to be pasted as prompt context when implementing the corresponding phase.

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

**Scope right now**: the playable dungeon is **2 hand-authored levels** — level 1 (Necromancer's
skeleton room) and level 2 (Ogre boss arena) — plus the tutorial village. `data/floors/levels.json`
is the whole content list and `TOTAL_LEVELS` in `floor_scene.gd` must match it; there is **no
fallback level and no procedural repetition** (a missing level ends the run with a warning). The
old 50-floor tower (`TowerManager`, `data/floors/tower.json`, the 5 great-boss + King JSONs) is
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
