# The Neon Graveyard: prototype

One isometric room, one interactable, and the Disco Elysium-style skill system.
Godot 4 (built and tested on 4.7.2). Placeholder art: Kenney's Isometric Miniature Library (CC0).

## Run it
Open `project.godot` in Godot 4 and press F5.

| Input | Action |
|---|---|
| Left-click floor | walk there |
| Left-click the display case | walk over and examine it |
| E | examine something adjacent |
| Tab | skill sheet |
| F1 | debug grid (solid cells) |
| Esc | close the dialogue |

## How it works
- `data/skills.json`: the 24 skills (6 groups of 4), starting levels, descriptions, voices.
- `data/room.json`: room size, player start, props (sprite, facing N/E/S/W, cell).
- `data/interactables/*.json`: an object's intro text, passive checks and active checks.
  Content is plain JSON, so a writing agent can fill it in without touching code.
- `scripts/skill_system.gd` (autoload `Skills`): 2d6 + skill vs target. Double six always succeeds, double one always fails.
  Passive checks are deterministic: skill + `PASSIVE_BASE` (7, an average roll) vs target.
  Targets: Trivial 5, Easy 8, Medium 10, Challenging 12, High 15, Legendary 18.
- `scripts/game_state.gd` (autoload `GameState`): red checks are one-shot; white checks retry only after the skill level rises.
- `scripts/iso.gd`: grid maths. `TILE_W`/`TILE_H` and `SPRITE_ORIGIN` live here.
- `scripts/room.gd`: builds the room from data, click-to-move with `AStarGrid2D`, y-sorting.
- `scripts/dialogue_ui.gd`: DOS-style panel, skill voices as pop-up windows, skill sheet.

## Tests
```
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd
```
