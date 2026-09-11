# Project structure

This layout keeps each feature's scenes and scripts easy to find without
mixing game code with imported art.

## Scenes

| Folder | Purpose |
| --- | --- |
| `scenes/autoload/` | Scene-based global services registered as autoloads |
| `scenes/cinematics/` | Intro and story sequences |
| `scenes/environment/` | Reusable world and environment scenes |
| `scenes/levels/` | Playable level roots |
| `scenes/menu/` | Main-menu scenes and menu scenery |
| `scenes/objects/` | Reusable props and interactable objects |
| `scenes/player/` | Player scene and future player-owned scenes |
| `scenes/ui/` | Reusable interface scenes |

Terrain3D region data lives separately under `terrain_data/<scene_name>/`.
Use a dedicated directory for each level; sharing one data directory between
two editable terrains would make changes leak from one scene into the other.

## Scripts

Scripts are grouped by the feature that owns their behavior:

- `audio/`, `cinematics/`, `core/`, `dialogue/`, `environment/`
- `interactions/`, `items/`, `menu/`, `player/`, `train/`, `ui/`
- `debug/`, `optimization/`, and `tools/` for development or infrastructure

Do not create new scripts directly under `scripts/`. Put each script beside
the feature it serves. Cross-feature systems belong in `core/` only when they
are genuinely shared.

## Naming conventions

- Files and folders: `snake_case`.
- Node names and globally named classes: `PascalCase`.
- Variables, functions, and signals: `snake_case`.
- Constants and enum members: `UPPER_SNAKE_CASE`.
- Level files: `chapter_01.tscn`, or `chapter_01_<location>.tscn` when a chapter
  is split into multiple maps.
- Imported third-party filenames may keep their original names. Renaming an
  imported model or texture can break import metadata and material links.

Keep each reusable scene self-contained. A reusable object should expose its
dependencies through exported properties or signals instead of reaching into
a particular level with long absolute node paths.

## Adding a level

1. Create its root scene in `scenes/levels/`.
2. Use a `Node3D` root named after the level, such as `Chapter01Station`.
3. Group children by responsibility: `Environment`, `Geometry`, `Gameplay`,
   `Lighting`, `PlayerSpawn`, and `UI` where applicable.
4. Give every Terrain3D node its own matching folder under `terrain_data/`.
5. Instance reusable content from `scenes/objects/`, `scenes/environment/`,
   and `scenes/player/` instead of duplicating it.
6. Put level-specific orchestration in `scripts/levels/`. Create that folder
   when the first level-specific script is needed; do not add an empty folder.
7. Use signals between triggers and level orchestration so object scripts stay
   reusable.
8. Store player-facing text as localization keys and update all catalogs in
   `localization/`.

## Dependency direction

Prefer this direction of dependencies:

`level controller -> reusable feature -> shared core service`

Core services must not reference a particular level. Player and interaction
scripts must not depend on menu or cinematic scenes. This keeps future levels
incremental and prevents a change in one scene from breaking unrelated ones.
