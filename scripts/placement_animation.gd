class_name PlacementAnimation
extends RefCounted

# Subtle pop-in when an object is first placed.
const START_SCALE: float = 0.8
const DURATION: float = 0.38


static func play(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	target.scale = Vector3.ONE * START_SCALE
	var tween := target.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector3.ONE, DURATION)
