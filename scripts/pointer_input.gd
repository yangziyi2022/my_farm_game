extends Node

## Unified pointer state for mouse + touch.
## - Desktop: mouse drives primary position (unchanged feel).
## - Touch: one finger ≈ primary (via emulate mouse OR direct touch);
##          two fingers are exposed for CameraController pan/pinch.
##
## Enable editor testing: Project → Project Settings →
##   Input Devices → Pointing → "Emulate Touch From Mouse"

signal primary_moved(position: Vector2, relative: Vector2)

var primary_position: Vector2 = Vector2.ZERO
var primary_down: bool = false

## Active touch points: finger_id -> screen position
var touches: Dictionary = {}

## True after any real ScreenTouch this session (or touchscreen hardware).
var _touch_session: bool = false

## Placement sets this while dragging objects / placing / marquee so camera
## won't steal one-finger gestures if we add orbit later.
var gameplay_captures_primary: bool = false


func _ready() -> void:
	primary_position = get_viewport().get_mouse_position()
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_touch_ui() -> bool:
	## Switch to touch-friendly tools only after a real finger event (or mobile export).
	if _touch_session:
		return true
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func touch_count() -> int:
	return touches.size()


func get_position() -> Vector2:
	return primary_position


func get_touch_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for id in touches.keys():
		out.append(touches[id])
	return out


func pinch_info() -> Dictionary:
	## { valid, center, distance, angle } for the first two touches.
	if touches.size() < 2:
		return {"valid": false, "center": Vector2.ZERO, "distance": 0.0, "angle": 0.0}
	var pts: Array[Vector2] = get_touch_positions()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var delta := b - a
	return {
		"valid": true,
		"center": (a + b) * 0.5,
		"distance": delta.length(),
		"angle": delta.angle(),
	}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_session = true
		var st := event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
			if touches.size() == 1:
				primary_position = st.position
				primary_down = true
		else:
			touches.erase(st.index)
			if touches.is_empty():
				primary_down = false
			elif touches.size() == 1:
				primary_position = get_touch_positions()[0]
		return

	if event is InputEventScreenDrag:
		_touch_session = true
		var sd := event as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() == 1:
			var prev := primary_position
			primary_position = sd.position
			primary_moved.emit(primary_position, primary_position - prev)
		return

	# Mouse (desktop, or emulated from touch when project setting is on).
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		primary_position = mb.position
		primary_down = mb.pressed
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		primary_position = mm.position
		if primary_down and touches.is_empty():
			primary_moved.emit(primary_position, mm.relative)
