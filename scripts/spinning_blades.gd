class_name SpinningBlades
extends Node

var speed: float = 55.0
var _pivot: Node3D
var _axis: Vector3 = Vector3.UP


func setup(pivot: Node3D, spin_speed: float = 55.0, axis: Vector3 = Vector3.UP) -> void:
	_pivot = pivot
	speed = spin_speed
	_axis = axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate(_axis, deg_to_rad(speed) * delta)
