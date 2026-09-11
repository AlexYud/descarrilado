# Unrailed

Godot 4.7 first-person horror project.

## Project map

- `assets/` contains imported source assets and reusable materials/shaders.
- `scenes/` contains all authored Godot scenes, grouped by gameplay domain.
- `scripts/` mirrors those domains and contains gameplay code.
- `localization/` contains gettext catalogs and localized voice folders.
- `terrain_data/` contains one Terrain3D data directory per scene. Do not
  rename its generated region files by hand.
- `addons/` contains third-party plugins. Keep game-specific code outside it.

The current entry flow is:

`scenes/menu/main_menu.tscn` -> `scenes/cinematics/dream_intro.tscn` -> future levels

See [Project structure](docs/project_structure.md) for naming rules and the
recommended workflow for adding levels and features.

## Validation

Before considering a feature complete:

1. Run the main menu and follow the normal transition into the game.
2. Run the changed scene directly with **F6**.
3. Check Godot's Output and Debugger panels for errors and new warnings.
4. Test both `en` and `pt_BR` when player-facing text changes.
5. Test every affected graphics preset when rendering changes.
