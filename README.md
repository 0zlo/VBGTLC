# Vault of Bent Geometry That Loads Correctly

Vault of Bent Geometry That Loads Correctly (VBGTLC) is a Godot 4 vertical slice for a low-poly first-person procedural dungeon crawler with suspiciously confident system language and geometry that is only mostly behaving.

## What Is In The Repo Now

- Deterministic seed-based dungeon generation with sample seeds and menu seed input.
- Procedural low-poly room and corridor geometry built in GDScript with `ArrayMesh`/`SurfaceTool`-style mesh assembly and generated collision.
- Irregular room footprints, wedge/trapezoid chambers, angled transforms, diagonal corridors, and sloped traversal.
- Limited verticality through ramps, raised platforms, split-height spaces, and elevation-changing corridors.
- Tiny staging hub before entering the generated dungeon.
- First-person controller with mouse look, sprint, jump, interaction, melee attack, and a ranged continuity pulse.
- Enemies that patrol, chase, and attack.
- Pickups and consumables: keys, tonics, and aether charges.
- Health, stamina, and mana stats with HUD bars.
- Doors, locked doors, and key gating.
- Deterministic minimap/floor representation.
- Save/load of the current run including seed, player state, inventory basics, and discovered map state.
- Title screen, pause flow, death/restart flow, and return-to-title path.
- Generated placeholder visuals only; no external asset dependency.

## Prerequisites

- Windows 10/11
- Godot 4.x installed and available as `godot` in `PATH`, or use the portable copy in this repo

## Quick Start

1. Launch the game:

```powershell
.\tools\run-game.ps1
```

2. Open the editor:

```powershell
.\tools\run-editor.ps1
```

3. Compile/validation pass without opening the game window:

```powershell
.\tools\run-game.ps1 -Headless -Quit
```

4. Export a Windows build:

```powershell
.\tools\install-export-templates.ps1
.\tools\export-windows.ps1
```

## Controls

- `WASD` / arrow keys: move
- `Shift`: sprint, or descend in godmode
- `Space`: jump, or ascend in godmode
- `E`: interact
- `Left Mouse`: melee strike
- `Right Mouse`: continuity pulse
- `Q`: use tonic
- `F`: use aether charge
- `Tab`: toggle minimap
- `F10`: toggle godmode
- `Esc`: pause

Godmode notes:

- disables collision
- raises movement speed
- `Space` flies up
- `Shift` flies down

## Sample Seeds

- `GEOMETRY-INTEGRITY`
- `BENT-STAIRS-14`
- `NO-MEANINGFUL-DEVIATION`
- `ARCHIVE-WEDGE-22`

## Save/Load Notes

- The title screen `Continue Run` button loads `user://run_save.json`.
- Autosave runs while you are in the hub or dungeon.
- Death clears the active save and offers a restart back through the hub.

## Project Notes

- The project title is integrated into `project.godot`, the main menu, and export metadata.
- The dungeon is generated at runtime and collision is created from the same geometry used for traversal.
- The repo stays self-contained: no external art packs, paid assets, or off-repo dependencies.
