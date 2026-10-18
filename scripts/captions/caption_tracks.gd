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

## Sophia on the overlook payphone (placeholder timing: one long line, an interruption,
## the lure, the warning).
const OVERLOOK_CALL: StringName = &"overlook_call"

const SPEAKER_SOPHIA_PHONE: String = "CAPTION_SPEAKER_SOPHIA_PHONE"
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
