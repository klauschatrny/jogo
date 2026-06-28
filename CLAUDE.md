# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status: Phase 1 implemented

The canonical spec is **`TDV_Arquitetura.md`** — a full GDD + software architecture for *A Torre da
Vingança* (Tower of Vengeance), a 2D retro roguelike. Read it before writing code; each section is
self-contained and meant to be pasted as prompt context when implementing the corresponding phase.

**Phase 1 (Fundação & Esqueleto) is done**: `project.godot` with autoloads, `data/balance.json` +
`BalanceConfig`, `EventBus`, seeded `RNGService`, stack-based `StateMachine`/`GameState`/`MainMenuState`,
`JsonLoader` + repositories, a `main_menu.tscn` scene, and a headless test suite under `tests/`.
Next up is **Phase 2 (Combate & Movimento Mínimo)** — see roadmap below.

Stack: **Godot 4 + GDScript** (§0.1). The `core/` entity folders are still empty placeholders
(`.gitkeep`); they get populated starting in Phase 2.

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

# Run the full test suite (exits 0 on pass, 1 on failure — CI-friendly)
godot --headless --script res://tests/test_runner.gd
```

- Tests live under `tests/`. Each suite extends `TestCase` (`tests/test_case.gd`) and defines
  `test_*()` methods; register new suites in the `SUITES` dict of `tests/test_runner.gd`. There is no
  single-test flag yet — comment out other entries in `SUITES`, or temporarily rename methods, to
  isolate one.
- `tests/sim_balance.gd` (Phase 5, not yet created) will be a balance simulator, not a unit test: it
  computes TTK per floor for a "median" player and flags values outside the target bands in §1.2.4.
  Re-run it after changing any constant in `balance.json`.

## Conventions established in Phase 1

- **Autoloads** (configured in `project.godot`, order matters): `BalanceConfig`, `EventBus`,
  `RNGService` load first; `GameManager` (bootstrap) loads last and depends on them.
- `GameState` uses `state_name` (not `name`, which collides with `Node`/`Object` members).
- All randomness goes through `RNGService` (seeded). `balance.json` is plain JSON — **no comments**
  (Godot's JSON parser rejects them), despite the JSONC examples in the GDD appendix.
- Data repositories extend `BaseRepository` and index JSON entries by their `"id"` field.
