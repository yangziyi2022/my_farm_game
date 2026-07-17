class_name CropGrowth
extends Node

# Visual growth over time — not tied to economy or quests.
signal stage_changed(stage: int)

const STAGE_COUNT: int = 4
const SECONDS_PER_STAGE: float = 4.5

var _stage: int = 0
var _elapsed: float = 0.0
var _crop_root: Node3D
var _stage_nodes: Array[Node3D] = []


func setup(crop_root: Node3D, start_stage: int = 0) -> void:
	_crop_root = crop_root
	_stage = clampi(start_stage, 0, STAGE_COUNT - 1)
	_collect_stage_nodes()
	_apply_stage(_stage)


func get_stage() -> int:
	return _stage


func set_stage(stage: int) -> void:
	_stage = clampi(stage, 0, STAGE_COUNT - 1)
	_apply_stage(_stage)


func _ready() -> void:
	if _crop_root == null:
		_crop_root = get_parent() as Node3D
	if _stage_nodes.is_empty() and _crop_root:
		_collect_stage_nodes()
		_apply_stage(_stage)


func _process(delta: float) -> void:
	if _stage >= STAGE_COUNT - 1:
		return

	_elapsed += delta
	if _elapsed >= SECONDS_PER_STAGE:
		_elapsed = 0.0
		_advance_stage()


func _collect_stage_nodes() -> void:
	_stage_nodes.clear()
	if _crop_root == null or not is_instance_valid(_crop_root):
		return
	for i in range(STAGE_COUNT):
		var node := _crop_root.get_node_or_null("Stage%d" % i)
		if node != null and is_instance_valid(node) and node is Node3D:
			_stage_nodes.append(node)


func _advance_stage() -> void:
	if _stage >= STAGE_COUNT - 1:
		return
	_stage += 1
	_apply_stage(_stage)
	stage_changed.emit(_stage)
	if _crop_root and is_instance_valid(_crop_root):
		_crop_root.set_meta("growth_stage", _stage)


func _apply_stage(stage: int) -> void:
	for i in range(_stage_nodes.size()):
		var node := _stage_nodes[i]
		if node != null and is_instance_valid(node):
			node.visible = i == stage

	if _stage_nodes.is_empty() and _crop_root and is_instance_valid(_crop_root):
		# Fallback: scale the whole crop for older saves without stage nodes.
		var scales := [0.25, 0.45, 0.7, 1.0]
		_crop_root.scale = Vector3.ONE * scales[stage]
