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

## The index (in the track) of the first cue said over the blackout; the camera glide and the lights are timed from the end of the cue before it.
const INTRO_BLACK_CUE_INDEX: int = 18

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
const HOUSE_DOOR_THREAT: StringName = &"house_door_threat"
const HOUSE_DOOR_SHUSH: StringName = &"house_door_shush"
const HOUSE_DOOR_COLD: StringName = &"house_door_cold"
const HOUSE_DOOR_HELP: StringName = &"house_door_help"

## Sophia on the overlook payphone (placeholder timing: one long line, an interruption,
## the lure, the warning).
const OVERLOOK_CALL: StringName = &"overlook_call"

## The waiting shed's recording scene (placeholder timing, subtitles only; future clips are timed from the start of their shot).
## Shot 1: Sophia and Juliana, remembered, over the tape on the bench. The recording that follows (the 62 s excerpt) is SILENT and has no track at all: nobody
## in it is captioned, and there is no transcript of what the people in it might say. It is not replayed, so there is no review. The close view of the
## photograph that follows it is silent too. Shot 4: the conversation, remembered. The girls' lines are remembered voices of the present, not the tape's.
const SHED_REMEMBERED_COPY: StringName = &"shed_remembered_copy"
const SHED_REMEMBERED_TALK: StringName = &"shed_remembered_talk"

const SPEAKER_SOPHIA_PHONE: String = "CAPTION_SPEAKER_SOPHIA_PHONE"
const SPEAKER_SOPHIA_RECORDING: String = "CAPTION_SPEAKER_SOPHIA_RECORDING"
const SPEAKER_JULIANA_RECORDING: String = "CAPTION_SPEAKER_JULIANA_RECORDING"
const SPEAKER_SOPHIA: String = "CAPTION_SPEAKER_SOPHIA"
const SPEAKER_JULIANA: String = "CAPTION_SPEAKER_JULIANA"
const SPEAKER_LUCAS: String = "CAPTION_SPEAKER_LUCAS"

const TRACKS: Dictionary = {
	# Juliana's opening narration over the train (an editable preview schedule; no recording yet). Time zero is the click on Start; the first caption comes at 3 s.
	# Every caption is ONE line (a long sentence is split into contiguous parts that share a timestamp, so nothing blinks out between them and no pause is added). The camera
	# glide is fitted to end `intro_ambient_tail_seconds` after the cue before `INTRO_BLACK_CUE_INDEX` (57.2 s); then the lights fail and the screen goes black, and the last
	# sentence (the last two cues) is said in that black: it begins a little after the blackout is complete and the next scene has been built (the narration is held while it is built, see MenuController._hold_narration_for_scene_change), and the opening begins right after its last word.
	INTRO_NARRATION: [
		{"start": 3.0, "end": 6.4, "key": "CAPTION_INTRO_01", "wide": true},
		{"start": 7.2, "end": 9.35, "key": "CAPTION_INTRO_02", "wide": true},
		{"start": 9.35, "end": 12.5, "key": "CAPTION_INTRO_03", "wide": true},
		{"start": 12.5, "end": 15.07, "key": "CAPTION_INTRO_04", "wide": true},
		{"start": 15.07, "end": 17.8, "key": "CAPTION_INTRO_05", "wide": true},
		{"start": 18.7, "end": 20.54, "key": "CAPTION_INTRO_06", "wide": true},
		{"start": 20.54, "end": 23.5, "key": "CAPTION_INTRO_07", "wide": true},
		{"start": 23.8, "end": 26.3, "key": "CAPTION_INTRO_08", "wide": true},
		{"start": 27.0, "end": 30.55, "key": "CAPTION_INTRO_09", "wide": true},
		{"start": 30.55, "end": 34.2, "key": "CAPTION_INTRO_10", "wide": true},
		{"start": 35.0, "end": 37.31, "key": "CAPTION_INTRO_11", "wide": true},
		{"start": 37.31, "end": 38.8, "key": "CAPTION_INTRO_12", "wide": true},
		{"start": 39.0, "end": 42.2, "key": "CAPTION_INTRO_13", "wide": true},
		{"start": 42.85, "end": 46.05, "key": "CAPTION_INTRO_14", "wide": true},
		{"start": 46.2, "end": 49.0, "key": "CAPTION_INTRO_15", "wide": true},
		{"start": 49.0, "end": 52.2, "key": "CAPTION_INTRO_16", "wide": true},
		{"start": 53.0, "end": 55.18, "key": "CAPTION_INTRO_17", "wide": true},
		{"start": 55.18, "end": 57.2, "key": "CAPTION_INTRO_18", "wide": true},
		{"start": 61.3, "end": 62.68, "key": "CAPTION_INTRO_19", "wide": true},
		{"start": 62.68, "end": 65.8, "key": "CAPTION_INTRO_20", "wide": true},
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
	# The voice at the bedroom door (cues 01 to 12), from Juliana's question on, at the pace of someone listening between the lines: Juliana asks, and nobody answers
	# for a long moment; then a voice with Sophia's, in short pieces with silences between them: warm and unsure (02 to 04), asking (05 and 06, as the handle is
	# tried again), afraid (07 to 09), sharper (10), and at the end the slow, long wait for a reply (11 and 12). Nobody answers.
	HOUSE_DOOR_THREAT: [
		{"start": 0.0, "end": 1.8, "key": "CAPTION_HOUSE_ESC_01", "speaker": SPEAKER_JULIANA},
		{"start": 4.0, "end": 4.9, "key": "CAPTION_HOUSE_ESC_02", "speaker": SPEAKER_SOPHIA},
		{"start": 6.0, "end": 7.3, "key": "CAPTION_HOUSE_ESC_03", "speaker": SPEAKER_SOPHIA},
		{"start": 8.7, "end": 11.4, "key": "CAPTION_HOUSE_ESC_04", "speaker": SPEAKER_SOPHIA},
		{"start": 12.8, "end": 13.9, "key": "CAPTION_HOUSE_ESC_05", "speaker": SPEAKER_SOPHIA},
		{"start": 14.2, "end": 16.0, "key": "CAPTION_HOUSE_ESC_06", "speaker": SPEAKER_SOPHIA},
		{"start": 17.8, "end": 18.8, "key": "CAPTION_HOUSE_ESC_07", "speaker": SPEAKER_SOPHIA},
		{"start": 19.6, "end": 20.6, "key": "CAPTION_HOUSE_ESC_08", "speaker": SPEAKER_SOPHIA},
		{"start": 21.8, "end": 23.8, "key": "CAPTION_HOUSE_ESC_09", "speaker": SPEAKER_SOPHIA},
		{"start": 25.6, "end": 26.6, "key": "CAPTION_HOUSE_ESC_10", "speaker": SPEAKER_SOPHIA},
		{"start": 28.8, "end": 29.6, "key": "CAPTION_HOUSE_ESC_11", "speaker": SPEAKER_SOPHIA},
		{"start": 31.4, "end": 33.2, "key": "CAPTION_HOUSE_ESC_12", "speaker": SPEAKER_SOPHIA},
	],
	# Cue 13: the shush at her right ear (its own track, played once, at the cut to her own view).
	HOUSE_DOOR_SHUSH: [
		{"start": 0.0, "end": 1.4, "key": "CAPTION_HOUSE_ESC_13", "speaker": SPEAKER_SOPHIA},
	],
	# Cues 14 to 17: from the original door again, while she looks back and while she goes through the new one.
	HOUSE_DOOR_COLD: [
		{"start": 0.0, "end": 1.4, "key": "CAPTION_HOUSE_ESC_14", "speaker": SPEAKER_SOPHIA},
		{"start": 1.9, "end": 2.8, "key": "CAPTION_HOUSE_ESC_15", "speaker": SPEAKER_SOPHIA},
	],
	HOUSE_DOOR_HELP: [
		{"start": 0.0, "end": 0.7, "key": "CAPTION_HOUSE_ESC_16", "speaker": SPEAKER_SOPHIA},
		{"start": 1.0, "end": 2.0, "key": "CAPTION_HOUSE_ESC_17", "speaker": SPEAKER_SOPHIA},
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
	# Shot 1 (about 8.6 s): the tape on the bench, the notebook and the clipping; Sophia, Juliana and Sophia as Juliana remembers them: where the copy came from, and that it has no sound. Held to the cut.
	SHED_REMEMBERED_COPY: [
		{"start": 0.8, "end": 3.8, "key": "CAPTION_SHED_MEM_01", "speaker": SPEAKER_SOPHIA},
		{"start": 4.4, "end": 5.6, "key": "CAPTION_SHED_MEM_02", "speaker": SPEAKER_JULIANA},
		{"start": 6.2, "end": 7.8, "key": "CAPTION_SHED_MEM_03", "speaker": SPEAKER_SOPHIA},
		{"start": 7.8, "end": 8.8, "key": ""},
	],
	# Shot 4 (about 90 s): the conversation, remembered, on one clock that starts with the second viewing (the brief replay of her greeting, with the machine running: four seconds of the tape in silence before anyone speaks). Juliana says "No." and, after a pause, asks to stop
	# ("Pode parar, por favor?"); the picture is held (the machine says PAUSE) a short while after the request (`replay_stop_after_request_seconds`), and after another pause Sophia says what she saw over the held frame
	# ("Ela parece conhecer quem chegou.") and Juliana warns her (`CAPTION_SHED_TALK_01`); `photo_after_replay_seconds` after ITS end the picture cuts to the printed photograph. While Sophia says the name
	# of Helena Clarke (TALK_06 to TALK_08) the picture is on the notice pinned to the post. After the apology Juliana forgives her ("Tudo bem."), a long silence follows, and the picture goes back to the bench with the tape
	# on it and drifts back to Juliana's own eyes, arriving as Sophia says the last word; she has the view back `return_hold_seconds` after it.
	# The sequence finds every mark from these cues, so retime here and nowhere else. Older keys no longer used (their texts stay in the translation files): CAPTION_SHED_REPLAY_01 to _06. The gaps are the director's:
	# 1.2 s and 1.2 s of hesitation before the request, 0.9 s to the pause and 2.0 s of silence over the frozen frame, 1.8 s after the warning, 2.3 s after "Nunca encontraram.", 1.8 s after the railway line,
	# almost none before Sophia is interrupted (TALK_11), 1.5 s before the work excuse, 3.0 s before the apology is forgiven, 5 s of silence over the change of view.
	SHED_REMEMBERED_TALK: [
		{"start": 4.8, "end": 5.9, "key": "CAPTION_SHED_REPLAY_08", "speaker": SPEAKER_JULIANA},
		{"start": 7.1, "end": 9.3, "key": "CAPTION_SHED_REPLAY_09", "speaker": SPEAKER_JULIANA},
		{"start": 12.2, "end": 14.8, "key": "CAPTION_SHED_REPLAY_07", "speaker": SPEAKER_SOPHIA},
		{"start": 16.2, "end": 19.6, "key": "CAPTION_SHED_TALK_01", "speaker": SPEAKER_JULIANA},
		{"start": 21.4, "end": 24.8, "key": "CAPTION_SHED_REPLAY_10", "speaker": SPEAKER_SOPHIA},
		{"start": 25.6, "end": 26.8, "key": "CAPTION_SHED_REPLAY_11", "speaker": SPEAKER_JULIANA},
		{"start": 27.8, "end": 29.3, "key": "CAPTION_SHED_REPLAY_12", "speaker": SPEAKER_SOPHIA},
		{"start": 31.6, "end": 35.2, "key": "CAPTION_SHED_TALK_02", "speaker": SPEAKER_SOPHIA},
		{"start": 36.2, "end": 37.6, "key": "CAPTION_SHED_TALK_03", "speaker": SPEAKER_JULIANA},
		{"start": 37.6, "end": 40.2, "key": "CAPTION_SHED_TALK_04", "speaker": SPEAKER_JULIANA},
		{"start": 41.2, "end": 43.0, "key": "CAPTION_SHED_TALK_05", "speaker": SPEAKER_SOPHIA},
		{"start": 43.0, "end": 45.8, "key": "CAPTION_SHED_TALK_06", "speaker": SPEAKER_SOPHIA},
		{"start": 46.8, "end": 49.8, "key": "CAPTION_SHED_TALK_07", "speaker": SPEAKER_JULIANA},
		{"start": 50.8, "end": 54.0, "key": "CAPTION_SHED_TALK_08", "speaker": SPEAKER_SOPHIA},
		{"start": 55.8, "end": 57.8, "key": "CAPTION_SHED_TALK_09", "speaker": SPEAKER_JULIANA},
		{"start": 58.8, "end": 62.0, "key": "CAPTION_SHED_TALK_10", "speaker": SPEAKER_SOPHIA},
		{"start": 62.1, "end": 63.1, "key": "CAPTION_SHED_TALK_11", "speaker": SPEAKER_JULIANA},
		{"start": 64.6, "end": 66.8, "key": "CAPTION_SHED_TALK_12", "speaker": SPEAKER_JULIANA},
		{"start": 66.8, "end": 70.4, "key": "CAPTION_SHED_TALK_13", "speaker": SPEAKER_JULIANA},
		{"start": 71.6, "end": 74.2, "key": "CAPTION_SHED_TALK_14", "speaker": SPEAKER_SOPHIA},
		{"start": 75.4, "end": 76.6, "key": "CAPTION_SHED_TALK_FORGIVEN", "speaker": SPEAKER_JULIANA},
		{"start": 81.8, "end": 84.8, "key": "CAPTION_SHED_TALK_15", "speaker": SPEAKER_JULIANA},
		{"start": 85.8, "end": 89.2, "key": "CAPTION_SHED_TALK_16", "speaker": SPEAKER_SOPHIA},
		{"start": 89.2, "end": 90.2, "key": ""},
	],
}


static func get_cues(track_id: StringName) -> Array:
	return TRACKS.get(track_id, [])


## The end of the last cue of a track (its length as a schedule), in seconds.
static func get_length(track_id: StringName) -> float:
	var length: float = 0.0
	for cue: Dictionary in get_cues(track_id):
		length = maxf(length, float(cue["end"]))
	return length
