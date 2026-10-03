# PROJECT_CONTEXT.md — Unrailed

> Single source of truth for the project. Read this before adding a feature or fixing a bug, and update it in the same change that alters anything described here.
>
> **Legend:** ✅ Implemented (verified in code) · 🚧 Partial / stub · 📋 Planned (design only, not built) · ❓ Open question

Last verified against the codebase: 2026-10-03.

---

## 1. Project Overview

| | |
|---|---|
| **Title** | Unrailed (working title; `config/name`) |
| **Genre** | First-person, realistic 3D horror |
| **Engine** | Godot 4.7, Forward Plus, GDScript 2.0 |
| **Physics** | Jolt Physics |
| **Rendering** | D3D12 on Windows, `run/max_fps=60` |
| **Languages** | `en`, `pt_BR` (text and voice, set independently) |
| **Current target** | The Demo: "Dream Intro" scene (see §7) |

**Tone pillars** (keep every addition consistent with these):
- Dark, realistic, oppressive. Light is scarce: the flashlight is the player's main tool.
- Quiet dread over jump scares. Lore is delivered through objects, places and short dialogue lines, not exposition dumps.
- The player is never told what to do; exploration order is the player's choice.

---

## 2. Technical Stack & Plugins

| Component | Detail |
|---|---|
| Engine | Godot 4.7 (`config/features`: `4.7`, `Forward Plus`) |
| Language | GDScript 2.0 — typed, `@export`, `@onready`, `class_name` |
| Terrain | **Terrain3D** (`addons/terrain_3d`, the only enabled editor plugin) |
| Terrain data | One folder per scene: `terrain_data/<scene_name>/`. Never hand-rename region files. Never share one data dir between two editable terrains |
| Localization | gettext `.po` catalogs in `localization/` |
| Tests | Headless smoke-test scenes/scripts in `tests/` (save system focused) |

Notes:
- `addons/terrain_3d/bin/~libterrain.windows.debug.x86_64.dll` is a transient file the editor creates when the plugin DLL is loaded. Don't commit it.
- The terrain `.res` files change whenever the terrain is sculpted, so a noisy git diff there is normal.

---

## 3. Architecture

### 3.1 Folder layout

```
res://
├── addons/terrain_3d/        third-party plugin; no game code here
├── assets/                   audios, materials, models, shaders, textures
├── docs/                     project_structure.md, save_system.md
├── localization/             en.po, pt_BR.po, messages.pot, glossary.md, voice/{en,pt_BR}
├── scenes/
│   ├── autoload/             scene-based autoloads (persistent_audio.tscn)
│   ├── cinematics/           dream_intro.tscn
│   ├── environment/          world_environment_store.tscn, streets/
│   ├── levels/               chapter_01.tscn
│   ├── menu/                 main_menu.tscn, scenery/ (chunks a–d)
│   ├── objects/              reusable props and interactables
│   ├── player/               player.tscn
│   └── ui/                   dialogue/, filters/, options, pause, save slots
├── scripts/                  mirrors the scenes/ domains (see below)
├── terrain_data/             one dir per Terrain3D scene
└── tests/                    smoke tests
```

`scripts/` domains: `audio, cinematics, core, debug, dialogue, environment, interactions, items, menu, optimization, player, save, tools, train, ui`. **Never create scripts directly under `scripts/`**; place each one beside the feature that owns it. Level-specific orchestration goes in `scripts/levels/` (create it when the first such script is needed).

### 3.2 Autoloads (global singletons)

| Name | Path | Responsibility |
|---|---|---|
| `GameSettings` | `scripts/core/game_settings.gd` | Persists `user://settings.cfg`: master volume, graphics preset (Low/Medium/High render scale), display mode, resolution, vsync, FPS limit, brightness, text/voice locale, mouse sensitivity, invert-Y. Emits a signal per setting |
| `SaveManager` | `scripts/save/save_manager.gd` | 3-slot versioned JSON saves in `user://saves/` (see §6) |
| `HorrorFilter` | `scenes/ui/filters/horror_filter.tscn` | Full-screen horror post-effect overlay |
| `SceneTransition` | `scripts/ui/scene_transition_manager.gd` | Black-fade scene transitions with threaded loading |
| `DialogueManager` | `scripts/dialogue/dialogue_manager.gd` | Queued subtitles: `show_timed(key, duration, freeze)` and `show_continue(key, freeze)`; emits `player_freeze_changed` |
| `PersistentAudio` | `scenes/autoload/persistent_audio.tscn` | Audio that survives scene changes |

### 3.3 Player architecture (composition)

`scenes/player/player.tscn` is a `CharacterBody3D` driven by [player_controller.gd](scripts/player/player_controller.gd), which is a thin coordinator over single-purpose child controllers. **Add behavior to the matching controller, not to `player_controller.gd`.**

| Controller | Owns |
|---|---|
| `player_movement_controller.gd` | Walk, sprint, crouch, jump, head bob, camera look, stair snapping, cutscene camera control, movement save/restore |
| `flashlight_controller.gd` | Flashlight toggle, battery/behavior, hand-held light (`Player/Hand/SpotLight3D`) |
| `player_interaction_controller.gd` | Center-screen `InteractRay` (2 m), prompt label, dispatches `interact()` |
| `player_inventory_controller.gd` | 6-slot inventory data model |
| `inventory_ui_controller.gd` (ui/) | Inventory panel: select, **Use**, **Inspect** buttons |
| `player_inspect_controller.gd` | 3D inspection of world objects and inventory items |
| `player_audio_controller.gd` | Footsteps and player sounds |

Player freeze states that block input: `cutscene_frozen`, `dialogue_frozen`, inventory open, inspect open. Manual saving is additionally gated by `set_manual_save_blocked()`.

Public player API that other systems rely on (keep stable): `has_inventory_space()`, `has_inventory_item(id)`, `consume_inventory_item(id)`, `add_item_to_inventory(...)`, `start_world_inspect(inspectable)`, `set_cutscene_frozen(bool)`, `set_manual_save_blocked(bool)`, `can_manual_save()`.

### 3.4 Dependency direction

`level controller → reusable feature → shared core service`

- Core services must not reference a particular level.
- Player and interaction scripts must not depend on menu or cinematic scenes.
- Triggers talk to level controllers via **signals**; reusable object scripts stay level-agnostic.
- Reusable scenes expose dependencies through `@export`, not long absolute node paths.

### 3.5 Conventions

- Files/folders `snake_case`; nodes and `class_name` `PascalCase`; vars/funcs/signals `snake_case`; constants/enums `UPPER_SNAKE_CASE`.
- Level files: `chapter_01.tscn` or `chapter_01_<location>.tscn`.
- **All player-facing text is a localization key**, never a literal string (see §8).
- Tabs for indentation; typed GDScript (`var x: float`, `-> void`) throughout.
- Imported third-party filenames may keep their original names; renaming breaks import metadata.

### 3.6 Performance tooling

`scripts/optimization/`: `scene_performance_profile.gd` (per-scene quality profile, instanced as `PerformanceProfile` in each level), `render_distance_group.gd`, `runtime_multimesh_batcher.gd`. `scripts/tools/forest_multi_mesh_baker.gd` bakes forest props into MultiMeshes (relevant to the demo's forest). `scripts/debug/performance_overlay.gd` is a debug FPS label.

---

## 4. Input Map

Defined in `project.godot`. Always use the action name, never raw keycodes.

| Action | Default key | Notes |
|---|---|---|
| `up` / `down` / `left` / `right` | W / S / A / D | Movement |
| `sprint` | Shift | Hold |
| `crouch` | Ctrl | |
| `jump` | Space | |
| `interact` | E | Doors, pickups, inspect, drawers |
| `flashlight` | F | Toggle |
| `inventory` | I | Open/close inventory |
| `dialog_continue` | Enter | Advances `show_continue` dialogue |
| `skip_cinematic` | Space | Shares the key with `jump` (different contexts) |

Mouse: look. Sensitivity (25–200 %) and invert-Y are user settings in `GameSettings`.

---

## 5. Implemented Mechanics

### 5.1 Scenes in the project

| Scene | Status | Purpose |
|---|---|---|
| `scenes/menu/main_menu.tscn` | ✅ | `run/main_scene`. Animated scenery loop (chunks a–d), New/Load Game with slot picker, options, language |
| `scenes/cinematics/dream_intro.tscn` | ✅ / 🚧 | The demo scene. Train, wake-up cinematic, 2 × Terrain3D, `CityBlockout` (16 lit blockout meshes). Forest paths **not built yet** |
| `scenes/levels/chapter_01.tscn` | 🚧 | CSG blockout of "Juliana's House" (rooms, doors, stairs, nightstand drawer). **Out of demo scope**; used to prototype interactions |

Entry flow: `main_menu.tscn` → (`SceneTransition`) → `dream_intro.tscn` → future levels.

`DreamIntroController` ([dream_intro_controller.gd](scripts/cinematics/dream_intro_controller.gd)) drives the opening: fast black reveal imitating a light flicker, head-raise animation (`Player/Head/HeadRaiseAnimationPlayer`, animation `HeadRaise`), player grounding, then hands control to the player. Fixed node paths: `Player`, `Train`, `UI`, `TransitionBlackout/BlackoutRect`.

### 5.2 Movement ✅
WASD walk, **Shift** sprint, **Ctrl** crouch, **Space** jump, head bob, smoothed camera, stair snapping (`stair_snap_length`), max floor angle 55°. Tunables are `@export` on `player_movement_controller.gd`.

### 5.3 Flashlight ✅
**F** toggles it. Blocked during cutscenes, dialogue, inventory and inspect (`is_flashlight_blocked()`). Its state is saved and restored.

### 5.4 Interaction system ✅

Raycast from the camera (`Head/Camera3D/InteractRay`, 2 m). The first collider's ancestors are searched for an `Interactable`; if `can_interact()` is true the prompt shows (`tr(get_prompt_text())`) and **E** calls `interact(player)`.

Class hierarchy (all in `scripts/interactions/`):

```
Interactable (interactable_base.gd)     prompt_text, can_interact(), get_prompt_text(), interact()
├── Collectible (collectible_interactable.gd)   → goes into inventory
├── Inspectable (inspectable_interactable.gd)   → 3D inspect view only, never inventory
├── DoorKnobInteractable                        → forwards to DoorController
└── Drawer (drawer_interactable.gd)             → opens/closes
DoorController (door_controller.gd)  hinge-based door; supports locked + required_key_id
```

**To add a new interactable:** extend `Interactable`, override the three methods, give it a `persistent_id` if its state must survive saves.

**Collectible vs. interactable-only** (the distinction in the design):

| | Collectible | Inspectable / other interactables |
|---|---|---|
| Result of **E** | Added to inventory, node `queue_free()`d | Inspect view / door / drawer toggles; stays in world |
| Needs a free slot | Yes (`can_interact` false when inventory is full) | No |
| Persistence | `SaveManager` section `collectibles`, keyed by `item_id` | Per-object `persistent_id` (doors, drawers) |
| Key fields | `item_id`, `item_name`, `item_description`, `pickup_prompt_text`, child node named `Visual` | `inspect_name`, `inspect_description`, child node named `Visual` |

A collectible's child node **must be named `Visual`**: it is duplicated as the 3D model shown when inspecting the item from the inventory.

### 5.5 Inventory ✅ / 🚧
- 6 slots (`INVENTORY_SIZE`), each `{id, name, description, inspect_visual_template, item_scene_path}`. **I** opens the UI.
- Item text is stored as localization **keys**, translated on display, so live language switching works.
- Saving stores `id/name/description/item_scene_path`; the inspect visual is rebuilt from `item_scene_path`. A collectible that is not in `ITEM_SCENE_PATHS` falls back to the scene path captured at pickup. Items already in the stock set: `cellphone`, `flashlight`.
- **Inspect** works from the inventory.
- 🚧 **Use is a stub.** The UI emits `use_requested`, but `PlayerController._on_inventory_use_requested()` is currently `pass`. Item use today happens through *world objects checking the inventory* (e.g. a door with `required_key_id` calls `has_inventory_item` then `consume_inventory_item`). The Climax needs this (see §7.4, ❓ Q1).

### 5.6 Doors, drawers, stairs ✅
- `DoorController`: `open_angle_degrees`, `rotate_speed`, `starts_open`, `starts_locked`, `required_key_id` (consumes the matching key on unlock), `persistent_id`, and prompt-key exports (`PROMPT_OPEN`, `PROMPT_CLOSE`, `PROMPT_LOCKED`, `PROMPT_UNLOCK`). Scenes: `door_interactable.tscn`, `fence_door_interactable.tscn`.
- `drawer_interactable.gd`: slides by `open_offset`, `persistent_id`.
- `stairs.gd`: procedural stairs with generated ramp collision for smooth walking.

### 5.7 Dialogue ✅
`DialogueManager.show_timed()` / `show_continue()`; optional player freeze. `dialogue_trigger.gd` is an Area trigger with `message`, `use_timed_dialogue`, `duration`, `freeze_player`, `trigger_once`, `persistent_id`. Use it for ambient lore lines.

### 5.8 Train ✅
`scripts/train/`: `moving_train_path.gd`, `outside_train_loop.gd` (passing scenery), `train_wagon_shake.gd`, `train_light_flicker.gd`. Scene: `train_wagon.tscn`. The opening wagon is built from these.

### 5.9 Environment & atmosphere ✅
- `horror_night_environment.gd` (~1200 lines): night sky, fog, lighting, and per-quality-preset behavior. Resource scene: `world_environment_store.tscn`.
- **Forest fog is per quality preset** via the `DREAM_FOREST_FOG` table in `horror_night_environment.gd` (depth begin/end, curve, camera far, volumetric on/off). Low/Medium use depth + height fog only; **volumetric fog is High/Ultra only** (it is the costly part). Tune fog there, not in the scene's `Environment` resource, since `apply_environment()` overwrites it at runtime.
- **Fog/sky rule:** the dream profile uses `BG_SKY` with a flat-colour `ProceduralSkyMaterial` (not `BG_COLOR`). Godot never fogs a `BG_COLOR` background, so fully fogged foliage rendered ~18% brighter than the sky (pale silhouettes). A sky goes through the same fog as meshes, so distant geometry and sky match. `fog_sky_affect` is 1.0 in the forest and fades to 0 on the descent to reveal the night sky. Keep fog end < camera far. The main menu still uses `BG_COLOR`.
- Camera far is set every frame by this script (it overrides `ScenePerformanceProfile.camera_far_distance` in `dream_intro.tscn`).
- `ultra_weather_layer.gd`: weather particles/layer for the Ultra look.
- `horror_filter_controller.gd` + `HorrorFilter` autoload: screen overlay.
- *Both `horror_night_environment.gd` and `ultra_weather_layer.gd` plus `world_environment_store.tscn` currently have uncommitted edits.*

### 5.10 UI ✅
Pause menu (with Save Game), options panel (audio, graphics, language, controls), save-slots panel, inventory UI, dialogue box, `menu_cinematic_pause.gd`.

### 5.11 Props & assets available
Scenes in `scenes/objects/`: cellphone, flashlight, floor_lamp, identification_badge, medical, medicine, newspaper, photo, doors, drawer, stairs, train wagon. Recent commits added araucaria trees, tent, rocks, bench, campfire and grass (forest dressing for the demo).

---

## 6. Save System ✅

Full detail: [docs/save_system.md](docs/save_system.md). Summary of rules:

- 3 slots, versioned JSON (`FORMAT_VERSION`), atomic write with backup.
- Gameplay state is saved **semantically under stable IDs**, not by serializing nodes:
  ```gdscript
  SaveManager.set_state_value(&"puzzles", &"path_a_solved", true)
  var solved: bool = SaveManager.get_state_value(&"puzzles", &"path_a_solved", false)
  SaveManager.save_checkpoint(scene_path, "checkpoint_id", "SAVE_LOCATION_KEY")
  ```
- State sections: `puzzles`, `triggers`, `collectibles`, `player` (others created on first use). Values must be JSON-safe.
- Manual save records scene, player position/view, crouch + flashlight, inventory, collectibles, registered interactables. Loading a manual Dream Intro save **skips the wake-up cinematic**.
- Anything unsafe to resume mid-way (puzzle animations, cutscenes, chases) must hold `player.set_manual_save_blocked(true)` for its full duration.
- **Persistent IDs and checkpoint IDs are part of the save format.** Once released, never rename without a migration in `_migrate_and_validate()`.
- Default new-game scene: `dream_intro.tscn`, checkpoint `dream_intro_start`, location key `SAVE_LOCATION_DREAM_INTRO`.
- Smoke tests in `tests/` cover slots, picker, menu flow, manual save, Dream Intro resume.

---

## 7. THE DEMO — "Dream Intro" Progression Flow

### 7.1 Design intent
A short, self-contained dark-dream vertical slice showing the game's atmosphere, interaction/inventory loop and lore delivery. Non-linear in the middle, with a gated climax.

### 7.2 Flow overview

```
[A] Train wagon (start)            ✅ cinematic + train systems exist
        │  player steps out
        ▼
[B] Forest crossroads              🚧 terrain + dressing in progress; junction not authored
        ├── Path 1 ── puzzle 1 + lore 1 ──► reward?  ┐
        ├── Path 2 ── puzzle 2 + lore 2 ──► reward?  ├─ any order, revisitable
        └── Path 3 ── puzzle 3 + lore 3 ──► reward?  ┘
        ▼   (all three lead here)
[C] Scenic overlook, city view     🚧 `CityBlockout` exists (16 lit meshes)
        │  requires: collectibles from 2 of the 3 paths
        ▼
[D] Final puzzle + final lore piece → demo climax → end of demo   📋
```

### 7.3 Stage details

**A. Train wagon ✅ (the start)**
- The player wakes up (head-raise animation), the wagon shakes and its lights flicker, and the scenery loops outside. Then the player gets control and steps out.
- Atmosphere: cramped, flickering warm light against an outside that is dark and cold.
- 📋 *Missing:* the exit trigger/door that hands the player to the forest, and any first dialogue line (use `dialogue_trigger.gd`).

**B. The crossroads 🚧**
- Forest, with exactly **3 distinct paths**, explorable in **any order**.
- Each path has its **own unique interaction puzzle** and **own lore delivery**.
- Paths must be visually distinguishable at a glance (landmark, light color, sound), without a HUD marker.
- All progress state lives in `SaveManager` under stable IDs (naming scheme below).

**Path template (fill in as each path is designed):**

| | Path 1 | Path 2 | Path 3 |
|---|---|---|---|
| Working name | ❓ | ❓ | ❓ |
| Landmark / mood | ❓ | ❓ | ❓ |
| Puzzle (interaction) | ❓ | ❓ | ❓ |
| Lore delivered | ❓ | ❓ | ❓ |
| Reward | ❓ collectible? | ❓ collectible? | ❓ collectible? |
| Status | 📋 | 📋 | 📋 |

**C. City overlook 🚧**
- Reached from all three paths.
- Faces the city view; `CityBlockout` in `dream_intro.tscn` is the current stand-in (lit blockout meshes).
- The final puzzle/lore piece is **locked** until the player has used the required collectibles.

**D. Climax 📋**
- Unlock condition: the player has **used specific collectible items from 2 of the 3 paths**.
- Unlocks the final puzzle and final lore piece, which triggers the climax of the demo.

### 7.4 Gating rule — design decisions pending ❓

The brief says the climax needs "specific collectible items obtained from 2 of the previous paths". Before building it, decide:

| # | Question | Impact |
|---|---|---|
| Q1 | Is the item **used from the inventory UI** (Use button, currently a stub) or **placed on a world object** at the overlook (like a key in a lock)? | The second is supported today via `has_inventory_item` / `consume_inventory_item`. The first requires implementing `_on_inventory_use_requested` |
| Q2 | Are the 2 items **fixed** (e.g. path 1's and path 2's), or **any 2 of 3**? | Fixed: 2 items; any-2: 3 items, 2 accepted, and the third path is optional or "bonus" lore |
| Q3 | If the player brings only 1 item, what feedback do they get? | Suggest a dialogue line via `DialogueManager`, never a UI counter |
| Q4 | Do items stay in inventory after use (consumed vs. kept)? | Inventory is 6 slots; fine for this demo either way |
| Q5 | How does the demo end (fade, cut to credits, return to the menu)? | Needs `SceneTransition` and a save/checkpoint decision |

### 7.5 Suggested implementation shape (guidance, not yet built)

- `scripts/levels/dream_intro_level.gd`: level orchestrator that listens to signals from path puzzles and the overlook; **no puzzle logic inside reusable object scripts**.
- Persistent IDs (keep these stable once chosen):
  - `puzzles/path_1_solved`, `puzzles/path_2_solved`, `puzzles/path_3_solved`
  - `puzzles/overlook_unlocked`, `puzzles/demo_climax_done`
  - Item IDs: unique `snake_case` `item_id` per collectible, matching a localization key set (`ITEM_<NAME>_NAME`, `ITEM_<NAME>_DESC`).
- Checkpoints via `save_checkpoint()` at: forest entry, each solved path, overlook unlock.
- Hold `set_manual_save_blocked(true)` during puzzle animations and the climax.
- Add each new collectible's scene path to `ITEM_SCENE_PATHS` only if it must be restorable without a saved `item_scene_path` (normally the pickup captures it).

### 7.6 Demo checklist

- [x] Main menu, slot picker, settings, pause + manual save
- [x] Player movement, flashlight, interaction, inventory, inspect
- [x] Train wagon sequence and wake-up cinematic
- [x] Night environment and horror filter
- [~] Forest terrain and dressing (Terrain3D, trees, rocks, tent, campfire, bench, grass)
- [ ] Wagon exit → forest handoff
- [ ] Crossroads layout with 3 paths
- [ ] Path 1 puzzle + lore + reward
- [ ] Path 2 puzzle + lore + reward
- [ ] Path 3 puzzle + lore + reward
- [ ] Overlook scene (replace `CityBlockout` with the final city view)
- [ ] Climax gating (resolve Q1–Q5)
- [ ] Final puzzle + final lore
- [ ] Demo ending
- [ ] Localization keys for all new text (en + pt_BR)
- [ ] Per-preset performance pass on the forest (Low / Medium / High)

---

## 8. Localization Rules ✅

- Never hard-code player-facing text. Put a descriptive key in `messages.pot`, then add the same key + translation to **both** `en.po` and `pt_BR.po`.
- Use keys in scene properties and exported fields (`prompt_text`, `item_name`, `message`, ...) or `tr()` in runtime UI.
- Preserve placeholders (`%s`, `{slot}`, `{item}`) exactly.
- Voice lives in `localization/voice/{en,pt_BR}`; a missing variant falls back to the stream assigned on the player node.
- See [localization/README.md](localization/README.md) and `glossary.md`.

---

## 9. Working Agreements (for Claude and the developer)

**Before changing code**
1. Read the relevant section of this file, then the actual script. Docs can lag the code.
2. Prefer extending existing systems (`Interactable`, `DialogueManager`, `SaveManager`) over parallel new ones.
3. Do not edit `addons/`, and do not rename files or IDs that appear in saves or `.import` metadata.

**While changing code**
- Keep typed GDScript, tab indentation, and the surrounding file's comment density.
- New reusable objects are self-contained scenes in `scenes/objects/` with matching scripts in `scripts/interactions/` or `scripts/items/`.
- New persistent state: stable ID plus a `SaveManager` section; consider the save-blocking rule.
- New text: keys in both `.po` files.

**Before calling a feature done** (from the README)
1. Run from the main menu through the normal transition.
2. Run the changed scene directly with **F6**.
3. Check the Output and Debugger panels for new errors/warnings.
4. Test `en` and `pt_BR` if text changed.
5. Test each graphics preset if rendering changed.

**Keeping this file current:** update the legend status, §5 and §7.6 whenever a mechanic ships; add new autoloads/input actions/IDs to their tables in the same change.

---

## 10. Known Gaps & Risks

| Item | Detail |
|---|---|
| Inventory **Use** is a stub | Blocks the "use item from inventory" climax design (Q1) |
| Only 2 stock item scenes in `ITEM_SCENE_PATHS` | Fine as long as pickups capture `scene_file_path` |
| `chapter_01.tscn` is a CSG prototype | Not part of the demo; don't build demo content there |
| Large scripts | `menu_controller.gd` (~1900 lines), `horror_night_environment.gd`, `dream_intro_controller.gd`, `game_settings.gd` are big, so make small, local edits and avoid refactors mid-feature |
| Dream Intro scene complexity | Contains the train, 2 terrains and the blockout city in one scene; mind draw calls (use the baker/MultiMesh tools) |
| Uncommitted work at time of writing | Environment scripts, `dream_intro.tscn`, terrain `.res` files |
