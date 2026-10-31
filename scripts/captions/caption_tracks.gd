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

## The cassette recording in the fig tree clearing (placeholder timing): the conversation up to Juliana's "Good.".
const FIG_RECORDING: StringName = &"fig_recording"

## Sophia's last line in the clearing, said once from an empty seat by the fire, not from the tape
## (placeholder timing, from the start of its own clip).
const FIG_EMPTY_SEAT: StringName = &"fig_empty_seat"

## The unfinished house's bedroom: Lucas and Sophia remembered over his unsent postcard, while the room is warm (placeholder
## timing, subtitles only; a future clip is timed from its start). Short pauses after "Yes.", "Just this one." and "In a
## moment.", a longer silence after "All right.", and two seconds held after the last line. No stage directions are printed.
const HOUSE_BEDROOM_MEMORY: StringName = &"house_bedroom_memory"

## The house's door beat: Sophia, close, at the moment the bedroom door is open a crack (subtitle only for now).
const HOUSE_DOOR_SHH: StringName = &"house_door_shh"

## Sophia on the overlook payphone (placeholder timing: one long line, an interruption,
## the lure, the warning).
const OVERLOOK_CALL: StringName = &"overlook_call"

const SPEAKER_SOPHIA_PHONE: String = "CAPTION_SPEAKER_SOPHIA_PHONE"
const SPEAKER_SOPHIA_RECORDING: String = "CAPTION_SPEAKER_SOPHIA_RECORDING"
const SPEAKER_JULIANA_RECORDING: String = "CAPTION_SPEAKER_JULIANA_RECORDING"
const SPEAKER_SOPHIA: String = "CAPTION_SPEAKER_SOPHIA"
const SPEAKER_LUCAS: String = "CAPTION_SPEAKER_LUCAS"

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
	],
	FIG_EMPTY_SEAT: [
		{"start": 0.0, "end": 1.5, "key": "CAPTION_REC_07", "speaker": SPEAKER_SOPHIA},
	],
	HOUSE_BEDROOM_MEMORY: [
		{"start": 0.8, "end": 3.4, "key": "CAPTION_HOUSE_BED_01", "speaker": SPEAKER_SOPHIA},
		{"start": 3.9, "end": 6.3, "key": "CAPTION_HOUSE_BED_02", "speaker": SPEAKER_LUCAS},
		{"start": 6.8, "end": 9.2, "key": "CAPTION_HOUSE_BED_03", "speaker": SPEAKER_SOPHIA},
		{"start": 9.7, "end": 11.3, "key": "CAPTION_HOUSE_BED_04", "speaker": SPEAKER_LUCAS},
		# A short pause.
		{"start": 12.8, "end": 15.6, "key": "CAPTION_HOUSE_BED_05", "speaker": SPEAKER_SOPHIA},
		{"start": 16.1, "end": 18.3, "key": "CAPTION_HOUSE_BED_06", "speaker": SPEAKER_LUCAS},
		{"start": 18.8, "end": 21.8, "key": "CAPTION_HOUSE_BED_07", "speaker": SPEAKER_SOPHIA},
		{"start": 22.3, "end": 24.7, "key": "CAPTION_HOUSE_BED_08", "speaker": SPEAKER_LUCAS},
		# A short pause.
		{"start": 26.2, "end": 28.0, "key": "CAPTION_HOUSE_BED_09", "speaker": SPEAKER_SOPHIA},
		{"start": 28.5, "end": 30.9, "key": "CAPTION_HOUSE_BED_10", "speaker": SPEAKER_LUCAS},
		{"start": 31.4, "end": 33.0, "key": "CAPTION_HOUSE_BED_11", "speaker": SPEAKER_SOPHIA},
		# A longer silence before he asks.
		{"start": 35.2, "end": 37.2, "key": "CAPTION_HOUSE_BED_12", "speaker": SPEAKER_LUCAS},
		{"start": 37.7, "end": 39.2, "key": "CAPTION_HOUSE_BED_13", "speaker": SPEAKER_SOPHIA},
		{"start": 39.7, "end": 41.5, "key": "CAPTION_HOUSE_BED_14", "speaker": SPEAKER_LUCAS},
		{"start": 42.0, "end": 43.6, "key": "CAPTION_HOUSE_BED_15", "speaker": SPEAKER_SOPHIA},
		# A short pause.
		{"start": 45.1, "end": 46.9, "key": "CAPTION_HOUSE_BED_16", "speaker": SPEAKER_SOPHIA},
		{"start": 47.4, "end": 49.8, "key": "CAPTION_HOUSE_BED_17", "speaker": SPEAKER_LUCAS},
		# The same shot held, in silence, before the camera goes back into the paper.
		{"start": 49.8, "end": 51.8, "key": ""},
	],
	HOUSE_DOOR_SHH: [
		{"start": 0.0, "end": 1.6, "key": "CAPTION_HOUSE_SHH", "speaker": SPEAKER_SOPHIA},
	],
	# Two voices on the one line, both captioned as Sophia: the warm one (turns 1 and 3, slow and soft) and the
	# desperate one (2 and 4, high and fast). `voice` says which one the placeholder audio plays. Each turn is
	# split into short blocks that appear as it goes (like film subtitles); the speaker is named on the first
	# block of a turn only.
	OVERLOOK_CALL: [
		{"start": 1.0, "end": 3.8, "key": "CAPTION_PHONE_01", "speaker": SPEAKER_SOPHIA_PHONE, "voice": &"warm"},
		{"start": 4.2, "end": 7.2, "key": "CAPTION_PHONE_02", "voice": &"warm"},
		{"start": 7.6, "end": 10.6, "key": "CAPTION_PHONE_03", "voice": &"warm"},
		{"start": 10.9, "end": 14.0, "key": "CAPTION_PHONE_04", "voice": &"warm"},
		{"start": 15.2, "end": 17.2, "key": "CAPTION_PHONE_05", "speaker": SPEAKER_SOPHIA_PHONE, "voice": &"desperate"},
		{"start": 17.4, "end": 19.8, "key": "CAPTION_PHONE_06", "voice": &"desperate"},
		{"start": 20.0, "end": 21.6, "key": "CAPTION_PHONE_07", "voice": &"desperate"},
		{"start": 22.8, "end": 25.4, "key": "CAPTION_PHONE_08", "speaker": SPEAKER_SOPHIA_PHONE, "voice": &"warm"},
		{"start": 25.8, "end": 29.2, "key": "CAPTION_PHONE_09", "voice": &"warm"},
		{"start": 30.4, "end": 32.8, "key": "CAPTION_PHONE_10", "speaker": SPEAKER_SOPHIA_PHONE, "voice": &"desperate"},
		{"start": 33.0, "end": 34.6, "key": "CAPTION_PHONE_11", "voice": &"desperate"},
		{"start": 34.8, "end": 36.8, "key": "CAPTION_PHONE_12", "voice": &"desperate"},
		# The line goes on hissing for a moment after she stops.
		{"start": 36.8, "end": 38.2, "key": ""},
	],
}


static func get_cues(track_id: StringName) -> Array:
	return TRACKS.get(track_id, [])
