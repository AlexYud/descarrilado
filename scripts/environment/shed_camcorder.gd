extends Interactable
class_name ShedCamcorder

## The waiting shed's physical camcorder on its tripod: it stays where it stands and is never carried. Using it asks the shed's sequence for the viewfinder
## (`viewfinder_requested`): a fixed, static look through its lens, from the same viewpoint as the recording's first shot.
##
## The model (`ShedRecordingProps._build_camcorder`) has explicit markers on its turning `Head`: `LensMarker` (the front of the lens glass: the viewpoint)
## and `EyeMarker` (the back of the eyecup: where a person's eye would be). `ShedCamcorder` only gives them names and an on/off.

signal viewfinder_requested

## False while something else holds the scene (the recording, the final reveal): the device offers nothing then.
@export var viewfinder_enabled: bool = true


func can_interact(_player: Node) -> bool:
	return viewfinder_enabled


func interact(_player: Node) -> void:
	if viewfinder_enabled:
		viewfinder_requested.emit()


## The part of the device that turns (the body, the lens and the viewfinder on the pan head).
func get_head() -> Node3D:
	return find_child("Head", true, false) as Node3D


## The front of the lens glass: the camera's viewpoint (its -Z is the way the lens looks).
func get_lens_marker() -> Marker3D:
	return find_child("LensMarker", true, false) as Marker3D


## The back of the eyecup: where the eye of whoever looks through the viewfinder is.
func get_eye_marker() -> Marker3D:
	return find_child("EyeMarker", true, false) as Marker3D


## Where the body stands to use it: behind the eyecup (the eye goes the last part of the way).
func get_stand_marker() -> Marker3D:
	return find_child("StandMarker", true, false) as Marker3D
