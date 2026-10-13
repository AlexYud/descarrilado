extends Interactable
class_name OrelhaoInteractable

## What the player looks at to use the overlook's payphone. It only reports that it was
## used and asks `OverlookPhoneSequence` what its prompt should say ("Insert ficha 2",
## "Pick up Receiver"...). Put the booth's model, a collision body and an interaction
## area under it, so a ray that hits any of them finds this node.

signal examined(player: Node)

## False once the call has happened (nothing more to do at the booth).
var enabled: bool = true
## Returns the prompt text (a localization key or already translated text).
var prompt_provider: Callable = Callable()


func can_interact(_player: Node) -> bool:
	return enabled


func get_prompt_text() -> String:
	if prompt_provider.is_valid():
		return str(prompt_provider.call())

	return "PROMPT_EXAMINE_ORELHAO"


func interact(player: Node) -> void:
	examined.emit(player)
