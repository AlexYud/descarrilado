extends GatedInspectable
class_name ShedTape

## The waiting shed's videotape. Before the first cinematic it is an ordinary inspectable (its first close of the view starts the directed first viewing). After it, the same physical tape is the entry to the
## voluntary tape review: using it asks the shed's sequence for the review (`review_requested`) instead of opening the inspect view, and its prompt says so.

signal review_requested

## True once the first cinematic is over (set by `WaitingShedSequence`).
var review_mode: bool = false

## The tape ignores a use before this time (real milliseconds). The review is closed with the same key that opened it, and the player's own interaction polls that key once a frame: the very press that
## closes the review would otherwise be seen again by the tape, now free, and open the review straight back.
var ignore_use_until_msec: int = 0


func get_prompt_text() -> String:
	return "PROMPT_REVIEW_TAPE" if review_mode else prompt_text


func interact(player: Node) -> void:
	if Time.get_ticks_msec() < ignore_use_until_msec:
		return

	if review_mode:
		review_requested.emit()
		return

	super(player)
