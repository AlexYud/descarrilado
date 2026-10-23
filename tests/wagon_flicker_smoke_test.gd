extends Node

## The wagon's lights in the dream intro's opening fail like in a horror film for as long as the player lifts their head
## (about six seconds) and end dark: a strobe, a calm, a cut to dark with a surge, heavy flicker, a long blackout, a
## weak restart, a stutter that falls apart, a dying flicker. Run it as a scene; it quits by itself with a non-zero
## exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_wagon_flicker_smoke"

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	_check_pattern()

	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "wagon_flicker_start", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	await _check_opening(level)

	SaveManager.delete_slot(1)
	print("WAGON_FLICKER_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _check_pattern() -> void:
	var beats: Array[Vector2] = TrainLightFlicker.build_horror_beats(1989, 5.8)
	var total: float = 0.0
	var dark_stretches: int = 0
	var longest_dark: float = 0.0
	var surge: float = 0.0
	var calm: float = 0.0
	var lit_beats: int = 0
	var dark_run: float = 0.0
	for beat: Vector2 in beats:
		total += beat.x
		surge = maxf(surge, beat.y)
		if beat.y < 0.05:
			dark_run += beat.x
		else:
			if dark_run >= 0.2:
				dark_stretches += 1

			longest_dark = maxf(longest_dark, dark_run)
			dark_run = 0.0
			lit_beats += 1
			if beat.y > 0.85 and beat.y < 1.05:
				calm += beat.x

	longest_dark = maxf(longest_dark, dark_run)
	_expect(absf(total - 5.8) < 0.05, "the failure lasts the time it is given (%.2f s of 5.8)" % total)
	_expect(beats.size() >= 40 and lit_beats >= 20, "it is made of many beats (%d, %d of them lit)" % [beats.size(), lit_beats])
	_expect(dark_stretches >= 3 and longest_dark >= 0.5, "with several real blackouts (%d of 0.2 s or more, the longest %.2f s)" % [dark_stretches, longest_dark])
	_expect(surge >= 1.5, "a surge brighter than the usual light as it comes back (%.1f times)" % surge)
	_expect(calm >= 0.4, "and a false calm in between (%.2f s of steady light)" % calm)
	_expect(beats[beats.size() - 1].y == 0.0, "it ends dark")
	var clock: float = 0.0
	var late_relights: int = 0
	var was_dark: bool = false
	for beat: Vector2 in beats:
		clock += beat.x
		var dark: bool = beat.y < 0.05
		if clock > 5.8 - 1.5 and was_dark and not dark:
			late_relights += 1

		was_dark = dark

	_expect(late_relights <= 2, "and the last second and a half is calm: only %d relights" % late_relights)
	_expect(TrainLightFlicker.build_horror_beats(1989, 5.8) == beats and TrainLightFlicker.build_horror_beats(7, 5.8) != beats, "the same seed fails the same way every time, another seed another way")
	var short: Array[Vector2] = TrainLightFlicker.build_horror_beats(1989, 3.0)
	var short_total: float = 0.0
	for beat: Vector2 in short:
		short_total += beat.x
	_expect(absf(short_total - 3.0) < 0.05, "and it is squeezed to a shorter time when it is asked for (%.2f s)" % short_total)


## The wagon's lights, sampled every frame while the opening plays.
func _check_opening(level: Node) -> void:
	var flicker: TrainLightFlicker = null
	for node: Node in level.find_children("*", "TrainLightFlicker", true, false):
		flicker = node as TrainLightFlicker
		break

	_expect(flicker != null and not flicker.lights.is_empty(), "the wagon has its light fittings")
	if flicker == null or flicker.lights.is_empty():
		return

	var light: OmniLight3D = flicker.lights[0]
	var start: int = Time.get_ticks_msec()
	var peak: float = 0.0
	var relights: int = 0
	var longest_dark: float = 0.0
	var dark_since: float = -1.0
	var was_dark: bool = false
	var levels: Dictionary = {}
	var seconds_to_dark: float = -1.0
	var last_lit: float = 0.0
	var first_change: float = -1.0
	while Time.get_ticks_msec() - start < 9000:
		await get_tree().process_frame
		var now: float = float(Time.get_ticks_msec() - start) / 1000.0
		var energy: float = light.light_energy if light.visible else 0.0
		peak = maxf(peak, energy)
		levels[snappedf(energy, 0.2)] = true
		var dark: bool = energy < 0.05
		if first_change < 0.0 and absf(energy - flicker.base_energy) > 0.2:
			first_change = now
		if dark and not was_dark:
			dark_since = now
		if not dark and was_dark:
			relights += 1
			longest_dark = maxf(longest_dark, now - dark_since)
		if not dark:
			last_lit = now
		was_dark = dark

	longest_dark = maxf(longest_dark, 0.0)
	_expect(relights >= 8, "the lights go out and come back many times during the opening (%d times)" % relights)
	_expect(longest_dark >= 0.4, "with at least one long dark stretch before the end (%.2f s)" % longest_dark)
	_expect(peak >= flicker.base_energy * 1.4, "and a surge above the usual brightness (peak %.1f against %.1f)" % [peak, flicker.base_energy])
	_expect(levels.size() >= 8, "at many different levels, not just on and off (%d)" % levels.size())
	var failure_seconds: float = last_lit - first_change
	_expect(first_change >= 0.0 and failure_seconds > 4.5 and failure_seconds < 6.3, "the failure goes on through the head raise, to its end (the last light %.1f s after the first flicker)" % failure_seconds)
	_expect(not light.visible and not flicker.horror_running, "and then the wagon is dark for good")
	_expect(flicker.process_mode == Node.PROCESS_MODE_DISABLED, "and it stays dark")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
