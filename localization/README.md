# Unrailed localization

The game stores stable string identifiers in scenes and scripts. Player-facing
text belongs in the gettext catalogs:

- messages.pot is the master key template.
- en.po contains English text.
- pt_BR.po contains Brazilian Portuguese text.

Register every new text locale in Godot under **Project Settings >
Localization > Translations**. The Options menu discovers registered text
locales automatically. Voice language is a separate setting and remains
limited to en and pt_BR.

## Adding text

1. Add a descriptive key to messages.pot, such as
   CHAPTER_01_STATION_WARNING.
2. Add the same key and translated value to every PO catalog.
3. Put the key in scene text properties, exported dialogue/item fields, or
   pass it through tr() when creating runtime UI.
4. Preserve placeholders such as %s, {slot}, and {item} exactly.
5. Test all supported locales and check for clipped or overflowing UI.

Do not duplicate scenes by language and do not store translated item text in
inventory state. Inventory and dialogue keep keys and translate them when
displayed, allowing live language changes.

## Localized voice

Localized recordings live under voice/en and voice/pt_BR. Assign the English
and Brazilian Portuguese variants to the localized voice exports on the
relevant audio controller. If a variant is missing, the original stream
assigned to its AudioStreamPlayer is used as a fallback.
