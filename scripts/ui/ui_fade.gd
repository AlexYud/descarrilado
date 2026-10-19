class_name UiFade

## Fades a piece of on-screen UI in or out, safely.
##
## A fade made with a bare `create_tween().tween_property(item, "modulate:a", ...)` is never cancelled by the next one: when the player
## acts fast (a hint is shown and, a few frames later, hidden because the thing it offered was used), two tweens write the same alpha
## together, and the one that finishes last wins whatever it was meant to do: a 0.25 s fade-in that is still running when a 0.2 s
## fade-out has ended puts the hint back on screen for good. This was the bug of the payphone's hints that stayed over the call.
## Every fade of a node goes through here, so that a new fade of it always replaces (kills) the one before.

const META_KEY: StringName = &"_ui_fade_tween"


## Fades `item`'s alpha to `alpha` over `seconds`, starting from wherever it is now, replacing any fade of `item` still running.
## `hide_when_clear` also sets `visible` to false when it has faded out. Returns the tween (null when it was instant).
static func to(item: CanvasItem, alpha: float, seconds: float, hide_when_clear: bool = false) -> Tween:
	if item == null or not is_instance_valid(item):
		return null

	cancel(item)
	if seconds <= 0.0 or not item.is_inside_tree():
		item.modulate.a = alpha
		if hide_when_clear and alpha <= 0.0:
			item.visible = false

		return null

	var tween: Tween = item.create_tween()
	tween.tween_property(item, "modulate:a", alpha, seconds)
	if hide_when_clear and alpha <= 0.0:
		tween.tween_callback(func() -> void:
			if is_instance_valid(item):
				item.visible = false)

	item.set_meta(META_KEY, tween)
	return tween


## Stops the fade of `item` that is running, if any (its alpha stays where it got to).
static func cancel(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item) or not item.has_meta(META_KEY):
		return

	var running: Tween = item.get_meta(META_KEY) as Tween
	if running != null and running.is_valid():
		running.kill()

	item.remove_meta(META_KEY)


## Whether a fade of `item` is running.
static func is_fading(item: CanvasItem) -> bool:
	if item == null or not is_instance_valid(item) or not item.has_meta(META_KEY):
		return false

	var running: Tween = item.get_meta(META_KEY) as Tween
	return running != null and running.is_valid()
