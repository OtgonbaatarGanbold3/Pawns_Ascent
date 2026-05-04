# Pawn Ascent

This is a Godot 4.6 GDScript project for a roguelike board-combat game.

## Primary References

Read `docs/` before implementing gameplay or narrative changes:

- `docs/pawns_ascent_concept.md`: core premise, tone, world, enemy voice, design pillars.
- `docs/pawns_ascent_mechanics.md`: combat, movement, turns, items, AI, evolution, legacy boss rules.
- `docs/pawns_ascent_story_world.md`: expanded world, lands, paths, legacy lands, writing rules.
- `docs/pawns_ascent_progression.md`: run structure, path graph, themes, economy, score, story mode.

## Project Layout

- `scripts/`: gameplay systems, UI logic, autoloads, tests, and resources.
- `scenes/`: runtime scenes and test scenes.
- `data/`: JSON config for gameplay numbers and tunable rules.
- `docs/`: design source of truth.

## Engineering Rules

- Keep numerical gameplay values in JSON config files under `data/`; do not hardcode tunable balance values in scripts.
- Prefer existing systems and naming patterns over new abstractions.
- Keep `RunState` and persistent meta/progression state separate.
- Enemies, allies, and legacy bosses should share the same data-driven AI path unless a doc explicitly requires a presentation-only special case.
- When changing gameplay behavior, check or update the matching files under `scripts/tests/` and `scenes/tests/` where applicable.

## Game Design Rules

- The board is the world. Terrain mutation should feel like the Plain or realm resisting the player, not arbitrary difficulty.
- Evolution should feel uncanny, not triumphant.
- Items are relics with story, not generic power-ups.
- The law, hierarchy, and cycle are the horror; avoid villain-driven explanations.

## Writing Rules

- No exposition dumps.
- Enemy dialogue should be short, bleak, and occasionally dark-wry, usually 2-3 lines maximum.
- Item descriptions should read as if written by a piece who once carried the item.
- Contradictions in lore are allowed and intentional.
- Do not make the world ironic, self-aware, parody-like, or comforting.
