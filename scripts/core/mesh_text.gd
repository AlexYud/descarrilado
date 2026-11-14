@tool
class_name MeshText
extends RefCounted

## What is written ON a thing (a note's handwriting, a photograph's back, a ticket, the map's names, a sign) is part of the thing, like its wood or its
## paper: it is in Portuguese, the language of the place, whatever language the player has chosen, and it never changes when the language does. Only what
## the game shows over it (the inspect overlay: a thing's name, its description, the text read from it, a subtitle) follows the player's language.
##
## Every Label3D that writes on a thing goes through `fix`: its text is the key's Portuguese translation, written once, and the label no longer
## translates itself (a Label3D would otherwise translate its text again on every change of language).

const LOCALE: String = "pt_BR"


## The Portuguese of `key` (the key itself if it is not a localization key: a literal text, a number).
static func written(key: String) -> String:
	if key.is_empty():
		return key

	var translation: Translation = TranslationServer.get_translation_object(LOCALE)
	if translation == null:
		return key

	var message: String = String(translation.get_message(StringName(key)))
	return key if message.is_empty() else message


## Writes the label's text (a localization key) in Portuguese, for good.
static func fix(label: Label3D) -> void:
	if label == null:
		return

	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = written(label.text)


## Every Label3D under `root` (an item's Visual, a prop).
static func fix_all(root: Node) -> void:
	if root == null:
		return

	for node: Node in root.find_children("*", "Label3D", true, false):
		fix(node as Label3D)
