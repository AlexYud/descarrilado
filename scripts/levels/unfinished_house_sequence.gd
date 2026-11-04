extends Node3D
class_name UnfinishedHouseSequence

## Orchestrates the unfinished house (the second dream puzzle). The pieces (doors, the postcard, items, the capsule) only
## raise signals; every decision lives here. Sounds are generated placeholders, and nothing is voiced yet: the lines are
## subtitles (CaptionTracks), with optional voice hooks (`memory_voice`) for the recordings to come.
##
## Room by room:
##  1. Kitchen: the recipe lies on a plank beside the sink. The first time it is read (its view closed), something falls
##     behind the player, then a latch gives at the pantry: the pantry door, locked until now, swings part way open and
##     its bare bulb comes on (and stays on for good). Reading it again plays nothing.
##  2. Pantry: once the player is all the way in, the door swings gently shut behind them (once, before the note is
##     read). The folded note and the bedroom key (`master_key`) are on the shelves; the key can be taken at any time.
##     From the moment the note is read, muffled arguing comes from the hallway whenever the player is in the pantry
##     with its door shut; opening the door cuts it at once, shutting it again brings it back. The bulb stays on and the
##     flashlight is never touched.
##  3. Bedroom: the key opens the door. Lucas's notebook lies on the bed and the nightstand drawer is empty (both
##     optional: nothing happens). Reading Lucas's unsent postcard on the nightstand plays one continuous directed scene, once,
##     with the controls taken away from beginning to end, almost still (no shaking anywhere):
##       - she is walked to the nightstand; through her eyes the postcard is taken up in one movement (she bows to it, the hand
##         lifts it, the head rises) and comes close until the paper is all there is to see, with no stop to read;
##       - under the paper the time changes (`_dissolve` of the paper alone): the scene's camera sees the postcard on the
##         nightstand exactly as she held it (`_fill_camera`), and draws slowly back into the warm room, to one held shot of the
##         postcard, the lamp and a little of the bed; Lucas and Sophia talk, unseen (subtitles, `HOUSE_BEDROOM_MEMORY`);
##       - after the last line the camera pushes back into the paper; under it, her eyes again, in the cold room; she lowers
##         the postcard back onto the nightstand; a while on the dark room;
##       - a hard cut, with the first footstep, to a camera far back, on the door's middle line and square on to the shut bedroom door, which
##         starts a slow, straight approach that goes on to the shush (the whole door always in the picture); slow, heavy steps come along the hallway
##         and stop outside; her flashlight, which points back at the nightstand where she stands, comes slowly round to the door; the handle goes down and
##         meets the lock, and comes back; a pause; it goes down again and again fails (the door never opens, never shows a gap, a head or an edge);
##         then the voice on the other side (`HOUSE_DOOR_THREAT`: Juliana asks who is there, and a voice with Sophia's, light at first and then afraid,
##         sharper, impatient, asks her to open it; nobody answers). Meanwhile, out of this camera's sight, the wall between the kitchen and the bedroom
##         becomes a doorway (`UnfinishedHouseBuilder.set_escape_doorway`), with a door (`EscapeDoor`, shut);
##       - the shush (`HOUSE_DOOR_SHUSH`) at her right ear and a HARD CUT to her own eyes at the bedside (her normal lens, looking at the original door,
##         her flashlight following her view); she turns to the right over about 0.85 s: the new door is opening, the kitchen's warm light in it; one look
##         back at the original door (the next plea, `HOUSE_DOOR_COLD`), and she walks, her own body, through the doorway (`HOUSE_DOOR_HELP`); only when all
##         of her is in the kitchen the door slams and locks behind her, the pleas stop, the two outside exits are shut and locked, the living room's light
##         comes up; a moment in the kitchen looking down the way, and the controls are hers (the capsule is unlocked then, as before);
##       - the pantry's door is open and its bulb on: a completely black head looks round the frame (`PantryWatcher`), only a partial shape; when her
##         view finds it from the corridor it goes back into the room and the bulb goes out with it. It never blocks anything. Taking Lucas's token (the
##         pickup, not the inspecting of it) unlocks the two exits again. An older game that only has the bedroom scene done is not changed by any of it.
##     Saving is blocked throughout.
##  4. Living room: the time capsule, unlocked by the scene (its own interaction): the advertisement, the two tickets and
##     Lucas's Ficha. Taking the Ficha raises `sequence_completed`. No door is ever locked by the story.
##
## Saved state (section `puzzles`): `house_recipe_done`, `house_pantry_closed_on_entry`, `house_argument_active`,
## `house_bedroom_memory_done` (the bedroom scene played, by the postcard now, or by the clock or the drawer of earlier versions),
## `house_ficha_taken`, and `house_migrated` (games saved by the old sequence are converted once, see `_migrate_legacy`). The
## capsule saves its own lid; it is unlocked by the story (no key) once the bedroom scene is done.

signal sequence_completed

const STATE_SECTION: StringName = &"puzzles"
const KEY_RECIPE_DONE: StringName = &"house_recipe_done"
const KEY_PANTRY_CLOSED: StringName = &"house_pantry_closed_on_entry"
const KEY_ARGUMENT_ACTIVE: StringName = &"house_argument_active"
const KEY_MEMORY_DONE: StringName = &"house_bedroom_memory_done"
const KEY_FICHA_TAKEN: StringName = &"house_ficha_taken"
const KEY_MIGRATED: StringName = &"house_migrated"
## The extended escape (the voice at the door, the new doorway, the kitchen) was played; the outside exits are locked until Lucas's token is taken; the black head
## in the pantry has been noticed. A legacy game that has only `house_bedroom_memory_done` never went through the escape: none of these is set for it.
const KEY_ESCAPE_DONE: StringName = &"house_escape_done"
const KEY_EXITS_LOCKED: StringName = &"house_exits_locked"
const KEY_WATCHER_DONE: StringName = &"house_watcher_done"
## Written by the old sequence (read once, by `_migrate_legacy`).
const LEGACY_KEY_STAGE: StringName = &"house_stage"
const LEGACY_KEY_PANTRY_BEAT: StringName = &"house_pantry_beat"

## The rooms, in the house's own frame (metres; see UnfinishedHouseBuilder).
const KITCHEN_AREA: AABB = AABB(Vector3(0.3, -1.0, 0.3), Vector3(4.1, 4.0, 5.7))
const PANTRY_AREA: AABB = AABB(Vector3(9.39, -1.0, 6.29), Vector3(2.235, 4.0, 2.92))
## The corridor the watcher is seen from (house local): from the kitchen's arch to the pantry door.
const WATCHER_AREA: AABB = AABB(Vector3(1.6, -1.0, 6.3), Vector3(7.7, 4.0, 2.2))

@export_category("Clues")
## `inspect_id` metadata of the Visual of each clue.
@export var recipe_id: StringName = &"kitchen_recipe"
@export var pantry_note_id: StringName = &"pantry_note"
@export var ficha_id: StringName = &"lucas_ficha"

@export_category("Pieces")
## Every door of the house (a DoorController child each).
@export var doors_root: Node3D
@export var pantry_door: DoorController
@export var bedroom_door: DoorController
@export var capsule: TimeCapsule
## Shown only while the room is not the memory.
@export var night_only: Array[Node3D] = []

@export_category("Kitchen: the pantry opens")
## The pantry's bare bulb: off until the recipe is read, then on for good. `pantry_lamp` is the bulb's prop (its glass glows).
## The light casts shadows (the walls and the ceiling keep it in the pantry and the hallway).
@export var pantry_light: OmniLight3D
@export var pantry_lamp: Node3D
@export var pantry_light_energy: float = 1.0
@export var pantry_bulb_glow: float = 2.5
## After the recipe is put away: the fall behind the player, the latch at the pantry, the door opening.
@export var fall_delay_seconds: float = 0.6
## How far behind the player the fall is heard (kept inside the kitchen).
@export var fall_distance: float = 2.2
@export var latch_delay_seconds: float = 1.6
@export var open_after_latch_seconds: float = 0.7
## The pantry door opens only this far by itself.
@export var pantry_ajar_degrees: float = 55.0
## When the pantry has opened and the player turns for the corridor, their flashlight goes out by itself (a little before the corridor), so
## the pantry's bulb and the open door are what they see: `kitchen_exit` is the corridor's arch (house local), `kitchen_light_off_distance`
## how close to it, in metres.
@export var kitchen_exit: Vector3 = Vector3(2.33, 0.0, 6.2)
@export var kitchen_light_off_distance: float = 2.4
## The living room's light, on once the bedroom door has opened (the way to the time capsule): it fades in over `living_light_fade_seconds`,
## and out when the capsule is opened.
@export var living_light: OmniLight3D
@export var living_light_energy: float = 2.2
## The ceiling lamp that gives it (its globe glows to `living_lamp_glow` as the light comes up).
@export var living_lamp: Node3D
@export var living_lamp_glow: float = 2.5
@export var living_light_fade_seconds: float = 2.0

@export_category("Pantry: the door and the arguing")
## The door closes behind the player once they are in the pantry and at least this far from its hinge (out of its swing).
@export var pantry_close_clearance: float = 1.34
## Speed of that swing (lower is gentler; see `DoorController.slam_shut`).
@export var pantry_close_speed: float = 1.4
## Muffled arguing from the hallway (it plays only while the note has been read, the door is shut and the player is in).
@export var argument_voices: AudioStreamPlayer3D
@export var voices_db: float = -9.0
@export var voices_fade_in_seconds: float = 1.5
@export var voices_cut_seconds: float = 0.08
## The door counts as shut (for the arguing) within this many degrees of closed.
@export var shut_tolerance_degrees: float = 2.0

@export_category("Bedroom: the postcard scene")
## Lucas's unsent postcard on the nightstand: reading it plays the scene (once; afterwards it is read like any note).
@export var postcard: Postcard
## The warm room: the dressing (bedding, chair, cups, lamp) and its light, shown only during the memory, and only ever changed
## while the paper fills the picture. The light casts shadows (the walls keep it in the bedroom).
@export var memory_root: Node3D
@export var memory_light: OmniLight3D
@export var memory_light_energy: float = 1.6
## The memory's one held shot: where the camera stands and what it looks at (close to the postcard, low and looking up a little, with the lamp
## and a part of the bed soft behind it), with `memory_fov`.
@export var memory_eye: Marker3D
@export var memory_aim: Marker3D
@export var memory_fov: float = 38.0
## The flashback's depth of field (`FocusBlur`): how soft the lamp and the bed are, how far behind the card the sharp part ends and how fast it softens.
@export var memory_blur_amount: float = 1.0
@export var memory_blur_depth: float = 0.02
@export var memory_blur_falloff: float = 0.5
## Before it is picked up she is walked (slowly, looking at the postcard) to where she stands over the nightstand, as the doors
## walk her to their handle: this marker, the walk's speed, and how long it may take.
@export var postcard_stand: Marker3D
@export var approach_speed: float = 0.8
@export var approach_timeout_seconds: float = 6.0
## The door shot: where the scene's camera stands at the cut (as far back as the bed allows, the whole door in the picture) and
## where its slow, straight approach ends (still the whole door in the picture). It always looks along the shut door's normal, from
## the door's middle line, so the frame stays square on, through one lens (`door_fov`).
@export var door_front_wide: Marker3D
@export var door_front_tight: Marker3D
## The master bedroom's light for the door shot (cold fill, moon through the window, a dim pool on the door, haze, vignette): in at the
## cut over `door_light_in_seconds`, out over the walk back to her eyes.
@export var door_lighting: HouseDoorLighting
@export var door_light_in_seconds: float = 0.4
## Her flashlight: when she turns to the door it points back at the nightstand (`beam_start_height` above the postcard); `beam_delay_seconds`
## after the head starts, the hand brings it round to the door (`beam_end_offset`, from its middle) over `beam_sweep_seconds` (an arc, never a
## straight line); it is on the door when the picture cuts to the door shot, and sways and trembles a little all the while (`beam_sway`).
## Her flashlight at the door shot is this fraction of its usual strength, so the master room is darker.
@export_range(0.05, 1.0, 0.05) var door_flashlight_strength: float = 0.2
## ...and it flickers, never the same twice: a dip to `flicker_depth` of its strength for `flicker_length` seconds, `flicker_every` seconds
## apart, sometimes twice in a row, and it is never quite steady in between.
@export var flicker_every: Vector2 = Vector2(0.3, 2.4)
@export var flicker_depth: Vector2 = Vector2(0.0, 0.6)
@export var flicker_length: Vector2 = Vector2(0.03, 0.45)
@export var beam_delay_seconds: float = 0.12
@export var beam_sweep_seconds: float = 0.62
@export var beam_start_height: float = 0.3
@export var beam_end_offset: Vector3 = Vector3(0.0, 0.05, 0.0)
@export var beam_arc: float = 0.3
@export var beam_sway: float = 0.06
## Optional voice hooks (empty: subtitles only). The memory recording is timed like HOUSE_BEDROOM_MEMORY from its start.
@export var memory_voice: AudioStream
@export var memory_voice_player: AudioStreamPlayer3D

@export_group("The postcard in her hands")
## The postcard is picked up in one movement, the putting down of it played backwards (`lift_seconds`): she bows to the nightstand,
## the hand takes it up with a small arc (`held_arc`), the head rises, and the card comes close (`fill_distance`) while her lens
## narrows, until the paper is most of the picture (`fill_width` of the screen's width: a little of the room still shows at its edges),
## tipped `fill_tilt_degrees` towards her. A moment still (`fill_hold_seconds`), and the
## matched change of time under the paper (`paper_dissolve_seconds`, the paper only).
@export var lift_seconds: float = 4.0
@export var held_arc: float = 0.05
## Once it is in her hand she looks at it as a person does: a moment on the written side (`look_seconds`), the hand holds it out a little
## (`show_seconds`, `show_out`, `show_low`), turns it over to the picture (`flip_seconds`), looks at it (`flip_hold_seconds`), turns it back
## (`unflip_seconds`), and only then brings it close to read. The hand is never quite still (`hand_sway` radians).
@export var look_seconds: float = 0.5
@export var show_seconds: float = 0.7
@export var show_out: float = 0.1
@export var show_low: float = 0.04
@export var flip_seconds: float = 1.1
@export var flip_hold_seconds: float = 0.9
@export var unflip_seconds: float = 0.9
@export var hand_sway: float = 0.014
## The bow: the camera sinks and tips down, and rises again, down quicker than up, never at a constant speed.
@export var bow_offset: Vector3 = Vector3(0.0, -0.07, -0.1)
@export var bow_pitch_degrees: float = -10.0
## Where the card is between the nightstand and the close pose: `read_distance` away and `read_low` under her eyes.
@export var read_distance: float = 0.26
@export var read_low: float = 0.0
## Once it is held at the reading distance the picture zooms in on it (the lens narrows, the card does not move) until the paper is
## all there is to see: `zoom_seconds`.
@export var zoom_seconds: float = 2.0
@export var fill_distance: float = 0.26
@export var fill_tilt_degrees: float = 12.0
@export_range(0.4, 1.0, 0.01) var fill_width: float = 0.78
## While she reads it, her flashlight is out and the card is lit the way any inspected item is (the inspect view's lamp, same colour and
## cone, at the eye; it fades in when the card is picked up and out as it is put back down).
@export var read_light_energy: float = 2.0
@export var read_light_range: float = 1.25
@export var read_light_color: Color = Color("#d7e5ff")
@export var read_light_angle: float = 48.0
@export var read_light_offset: Vector3 = Vector3(0.055, 0.045, 0.015)
@export var fill_hold_seconds: float = 2.3
@export var paper_dissolve_seconds: float = 0.8
## From the paper the camera draws slowly back to the memory shot; the voices begin `conversation_after_seconds` into it.
@export var pullback_seconds: float = 6.0
@export var conversation_after_seconds: float = 4.0

@export_group("Back to the night")
## After the last line (and its hold, which is in the track): the slow push back into the paper, still, the change back under it,
## a moment, the postcard lowered back onto the nightstand, and her own eyes on the dark room before the first step.
@export var push_seconds: float = 4.0
@export var push_hold_seconds: float = 0.3
@export var return_hold_seconds: float = 0.4
@export var lower_seconds: float = 3.0
## The postcard touches the nightstand and she hears the steps: a beat of stillness (`scare_hesitation_seconds`), a wind-up the other way
## (`scare_windup_seconds`), then the head whips round to the door (`scare_whip_seconds`, fast from the first moment, slowing as it
## arrives), settles a little past and back (`scare_settle_seconds`), the head ducking as it goes; the flashlight, brought up by the hand a
## moment after the head, follows and finds the door. She stares `night_seconds` and the picture cuts to the door shot, the flashlight
## already on the door.
@export var night_seconds: float = 0.25
@export var scare_hesitation_seconds: float = 0.25
@export var scare_windup_seconds: float = 0.09
@export var scare_whip_seconds: float = 0.5
@export var scare_settle_seconds: float = 0.25
@export var scare_windup_degrees: float = 3.0
@export var scare_overshoot_degrees: float = 1.5
@export_range(0.0, 1.0, 0.05) var scare_flinch: float = 0.45
## The postcard is on the nightstand this far through its lowering: the cut to the door comes then.
@export_range(0.5, 1.0, 0.01) var lower_land_share: float = 0.84

@export_group("The door")
## The door camera's one lens (degrees); its slow approach from the cut to the shush (`door_approach_seconds`: it never stops before, and never goes through the door).
@export var door_fov: float = 40.0
@export var door_approach_seconds: float = 44.0
## The footsteps in the hallway, house-local points: towards the bedroom door, a step every `step_interval_seconds` (slowing
## to `step_interval_end_seconds` at the door), `step_stride` metres apart, louder as they come. The first is heard with the cut.
## The sound is the player's own indoor step (`walk.wav`), lower and heavier. They are heard from the door camera
## (`step_unit_size`: louder further off; `step_max_distance`).
@export var footstep_path: Array[Vector3] = [Vector3(1.4, 0.08, 8.0), Vector3(2.6, 0.08, 7.35), Vector3(6.0, 0.08, 7.3), Vector3(7.45, 0.08, 6.9)]
@export var step_stride: float = 0.8
## The run begins this long before the cut to the door, while the postcard is being put away (heard far off, from her eyes).
@export var steps_lead_seconds: float = 5.0
@export var step_interval_seconds: float = 0.62
@export var step_interval_end_seconds: float = 0.7
## How uneven the running is (a share of the interval, either way), so it is never a metronome.
@export_range(0.0, 0.4, 0.01) var step_unevenness: float = 0.06
@export var first_step_db: float = -4.0
@export var last_step_db: float = 14.0
@export var step_unit_size: float = 5.0
@export var step_max_distance: float = 30.0
@export var step_pitch: Vector2 = Vector2(0.8, 0.9)
## The outside (wind, night) is pushed back this much while the steps and the door play (`OutdoorAmbience.set_muffle`).
@export_range(0.0, 1.0, 0.05) var footsteps_duck: float = 0.6
## The steps are fitted to end `steps_end_after_cut_seconds` after the cut (never faster than `steps_fastest_scale` of their own intervals); the first
## handle attempt comes `handle_after_steps_seconds` after the last step. The handle's sound is a little slower and heavier than usual.
@export_range(0.3, 1.0, 0.05) var steps_fastest_scale: float = 0.55
@export var handle_after_steps_seconds: float = 0.3
@export var handle_sound_pitch: float = 0.75

@export_group("The voice at the door and the impossible exit")
## The wall between the kitchen and the master bedroom (it can be built with a doorway: `UnfinishedHouseBuilder.set_escape_doorway`), the door that goes in
## the doorway (one of the house's own doors, kept out of the world until the doorway is made), the two outside exits, the light that makes the kitchen
## readable from the bedroom, and the black head that watches from the pantry (optional).
@export var shell: UnfinishedHouseBuilder
@export var escape_door: DoorController
@export var back_door: DoorController
@export var front_door: DoorController
@export var kitchen_light: OmniLight3D
@export var kitchen_light_energy: float = 1.8
## The kitchen's light after she has gone through: it stays, dimmer (the living room's is the one that calls).
@export_range(0.0, 1.0, 0.05) var kitchen_light_after: float = 0.35
const TENSION_PATH: String = "res://assets/audios/placeholder_string_tension.mp3"

## The light changes as she goes, not all at once: the kitchen's light comes up over `kitchen_light_fade_in_seconds` from the shush, the living room's
## starts coming up as she begins to walk (`living_light_walk_fade_seconds`), and the kitchen's eases down to `kitchen_light_after` over
## `kitchen_light_settle_seconds` from the slam (it was a jump at the end of the scene).
@export var kitchen_light_fade_in_seconds: float = 3.5
## `placeholder_string_tension` comes in with the shush, fading in over `tension_in_seconds` to `tension_db`, and goes out as the controls come back (`tension_out_seconds`).
@export var tension_in_seconds: float = 1.5
@export var tension_db: float = -3.0
@export var tension_out_seconds: float = 3.0
@export var living_light_walk_fade_seconds: float = 4.0
@export var kitchen_light_settle_seconds: float = 4.5
@export var watcher: PantryWatcher
## The source of the voice beyond the original bedroom door (the one door, in the hallway). The other two sources are made on the player's own head.
@export var door_voice_player: AudioStreamPlayer3D
## Optional recordings, one per cue (1 to 8, in the order of the approved dialogue; empty: the subtitles alone carry the line, and nothing waits for a
## stream). Cue 1 is Juliana's, at the player; 2 to 5, 7 and 8 come from the original door; 6 is the shush at her right ear.
@export var cue_voices: Array[AudioStream] = []
## How far to the right of her head, and how far in front of it, the shush is (metres).
@export var shush_ear_offset: Vector3 = Vector3(0.2, -0.03, -0.05)

@export_subgroup("The door shot: the steps, two attempts, the voice")
## The steps end this long after the cut to the door shot (they are fitted to it; the first is heard before the cut).
@export var steps_end_after_cut_seconds: float = 3.0
## An attempt at the handle: the press, the strain against the lock, the release (seconds). Then a pause, the second attempt, and a breath before she speaks.
@export var attempt_one: Vector3 = Vector3(0.9, 2.2, 1.1)
@export var attempt_two: Vector3 = Vector3(0.8, 1.3, 0.9)
@export var pause_before_speak_seconds: float = 0.85
## The second attempt is made as the voice says "Open the door. I think it's stuck.": this long after the voice begins (cue 05, "Open the door.", begins 12.8 s in;
## the handle is meant to be down by then).
@export var second_attempt_after_voice_seconds: float = 12.2
## While the handle strains the door is pushed a little (it gives by this much and comes back), as someone pushing against a door that will not open.
@export var door_nudge_degrees: float = 2.2
## After the last unanswered question, before the shush.
@export var unanswered_beat_seconds: float = 1.2

@export_subgroup("Her own view: the shush, the doorway, one look back")
## She stands this long looking at the original door after the cut to her own eyes; then the turn to the right (`turn_right_seconds`, decisive and braking).
@export var pov_beat_seconds: float = 0.2
@export var turn_right_seconds: float = 0.85
## The look to the doorway is not direct: her light goes over the opening and on past it by `pass_overshoot_degrees`, drifting on for `pass_drift_seconds`, and only
## then, with a start, does the mind catch up and the view come back to it (`realize_seconds`, a half second at most).
@export var pass_overshoot_degrees: float = 38.0
@export var pass_drift_seconds: float = 0.3
@export var realize_seconds: float = 0.25
## The flashback (from the postcard being taken up to the paper that brings her back to the night) can be skipped by holding the intro cinematic key (the prompt shows only once the
## player has pressed something): the picture goes dark for skip_fade_seconds and comes back in the night room, the horror about to begin.
@export var skip_fade_seconds: float = 0.3
## The new door opens to `escape_door_open_degrees` over `escape_door_open_seconds` (it begins as she begins to turn, out of her view), and she looks at it for
## `reveal_hold_seconds` after the turn.
@export var escape_door_open_degrees: float = 130.0
@export var escape_door_open_seconds: float = 5.5
@export var reveal_hold_seconds: float = 0.6
## The one look back at the original door and the turn to the passage again.
@export var glance_seconds: float = 0.55
@export var glance_hold_seconds: float = 0.35
## She looks at the original door and waits this long, in silence, until Sophia begins to speak again; then she turns away and goes.
@export var glance_wait_seconds: float = 2.0
@export var turn_back_seconds: float = 0.5
## Her flashlight in the kitchen: from the slam it flickers, each step a share of its strength for some seconds, and is out for good after the last one. It works again
## when Lucas's token is taken.
@export var flashlight_death: Array[Vector2] = [Vector2(0.15, 0.08), Vector2(1.0, 0.14), Vector2(0.0, 0.1), Vector2(0.8, 0.12), Vector2(0.1, 0.07), Vector2(0.55, 0.18), Vector2(0.0, 0.22), Vector2(0.3, 0.09), Vector2(0.0, 0.35), Vector2(0.2, 0.1), Vector2(0.0, 0.2)]
## Her flashlight in her own view (a share of its usual strength).
@export_range(0.05, 1.0, 0.05) var escape_flashlight_strength: float = 0.55
## The walk through the new door, in the house's own frame: where her body goes, one point after the other (she walks on through the first ones without
## slowing). She looks at the next point (at `escape_eye_height`); at the last she looks at `escape_final_look`, down the kitchen to the arch and the lit
## rooms beyond it. The door slams when her whole body is west of `escape_clear_x` (the wall's face, her body's width and a margin).
@export var escape_path: Array[Vector3] = [Vector3(6.1, 0.0, 1.6), Vector3(5.2, 0.0, 2.2), Vector3(4.65, 0.0, 2.32), Vector3(3.9, 0.0, 2.45), Vector3(3.35, 0.0, 2.9)]
@export var escape_final_look: Vector3 = Vector3(2.33, 1.3, 6.2)
@export var escape_eye_height: float = 1.35
@export var escape_clear_x: float = 4.2
@export var escape_pass_radius: float = 0.3
@export var escape_walk_timeout_seconds: float = 6.0
## Reluctant: the pace on each leg as a share of her walking pace (slow at first, slowest at the threshold, quicker once she is through). She walks to the new door
## (the safe one) looking back at the original one (the unsafe one), almost backwards and slowly (`escape_look_back_pace` of that pace), and turns to the front, as
## one does, when the open leaf is about to come between her eyes and it, or when she is at the doorway (house x at most `escape_look_back_until_x`), or after
## `escape_look_back_max_seconds` at the latest.
@export var escape_speeds: PackedFloat32Array = PackedFloat32Array([0.45, 0.55, 0.4, 0.8, 0.9])
@export var escape_look_back_pace: float = 0.8
@export var escape_look_back_until_x: float = 4.85
@export var escape_look_back_max_seconds: float = 7.0
## She turns to the front this long BEFORE any of those would be true: they are tested where she will be this many seconds later on the path
## (and `escape_look_back_max_seconds` is shortened by as much).
@export var escape_look_back_lead_seconds: float = 1.0
@export var slam_speed: float = 14.0
## She stands a moment in the kitchen before the view is hers.
@export var settle_seconds: float = 0.8

@export_subgroup("The pantry watcher")
## It is armed this long after the scene is over, and waits there, the pantry's bulb on, as long as it takes: it goes when the player's FLASHLIGHT (on, and
## pointing where the view does) comes within `watcher_look_degrees` of it, from the corridor (`WATCHER_AREA`), within `watcher_range` metres and with nothing between.
@export var watcher_arm_delay_seconds: float = 0.8
@export var watcher_look_degrees: float = 30.0
@export var watcher_range: float = 11.0
## When the light finds it, the head goes back into the room, and the pantry's bulb goes out with it, over this long.
@export var watcher_retreat_seconds: float = 1.0

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _recipe_done: bool = false
var _pantry_closed: bool = false
var _argument_active: bool = false
var _memory_done: bool = false
var _ficha_taken: bool = false

var _connected: bool = false
var _connect_retry: float = 0.0
var _kitchen_running: bool = false
var _awaiting_latch: bool = false
var _voices_on: bool = false
var _voices_tween: Tween = null

## The scene in the bedroom: true while it plays; each run has its own number, so a cancelled one stops at its next step.
var memory_running: bool = false
var _run: int = 0
var _tweens: Array[Tween] = []
var _held: Node = null
var _held_view_locked: bool = false
var _held_scripted_flashlight: bool = false
var _held_save_block: bool = false
var _held_motion_still: bool = false
## What the scene did, in order (for tests): {"beat": StringName, "time": seconds since it began}.
var memory_log: Array[Dictionary] = []
## Seconds of game time since the scene began (it stands still while the game is paused).
var scene_clock: float = 0.0
## The room as the memory has it (warm), or the night.
var in_memory: bool = false

# The scene's camera (made when it starts), the one showing (null: the player's own eyes), and its shot: a move from one
# transform to another and a lens from one field of view to another, each over its own time (eased in and out).
var _cinema: Camera3D = null
var _cam: Camera3D = null
var _move_from: Transform3D = Transform3D.IDENTITY
var _move_to: Transform3D = Transform3D.IDENTITY
var _move_t: float = 1.0
var _move_seconds: float = 0.0
var _lens_from: float = 75.0
var _lens_to: float = 75.0
var _lens_t: float = 1.0
var _lens_seconds: float = 0.0
## The still of the last frame that the dissolves fade away (see `_dissolve`).
var _freeze_layer: CanvasLayer = null
## The postcard in her hands (a copy of its model; the postcard itself is hidden meanwhile). Where it is held is worked out every
## frame from her eyes (`_place_held_card`): `_held_weight` from the nightstand (0) to her hands (1), `_held_near` from reading (0)
## to filling the picture (1). `_fill_at` is the scene camera that sees the postcard on the nightstand as her eyes see the held one
## at its closest (`_fill_rel`: the postcard in that camera's frame), through `_fill_fov` (her lens narrows to it; `_fill_fov_used`
## is the lens actually reached at the change of time). `_base_fov` is her own lens.
var held_card: Node3D = null
var _held_weight: float = 0.0
var _held_near: float = 0.0
## The card held out from her (0 to 1) and turned over to its picture side (0 to 1) while she looks it over.
var _held_show: float = 0.0
var _held_flip: float = 0.0
var _held_from: Transform3D = Transform3D.IDENTITY
var _fill_at: Transform3D = Transform3D.IDENTITY
var _fill_rel: Transform3D = Transform3D.IDENTITY
var _fill_fov: float = 30.0
var _fill_fov_used: float = 30.0
var _base_fov: float = 75.0
## Left for after the scene: the door put back shut, the first moment it is out of her sight.
var _door_reset_pending: bool = false
var _ducking: bool = false

var _flashlight: Node = null
var _flashlight_scripted: bool = false
var _flashlight_available: bool = false
var _step_sound: AudioStream = null
## The head bowed to the nightstand, 0 to 1 (see `bow_offset`), and whether she is being walked to it.
var _bow: float = 0.0
var _approaching: bool = false
var _approach_save_block: bool = false
var _held_gesture_direct: bool = false
## The flashlight's sweep to the door.
var _beam_on: bool = false
## The postcard is being read (her flashlight is out, the card has its own light) and how strong that light is.
var _reading: bool = false
var _read_level: float = 0.0
var _read_light: SpotLight3D = null
var _flash_strength: float = 1.0
## Her flashlight dies in the kitchen after the escape (`_fail_flashlight`): the scene's light is out for good, and `_release_player` gives the player a flashlight that
## does not work (`FlashlightController.set_failed`) until Lucas's token is taken (`_sync_flashlight_failure`).
var _tension: AudioStreamPlayer = null
var _flash_failed: bool = false
var _flash_failing: bool = false
var _flash_sync_clock: float = 0.0
var _flicker_wait: float = 1.0
var _flicker_left: float = 0.0
var _flicker_level: float = 1.0
var _flicker_repeat: bool = false
var _flicker_drift: float = 1.0
## The walker has stopped outside the door: the handle goes at once.
var _steps_done: bool = false
var _steps_end_clock: float = 0.0
var _cut_clock: float = 0.0
var _beam_time: float = 0.0
var _kitchen_exit_watch: bool = false
var _living_light_on: bool = false
var _kitchen_fade: Tween = null
var _escape_done: bool = false
var _exits_locked: bool = false
var _watcher_done: bool = false
var _watcher_clock: float = 0.0
var _escape_door_home_y: float = 0.0
## Her flashlight follows her view exactly (from the cut to her own eyes at the shush until the view is given back), and she is being walked.
var _pov_follow: bool = false
var _walking: bool = false
var _head_voices: Dictionary = {}
## The flashback's skip: the prompt (made the first time), whether the skip can be asked for now, whether it was asked for, whether it was done, and the black it goes through.
var _skip_ui: HoldToSkip = null
var _skip_open: bool = false
var _skip_requested: bool = false
var _skipped: bool = false
var _skip_black: CanvasLayer = null
var _beam_from: Vector3 = Vector3.ZERO
var _beam_to: Vector3 = Vector3.ZERO


func _ready() -> void:
	_migrate_legacy()
	_recipe_done = _get_flag(KEY_RECIPE_DONE)
	_pantry_closed = _get_flag(KEY_PANTRY_CLOSED)
	_argument_active = _get_flag(KEY_ARGUMENT_ACTIVE)
	_memory_done = _get_flag(KEY_MEMORY_DONE)
	_ficha_taken = _get_flag(KEY_FICHA_TAKEN)
	_escape_done = _get_flag(KEY_ESCAPE_DONE)
	_exits_locked = _get_flag(KEY_EXITS_LOCKED)
	_watcher_done = _get_flag(KEY_WATCHER_DONE)
	if escape_door != null:
		_escape_door_home_y = escape_door.position.y

	if argument_voices != null:
		argument_voices.stream = PlaceholderAudio.make_muffled_argument()
		argument_voices.stop()

	if postcard != null:
		postcard.scene_requested.connect(_on_postcard_scene_requested)
	if capsule != null:
		capsule.opened.connect(_on_capsule_opened)

	_restore()
	_connect_to_player.call_deferred()


## Puts the house as the saved story left it.
func _restore() -> void:
	_set_pantry_lamp(_pantry_lamp_wanted(), false)
	# The kitchen beat was cut short (a save in the second between reading and the latch): the pantry opens now.
	if _recipe_done and pantry_door != null and pantry_door.is_locked:
		pantry_door.unlock()
		pantry_door.force_open(0.0, pantry_ajar_degrees)

	_set_room(false)
	_unlock_capsule()
	_set_living_light(_memory_done and not _capsule_open(), 0.0)
	if postcard != null:
		postcard.plays_scene = not _memory_done

	# The new passage and what came with it, only for a game that went through the escape (an older game with the bedroom scene done never did: it keeps its
	# wall, and nothing is locked round it).
	_apply_doorway(_escape_done)
	if _escape_done:
		if escape_door != null:
			escape_door.ajar_degrees = 0.0
			escape_door.close_instantly()
			escape_door.lock()
		_set_kitchen_light(kitchen_light_energy * kitchen_light_after, 0.0)
		if _token_owned():
			if _exits_locked:
				_release_exits()
		elif _exits_locked:
			_close_exits()
			for door: DoorController in [back_door, front_door]:
				if door != null:
					door.lock()
		_arm_watcher.call_deferred()
	elif _exits_locked and _token_owned():
		_release_exits()


## Games saved by the old sequence (`house_stage`, `house_pantry_beat`) are converted once: what was reached is kept,
## what no longer exists (the red light, the trap, the locked exit) is dropped. Safe to run on any game, any number of
## times (it marks itself done).
func _migrate_legacy() -> void:
	if _get_flag(KEY_MIGRATED):
		return

	var stage: int = int(SaveManager.get_state_value(STATE_SECTION, LEGACY_KEY_STAGE, 0))
	var beat: int = int(SaveManager.get_state_value(STATE_SECTION, LEGACY_KEY_PANTRY_BEAT, 0))
	var recipe_read: bool = bool(SaveManager.get_state_value(&"triggers", &"house_recipe_open", false))

	if stage >= 1 or beat >= 1 or recipe_read:
		_set_flag(KEY_RECIPE_DONE, true)
	if beat >= 1:
		_set_flag(KEY_ARGUMENT_ACTIVE, true)
		_set_flag(KEY_PANTRY_CLOSED, true)
	# The old climax came after the bedroom was opened with its key.
	if stage >= 2 and bedroom_door != null:
		bedroom_door.unlock()
	# The capsule already stands open: there is nothing for the scene to unlock.
	if _capsule_open():
		_set_flag(KEY_MEMORY_DONE, true)

	# The old trap locked every door until the Ficha was taken; nothing locks them now.
	for door: DoorController in _doors():
		if door != pantry_door and door != bedroom_door and door.is_locked:
			door.unlock()

	_set_flag(KEY_MIGRATED, true)


func _connect_to_player() -> void:
	var target: Node = _get_player()
	if target == null:
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect == null:
		return

	if not inspect.inspect_opened.is_connected(_on_inspect_opened):
		inspect.inspect_opened.connect(_on_inspect_opened)
	if not inspect.inspect_closed.is_connected(_on_inspect_closed):
		inspect.inspect_closed.connect(_on_inspect_closed)
	_connected = true
	_sync_flashlight_failure(0.0, true)


func _exit_tree() -> void:
	_cancel_memory()
	get_tree().call_group(OutdoorAmbience.GROUP, "set_silenced", &"house_memory", false)


func _process(delta: float) -> void:
	if not _connected:
		_connect_retry -= delta
		if _connect_retry <= 0.0:
			_connect_retry = 0.5
			_connect_to_player()

	if memory_running and _held != null and is_instance_valid(_held):
		if bool(_held.call("is_inventory_open")):
			# The inventory is the one thing a held view still lets the player open: not during this scene.
			var inventory_ui: Node = _held.get("inventory_ui_controller") as Node
			if inventory_ui != null:
				inventory_ui.call("close")

		scene_clock += delta
		_drive_camera(delta)
		_place_held_card()
		_apply_bow()
		if _beam_on:
			_drive_beam(delta)
		if _pov_follow:
			_follow_view_with_the_beam()
	if _door_reset_pending:
		_settle_pending(false)


func _physics_process(delta: float) -> void:
	_update_pantry()
	_update_kitchen_exit()
	# The exits open the moment Lucas's token is collected (not inspected, not read about): the pickup records it before anything is shown.
	if _exits_locked and _token_owned():
		_release_exits()
	_sync_flashlight_failure(delta)
	_update_watcher(delta)
	if _walking:
		_hold_the_walker()


## The player's flashlight is broken from the end of the escape until Lucas's token is taken (checked twice a second, and when the player is found), and works again
## the moment it is (with its usual start-up flicker). Not while the scene itself plays.
func _sync_flashlight_failure(delta: float, force: bool = false) -> void:
	_flash_sync_clock -= delta
	if not force and _flash_sync_clock > 0.0:
		return

	_flash_sync_clock = 0.5
	if memory_running:
		return

	var target: Node3D = _get_player()
	var light: Node = target.get("flashlight_controller") as Node if target != null else null
	if light == null or not light.has_method("set_failed"):
		return

	var dead: bool = _escape_done and not _token_owned()
	if bool(light.get("failed")) != dead:
		light.call("set_failed", dead)
		_log(&"flashlight_broken" if dead else &"flashlight_repaired")


## The flashlight goes out as the player, with the pantry open, comes within `kitchen_light_off_distance` of the corridor's arch (inside the
## kitchen), once; they can switch it on again.
func _update_kitchen_exit() -> void:
	if not _kitchen_exit_watch or _kitchen_running or memory_running:
		return

	var body: Node3D = _get_player()
	if body == null:
		return

	var local: Vector3 = to_local(body.global_position)
	if local.z >= kitchen_exit.z or Vector2(local.x - kitchen_exit.x, local.z - kitchen_exit.z).length() > kitchen_light_off_distance:
		return

	_kitchen_exit_watch = false
	var light: Node = body.get("flashlight_controller") as Node
	if light != null and light.has_method("turn_off"):
		light.call("turn_off")


# ============================================================
# INSPECT: THE CLUES
# ============================================================

func _on_inspect_opened(opened_id: String) -> void:
	# Reading the pantry note: from now on the arguing is heard whenever the player is shut in the pantry.
	if StringName(opened_id) == pantry_note_id and not _argument_active:
		_argument_active = true
		_set_flag(KEY_ARGUMENT_ACTIVE, true)


func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)
	if id == recipe_id:
		if not _recipe_done and not _kitchen_running:
			_run_kitchen_beat()
	elif id == ficha_id and not _ficha_taken:
		_ficha_taken = true
		_set_flag(KEY_FICHA_TAKEN, true)
		sequence_completed.emit()


# ============================================================
# THE KITCHEN: SOMETHING FALLS, THE PANTRY OPENS
# ============================================================

func _run_kitchen_beat() -> void:
	_kitchen_running = true
	# The state first: a save from here on finds the pantry open (see `_restore`).
	_recipe_done = true
	_set_flag(KEY_RECIPE_DONE, true)

	await _wait(fall_delay_seconds)
	_play_fall_behind_player()

	await _wait(latch_delay_seconds)
	if pantry_door != null:
		_play_at(PlaceholderAudio.make_bolt_throw(), pantry_door.global_position + Vector3(0.0, 1.0, 0.0), 2.0, 1.0, 10.0, 50.0)
		pantry_door.unlock()

	await _wait(open_after_latch_seconds)
	if pantry_door != null:
		pantry_door.force_open(0.0, pantry_ajar_degrees)
	_set_pantry_lamp(true, true)
	_kitchen_running = false
	_kitchen_exit_watch = true


## Behind the player, on the kitchen floor: a foot slipping, a body hitting the boards, something small rolling away.
func _play_fall_behind_player() -> void:
	var target: Node3D = _get_player()
	var camera: Camera3D = _get_camera()
	if target == null:
		return

	var back: Vector3 = camera.global_basis.z if camera != null else target.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var local: Vector3 = to_local(target.global_position + back * fall_distance)
	local = local.clamp(KITCHEN_AREA.position, KITCHEN_AREA.end)
	local.y = 0.15
	var at: Vector3 = to_global(local)

	_play_at(PlaceholderAudio.make_footstep(), at, -6.0, 1.3)
	_play_at_later(PlaceholderAudio.make_door_thud(), at, -2.0, 0.75, 0.12)
	_play_at_later(PlaceholderAudio.make_coin_clatter(), at + Vector3(0.3, 0.0, 0.2), -14.0, 0.7, 0.45)


## The bulb on or off (`fade`: it comes up over a moment, as an old filament does).
func _set_pantry_lamp(on: bool, fade: bool) -> void:
	var glass: StandardMaterial3D = _bulb_material()
	if pantry_light != null:
		pantry_light.visible = on
		if on and fade:
			pantry_light.light_energy = 0.0
			_track(create_tween()).tween_property(pantry_light, "light_energy", pantry_light_energy, 0.35)
		else:
			pantry_light.light_energy = pantry_light_energy if on else 0.0

	if glass != null:
		glass.emission_energy_multiplier = pantry_bulb_glow if on else 0.0


func _bulb_material(lamp: Node3D = pantry_lamp) -> StandardMaterial3D:
	if lamp == null:
		return null

	var bulb: MeshInstance3D = lamp.get_node_or_null(^"Bulb") as MeshInstance3D
	return bulb.material_override as StandardMaterial3D if bulb != null else null


func is_pantry_lamp_on() -> bool:
	return pantry_light != null and pantry_light.visible and pantry_light.light_energy > 0.0


# ============================================================
# THE PANTRY: THE DOOR CLOSES, THE ARGUING
# ============================================================

func _update_pantry() -> void:
	if pantry_door == null:
		return

	var inside: bool = is_player_in_pantry()

	# Once, on the way in: the door swings shut behind the player (before the note is read).
	if _recipe_done and not _pantry_closed and inside and not _kitchen_running:
		if not pantry_door.is_open:
			# The player shut it themselves.
			_mark_pantry_closed()
		elif not pantry_door.is_busy() and _clear_of_pantry_door():
			_mark_pantry_closed()
			pantry_door.slam_shut(pantry_close_speed)
			_awaiting_latch = true

	if _awaiting_latch:
		if pantry_door.is_open:
			_awaiting_latch = false
		elif _door_offset_degrees(pantry_door) < 1.0:
			_awaiting_latch = false
			_play_at(PlaceholderAudio.make_door_latch_close(), pantry_door.global_position + Vector3(0.0, 1.0, 0.0), -8.0)

	var wanted: bool = _argument_active and inside and is_pantry_door_shut()
	if wanted != _voices_on:
		_set_voices(wanted)


func _mark_pantry_closed() -> void:
	_pantry_closed = true
	_set_flag(KEY_PANTRY_CLOSED, true)


## The player is far enough from the hinge that the swinging leaf cannot touch them.
func _clear_of_pantry_door() -> bool:
	var target: Node3D = _get_player()
	if target == null:
		return false

	var flat: Vector3 = target.global_position - pantry_door.global_position
	flat.y = 0.0
	return flat.length() >= pantry_close_clearance


func is_player_in_pantry() -> bool:
	var target: Node3D = _get_player()
	return target != null and PANTRY_AREA.has_point(to_local(target.global_position))


## Shut, and not just swinging towards shut.
func is_pantry_door_shut() -> bool:
	return pantry_door != null and not pantry_door.is_open and _door_offset_degrees(pantry_door) <= shut_tolerance_degrees


func is_argument_playing() -> bool:
	return _voices_on


func _door_offset_degrees(door: DoorController) -> float:
	if door.hinge == null:
		return 0.0

	return absf(angle_difference(deg_to_rad(door.hinge.rotation_degrees.y), deg_to_rad(door.closed_rotation_degrees.y))) * 180.0 / PI


## Fades the arguing in, or cuts it (an opening door cuts it at once).
func _set_voices(on: bool) -> void:
	_voices_on = on
	if argument_voices == null:
		return

	if _voices_tween != null and _voices_tween.is_valid():
		_voices_tween.kill()

	_voices_tween = create_tween()
	if on:
		argument_voices.volume_db = -60.0
		argument_voices.play()
		_voices_tween.tween_property(argument_voices, "volume_db", voices_db, voices_fade_in_seconds)
	else:
		_voices_tween.tween_property(argument_voices, "volume_db", -60.0, voices_cut_seconds)
		_voices_tween.tween_callback(argument_voices.stop)


# ============================================================
# THE BEDROOM: THE POSTCARD AND THE DOOR
# ============================================================

func _on_postcard_scene_requested(_who: Node) -> void:
	if not _memory_done and not memory_running:
		_play_memory()


## For the developer console (`house_postcard`): plays the scene again from where the player stands. Nothing else is reset (a key
## already taken does not come back). False when it is already playing or there is nobody to show it to.
func replay_bedroom_scene() -> bool:
	if memory_running or _get_movement() == null:
		return false

	_memory_done = false
	_play_memory()
	return memory_running


func _play_memory() -> void:
	var target: Node = _get_player()
	var movement: PlayerMovementController = _get_movement()
	if target == null or movement == null or movement.camera == null or postcard == null or memory_eye == null or memory_aim == null or door_front_wide == null or door_front_tight == null:
		# Nobody to show it to: the key is simply there.
		_finish_memory_state()
		return

	# Whatever the last scene left for later is done now.
	_settle_pending(true)
	_run += 1
	var run: int = _run
	memory_running = true
	memory_log.clear()
	scene_clock = 0.0
	_skip_open = false
	_skip_requested = false
	_skipped = false
	# Walked to the nightstand first, as the doors walk her to the handle (before she is held: a held view does not walk).
	if not await _walk_to_nightstand(run, target, movement):
		return
	# (The postcard's reading stays the scene's until it is over: using it again meanwhile asks for the scene, which is
	# already playing, and nothing happens.)

	if not await _shot_read(run): return
	if not await _shot_conversation(run): return
	if not await _shot_return(run): return
	if not await _shot_door(run): return
	if not await _shot_escape(run): return

	# What the scene leaves behind is settled before the player can save again.
	memory_running = false
	_tweens.clear()
	_close_skip_window()
	_complete_escape_state()
	_finish_memory_state()
	_release_player()
	_stop_tension(tension_out_seconds)
	_log(&"released")
	# The head in the pantry, only now that the controls are hers: the scene's own looks back cannot spend it.
	_arm_watcher()


# ---- Walking up to the nightstand ---------------------------------------------------------------------------------

## She is walked, slowly and looking at the postcard, to where she stands over the nightstand, unless she is already there. Saving
## is blocked from the first step; the walk ends as the sequence holds her. False if the scene was cancelled meanwhile.
func _walk_to_nightstand(run: int, target: Node, movement: PlayerMovementController) -> bool:
	_approach_save_block = bool(target.get("manual_save_blocked"))
	target.call("set_manual_save_blocked", true)
	_approaching = true
	if postcard_stand != null:
		var stand: Vector3 = postcard_stand.global_position
		stand.y = (target as Node3D).global_position.y
		var flat: Vector3 = (target as Node3D).global_position - stand
		flat.y = 0.0
		if flat.length() > 0.12 and movement.begin_guided_walk(stand, postcard.global_position, approach_speed, approach_timeout_seconds):
			_log(&"approach")
			var waited: float = 0.0
			while movement.is_guided_walking() and waited < approach_timeout_seconds + 1.0:
				await get_tree().process_frame
				waited += get_process_delta_time()
				if not _still(run):
					return false
			movement.cancel_guided_walk()
	_approaching = false
	if not _still(run):
		return false
	# (Held next: `_hold_player` takes saving back as it found it.)
	target.call("set_manual_save_blocked", _approach_save_block)
	# The frame the player sees now is where the reading starts.
	_hold_player(target)
	CaptionManager.clear()
	_log(&"start")
	return true


# ---- The postcard in her hands, and into the memory ---------------------------------------------------------------

## Through her eyes the postcard comes up from the nightstand into her hands, written side to her, and she reads it; she brings it
## close until the paper is all there is to see; under the paper the time changes (the scene's camera sees the postcard on the
## nightstand exactly as she held it: the same writing on the same pixels), and the camera draws slowly back from it into the warm
## room. The bedroom door is shut while the paper covers everything.
func _shot_read(run: int) -> bool:
	_log(&"lift")
	_open_skip_window()
	_set_reading(true, 0.8)
	var card: Transform3D = postcard.get_visual_node().global_transform
	_fill_at = _fill_camera()
	_fill_fov = _fill_lens()
	_fill_rel = _fill_at.affine_inverse() * card
	_base_fov = _get_camera().fov
	_take_up_card()
	# One movement, the putting down of it played backwards: she bows to the nightstand, the hand takes the card up (slow at both
	# ends), the head rises, and the card comes close until the paper is all there is to see; no stop to read it.
	_tween_held(&"_bow", 1.0, lift_seconds * 0.3, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 0.0, lift_seconds * 0.58, lift_seconds * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_held_weight", 1.0, lift_seconds * 0.62, lift_seconds * 0.18, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	# In her hand: a look at the written side, the card held out, turned over to the picture and looked at, turned back, drawn in.
	var at: float = lift_seconds * 0.85 + look_seconds
	_tween_held(&"_held_show", 1.0, show_seconds, at, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	at += show_seconds * 0.8
	_tween_held(&"_held_flip", 1.0, flip_seconds, at, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	at += flip_seconds + flip_hold_seconds
	_tween_held(&"_held_flip", 0.0, unflip_seconds, at, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	at += unflip_seconds * 0.9
	_tween_held(&"_held_show", 0.0, show_seconds, at, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	at += show_seconds
	# Held at the reading distance, the picture then zooms in on it until the paper fills the picture.
	_tween_held(&"_held_near", 1.0, zoom_seconds, at, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	if not await _flash_wait(run, at + zoom_seconds + fill_hold_seconds):
		return false
	if _skipped:
		return true

	_log(&"dissolve_in")
	_read_level = 0.0
	_fill_fov_used = _get_camera().fov
	_dissolve(paper_dissolve_seconds)
	_set_room(true)
	held_card.visible = false
	postcard.visible = true
	_show_camera(_fill_at, _fill_fov_used)
	if bedroom_door != null:
		bedroom_door.close_instantly()
	# The pantry too: its door shut and its bulb out (nothing seen, nothing heard).
	if pantry_door != null:
		pantry_door.close_instantly()
	_set_pantry_lamp(false, false)
	_log(&"door_closed")
	if not await _flash_wait(run, paper_dissolve_seconds):
		return false
	if _skipped:
		return true

	_log(&"pullback")
	_move_camera(_memory_shot(), pullback_seconds)
	_change_lens(memory_fov, pullback_seconds)
	if not await _flash_wait(run, conversation_after_seconds):
		return false
	return true


## The camera that has the postcard on the nightstand fill the picture: straight over its written side, tipped
## `fill_tilt_degrees` towards the foot of the writing, `fill_distance` away, the writing upright.
func _fill_camera() -> Transform3D:
	var card: Transform3D = postcard.get_visual_node().global_transform
	var normal: Vector3 = card.basis.z.normalized()
	var up: Vector3 = card.basis.y.normalized()
	var tilt: float = deg_to_rad(fill_tilt_degrees)
	var eye: Vector3 = card.origin + (normal * cos(tilt) - up * sin(tilt)) * fill_distance
	return Transform3D(Basis.looking_at(card.origin - eye, up), eye)


## The lens (vertical field of view, degrees) at which the paper, `fill_distance` away, is `fill_width` of the picture's width.
func _fill_lens() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	# The card's width is `fill_width` of the picture's width.
	var height: float = HouseProps.POSTCARD_SIZE.x / (aspect * fill_width)
	return rad_to_deg(2.0 * atan(height * 0.5 / fill_distance))


func _memory_shot() -> Transform3D:
	var eye: Vector3 = memory_eye.global_position
	return Transform3D(Basis.looking_at(memory_aim.global_position - eye, Vector3.UP), eye)


## A copy of the postcard's model, where the postcard lies, in place of it.
func _take_up_card() -> void:
	_drop_held_card()
	var visual: Node3D = postcard.get_visual_node()
	held_card = visual.duplicate() as Node3D
	held_card.name = "HeldPostcard"
	add_child(held_card)
	_held_from = visual.global_transform
	_held_weight = 0.0
	_held_near = 0.0
	_held_show = 0.0
	_held_flip = 0.0
	# Lit as an inspected item is: the reading light touches this layer only, so the walls round her stay dark.
	_on_inspect_layer(held_card)
	held_card.global_transform = _held_from
	postcard.visible = false


## The inspect view's render layer (the same one `PlayerInspectController` puts an inspected item on).
const INSPECT_LAYER_NUMBER: int = 20


func _on_inspect_layer(node: Node) -> void:
	var visual: VisualInstance3D = node as VisualInstance3D
	if visual != null and not (visual is Light3D):
		visual.set_layer_mask_value(INSPECT_LAYER_NUMBER, true)
	for child: Node in node.get_children():
		_on_inspect_layer(child)


func _tween_held(property: StringName, value: float, seconds: float, delay: float = 0.0, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_kind: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var move: Tween = _track(create_tween())
	move.tween_property(self, NodePath(String(property)), value, maxf(seconds, 0.01)).set_delay(delay).set_trans(trans).set_ease(ease_kind)


## Where the held postcard is, every frame, from her eyes: between the nightstand (`_held_weight` 0) and her hands (1), and in her
## hands between reading (`_held_near` 0) and filling the picture (1), her lens narrowing with it.
func _place_held_card() -> void:
	if held_card == null or not is_instance_valid(held_card) or not held_card.visible:
		return

	var eye: Transform3D = _get_camera().global_transform.orthonormalized()
	var near: float = clampf(_held_near, 0.0, 1.0)
	var out: float = clampf(_held_show, 0.0, 1.0)
	var back: Vector3 = Vector3(0.0, -read_low, -(read_distance - fill_distance)) * (1.0 - near) + Vector3(0.0, -show_low, -show_out) * out
	var weight: float = clampf(_held_weight, 0.0, 1.0)
	# The hand: turned over about the card's own upright axis (a little rolled and drawn in as it goes), never quite steady while it is
	# held away from the eye; exactly as the camera will have it once it is close.
	var flip: float = clampf(_held_flip, 0.0, 1.0)
	var loose: float = weight * (1.0 - near)
	var t: float = scene_clock
	var hand: Basis = Basis.from_euler(Vector3(sin(t * 1.3) * hand_sway, sin(t * 0.9 + 1.0) * hand_sway * 1.2, sin(t * 1.7 + 2.0) * hand_sway * 0.8) * loose)
	var turned: Basis = Basis(Vector3.UP, PI * flip) * Basis(Vector3.BACK, sin(PI * flip) * deg_to_rad(7.0))
	var held: Transform3D = eye * Transform3D(Basis.IDENTITY, back) * _fill_rel * Transform3D(hand * turned, Vector3(0.0, 0.0, sin(PI * flip) * 0.03))
	var pose: Transform3D = _held_from.interpolate_with(held, weight)
	# Up a little on the way, as a hand lifts a thing and sets it down (nothing at either end).
	pose.origin += Vector3.UP * sin(PI * weight) * held_arc
	held_card.global_transform = pose
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.scripted_fov = lerpf(_base_fov, _fill_fov, near) if near > 0.0 else 0.0
		# Her lens follows at once (the controller's own easing would lag a little behind the card, and the paper must be where the
		# scene's camera will have it).
		if near > 0.0 and movement.camera != null:
			movement.camera.fov = movement.scripted_fov
	_place_read_light(eye, pose.origin)


## The bow: the head sinks to the nightstand and tips down, as a gesture the movement controller applies as it is (direct).
func _apply_bow() -> void:
	var movement: PlayerMovementController = _get_movement()
	if movement == null or _held == null:
		return

	movement.gesture_direct = true
	movement.gesture_offset = bow_offset * _bow
	movement.gesture_pitch_degrees = bow_pitch_degrees * _bow


## The held copy goes and the postcard lies on the nightstand again; her lens is her own.
func _drop_held_card() -> void:
	if held_card != null and is_instance_valid(held_card):
		held_card.queue_free()
	held_card = null
	if postcard != null:
		postcard.visible = true
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.scripted_fov = 0.0


# ---- The conversation ---------------------------------------------------------------------------------------------

## The voices, over the one held shot of the postcard (the track ends with a held silence after the last line).
func _shot_conversation(run: int) -> bool:
	if _skipped:
		return _still(run)

	_log(&"conversation")
	if memory_voice != null and memory_voice_player != null:
		memory_voice_player.stream = memory_voice
		memory_voice_player.play()
	var run_id: int = CaptionManager.play_scripted(CaptionTracks.HOUSE_BEDROOM_MEMORY)
	var finished: Array[bool] = [false]
	var on_finished: Callable = func(finished_id: int) -> void:
		if finished_id == run_id:
			finished[0] = true
	CaptionManager.run_finished.connect(on_finished)
	while not finished[0] and not _skip_requested and _still(run):
		await get_tree().process_frame
	CaptionManager.run_finished.disconnect(on_finished)
	if _skip_requested and not _skipped and _still(run):
		await _perform_skip(run)
	return _still(run)


# ---- Back to the night --------------------------------------------------------------------------------------------

## The camera pushes slowly back into the paper; under it the time changes back (her eyes, the postcard in her hands, close, in
## the cold room); she lowers it back onto the nightstand; her eyes rest on the dark room a while.
func _shot_return(run: int) -> bool:
	if not _skipped:
		_log(&"return")
		if memory_voice_player != null:
			memory_voice_player.stop()
		_move_camera(_fill_at, push_seconds)
		_change_lens(_fill_fov_used, push_seconds)
		if not await _flash_wait(run, push_seconds + push_hold_seconds):
			return false

	if not _skipped:
		_log(&"dissolve_out")
		_close_skip_window()
		_dissolve(paper_dissolve_seconds)
		_back_to_the_night()
	_close_skip_window()
	await _wait(paper_dissolve_seconds + return_hold_seconds)
	if not _still(run):
		return false

	_log(&"lower")
	# The steps are fitted to end `steps_end_after_cut_seconds` after the cut.
	var to_cut: float = lower_seconds * lower_land_share + _scare_seconds() + night_seconds
	var steps_delay: float = maxf(to_cut - steps_lead_seconds, 0.0)
	_steps_after(run, steps_delay, to_cut + steps_end_after_cut_seconds - steps_delay - STEPS_MARGIN_SECONDS)
	_tween_held(&"_read_level", 0.0, lower_seconds * 0.8, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_held_near", 0.0, lower_seconds * 0.34, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_held_weight", 0.0, lower_seconds * 0.62, lower_seconds * 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 1.0, lower_seconds * 0.58, lower_seconds * 0.12, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 0.0, lower_seconds * 0.3, lower_seconds * 0.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	# The postcard touches the nightstand; she hears the steps and turns to the door, scared, her flashlight finding it.
	await _wait(lower_seconds * lower_land_share)
	if not _still(run):
		return false
	_drop_held_card()
	_read_level = 0.0
	if _read_light != null:
		_read_light.visible = false
	_log(&"settled")
	if not await _scared_turn(run):
		return false
	if night_seconds > 0.0:
		await _wait(night_seconds)
	return _still(run)


## The time changes back to the night under the paper: the cold room, the postcard in her hands close, her own eyes. (Also where a skip lands.)
func _back_to_the_night() -> void:
	_set_room(false)
	_read_level = 1.0
	postcard.visible = false
	_held_weight = 1.0
	_held_near = 1.0
	held_card.visible = true
	var camera: Camera3D = _get_camera()
	_get_movement().scripted_fov = _fill_fov_used
	camera.fov = _fill_fov_used
	_place_held_card()
	_show_eyes()
	_log(&"night")


# ---- Skipping the flashback -------------------------------------------------------------------------------------------

## From the postcard's being taken up: the prompt can be shown (when the player presses something) and the skip asked for.
func _open_skip_window() -> void:
	if _skip_ui == null:
		_skip_ui = HoldToSkip.new()
		_skip_ui.name = "HoldToSkip"
		add_child(_skip_ui)
		_skip_ui.skipped.connect(func() -> void: _skip_requested = true)
	_skip_open = true
	_skip_requested = false
	_skip_ui.arm()


func _close_skip_window() -> void:
	_skip_open = false
	if _skip_ui != null:
		_skip_ui.disarm()


## A wait inside the flashback that a skip cuts short (and performs): false if the scene was cancelled, true otherwise (check `_skipped` after it).
func _flash_wait(run: int, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0 and _still(run) and not _skip_requested:
		await get_tree().process_frame
		left -= get_process_delta_time() if not get_tree().paused else 0.0
	if _skip_requested and not _skipped and _still(run):
		await _perform_skip(run)
	return _still(run)


## The skip: the picture goes dark, the flashback's work is stopped where it is, the room is the night again with the postcard in her hands (the same state the change
## of time back to the night leaves), and the picture comes back. The scene goes on from there: the postcard put down, the steps, the door.
func _perform_skip(run: int) -> void:
	_skipped = true
	_close_skip_window()
	_log(&"skipped")
	await _skip_fade(1.0, skip_fade_seconds * 0.6)
	if not _still(run):
		return

	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_clear_freeze()
	CaptionManager.clear()
	if memory_voice_player != null:
		memory_voice_player.stop()
	# What the change of time into the memory did to the house (the original door shut, the pantry shut and its bulb out), if it had not happened yet.
	if bedroom_door != null:
		bedroom_door.close_instantly()
	if pantry_door != null:
		pantry_door.close_instantly()
	_set_pantry_lamp(false, false)
	if _fill_fov_used <= 0.0 or not _logged_beat(&"dissolve_in"):
		_fill_fov_used = _fill_fov
	_bow = 0.0
	_held_show = 0.0
	_held_flip = 0.0
	_free_cinema_camera()
	_cam = null
	_back_to_the_night()
	await _skip_fade(0.0, skip_fade_seconds)


func _logged_beat(beat: StringName) -> bool:
	for entry: Dictionary in memory_log:
		if entry["beat"] == beat:
			return true
	return false


## The black over the picture (under the subtitles and the menus), to `alpha` over `seconds`; gone at 0.
func _skip_fade(alpha: float, seconds: float) -> void:
	if _skip_black == null:
		_skip_black = CanvasLayer.new()
		_skip_black.name = "SkipBlack"
		_skip_black.layer = 2
		var cover: ColorRect = ColorRect.new()
		cover.name = "Cover"
		cover.color = Color.BLACK
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		cover.modulate.a = 0.0
		_skip_black.add_child(cover)
		add_child(_skip_black)

	var cover_rect: ColorRect = _skip_black.get_node("Cover") as ColorRect
	var fade: Tween = create_tween()
	fade.tween_property(cover_rect, "modulate:a", alpha, maxf(seconds, 0.01))
	await fade.finished
	if alpha <= 0.0 and _skip_black != null:
		_skip_black.queue_free()
		_skip_black = null


## How long the frightened turn takes, from the postcard landing to her looking at the door.
func _scare_seconds() -> float:
	return scare_hesitation_seconds + scare_windup_seconds + scare_whip_seconds + scare_settle_seconds


## She hears someone coming and turns back to the door, afraid, the way a person does: a beat of stillness (the sound registers), a small
## wind-up the other way, then the head whips round (fast from the first moment, slowing as it arrives), a little past and back, the head
## ducking as it goes and rising to the door; the flashlight is brought up by the hand a moment after the head starts and swings after it
## (a hand-held beam lags and tremors), finding the door as the head arrives. Ends with her looking at the door, the beam on it.
func _scared_turn(run: int) -> bool:
	var movement: PlayerMovementController = _get_movement()
	if movement == null:
		return _still(run)

	var angles: Vector2 = _look_angles(_door_middle() + beam_end_offset)
	var from_yaw: float = movement.look_yaw
	var to_yaw: float = from_yaw + wrapf(angles.x - from_yaw, -180.0, 180.0)
	var from_pitch: float = movement.look_pitch
	var to_pitch: float = clampf(angles.y, -35.0, 75.0)
	var side: float = signf(to_yaw - from_yaw) if absf(to_yaw - from_yaw) > 0.01 else 1.0

	await _wait(scare_hesitation_seconds)
	if not _still(run):
		return false

	# The hand has the flashlight on (weak, and unsteady), pointing back where it was, and brings it round after the head.
	_reading = false
	_flash_strength = door_flashlight_strength
	_flash_apply()
	_beam_start()
	_tween_held(&"_bow", scare_flinch, scare_windup_seconds + scare_whip_seconds * 0.3, 0.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween_held(&"_bow", 0.0, scare_whip_seconds + scare_settle_seconds, scare_windup_seconds + scare_whip_seconds * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	var look: Tween = _track(create_tween())
	look.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var wound: float = from_yaw - side * scare_windup_degrees
	var past: float = to_yaw + side * scare_overshoot_degrees
	look.tween_method(func(yaw: float) -> void: movement.look_yaw = yaw, from_yaw, wound, scare_windup_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	look.tween_method(func(yaw: float) -> void: movement.look_yaw = yaw, wound, past, scare_whip_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	look.tween_method(func(yaw: float) -> void: movement.look_yaw = yaw, past, to_yaw, scare_settle_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var rise: Tween = _track(create_tween())
	rise.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_method(func(pitch: float) -> void: movement.look_pitch = pitch, from_pitch, to_pitch, scare_windup_seconds + scare_whip_seconds + scare_settle_seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await look.finished
	return _still(run)


## The running begins part way through the putting away, so it is heard far off before the cut.
## The steps are fitted to end this much earlier than the handle needs, so the door opens on time whatever the unevenness of the steps.
const STEPS_MARGIN_SECONDS: float = 0.4


func _steps_after(run: int, delay: float, fit_seconds: float = 0.0) -> void:
	await _wait(delay)
	if not _still(run):
		return
	_duck_outside(true)
	_walk_to_door(run, fit_seconds)


# ---- The door -----------------------------------------------------------------------------------------------------

## A hard cut, with the first footstep, to the door square on from far back; the camera starts its slow, straight approach at once and never stops
## until the shush. The steps come along the hallway and stop outside; the handle is tried twice and the door does not open (it stays shut, with no gap, for
## the whole scene); then the voice (`HOUSE_DOOR_THREAT`, cues 1 to 5). The doorway to the kitchen is made meanwhile, out of this camera's sight.
func _shot_door(run: int) -> bool:
	# A plain cut from her eyes, which are on the door, her flashlight on it already (`_scared_turn`); the door's light comes on with it.
	_duck_outside(true)
	var facing: Basis = _door_facing(door_front_wide.global_position)
	_show_camera(Transform3D(facing, door_front_wide.global_position), door_fov)
	_move_camera(Transform3D(facing, door_front_tight.global_position), door_approach_seconds)
	_log(&"door")
	_cut_clock = scene_clock
	if door_lighting != null:
		door_lighting.fade_to(1.0, 0.0)
	_prepare_doorway()

	while not _steps_done and _still(run):
		await get_tree().process_frame
	if not _still(run):
		return false

	await _wait(handle_after_steps_seconds)
	if not _still(run):
		return false
	if not await _handle_attempt(run, attempt_one, 0):
		return false
	await _wait(pause_before_speak_seconds)
	if not _still(run):
		return false

	_log(&"voice")
	_schedule_cue_voices(CaptionTracks.HOUSE_DOOR_THREAT, 1)
	_second_attempt(run)
	await CaptionManager.play_scripted_and_wait(CaptionTracks.HOUSE_DOOR_THREAT)
	if not _still(run):
		return false
	await _wait(unanswered_beat_seconds)
	return _still(run)


## The second try at the handle comes as the voice says to open the door because it must be stuck.
func _second_attempt(run: int) -> void:
	await _wait(second_attempt_after_voice_seconds)
	if _still(run):
		await _handle_attempt(run, attempt_two, 1)


## One try at the handle from the other side: it goes down (`timing.x`), meets the lock and strains there (`timing.y`, a little shudder and one rattle of the
## lock), and comes back up (`timing.z`). The door does not move.
func _handle_attempt(run: int, timing: Vector3, variant: int) -> bool:
	_log(&"handle")
	bedroom_door.play_handle_sound(handle_sound_pitch, variant)
	var press: Tween = _track(create_tween())
	press.tween_method(bedroom_door.set_handle_turn, 0.0, 1.0, timing.x).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await press.finished
	if not _still(run):
		return false

	# It meets the lock; the door is pushed a little (it gives by `door_nudge_degrees` and comes back), the handle held down and shuddering. No sound but the
	# handle's own.
	_log(&"resist")
	var strain: Tween = _track(create_tween())
	strain.tween_method(func(t: float) -> void:
		bedroom_door.set_handle_turn(1.0 - 0.04 * absf(sin(t * PI * 3.0)))
		var push: float = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.7, 1.0, t)) * (0.92 + 0.08 * sin(t * PI * 6.0))
		bedroom_door.ajar_degrees = door_nudge_degrees * push, 0.0, 1.0, timing.y)
	await strain.finished
	bedroom_door.ajar_degrees = 0.0
	if not _still(run):
		return false

	_log(&"release")
	bedroom_door.play_handle_sound(handle_sound_pitch * 0.9, 1 - variant)
	var release: Tween = _track(create_tween())
	release.tween_method(bedroom_door.set_handle_turn, 1.0, 0.0, timing.z).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await release.finished
	return _still(run)


## The wall between the kitchen and the bedroom becomes a doorway, with the door in it (shut), while the camera is on the original door: the doorway is
## far outside its picture (this is checked and logged), and the pictures and the collision change together.
func _prepare_doorway() -> void:
	var camera: Camera3D = _cam
	var seen: bool = false
	if camera != null:
		for corner: Vector3 in _doorway_corners():
			seen = seen or camera.is_position_in_frustum(corner)
	_apply_doorway(true)
	if escape_door != null:
		escape_door.unlock()
		escape_door.close_instantly()
	_log(&"doorway_in_view" if seen else &"doorway_prepared")


## The corners and the middle of the doorway (house local points made world): what the camera must not see when the wall changes.
func _doorway_corners() -> Array[Vector3]:
	var wall_x: float = 3.0 * UnfinishedHouseBuilder.PLAN_SCALE
	var middle: float = UnfinishedHouseBuilder.ESCAPE_DOORWAY_CENTER
	var half: float = UnfinishedHouseBuilder.DOOR_WIDTH * 0.5
	var corners: Array[Vector3] = []
	for along: float in [middle - half, middle, middle + half]:
		for height: float in [0.0, 1.0, UnfinishedHouseBuilder.DOOR_HEIGHT]:
			corners.append(to_global(Vector3(wall_x, height, along)))
	return corners


## The doorway (or the plain wall) and the door in it, kept far under the world while there is none.
func _apply_doorway(on: bool) -> void:
	if shell != null:
		shell.set_escape_doorway(on)
	if escape_door != null:
		escape_door.position.y = _escape_door_home_y if on else -60.0
		escape_door.visible = on


## Where the doorway is, at the height of her eyes (what she looks at to see the new door).
func _doorway_view_point() -> Vector3:
	return to_global(Vector3(3.0 * UnfinishedHouseBuilder.PLAN_SCALE, escape_eye_height, UnfinishedHouseBuilder.ESCAPE_DOORWAY_CENTER))


# ---- The voices (optional recordings) ------------------------------------------------------------------------------

## Starts the recording of each cue of a track (numbers from `first_number`) at its time, if one is assigned; the subtitles never wait for a stream.
func _schedule_cue_voices(track: StringName, first_number: int) -> void:
	var cues: Array = CaptionTracks.get_cues(track)
	for index: int in cues.size():
		_play_cue_voice(first_number + index, float((cues[index] as Dictionary)["start"]), _run)


func _play_cue_voice(number: int, delay: float, run: int) -> void:
	await _wait(delay)
	if not _still(run) or number < 1 or number > cue_voices.size() or cue_voices[number - 1] == null:
		return

	var voice: AudioStreamPlayer3D = _voice_for_cue(number)
	if voice != null:
		voice.stream = cue_voices[number - 1]
		voice.play()


## Cue 1 is Juliana's, at her own head; cue 6 is the shush, at her right ear; the others are beyond the original door.
func _voice_for_cue(number: int) -> AudioStreamPlayer3D:
	if number == 1:
		return _head_voice(&"question", Vector3(0.0, 0.0, -0.1))
	if number == 13:
		return _head_voice(&"shush", shush_ear_offset)
	return door_voice_player


## A voice source on her real head (a child of her camera), made the first time and freed with the scene.
func _head_voice(slot: StringName, offset: Vector3) -> AudioStreamPlayer3D:
	if _head_voices.has(slot) and is_instance_valid(_head_voices[slot]):
		return _head_voices[slot] as AudioStreamPlayer3D

	var camera: Camera3D = _get_camera()
	if camera == null:
		return null

	var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	voice.name = "Voice_%s" % slot
	voice.unit_size = 1.5
	voice.max_distance = 8.0
	camera.add_child(voice)
	voice.position = offset
	_head_voices[slot] = voice
	return voice


func _free_head_voices() -> void:
	for slot: Variant in _head_voices.keys():
		var voice: Variant = _head_voices[slot]
		if voice != null and is_instance_valid(voice):
			(voice as Node).queue_free()
	_head_voices.clear()


## Square on to the shut door from `eye`: looking along the door's normal, towards it.
func _door_facing(eye: Vector3) -> Basis:
	var normal: Vector3 = bedroom_door.global_basis.z
	normal.y = 0.0
	normal = normal.normalized()
	if normal.dot(bedroom_door.global_position - eye) < 0.0:
		normal = -normal
	return Basis.looking_at(normal, Vector3.UP)


## Someone walks along the hallway to the bedroom door, slowly and heavily, louder as they come, and stops outside it; with the
## last steps their the camera is square on to the shut door.
func _walk_to_door(run: int, fit_seconds: float = 0.0) -> void:
	var points: Array[Vector3] = _path_points(footstep_path, step_stride)
	if _step_sound == null:
		_step_sound = _indoor_step()

	# Hurried, if it must be, to end in `fit_seconds` (never past `steps_fastest_scale` of the usual pace).
	var natural: float = 0.0
	for index: int in maxi(points.size() - 1, 0):
		natural += lerpf(step_interval_seconds, step_interval_end_seconds, float(index) / float(maxi(points.size() - 1, 1)))
	var pace: float = clampf(fit_seconds / natural, steps_fastest_scale, 1.0) if fit_seconds > 0.0 and natural > 0.0 else 1.0

	_log(&"steps")
	_steps_done = false
	for index: int in points.size():
		var along: float = float(index) / float(maxi(points.size() - 1, 1))
		var at: Vector3 = to_global(points[index])
		var loudness: float = along
		_play_at(_step_sound, at, lerpf(first_step_db, last_step_db, loudness), randf_range(step_pitch.x, step_pitch.y), step_unit_size, step_max_distance)
		if index == points.size() - 1:
			break

		var interval: float = lerpf(step_interval_seconds, step_interval_end_seconds, along)
		await _wait(interval * pace * randf_range(1.0 - step_unevenness, 1.0 + step_unevenness))
		if not _still(run):
			return
	_log(&"steps_end")
	_steps_end_clock = scene_clock
	_steps_done = true


## The player's own indoor footstep (the default of their `sfx_walk`), for the walker in the hallway.
func _indoor_step() -> AudioStream:
	var body: Node3D = _get_player()
	var audio: Node = body.get("audio_controller") as Node if body != null else null
	if audio != null:
		var step: AudioStream = audio.get("_default_step") as AudioStream
		if step != null:
			return step
		var walk: AudioStreamPlayer = audio.get("sfx_walk") as AudioStreamPlayer
		if walk != null and walk.stream != null:
			return walk.stream
	return PlaceholderAudio.make_footstep()


# ---- The flashlight in the door shot ---------------------------------------------------------------------------------

## The beam starts pointing back at the nightstand, away from the door; `_drive_beam` brings it round to the door.
func _beam_start() -> void:
	if _flashlight == null or not is_instance_valid(_flashlight) or not _flashlight_scripted:
		return

	# She is standing at the nightstand, so the light points back there, away from the door the camera sees.
	_beam_from = postcard.global_position + Vector3(0.0, beam_start_height, 0.0)
	_beam_to = _door_middle() + beam_end_offset
	_beam_time = 0.0
	_beam_on = true
	_flashlight.set("scripted_aim_on", true)
	_flashlight.set("scripted_aim_speed", 2.5)
	_flashlight.set("smoothed_aim_target", _beam_from)
	_flashlight.set("has_smoothed_aim_target", true)
	_drive_beam(0.0)


## Every frame: where the beam points. After `beam_delay_seconds` (a few steps) it travels to the door over `beam_sweep_seconds`, with a
## smooth start and stop, rising on an arc; a little sway and tremble all the while, more while it moves.
func _drive_beam(delta: float) -> void:
	if _flashlight == null or not is_instance_valid(_flashlight):
		_beam_on = false
		return

	_beam_time += delta
	_flicker_flashlight(delta)
	var sweeping: bool = _beam_from.distance_to(_beam_to) > 0.01
	var s: float = clampf((_beam_time - beam_delay_seconds) / maxf(beam_sweep_seconds, 0.01), 0.0, 1.0)
	var eased: float = s * s * s * (s * (s * 6.0 - 15.0) + 10.0)
	var point: Vector3 = _beam_from.lerp(_beam_to, eased)
	if sweeping:
		point += Vector3.UP * sin(PI * eased) * beam_arc
	var t: float = _beam_time
	var moving: float = 1.0 + 1.2 * sin(PI * eased)
	var sway: Vector3 = Vector3(
		sin(t * 1.3) * 0.7 + sin(t * 2.9 + 1.0) * 0.4 + sin(t * 7.1 + 0.4) * 0.12,
		sin(t * 1.7 + 2.0) * 0.5 + sin(t * 3.7 + 0.6) * 0.3 + sin(t * 8.3 + 1.5) * 0.12,
		0.0
	)
	point += sway * beam_sway * moving
	var hand: Vector3 = (_flashlight as Node3D).global_position
	_flashlight.set("scripted_aim_direction", (point - hand).normalized())


## Her flashlight in the door shot: weak, and now and then it stutters (a quick dip, some of it unsteady), as a failing battery does.
func _flicker_flashlight(delta: float) -> void:
	_flicker_wait -= delta
	if _flicker_left <= 0.0 and _flicker_wait <= 0.0:
		_flicker_left = randf_range(flicker_length.x, flicker_length.y)
		_flicker_level = randf_range(flicker_depth.x, flicker_depth.y)
		# Sometimes a second, quicker dip follows at once.
		_flicker_repeat = not _flicker_repeat and randf() < 0.35
		_flicker_wait = randf_range(0.05, 0.18) if _flicker_repeat else randf_range(flicker_every.x, flicker_every.y)
	# Never quite steady: the strength wanders a little by itself.
	_flicker_drift = clampf(_flicker_drift + randf_range(-0.06, 0.06), 0.8, 1.1)
	var factor: float = _flicker_drift
	if _flicker_left > 0.0:
		_flicker_left -= delta
		factor = _flicker_level * randf_range(0.4, 1.6)
	_flash_strength = door_flashlight_strength * clampf(factor, 0.0, 1.0)
	_flash_apply()


func _beam_stop() -> void:
	_beam_on = false
	if _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.set("scripted_aim_on", false)
		_flashlight.set("scripted_aim_speed", 1.0)


## The middle of the bedroom door, at the height of the handle.
func _door_middle() -> Vector3:
	var handle: Vector3 = bedroom_door.get_handle_position_facing(_get_camera().global_position)
	var hinge: Vector3 = bedroom_door.global_position
	return Vector3((hinge.x + handle.x) * 0.5, handle.y + 0.1, (hinge.z + handle.z) * 0.5)


# ---- Back to her eyes ---------------------------------------------------------------------------------------------

## The shush at her right ear, and the hard cut to her own eyes at the bedside (her normal lens, looking at the original door, her flashlight and her view
## together); the turn to the right, to the doorway that was a wall, whose new door is already opening; one look back at the original door (the pleas
## go on); the walk, in her own body, through the doorway into the kitchen; the slam behind her, the lock; a moment in the kitchen, looking down the way to
## the lit rooms. The view is hers again only after all of it (`_play_memory` hands it back).
func _shot_escape(run: int) -> bool:
	var movement: PlayerMovementController = _get_movement()
	var camera: Camera3D = _get_camera()
	if movement == null or camera == null:
		return false

	# Off camera (the picture is still the door camera's): the exits are shut, her view is turned to the original door as the cut will show it.
	_close_exits()
	_duck_outside(false)
	_beam_on = false
	movement.scripted_fov = 0.0
	camera.fov = _base_fov
	_aim_now(_door_middle())
	_flash_strength = escape_flashlight_strength
	_flash_apply()
	await get_tree().physics_frame
	if not _still(run):
		return false

	# The hard cut. The beam follows her view from here on (never a lagging beam that misses what she turns to).
	_pov_follow = true
	_follow_view_with_the_beam()
	_show_eyes()
	_log(&"cut_to_eyes")
	if door_lighting != null:
		door_lighting.fade_to(0.0, 0.4)
	CaptionManager.clear()
	await _wait(pov_beat_seconds)
	if not _still(run):
		return false

	# Then the shush, at her right ear; she turns to the right, to the new door, which is opening (it began out of her sight): her light goes over the
	# opening and on past it, drifting; and only then, with a start, does she see it and come back to it.
	_log(&"shush")
	_start_tension()
	_schedule_cue_voices(CaptionTracks.HOUSE_DOOR_SHUSH, 13)
	CaptionManager.play_scripted(CaptionTracks.HOUSE_DOOR_SHUSH)
	_set_kitchen_light(kitchen_light_energy, kitchen_light_fade_in_seconds)
	_open_escape_door()
	_log(&"turn_right")
	var doorway: Vector2 = _look_angles(_doorway_view_point())
	var side: float = signf(wrapf(doorway.x - _get_movement().look_yaw, -180.0, 180.0))
	if side == 0.0:
		side = 1.0
	var past: Vector2 = Vector2(doorway.x + side * pass_overshoot_degrees, doorway.y + 1.0)
	_turn_view(past, turn_right_seconds, Tween.TRANS_QUART, Tween.EASE_OUT)
	await _wait(turn_right_seconds)
	if not _still(run):
		return false
	_log(&"passed")
	_turn_view(Vector2(past.x + side * 7.0, past.y), pass_drift_seconds, Tween.TRANS_SINE, Tween.EASE_OUT)
	await _wait(pass_drift_seconds)
	if not _still(run):
		return false
	_log(&"realized")
	_turn_view(doorway, realize_seconds, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	await _wait(realize_seconds)
	if not _still(run):
		return false
	_log(&"noticed")
	await _wait(reveal_hold_seconds)
	if not _still(run):
		return false

	# One look back at the original door: she stays there, unsure, for `glance_wait_seconds` in silence; Sophia begins to speak again beyond it, and with that voice
	# behind the door she wants to be away from it: she turns to the passage and goes.
	_log(&"look_back")
	_turn_view(_look_angles(_door_middle()), glance_seconds)
	await _wait(glance_seconds + glance_wait_seconds)
	if not _still(run):
		return false
	_log(&"sophia_speaks_again")
	_schedule_cue_voices(CaptionTracks.HOUSE_DOOR_COLD, 14)
	CaptionManager.play_scripted(CaptionTracks.HOUSE_DOOR_COLD)
	await _wait(glance_hold_seconds)
	if not _still(run):
		return false
	_turn_view(_look_angles(_doorway_view_point()), turn_back_seconds)
	await _wait(turn_back_seconds)
	if not _still(run):
		return false

	_log(&"go")
	# The living room's light starts to come up as she starts to walk (it used to come on at the slam).
	if not _capsule_open():
		_set_living_light(true, living_light_walk_fade_seconds)
	_schedule_cue_voices(CaptionTracks.HOUSE_DOOR_HELP, 16)
	CaptionManager.play_scripted(CaptionTracks.HOUSE_DOOR_HELP)
	if not await _escape_walk(run):
		# She could not be walked (nothing cancelled the scene): the scene is cancelled here, not left holding the player. The postcard offers it again, the doorway
		# stays open as an ordinary door, and nothing was locked or recorded.
		if _still(run):
			_cancel_memory()
		return false

	# In the kitchen, her view settling on the way to the lit rooms.
	_log(&"arrived")
	_turn_view(_look_angles(to_global(escape_final_look)), 0.5)
	await _wait(maxf(settle_seconds, 0.5))
	if not _still(run):
		return false
	# (The light is dead before the view is hers: the death can take longer than the walk's last steps.)
	while _flash_failing and _still(run):
		await get_tree().physics_frame
	if not _still(run):
		return false
	_log(&"glance_end")
	return true


## Her own body goes through the passage: a chain of guided walks (the game's ordinary walk, footsteps and all, driven by the scene instead of the keys)
## that carries on through every point but the last without slowing, so there is no stop at the doorway. The mouse and the keys are the scene's meanwhile.
## The door slams when all of her is in the kitchen. False if she cannot be walked (the scene is then cancelled and the player given back, where they are).
func _escape_walk(run: int) -> bool:
	var target: Node3D = _get_player()
	var movement: PlayerMovementController = _get_movement()
	if target == null or movement == null or escape_path.is_empty():
		return false

	# The held view does not walk: it is let go for the walk, and held again after it (saving stays blocked all the time).
	target.call("set_view_locked", false)
	_walking = true
	_show_reticle(false)
	var slammed: bool = false
	var walk_clock: float = 0.0
	var glancing: bool = true
	_log(&"glance_over_shoulder")
	for index: int in escape_path.size():
		var last: bool = index == escape_path.size() - 1
		var stand: Vector3 = to_global(escape_path[index])
		stand.y = target.global_position.y
		var ahead: Vector3 = to_global(escape_final_look) if last else to_global(Vector3(escape_path[index + 1].x, escape_eye_height, escape_path[index + 1].z))
		var share: float = escape_speeds[index] if index < escape_speeds.size() else 1.0
		var speed: float = PlayerMovementController.WALK_SPEED * share
		# Looking back at the original door (the walk goes on, slower) until the open one is about to be in the way, then ahead.
		glancing = glancing and not _looking_back_is_over(walk_clock, _path_ahead(index, target.global_position))
		var tries: int = 0
		while not movement.begin_guided_walk(stand, _door_middle() if glancing else ahead, speed * (escape_look_back_pace if glancing else 1.0), escape_walk_timeout_seconds):
			tries += 1
			await get_tree().physics_frame
			if tries > 40 or not _still(run):
				_walking = false
				return false

		while movement.is_guided_walking():
			await get_tree().physics_frame
			if not _still(run):
				_walking = false
				return false
			walk_clock += get_physics_process_delta_time()
			if not slammed and _body_clear_of_door():
				slammed = true
				_slam_and_lock(run)
			var flat: Vector3 = target.global_position - stand
			flat.y = 0.0
			if not last and flat.length() < escape_pass_radius:
				break
			if glancing and _looking_back_is_over(walk_clock, _path_ahead(index, target.global_position)):
				glancing = false
				_log(&"glance_over")
				movement.begin_guided_walk(stand, ahead, speed, escape_walk_timeout_seconds)

	_walking = false
	_show_reticle(true)
	if not slammed:
		slammed = true
		_slam_and_lock(run)
	target.call("set_view_locked", true)
	return _still(run)


## She has looked back long enough: the open leaf is about to come between her eyes and the original door (a ray from her eyes to it meets the new door's
## leaf), or she is at the doorway, or it has been long enough.
func _looking_back_is_over(walk_clock: float, ahead: Vector3) -> bool:
	var target: Node3D = _get_player()
	var camera: Camera3D = _get_camera()
	if target == null or camera == null or walk_clock >= escape_look_back_max_seconds - escape_look_back_lead_seconds:
		return true
	if to_local(ahead).x <= escape_look_back_until_x:
		return true

	# The leaf's check is made from where her eyes will be `escape_look_back_lead_seconds` on.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position + (ahead - target.global_position), _door_middle())
	query.exclude = [target.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and escape_door != null and escape_door.is_ancestor_of(hit["collider"] as Node)


## Where she will stand `escape_look_back_lead_seconds` from now if she goes on along the path from leg `from_leg` at the pace she looks back at: leg by leg,
## each at its own share of the walk speed (the end of the path if it is shorter).
func _path_ahead(from_leg: int, from: Vector3) -> Vector3:
	var point: Vector3 = from
	var left: float = escape_look_back_lead_seconds
	for leg: int in range(from_leg, escape_path.size()):
		var stand: Vector3 = to_global(escape_path[leg])
		stand.y = point.y
		var share: float = escape_speeds[leg] if leg < escape_speeds.size() else 1.0
		var speed: float = maxf(PlayerMovementController.WALK_SPEED * share * escape_look_back_pace, 0.05)
		var seconds: float = point.distance_to(stand) / speed
		if seconds >= left:
			return point.move_toward(stand, speed * left)

		left -= seconds
		point = stand

	return point


## All of her (her body's width and a margin) is west of the wall's face: the leaf, which swings in the bedroom, cannot touch her.
func _body_clear_of_door() -> bool:
	var target: Node3D = _get_player()
	return target != null and to_local(target.global_position).x < escape_clear_x


## The new door opens, slowly, to `escape_door_open_degrees` (into the bedroom, so that the leaf is never in her way), and is then an ordinary open door.
func _open_escape_door() -> void:
	if escape_door == null:
		return

	escape_door.unlock()
	_log(&"escape_door_opening")
	var open: Tween = _track(create_tween())
	# A shove and then nothing: the leaf is thrown open and coasts, slowing all the way, creeping the last of its way.
	open.tween_property(escape_door, "ajar_degrees", escape_door_open_degrees, escape_door_open_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	open.tween_callback(func() -> void:
		escape_door.ajar_degrees = 0.0
		escape_door.force_open(0.0, escape_door_open_degrees)
		_log(&"escape_door_open")
	)


## The slam, only once she is clear: the door swings shut fast and hard, the pleas stop where they are, the two outside exits are locked, the door itself
## locks as it meets the frame; the living room's light comes up (the way on).
func _slam_and_lock(run: int) -> void:
	if escape_door == null:
		return

	_log(&"slam")
	if door_voice_player != null:
		door_voice_player.stop()
	CaptionManager.clear()
	escape_door.slam_shut(slam_speed)
	_lock_exits()
	if _living_light_on == _capsule_open():
		_set_living_light(not _capsule_open(), living_light_fade_seconds)
	_fail_flashlight(run)
	# The kitchen's light, which called her through, eases down to what it stays at.
	_set_kitchen_light(kitchen_light_energy * kitchen_light_after, kitchen_light_settle_seconds)
	var thud_played: bool = false
	var waited: float = 0.0
	while waited < 2.5 and _still(run):
		var offset: float = _door_offset_degrees(escape_door)
		if not thud_played and offset < 12.0:
			thud_played = true
			_play_at(PlaceholderAudio.make_door_thud(), escape_door.global_position + Vector3(0.0, 1.0, 0.5), 4.0, 0.85, 6.0, 40.0)
		if offset < 1.0 and not escape_door.is_open:
			break
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()

	if not thud_played:
		_play_at(PlaceholderAudio.make_door_thud(), escape_door.global_position + Vector3(0.0, 1.0, 0.5), 4.0, 0.85, 6.0, 40.0)
	_play_at(PlaceholderAudio.make_door_latch_close(), escape_door.global_position + Vector3(0.0, 1.0, 0.5), -2.0, 0.9, 6.0, 30.0)
	escape_door.lock()
	_log(&"escape_door_locked")


## The string tension comes in with the shush and stays until the controls are back.
func _start_tension() -> void:
	_stop_tension(0.0)
	_tension = AudioStreamPlayer.new()
	_tension.name = "Tension"
	_tension.stream = load(TENSION_PATH) as AudioStream
	_tension.volume_db = -60.0
	add_child(_tension)
	_tension.play()
	create_tween().tween_property(_tension, "volume_db", tension_db, tension_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _stop_tension(seconds: float) -> void:
	if _tension == null or not is_instance_valid(_tension):
		return

	var player: AudioStreamPlayer = _tension
	_tension = null
	if seconds <= 0.0 or not player.playing:
		player.queue_free()
		return

	var fall: Tween = create_tween()
	fall.tween_property(player, "volume_db", -60.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_callback(player.queue_free)


## Her flashlight flickers and dies, as she is in the kitchen (the scene's light first, and then the player's own, which stays broken: see `_release_player`).
func _fail_flashlight(run: int) -> void:
	if _flash_failing or _flash_failed or _flashlight == null or not _flashlight_scripted:
		return

	_flash_failing = true
	_log(&"flashlight_failing")
	for step: Vector2 in flashlight_death:
		_flash_strength = escape_flashlight_strength * step.x
		_flash_apply()
		await _wait(step.y)
		if not _still(run):
			break

	_flash_failed = true
	_flash_failing = false
	_flash_apply()


## Her view at once to look at `point` (the controller's own yaw and pitch, so that the mouse never snaps back to an older orientation).
func _aim_now(point: Vector3) -> void:
	var movement: PlayerMovementController = _get_movement()
	var angles: Vector2 = _look_angles(point)
	movement.look_yaw = movement.look_yaw + wrapf(angles.x - movement.look_yaw, -180.0, 180.0)
	movement.look_pitch = angles.y


## The kitchen's light (the escape's destination), faded to `energy` over `seconds`.
func _set_kitchen_light(energy: float, seconds: float) -> void:
	if kitchen_light == null or not is_instance_valid(kitchen_light):
		return

	if _kitchen_fade != null and _kitchen_fade.is_valid():
		_kitchen_fade.kill()
	kitchen_light.visible = energy > 0.0
	if seconds <= 0.0:
		kitchen_light.light_energy = energy
		return

	_kitchen_fade = _track(create_tween())
	_kitchen_fade.tween_property(kitchen_light, "light_energy", energy, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---- The exits, the escape's outcome, the watcher --------------------------------------------------------------------

## The two outside exits shut (at once, with no sound) when they were left open, for the scene to lock them while nobody is looking at them.
func _close_exits() -> void:
	for door: DoorController in [back_door, front_door]:
		if door != null and (door.is_open or door.is_busy()):
			door.close_instantly()


## The back and front doors locked, for as long as Lucas's token is not taken: not when it already is (an owned, collected or inserted token never re-locks).
func _lock_exits() -> void:
	if _token_owned():
		return

	for door: DoorController in [back_door, front_door]:
		if door != null:
			door.lock()
	_exits_locked = true
	_set_flag(KEY_EXITS_LOCKED, true)


## Both exits usable again (idempotent).
func _release_exits() -> void:
	for door: DoorController in [back_door, front_door]:
		if door != null and door.is_locked:
			door.unlock()
	_exits_locked = false
	_set_flag(KEY_EXITS_LOCKED, false)


## Lucas's token is in the player's hands, or was (collected: the pickup records it before anything is shown), or is in the payphone.
func _token_owned() -> bool:
	if bool(SaveManager.get_state_value(&"collectibles", ficha_id, false)):
		return true

	var target: Node = _get_player()
	if target != null and target.has_method("has_inventory_item") and bool(target.call("has_inventory_item", String(ficha_id))):
		return true

	var inserted: Variant = SaveManager.get_state_value(STATE_SECTION, &"orelhao_fichas", [])
	return inserted is Array and (inserted as Array).has(String(ficha_id))


## What the escape leaves behind, before the player can save again: the doorway for good, its door shut and locked, the exits locked (until the token),
## the kitchen's light low, the watcher waiting.
func _complete_escape_state() -> void:
	_escape_done = true
	_set_flag(KEY_ESCAPE_DONE, true)
	_apply_doorway(true)
	if escape_door != null:
		escape_door.ajar_degrees = 0.0
		if not escape_door.is_locked:
			escape_door.close_instantly()
			escape_door.lock()
	# (Left to finish if it is still easing down: setting it here would jump.)
	if _kitchen_fade == null or not _kitchen_fade.is_valid() or not _kitchen_fade.is_running():
		_set_kitchen_light(kitchen_light_energy * kitchen_light_after, 0.0)
	_lock_exits()
	# The pantry: its door open and its bulb on again (the paper had them shut and out), done where she cannot see: she is in the kitchen.
	if pantry_door != null and not _watcher_done:
		pantry_door.unlock()
		pantry_door.force_open(0.0, pantry_ajar_degrees)
	_set_pantry_lamp(not _watcher_done, false)


## The black head looks round the pantry door's frame (from the end of the scene, once the controls are back, until the player's view finds it).
func _arm_watcher() -> void:
	if watcher == null or _watcher_done or not _escape_done:
		return

	_watcher_clock = 0.0
	watcher.peek()


func _update_watcher(delta: float) -> void:
	if watcher == null or not watcher.is_peeking or _watcher_done or memory_running or not _escape_done:
		return

	_watcher_clock += delta
	if _watcher_clock < watcher_arm_delay_seconds:
		return

	var target: Node3D = _get_player()
	var camera: Camera3D = _get_camera()
	if target == null or camera == null:
		return

	# Not while the view is anyone else's: a panel, the inventory, a held view, an inspected thing.
	if bool(target.get("view_locked")) or bool(target.get("modal_ui_open")) or bool(target.get("cutscene_frozen")) or bool(target.get("dialogue_frozen")):
		return
	if bool(target.call("is_inventory_open")):
		return

	# Only a light, or her eyes while the flashlight is broken, find it: the shadow waits, in the lit pantry, for as long as the flashlight is off.
	var light: Node = target.get("flashlight_controller") as Node
	if light == null or not (bool(light.get("flashlight_on")) or bool(light.get("failed"))):
		return

	if not WATCHER_AREA.has_point(to_local(target.global_position)):
		return

	var head: Vector3 = watcher.head_point()
	var way: Vector3 = head - camera.global_position
	if way.length() > watcher_range or way.length() < 0.5:
		return
	if (-camera.global_basis.z).dot(way.normalized()) < cos(deg_to_rad(watcher_look_degrees)):
		return

	# With nothing between her eyes and the head (the head itself has no collision).
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, head)
	query.exclude = [target.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(head) > 0.45:
		return

	_consume_watcher()


## Found by the light: the head goes back into the room and the pantry's lamp goes out with it, together, over `watcher_retreat_seconds`; it will not look again (saved).
func _consume_watcher() -> void:
	_watcher_done = true
	_set_flag(KEY_WATCHER_DONE, true)
	_log(&"watcher_noticed")
	var seconds: float = watcher.retreat(watcher_retreat_seconds)
	_fade_pantry_lamp_out(maxf(seconds, 0.2))


func _fade_pantry_lamp_out(seconds: float) -> void:
	var glass: StandardMaterial3D = _bulb_material()
	var fade: Tween = _track(create_tween())
	fade.set_parallel(true)
	if pantry_light != null:
		fade.tween_property(pantry_light, "light_energy", 0.0, seconds)
	if glass != null:
		fade.tween_property(glass, "emission_energy_multiplier", 0.0, seconds)
	fade.chain().tween_callback(func() -> void: _set_pantry_lamp(false, false))


## Whether the pantry's bulb is on in a game as the story left it: lit from the recipe on; after the old scene it was out; after the new one it stays on until the
## watcher has been noticed.
func _pantry_lamp_wanted() -> bool:
	if not _recipe_done:
		return false
	if _escape_done:
		return not _watcher_done
	return not _memory_done


## The marks of the things she could use (and the dot) hidden while she is walked by the scene, and back after.
func _show_reticle(on: bool) -> void:
	var target: Node3D = _get_player()
	var interaction: Object = target.get("interaction_controller") as Object if target != null else null
	var reticle: Control = interaction.get("reticle") as Control if interaction != null else null
	if reticle != null and is_instance_valid(reticle):
		reticle.visible = on


## Every physics frame while she is walked: nothing else can be done with the hands (no prompt, no inventory, no map).
func _hold_the_walker() -> void:
	var target: Node3D = _get_player()
	if target == null:
		return

	var interaction: Object = target.get("interaction_controller") as Object
	if interaction != null:
		interaction.call("clear_prompt")
	var map: Object = target.get("map_controller") as Object
	if map != null and bool(map.get("is_open")):
		map.call("close")


## Her flashlight points where her view does, every frame (and follows it fast), so that the beam is on whatever she turns to.
func _follow_view_with_the_beam() -> void:
	var camera: Camera3D = _get_camera()
	if camera == null or _flashlight == null or not is_instance_valid(_flashlight) or not _flashlight_scripted:
		return

	_flashlight.set("scripted_aim_on", true)
	_flashlight.set("scripted_aim_speed", 14.0)
	_flashlight.set("scripted_aim_direction", -camera.global_basis.z)


## The door put back shut when none of it can be seen from her eyes (`now`: at once, whatever is seen).
func _settle_pending(now: bool) -> void:
	if _door_reset_pending:
		var touched: bool = bedroom_door != null and (bedroom_door.is_open or bedroom_door.is_busy())
		if now or touched or not _door_in_view():
			_door_reset_pending = false
			if touched:
				bedroom_door.ajar_degrees = 0.0
				bedroom_door.set_handle_turn(0.0)
			else:
				_reset_bedroom_door()
			_log(&"door_reset")


## True while any corner of the bedroom door's leaf, or of its doorway, is in the player's view.
func _door_in_view() -> bool:
	var camera: Camera3D = _get_camera()
	if camera == null or bedroom_door == null:
		return false

	var corners: Array[Vector3] = []
	for along: float in [0.0, 0.45, 0.9]:
		for height: float in [0.0, 1.0, 2.0]:
			corners.append(bedroom_door.to_global(Vector3(along, height, 0.0)))
			corners.append(bedroom_door.door_root.to_global(Vector3(along - 0.45, height - 1.0, 0.0)))
	for corner: Vector3 in corners:
		if camera.is_position_in_frustum(corner):
			return true

	return false


func _reset_bedroom_door() -> void:
	if bedroom_door != null:
		bedroom_door.close_instantly()


## The outside pushed back while the steps and the door play (so the steps are not lost under the wind), and let back.
func _duck_outside(on: bool) -> void:
	if on == _ducking or not is_inside_tree():
		return

	_ducking = on
	get_tree().call_group(OutdoorAmbience.GROUP, "set_muffle", &"house_footsteps", footsteps_duck if on else 0.0)


# ---- The scene's outcome ------------------------------------------------------------------------------------------

## The scene's outcome, whether it played or was skipped: done for good, the capsule unlocked, and the postcard is only a
## postcard again.
func _finish_memory_state() -> void:
	_memory_done = true
	_set_flag(KEY_MEMORY_DONE, true)
	_set_room(false)
	_unlock_capsule()
	_set_living_light(not _capsule_open(), 0.0)
	if postcard != null:
		postcard.plays_scene = false


## For the developer console and the tests: whatever the house is doing, the bedroom scene is over at once (the player is
## let go, the capsule unlocked), and the pantry and the bedroom are open to them.
func force_finish_memory() -> void:
	_cancel_memory()
	_settle_pending(true)
	if not _recipe_done:
		_recipe_done = true
		_set_flag(KEY_RECIPE_DONE, true)
		_set_pantry_lamp(true, false)
	for door: DoorController in [pantry_door, bedroom_door]:
		if door != null and door.is_locked:
			door.unlock()
	_finish_memory_state()


## Stops a scene that is playing and gives everything back (the cameras, the player, the postcard, the door, the room). Not
## done: the postcard can be read to play it from the start.
func _cancel_memory() -> void:
	if not memory_running:
		return

	_run += 1
	memory_running = false
	_walking = false
	_stop_tension(0.0)
	var mover: PlayerMovementController = _get_movement()
	if mover != null:
		mover.cancel_guided_walk()
	if door_voice_player != null:
		door_voice_player.stop()
	# A passage that was made and not finished stays open (an ordinary, unlocked door) rather than closing on whoever is in it.
	if not _escape_done and shell != null and shell.escape_doorway_open and escape_door != null:
		escape_door.ajar_degrees = 0.0
		escape_door.close_instantly()
		escape_door.unlock()
	if _approaching:
		_approaching = false
		var walker: PlayerMovementController = _get_movement()
		if walker != null:
			walker.cancel_guided_walk()
		if _get_player() != null:
			_get_player().call("set_manual_save_blocked", _approach_save_block)
	_bow = 0.0
	_beam_stop()
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()

	_clear_freeze()
	_drop_held_card()
	if memory_voice_player != null:
		memory_voice_player.stop()
	if is_inside_tree():
		CaptionManager.clear()
	_duck_outside(false)
	_set_reading(false, 0.0)
	_flash_strength = 1.0
	if door_lighting != null:
		door_lighting.fade_to(0.0, 0.0)
	_set_room(false)
	_door_reset_pending = false
	if bedroom_door != null:
		bedroom_door.ajar_degrees = 0.0
		bedroom_door.set_handle_turn(0.0)
	_unlock_capsule()
	if postcard != null:
		postcard.plays_scene = not _memory_done
	_release_player()


func _still(run: int) -> bool:
	return memory_running and run == _run and is_inside_tree()


## The room as the memory has it (the dressing and the lamp, the notebook gone, the flashlight out), or the night (the
## flashlight back). Changed all at once: only ever while a dissolve covers it, or with the room out of the shot.
func _set_room(memory: bool) -> void:
	in_memory = memory
	# The memory is not the night: the wind and the night chorus are gone while it lasts (they come back with the cold room).
	if is_inside_tree():
		get_tree().call_group(OutdoorAmbience.GROUP, "set_silenced", &"house_memory", memory)
	if memory_root != null:
		memory_root.visible = memory
	if memory_light != null:
		memory_light.light_energy = memory_light_energy if memory else 0.0
	for node: Node3D in night_only:
		if node != null and is_instance_valid(node):
			node.visible = not memory
	# What is only in the memory (the bed, the bedding, the lamp) is not solid in the night either.
	if memory_root != null:
		for shape: Node in memory_root.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).set_deferred("disabled", not memory)
	_flash_apply()


## Her flashlight as the scene wants it: on in the night (at `_flash_strength`), out in the memory and while the postcard is read.
func _flash_apply() -> void:
	if _flashlight_scripted and _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.call("set_scripted_light", _flashlight_available and not in_memory and not _reading and not _flash_failed, _flash_strength)


## The postcard is read (or not): her flashlight goes out and the card's own light fades in over `seconds`, or the reverse.
func _set_reading(on: bool, seconds: float) -> void:
	_reading = on
	if on and _read_light == null:
		_read_light = SpotLight3D.new()
		_read_light.name = "ReadLight"
		_read_light.light_color = read_light_color
		_read_light.spot_range = read_light_range
		_read_light.spot_angle = read_light_angle
		_read_light.spot_attenuation = 0.65
		_read_light.spot_angle_attenuation = 0.8
		_read_light.light_specular = 0.45
		_read_light.light_indirect_energy = 0.0
		# Only what is on the inspect layer (the card in her hands) is lit, as in the inspect view; not the walls.
		_read_light.light_cull_mask = 1 << (INSPECT_LAYER_NUMBER - 1)
		_read_light.shadow_enabled = false
		_read_light.visible = false
		add_child(_read_light)
	_flash_apply()
	if on:
		_read_level = 0.0
		if seconds > 0.0:
			_tween_held(&"_read_level", 1.0, seconds, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		else:
			_read_level = 1.0
	else:
		_read_level = 0.0
		if _read_light != null:
			_read_light.visible = false


## The card's light: the inspect view's lamp, at her eye, pointing where she looks.
func _place_read_light(eye: Transform3D, _card_at: Vector3) -> void:
	if _read_light == null:
		return

	_read_light.visible = _reading and _read_level > 0.01
	_read_light.light_energy = read_light_energy * clampf(_read_level, 0.0, 1.0)
	_read_light.global_transform = Transform3D(eye.basis, eye.origin + eye.basis * read_light_offset)


## The living room's light, on or off (fading over `seconds`): the capsule's room.
func _set_living_light(on: bool, seconds: float) -> void:
	_living_light_on = on
	if living_light == null or not is_instance_valid(living_light):
		return

	var target: float = living_light_energy if on else 0.0
	if seconds <= 0.0:
		_apply_living_light(target)
		living_light.visible = on
		return

	if on:
		living_light.visible = true
	var fade: Tween = _track(create_tween())
	fade.tween_method(_apply_living_light, living_light.light_energy, target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not on:
		fade.tween_callback(func() -> void: living_light.visible = false)


## The living room's light at `energy`, its lamp's globe glowing with it.
func _apply_living_light(energy: float) -> void:
	if living_light == null or not is_instance_valid(living_light):
		return

	living_light.light_energy = energy
	var glass: StandardMaterial3D = _bulb_material(living_lamp)
	if glass != null:
		glass.emission_energy_multiplier = living_lamp_glow * energy / maxf(living_light_energy, 0.001)


func _on_capsule_opened() -> void:
	_set_living_light(false, living_light_fade_seconds)


## Once the bedroom scene is done the capsule opens to the player, with no key.
func _unlock_capsule() -> void:
	if capsule != null and is_instance_valid(capsule):
		capsule.story_unlocked = _memory_done


func _capsule_open() -> bool:
	if capsule != null:
		return capsule.is_open

	return bool(SaveManager.get_state_value(STATE_SECTION, &"time_capsule_open", false))


# ============================================================
# THE PLAYER, HELD
# ============================================================

## The player is held as a scene holds them: no walking, looking, interacting or saving, and the flashlight is the scene's
## (on while the room is the night, out in the memory). Their body's own motion is stilled for the shots through their eyes.
## What another system had set is remembered and put back.
func _hold_player(target: Node) -> void:
	_held = target
	_held_view_locked = bool(target.get("view_locked"))
	_held_scripted_flashlight = bool(target.get("scripted_flashlight"))
	_held_save_block = bool(target.get("manual_save_blocked"))
	target.set("scripted_flashlight", true)
	target.call("set_view_locked", true)
	target.call("set_manual_save_blocked", true)

	var movement: PlayerMovementController = _get_movement()
	_held_motion_still = movement.view_motion_still
	movement.view_motion_still = true
	_held_gesture_direct = movement.gesture_direct
	_bow = 0.0

	_flashlight = target.get("flashlight_controller") as Node
	_flashlight_scripted = false
	_flashlight_available = false
	_flash_failed = false
	_flash_failing = false
	if _flashlight != null and bool(_flashlight.get("failed")):
		# A scene played again on a game whose flashlight is broken: it works for the scene (it is broken again when the scene lets go, if it still should be).
		_flashlight.call("set_failed", false)
	if _flashlight != null and _flashlight.has_method("begin_scripted_light"):
		# She has the flashlight (and may use it): it lights the night shots, whatever its switch was.
		_flashlight_available = bool(_flashlight.get("flashlight_input_enabled")) and bool(_flashlight.call("_player_has_flashlight"))
		_flashlight.call("begin_scripted_light")
		_flashlight_scripted = true
		_flash_apply()


## Gives the player back: their own eyes (the view already where the scene left it, so the first mouse movement turns from
## there), their flashlight (left on if it lit the scene), and whatever was held before.
func _release_player() -> void:
	_pov_follow = false
	_walking = false
	_show_reticle(true)
	_free_head_voices()
	_clear_freeze()
	_cam = null
	_bow = 0.0
	_beam_stop()
	var movement: PlayerMovementController = _get_movement()
	if movement != null and movement.camera != null and movement.camera.is_inside_tree():
		movement.camera.make_current()
		movement.scripted_fov = 0.0
		movement.gesture_offset = Vector3.ZERO
		movement.gesture_pitch_degrees = 0.0
		movement.gesture_direct = _held_gesture_direct
		movement.view_motion_still = _held_motion_still
	_free_cinema_camera()

	if _flashlight_scripted and _flashlight != null and is_instance_valid(_flashlight):
		if _flashlight_available:
			_flashlight.set("flashlight_on", true)
		if _flash_failed:
			_flashlight.call("set_failed", true)
		_flashlight.call("end_scripted_light")
	_flashlight_scripted = false

	if _held == null or not is_instance_valid(_held):
		_held = null
		return

	_held.call("set_view_locked", _held_view_locked)
	_held.set("scripted_flashlight", _held_scripted_flashlight)
	_held.call("set_manual_save_blocked", _held_save_block)
	_held = null


## Juliana's view turns to look at `point` over `seconds` (0: at once), eased in and out: her own, authored head turn, on the
## same physics step the player's look is applied on.
func _look_at_point(point: Vector3, seconds: float) -> void:
	_turn_view(_look_angles(point), seconds)


func _turn_view(angles: Vector2, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_kind: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var movement: PlayerMovementController = _get_movement()
	if movement == null:
		return

	var from: Vector2 = Vector2(movement.look_yaw, movement.look_pitch)
	var to: Vector2 = Vector2(from.x + wrapf(angles.x - from.x, -180.0, 180.0), clampf(angles.y, -35.0, 75.0))
	if seconds <= 0.0:
		movement.look_yaw = to.x
		movement.look_pitch = to.y
		return

	var turn: Tween = _track(create_tween())
	turn.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	turn.tween_method(
		func(value: Vector2) -> void:
			movement.look_yaw = value.x
			movement.look_pitch = value.y,
		from, to, seconds
	).set_trans(trans).set_ease(ease_kind)


## Yaw and pitch (the movement controller's degrees) that look from the player's eye at `point`.
func _look_angles(point: Vector3) -> Vector2:
	var movement: PlayerMovementController = _get_movement()
	var body: Node3D = _get_player()
	var eye: Vector3 = movement.camera.global_position
	var d: Vector3 = body.global_basis.inverse() * (point - eye)
	var yaw: float = rad_to_deg(atan2(d.x, -d.z))
	var pitch: float = clampf(rad_to_deg(atan2(-d.y, Vector2(d.x, d.z).length())), -35.0, 75.0)
	return Vector2(yaw, pitch)


# ---- The cameras ---------------------------------------------------------------------------------------------------

## Cuts to the scene's camera, at `at` with field of view `fov`, standing still.
func _show_camera(at: Transform3D, fov: float) -> void:
	var camera: Camera3D = _cinema_camera()
	_cam = camera
	_move_from = at
	_move_to = at
	_move_t = 1.0
	_move_seconds = 0.0
	_lens_from = fov
	_lens_to = fov
	_lens_t = 1.0
	_lens_seconds = 0.0
	camera.global_transform = at
	camera.fov = fov
	camera.make_current()


## The scene's camera, made the first time: the player's lens settings (exposure included), without their depth of field
## (it follows what the player aims at), and a near plane close enough for things held in the hands.
func _cinema_camera() -> Camera3D:
	if _cinema != null and is_instance_valid(_cinema):
		return _cinema

	_cinema = Camera3D.new()
	_cinema.name = "CinemaCamera"
	var eyes: Camera3D = _get_camera()
	if eyes != null:
		_cinema.cull_mask = eyes.cull_mask
		_cinema.far = eyes.far
		_cinema.keep_aspect = eyes.keep_aspect
		_cinema.environment = eyes.environment
		_cinema.compositor = eyes.compositor
		if eyes.attributes != null:
			var lens: CameraAttributes = eyes.attributes.duplicate() as CameraAttributes
			if lens is CameraAttributesPractical:
				(lens as CameraAttributesPractical).dof_blur_far_enabled = false
				(lens as CameraAttributesPractical).dof_blur_near_enabled = false
			_cinema.attributes = lens
	_cinema.near = 0.02
	add_child(_cinema)
	return _cinema


func _free_cinema_camera() -> void:
	if _cinema != null and is_instance_valid(_cinema):
		_cinema.queue_free()
	_cinema = null


## Cuts to Juliana's own eyes (where her look already is; her body still).
func _show_eyes() -> void:
	_cam = null
	var camera: Camera3D = _get_camera()
	if camera != null:
		camera.make_current()


## The shot moves from where it is now to `to` over `seconds`, eased in and out.
func _move_camera(to: Transform3D, seconds: float) -> void:
	_move_from = _shot_between(_move_from, _move_to, _ease(_move_t))
	_move_to = to
	_move_t = 0.0
	_move_seconds = maxf(seconds, 0.001)


func _change_lens(fov: float, seconds: float) -> void:
	_lens_from = lerpf(_lens_from, _lens_to, _ease(_lens_t))
	_lens_to = fov
	_lens_t = 0.0
	_lens_seconds = maxf(seconds, 0.001)


## Every frame: the one writer of the scene's camera, its move and its lens.
func _drive_camera(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return

	_move_t = minf(_move_t + delta / maxf(_move_seconds, 0.001), 1.0)
	_lens_t = minf(_lens_t + delta / maxf(_lens_seconds, 0.001), 1.0)
	_cam.global_transform = _shot_between(_move_from, _move_to, _ease(_move_t))
	_cam.fov = lerpf(_lens_from, _lens_to, _ease(_lens_t))
	_focus_on_the_card()


## In the flashback (and only there: the door shots of the night have none) the scene's camera is focused on the postcard on the nightstand, close to the lens: the card
## is sharp and the lamp behind it and the bed are soft.
func _focus_on_the_card() -> void:
	var card: Node3D = null
	if in_memory:
		if held_card != null and is_instance_valid(held_card) and held_card.visible:
			card = held_card
		elif postcard != null and is_instance_valid(postcard) and postcard.visible:
			card = postcard
	if card == null:
		FocusBlur.clear(_cam)
		return

	var distance: float = _cam.global_position.distance_to(card.global_position)
	FocusBlur.focus_on(_cam, distance, 1.0, memory_blur_amount, memory_blur_depth, memory_blur_falloff)


func _ease(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


## A camera `weight` of the way from one transform to another: the position along the straight line, the aim turned by its
## heading and its tilt (never rolling, which turning the whole orientation the shortest way would do part way).
func _shot_between(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	if weight >= 1.0:
		return to

	var a: Vector3 = -from.basis.z.normalized()
	var b: Vector3 = -to.basis.z.normalized()
	var yaw_a: float = atan2(-a.x, -a.z)
	var yaw: float = yaw_a + angle_difference(yaw_a, atan2(-b.x, -b.z)) * weight
	var pitch: float = lerpf(asin(clampf(a.y, -1.0, 1.0)), asin(clampf(b.y, -1.0, 1.0)), weight)
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), from.origin.lerp(to.origin, weight))


## The matched dissolve: a still of the last frame shown (the picture as it is now) over the live one, and faded away over
## `seconds`. Whatever changes under it in the same frame is revealed through the dissolve, not seen happening. (Nothing to
## take a still of without a screen: then it is a plain cut.)
func _dissolve(seconds: float) -> void:
	_clear_freeze()
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return

	_freeze_layer = CanvasLayer.new()
	_freeze_layer.name = "DissolveStill"
	# Over the world, its filters and the motion blur, under the subtitles and the menus.
	_freeze_layer.layer = 1
	var still: TextureRect = TextureRect.new()
	still.texture = ImageTexture.create_from_image(image)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_freeze_layer.add_child(still)
	add_child(_freeze_layer)

	var layer: CanvasLayer = _freeze_layer
	var fade: Tween = _track(create_tween())
	fade.tween_property(still, "modulate:a", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if _freeze_layer == layer:
			_freeze_layer = null)


func _clear_freeze() -> void:
	if _freeze_layer != null and is_instance_valid(_freeze_layer):
		_freeze_layer.queue_free()
	_freeze_layer = null


func _log(beat: StringName) -> void:
	memory_log.append({"beat": beat, "time": scene_clock})


# ============================================================
# HELPERS
# ============================================================

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


## Points along a polyline (house-local) every `stride` metres, from its start to its end.
func _path_points(path: Array[Vector3], stride: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if path.is_empty():
		return points

	points.append(path[0])
	var carried: float = 0.0
	for i: int in range(1, path.size()):
		var from: Vector3 = path[i - 1]
		var length: float = from.distance_to(path[i])
		var at: float = stride - carried
		while at <= length:
			points.append(from.lerp(path[i], at / length))
			at += stride
		carried = length - (at - stride)
	if points[points.size() - 1].distance_to(path[path.size() - 1]) > stride * 0.4:
		points.append(path[path.size() - 1])
	return points


## One sound at a point; the player removes itself when done.
func _play_at(stream: AudioStream, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0, unit_size: float = 5.0, max_distance: float = 30.0) -> AudioStreamPlayer3D:
	if stream == null or not is_inside_tree():
		return null

	var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = pitch
	sound.unit_size = unit_size
	sound.max_distance = max_distance
	sound.max_db = maxf(3.0, volume_db + 3.0)
	add_child(sound)
	sound.global_position = at
	sound.finished.connect(sound.queue_free)
	sound.play()
	return sound


func _play_at_later(stream: AudioStream, at: Vector3, volume_db: float, pitch: float, delay: float) -> void:
	await _wait(delay)
	_play_at(stream, at, volume_db, pitch)


func _doors() -> Array[DoorController]:
	var doors: Array[DoorController] = []
	if doors_root != null:
		for child: Node in doors_root.get_children():
			if child is DoorController:
				doors.append(child as DoorController)

	return doors


func _get_flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _set_flag(key: StringName, value: bool) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, value)


func _get_player() -> Node3D:
	if player != null:
		return player

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _get_movement() -> PlayerMovementController:
	var target: Node3D = _get_player()
	return target.get("movement_controller") as PlayerMovementController if target != null else null


func _get_camera() -> Camera3D:
	var movement: PlayerMovementController = _get_movement()
	return movement.camera if movement != null else null


func _wait(seconds: float) -> void:
	# Not "process always": the pause menu also pauses the house.
	await get_tree().create_timer(maxf(seconds, 0.0), false).timeout
