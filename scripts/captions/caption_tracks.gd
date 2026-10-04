class_name CaptionTracks
extends RefCounted

## Caption cues for every voiced track, in seconds from the start of the audio.
##
## Each cue is {"start": float, "end": float, "key": String}. The key is a
## localization key (see localization/): the text shown is looked up in the
## player's caption language, which is independent of the interface language.
## Cues must not overlap. Sound effects and music are not captioned.
##
## Cues follow the timestamped transcript of the narration (one per sentence).

const INTRO_NARRATION: StringName = &"intro_narration"

const TRACKS: Dictionary = {
	INTRO_NARRATION: [
		{"start": 10.0, "end": 17.5, "key": "CAPTION_INTRO_01"},
		{"start": 18.0, "end": 19.8, "key": "CAPTION_INTRO_02"},
		{"start": 20.0, "end": 25.0, "key": "CAPTION_INTRO_03"},
		{"start": 26.0, "end": 32.5, "key": "CAPTION_INTRO_04"},
		{"start": 33.0, "end": 39.5, "key": "CAPTION_INTRO_05"},
	],
}


static func get_cues(track_id: StringName) -> Array:
	return TRACKS.get(track_id, [])
