# The Neon Graveyard: prototype

One isometric room, one interactable, and the Disco Elysium-style skill system.
Godot 4 (built and tested on 4.7.2). Placeholder art: Kenney's Isometric Miniature Library (CC0).

## Run it
Open `project.godot` in Godot 4 and press F5.

## TEST LINE FOR GIT

| Input | Action |
|---|---|
| Left-click floor | walk there |
| Left-click an object | walk over and examine / pick it up |
| E | examine something adjacent |
| C | character sheet |
| I | inventory |
| F1 | debug grid (solid cells) |
| Esc | close whatever is open |

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

## Character menu (modelled on Disco Elysium's)
- **Character sheet (C):** level, XP bar, skill points; skills in grouped rows with a detail pane
  (learned level, clothing modifiers, learning cap). Raise a skill for 1 point; **Revert** undoes
  raises made since the sheet was opened (closing the sheet commits them).
- **Inventory (I):** health and morale with healing charges, clothing modifiers, a paper doll with
  8 named slots (headgear, eyewear, neckwear, jacket, shirt, gloves, pants, shoes), and Clothes / Other tabs.
- **HUD:** health and morale pips with healing buttons (bottom left), money (top right).
- `scripts/character.gd` (autoload `Character`) holds the state; `scripts/character_menu.gd` is the UI.
- Data: `data/character.json` (starting state), `data/items.json`, `data/progression.json`.

## Interactables and pick-ups
Objects in `data/interactables/*.json` have a `kind`:
- `dialogue` (default): opens the dialogue panel with passive and active skill checks.
- `pickup`: has an `item` id from `data/items.json`. Interacting adds it to the inventory and removes it from the room for good.
- `money`: has an `amount`. Interacting gives the money once; the object stays but is empty afterwards.
- `container`: has `contents`, a list of item ids. Interacting opens a pop-up with the contents beside your inventory; click an item to move it across (take or store), or use TAKE ALL. Contents persist per container id in `GameState.containers`. Example: `data/interactables/footlocker.json`.

Set `"blocking": false` for things lying on the floor. Objects can use a Kenney sprite (`sprite` + `dir`) or a standalone
`image` + `origin` (the pixel that sits on the cell centre). The hard hat and wallet use generated placeholder images in
`assets/placeholders/`, so real art can replace them by swapping the files.

### Known gaps / TODO
- **Attributes:** the design docs have no attribute layer (DE has four attributes that set each skill's cap). Add it to the
  Skills doc, then replace the stopgap below. Reminder requested by the project owner.

### Assumptions to revisit
- Each of your 6 skill groups plays the role of a DE attribute: its `score` in `skills.json` is the learning cap for
  its skills, and the signature skill raises that cap by 1.
- Health follows Hardscrabble and morale follows Keel (DE uses Endurance and Volition).
- `data/progression.json` (XP per level, level cap 15) is **placeholder**: DE's real numbers were not verified.
  One skill point per level is the confirmed rule.
- Currency symbol, item names and modifiers are placeholders. Thought Cabinet and Journal are not built yet.

## Tests
```
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/test_character.gd
godot --headless --path . --script tests/test_pickups.gd
godot --headless --path . --script tests/test_containers.gd
```
