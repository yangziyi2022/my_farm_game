class_name SpinningBlades
extends Node

var speed: float = 55.0
var _pivot: Node3D


func setup(pivot: Node3D, spin_speed: float = 55.0) -> void:
	_pivot = pivot
	speed = spin_speed


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(deg_to_rad(speed) * delta)
