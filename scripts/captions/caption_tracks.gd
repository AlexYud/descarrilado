class_name CaptionTracks
extends RefCounted

## Caption cues for every voiced track, in seconds from the start of the audio.
##
## Each cue is {"start": float, "end": float, "key": String} plus an optional
## "speaker": String. The keys are localization keys (see localization/): the
## text shown is looked up in the player's caption language, which is
## independent of the interface language. A cue with an empty key shows nothing
## (use it to hold a silent stretch). Cues must not overlap. Sound effects and
## music are not captioned.
##
## Cues follow the timestamped transcript of the narration (one per sentence).
## Tracks with no recording yet are timed by hand: tune start/end here.

const INTRO_NARRATION: StringName = &"intro_narration"

## The cassette recording in the fig tree clearing (placeholder timing).
const FIG_RECORDING: StringName = &"fig_recording"

const SPEAKER_SOPHIA_RECORDING: String = "CAPTION_SPEAKER_SOPHIA_RECORDING"
const SPEAKER_JULIANA_RECORDING: String = "CAPTION_SPEAKER_JULIANA_RECORDING"

const TRACKS: Dictionary = {
	INTRO_NARRATION: [
		{"start": 10.0, "end": 17.5, "key": "CAPTION_INTRO_01"},
		{"start": 18.0, "end": 19.8, "key": "CAPTION_INTRO_02"},
		{"start": 20.0, "end": 25.0, "key": "CAPTION_INTRO_03"},
		{"start": 26.0, "end": 32.5, "key": "CAPTION_INTRO_04"},
		{"start": 33.0, "end": 39.5, "key": "CAPTION_INTRO_05"},
	],
	FIG_RECORDING: [
		{"start": 3.5, "end": 6.0, "key": "CAPTION_REC_01", "speaker": SPEAKER_SOPHIA_RECORDING},
		{"start": 6.6, "end": 8.2, "key": "CAPTION_REC_02", "speaker": SPEAKER_JULIANA_RECORDING},
		{"start": 8.8, "end": 11.2, "key": "CAPTION_REC_03", "speaker": SPEAKER_SOPHIA_RECORDING},
		{"start": 11.8, "end": 14.4, "key": "CAPTION_REC_04", "speaker": SPEAKER_JULIANA_RECORDING},
		{"start": 17.0, "end": 20.6, "key": "CAPTION_REC_05", "speaker": SPEAKER_SOPHIA_RECORDING},
		{"start": 21.2, "end": 22.4, "key": "CAPTION_REC_06", "speaker": SPEAKER_JULIANA_RECORDING},
		{"start": 26.5, "end": 29.5, "key": "CAPTION_REC_07", "speaker": SPEAKER_SOPHIA_RECORDING},
		# Silent tail: the bus engine turns into the cassette mechanism.
		{"start": 29.5, "end": 33.0, "key": ""},
	],
}


static func get_cues(track_id: StringName) -> Array:
	return TRACKS.get(track_id, [])
