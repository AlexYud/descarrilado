class_name DevCommands
extends RefCounted

## The developer console's commands (see `DevConsole`). Every command is one entry of `commands`: a
## `run` callable taking the argument list and returning the text to print, a `usage` line and a `help`
## line. Add a command by adding an entry in `_build`; nothing else needs to know about it.
##
## These are cheats for speeding up play tests. They only exist in debug builds (or with `--dev`).

## Where a place is, in the dream intro: the scene node it hangs on.
const PLACES: Dictionary = {
	"train": "Train/Wagons/TrainWagon",
	"shed": "Scenery/WaitingShed",
	"clearing": "Scenery/FigClearing",
	"tower": "Scenery/SignalTower",
	"house": "Scenery/UnfinishedHouse",
	"overlook": "Scenery/OverlookPhone",
}
## How far from a place's origin the player is put by `tp`, towards the train (where the paths come from).
const DEFAULT_DISTANCE: float = 10.0

var commands: Dictionary = {}

var _console: Node = null


func _init(console: Node) -> void:
	_console = console
	_build()


## Runs a command line; returns what to print.
func execute(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""

	var name: String = parts[0].to_lower()
	if not commands.has(name):
		return "[color=%s]Unknown command '%s'. Type help.[/color]" % [_bad_colour(), name]

	var args: PackedStringArray = parts.slice(1)
	return str((commands[name]["run"] as Callable).call(args))


## Command names starting with `prefix`, sorted.
func complete(prefix: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for name: String in commands.keys():
		if name.begins_with(prefix.to_lower()):
			found.append(name)

	found.sort()
	return found


func _build() -> void:
	_add("help", "help [command]", "Lists the commands, or explains one.", _help)
	_add("clear", "clear", "Clears the console.", func(_a: PackedStringArray) -> String:
		_console.call("clear_log")
		return ""
	)
	_add("pos", "pos", "Prints where the player is.", _pos)
	_add("places", "places", "Lists the places tp knows.", func(_a: PackedStringArray) -> String:
		return "Places: " + ", ".join(PackedStringArray(PLACES.keys()))
	)
	_add("tp", "tp <place> [distance]", "Puts the player at a place (default 10 m from it, towards the train).", _tp)
	_add("give_fichas", "give_fichas", "Puts the three fichas in the inventory (and removes the ones lying in the world).", _give_fichas)
	_add("skip_to", "skip_to <place|wagon|finale>", "Jumps to a place; overlook also gives the fichas, wagon goes straight into the finale's wagon, finale starts the blackout.", _skip_to)
	_add("speed", "speed <factor>", "Multiplies the player's walking speed (1 = normal).", _speed)
	_add("time_scale", "time_scale <factor>", "Sets the game's time scale (1 = normal).", _time_scale)
	_add("flashlight", "flashlight <on|off>", "Switches the flashlight on or off.", _flashlight)
	_add("state_get", "state_get <section> <key>", "Reads a value of the save state (e.g. puzzles house_stage).", _state_get)
	_add("state_set", "state_set <section> <key> <value>", "Writes a value of the save state (true, false, a number or text).", _state_set)
	_add("scene", "scene <res://path.tscn>", "Changes to a scene.", _scene)
	_add("reload", "reload", "Reloads the current scene.", func(_a: PackedStringArray) -> String:
		_console.call("close")
		_console.get_tree().reload_current_scene()
		return "Reloading."
	)
	_add("quit", "quit", "Quits the game.", func(_a: PackedStringArray) -> String:
		_console.get_tree().quit()
		return ""
	)


func _add(name: String, usage: String, help: String, run: Callable) -> void:
	commands[name] = {"usage": usage, "help": help, "run": run}


# ============================================================
# COMMANDS
# ============================================================

func _help(args: PackedStringArray) -> String:
	if args.size() > 0:
		var asked: String = args[0].to_lower()
		if not commands.has(asked):
			return "[color=%s]No command '%s'.[/color]" % [_bad_colour(), asked]

		return "%s\n%s" % [commands[asked]["usage"], commands[asked]["help"]]

	var names: Array = commands.keys()
	names.sort()
	return "Commands: " + ", ".join(PackedStringArray(names)) + "\nTab completes, Up and Down are the history, the backquote key or Esc closes. help <command> explains one."


func _pos(_args: PackedStringArray) -> String:
	var player: Node3D = _player()
	if player == null:
		return _no_player()

	var at: Vector3 = player.global_position
	return "Player at (%.2f, %.2f, %.2f)" % [at.x, at.y, at.z]


func _tp(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: tp <place> [distance]. Places: " + ", ".join(PackedStringArray(PLACES.keys()))

	var player: Node3D = _player()
	if player == null:
		return _no_player()

	var distance: float = float(args[1]) if args.size() > 1 else DEFAULT_DISTANCE
	var target: Variant = place_position(args[0].to_lower(), distance)
	if target == null:
		return "[color=%s]No place '%s' in this scene. Places: %s[/color]" % [_bad_colour(), args[0], ", ".join(PackedStringArray(PLACES.keys()))]

	move_player(player, target as Vector3)
	return "Teleported to %s." % args[0]


## Where `tp` puts the player for a place, or null when the scene has no such place.
func place_position(place: String, distance: float = DEFAULT_DISTANCE) -> Variant:
	if not PLACES.has(place):
		return null

	var scene: Node = _console.call("scene_root")
	if scene == null:
		return null

	var node: Node3D = scene.get_node_or_null(str(PLACES[place])) as Node3D
	if node == null:
		return null

	if place == "train":
		return node.to_global(Vector3(-0.18, 0.7657, 3.1))

	if place == "overlook":
		var phone: Node = _find_phone()
		if phone != null and phone.has_method("get_standing_spot"):
			# (the spot keeps the player's own height, so put it on the ground there)
			var stand: Vector3 = phone.call("get_standing_spot")
			stand.y = _ground_height(scene, stand) + 1.2
			return stand

	# Outdoors: the given distance from the place, towards the train, on the ground.
	var train: Node3D = scene.get_node_or_null(str(PLACES["train"])) as Node3D
	var toward: Vector3 = Vector3(-1.0, 0.0, 0.0)
	if train != null:
		toward = train.global_position - node.global_position
		toward.y = 0.0
		toward = toward.normalized()

	var spot: Vector3 = node.global_position + toward * distance
	spot.y = _ground_height(scene, spot) + 1.2
	return spot


func _give_fichas(_args: PackedStringArray) -> String:
	var player: Node = _player()
	if player == null:
		return _no_player()

	var given: Array[String] = give_fichas(player)
	if given.is_empty():
		return "The fichas are already in the inventory."

	return "Gave: " + ", ".join(PackedStringArray(given))


## Puts the three fichas in the player's inventory (the ones already carried or in the slot are left),
## marks them collected so they do not lie in the world again, and removes the ones lying about now.
func give_fichas(player: Node) -> Array[String]:
	var given: Array[String] = []
	var inserted: Variant = SaveManager.get_state_value(&"puzzles", &"orelhao_fichas", [])
	for id: String in OverlookPhoneSequence.FICHA_IDS:
		SaveManager.set_state_value(&"collectibles", StringName(id), true)
		_remove_world_pickups(id)
		if bool(player.call("has_inventory_item", id)) or (inserted is Array and (inserted as Array).has(id)):
			continue

		var scene: PackedScene = load(str(OverlookPhoneSequence.FICHA_SCENES[id])) as PackedScene
		var root: Node = scene.instantiate()
		var visual: Node3D = (root.get_node("Visual") as Node3D).duplicate() as Node3D
		var item_name: String = str(root.get("item_name"))
		var item_description: String = str(root.get("item_description"))
		root.free()
		if bool(player.call("add_item_to_inventory", id, item_name, item_description, visual, scene.resource_path)):
			given.append(id)

	return given


func _remove_world_pickups(item_id: String) -> void:
	var scene: Node = _console.call("scene_root")
	if scene == null:
		return

	for node: Node in scene.find_children("*", "Collectible", true, false):
		if str(node.get("item_id")) == item_id:
			node.queue_free()


func _skip_to(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: skip_to <place|wagon|finale>"

	var player: Node3D = _player()
	if player == null:
		return _no_player()

	var where: String = args[0].to_lower()
	match where:
		"wagon", "finale":
			var finale: Node = _find_finale()
			if finale == null:
				return "[color=%s]This scene has no finale.[/color]" % _bad_colour()

			give_fichas(player)
			_console.call("close")
			if where == "wagon":
				finale.call("start_in_wagon")
			else:
				var overlook: Variant = place_position("overlook")
				if overlook != null:
					move_player(player, overlook as Vector3)

				finale.call("start")

			return "Skipping to the %s." % where
		"overlook":
			var given: Array[String] = give_fichas(player)
			var spot: Variant = place_position("overlook")
			if spot == null:
				return "[color=%s]No overlook in this scene.[/color]" % _bad_colour()

			move_player(player, spot as Vector3)
			return "At the overlook, with the three fichas%s." % (" (already had some)" if given.size() < 3 else "")

	return _tp(args)


func _speed(args: PackedStringArray) -> String:
	var player: Node = _player()
	if player == null:
		return _no_player()

	var movement: Node = player.get("movement_controller") as Node
	if movement == null:
		return "[color=%s]The player has no movement controller.[/color]" % _bad_colour()

	if args.is_empty():
		return "Speed factor is %.2f." % float(movement.get("speed_multiplier"))

	var factor: float = clampf(float(args[0]), 0.1, 20.0)
	movement.set("speed_multiplier", factor)
	return "Speed factor %.2f." % factor


func _time_scale(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Time scale is %.2f." % Engine.time_scale

	Engine.time_scale = clampf(float(args[0]), 0.05, 20.0)
	return "Time scale %.2f." % Engine.time_scale


func _flashlight(args: PackedStringArray) -> String:
	var player: Node = _player()
	if player == null:
		return _no_player()

	var flashlight: Node = player.get("flashlight_controller") as Node
	if flashlight == null:
		return "[color=%s]The player has no flashlight.[/color]" % _bad_colour()

	var on: bool = args.is_empty() or args[0].to_lower() in ["on", "1", "true"]
	flashlight.call("set_flashlight_input_enabled", true)
	if on:
		flashlight.call("turn_on")
	else:
		flashlight.call("turn_off")

	return "Flashlight %s." % ("on" if on else "off")


func _state_get(args: PackedStringArray) -> String:
	if args.size() < 2:
		return "Usage: state_get <section> <key>"

	var value: Variant = SaveManager.get_state_value(StringName(args[0]), StringName(args[1]), null)
	return "%s/%s = %s" % [args[0], args[1], "(not set)" if value == null else str(value)]


func _state_set(args: PackedStringArray) -> String:
	if args.size() < 3:
		return "Usage: state_set <section> <key> <value>"

	var raw: String = " ".join(args.slice(2))
	var value: Variant = raw
	match raw.to_lower():
		"true":
			value = true
		"false":
			value = false
		_:
			if raw.is_valid_int():
				value = int(raw)
			elif raw.is_valid_float():
				value = float(raw)

	var result: Error = SaveManager.set_state_value(StringName(args[0]), StringName(args[1]), value)
	if result != OK:
		return "[color=%s]Could not set it (%s). Is a game loaded?[/color]" % [_bad_colour(), error_string(result)]

	return "%s/%s = %s" % [args[0], args[1], str(value)]


func _scene(args: PackedStringArray) -> String:
	if args.is_empty() or not ResourceLoader.exists(args[0]):
		return "[color=%s]Usage: scene <res://path.tscn> (an existing scene).[/color]" % _bad_colour()

	_console.call("close")
	_console.get_tree().change_scene_to_file(args[0])
	return "Changing scene."


# ============================================================
# HELPERS
# ============================================================

func _player() -> Node3D:
	return _console.get_tree().get_first_node_in_group(&"player") as Node3D


func _no_player() -> String:
	return "[color=%s]There is no player in this scene.[/color]" % _bad_colour()


func _bad_colour() -> String:
	return UIConfig.color_accent.to_html(false)


func _find_phone() -> Node:
	var scene: Node = _console.call("scene_root")
	if scene == null:
		return null

	var found: Array[Node] = scene.find_children("*", "OverlookPhoneSequence", true, false)
	return found[0] if not found.is_empty() else null


func _find_finale() -> Node:
	var scene: Node = _console.call("scene_root")
	if scene == null:
		return null

	var found: Array[Node] = scene.find_children("*", "DreamFinale", true, false)
	return found[0] if not found.is_empty() else null


## The ground height at a spot (Terrain3D when the scene has one, else the spot's own height).
func _ground_height(scene: Node, spot: Vector3) -> float:
	var terrains: Array[Node] = scene.find_children("*", "Terrain3D", true, false)
	if not terrains.is_empty():
		var height: float = float((terrains[0] as Terrain3D).data.get_height(spot))
		if not is_nan(height):
			return height

	return spot.y


## Puts the player at a spot (standing still).
func move_player(player: Node3D, spot: Vector3) -> void:
	player.global_position = spot
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
