# Save system

The project uses three fixed save slots managed by the `SaveManager` autoload.
Save files are versioned JSON documents stored in `user://saves/`. Writes use a
temporary file and preserve the previous file until the replacement has been
validated and promoted.

## Current behavior

- **New Game** opens the slot picker. Choosing an occupied or unreadable slot
  requires confirmation before it is replaced.
- **Load Game** is disabled until at least one valid slot exists. It opens the
  same picker and transitions directly to the saved scene using the menu's
  threaded scene loader. A persistent black transition layer covers scene
  initialization and then smoothly reveals the restored game.
- Slots show their location, last save time, and total playtime.
- Saves can be deleted after confirmation.
- Starting a game creates its slot immediately.
- **Save Game** in the gameplay pause menu records the current scene, player
  position and view, crouch and flashlight state, inventory, collected items,
  and registered interactable state. Loading a manual Dream Intro save skips
  the wake-up cinematic and restores normal player control.
- Manual saving is unavailable during cinematics, dialogue, inspection,
  inventory use, transitions, and any sequence that explicitly blocks it.
- Dynamic ambience, active tweens, and arbitrary physics motion are not
  serialized; those systems restart in a stable scene-authored state.
- Returning to the main menu saves accumulated playtime and closes the active
  save session.

## Safe manual saving

The player exposes `set_manual_save_blocked()`. Any puzzle animation, chase,
teleport, or scene transition that would be unsafe to resume in the middle
must hold this block for its complete duration:

```gdscript
player.set_manual_save_blocked(true)
await puzzle_animation.finished
player.set_manual_save_blocked(false)
```

Doors, drawers, and one-shot dialogue triggers expose a `persistent_id` in the
Inspector. Give every persistent instance a unique, descriptive ID. Collected
items use their unique `item_id`. The current Chapter 1 doors and nightstand
drawer already have IDs assigned.

## Adding checkpoints

Use stable semantic IDs that will remain valid when scene nodes are renamed.
A level controller can update state in memory and then persist a checkpoint:

```gdscript
SaveManager.set_state_value(
	&"puzzles",
	&"maintenance_power",
	true
)

SaveManager.save_checkpoint(
	"res://scenes/levels/chapter_01.tscn",
	"maintenance_power_restored",
	"SAVE_LOCATION_CHAPTER_01_STATION"
)
```

At scene startup, read state with a matching stable ID:

```gdscript
var power_restored: bool = SaveManager.get_state_value(
	&"puzzles",
	&"maintenance_power",
	false
)
```

The initial state sections are `puzzles`, `triggers`, `collectibles`, and
`player`; doors and drawers add their own sections when first used. Additional
sections can be added without changing the save manager.
Values must be JSON-safe: null, booleans, numbers, strings, arrays, or
dictionaries with string keys. Convert engine types such as `Vector3` to an
array or dictionary before saving them.

Checkpoint and object IDs are part of the save format. Once released, do not
rename them without adding a save migration.

## Save format changes

`FORMAT_VERSION` in `scripts/save/save_manager.gd` identifies the schema.
When the schema changes, add a migration in `_migrate_and_validate()` before
increasing the version. Never silently reinterpret old fields.

Automated smoke coverage lives under `tests/`. It covers slot persistence,
the slot picker, main-menu integration, and the controlled manual-save flow.
