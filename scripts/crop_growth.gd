class_name CropGrowth
extends Node

## Visual growth over time. Mature after ~3 minutes (3 stage advances).
signal stage_changed(stage: int)
signal growth_changed

const STAGE_COUNT: int = 4
## Three advances × 60s = 3 minutes seed → mature.
const SECONDS_PER_STAGE: float = 60.0
const FERTILIZE_MULT: float = 1.75

var _stage: int = 0
var _elapsed: float = 0.0
var _crop_root: Node3D
var _stage_nodes: Array[Node3D] = []
var _fertilized: bool = false
var _rate: float = 1.0


func setup(crop_root: Node3D, start_stage: int = 0) -> void:
	_crop_root = crop_root
	_stage = clampi(start_stage, 0, STAGE_COUNT - 1)
	_collect_stage_nodes()
	_apply_stage(_stage)


func get_stage() -> int:
	return _stage


func is_mature() -> bool:
	return _stage >= STAGE_COUNT - 1


func is_fertilized() -> bool:
	return _fertilized


func get_stage_progress() -> float:
	## 0–100 progress within the current stage (100 if mature).
	if is_mature():
		return 100.0
	return clampf((_elapsed / SECONDS_PER_STAGE) * 100.0, 0.0, 100.0)


func get_total_progress() -> float:
	## 0–100 overall seed → mature.
	if is_mature():
		return 100.0
	var base := float(_stage) / float(STAGE_COUNT - 1)
	var within := (_elapsed / SECONDS_PER_STAGE) / float(STAGE_COUNT - 1)
	return clampf((base + within) * 100.0, 0.0, 100.0)


func set_stage(stage: int) -> void:
	_stage = clampi(stage, 0, STAGE_COUNT - 1)
	_elapsed = 0.0
	_apply_stage(_stage)
	growth_changed.emit()


func try_fertilize() -> Dictionary:
	## One-shot growth speed boost until mature.
	if is_mature():
		return {"ok": false, "message": LocaleManager.t("Already mature")}
	if _fertilized:
		return {"ok": false, "message": LocaleManager.t("Already fertilized")}
	_fertilized = true
	_rate = FERTILIZE_MULT
	growth_changed.emit()
	return {"ok": true, "message": LocaleManager.t("Fertilized — growing faster")}


func to_save_dict() -> Dictionary:
	return {
		"growth_elapsed": snappedf(_elapsed, 0.1),
		"fertilized": _fertilized,
	}


func apply_saved(elapsed: float, fertilized: bool) -> void:
	_elapsed = maxf(0.0, elapsed)
	_fertilized = fertilized
	_rate = FERTILIZE_MULT if _fertilized and not is_mature() else 1.0
	growth_changed.emit()


func _ready() -> void:
	if _crop_root == null:
		_crop_root = get_parent() as Node3D
	if _stage_nodes.is_empty() and _crop_root:
		_collect_stage_nodes()
		_apply_stage(_stage)


func _process(delta: float) -> void:
	if _stage >= STAGE_COUNT - 1:
		return

	_elapsed += delta * _rate
	if _elapsed >= SECONDS_PER_STAGE:
		_elapsed = 0.0
		_advance_stage()
	else:
		# Throttle UI churn a bit — emit every ~0.5s of real time via meta stamp.
		var stamp := int(_elapsed * 2.0)
		if _crop_root and int(_crop_root.get_meta("_growth_ui_stamp", -1)) != stamp:
			_crop_root.set_meta("_growth_ui_stamp", stamp)
			growth_changed.emit()


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
	growth_changed.emit()
	if _crop_root and is_instance_valid(_crop_root):
		_crop_root.set_meta("growth_stage", _stage)
	if is_mature():
		_rate = 1.0


func _apply_stage(stage: int) -> void:
	for i in range(_stage_nodes.size()):
		var node := _stage_nodes[i]
		if node != null and is_instance_valid(node):
			node.visible = i == stage

	if _stage_nodes.is_empty() and _crop_root and is_instance_valid(_crop_root):
		# Fallback: scale the whole crop for older saves without stage nodes.
		var scales := [0.25, 0.45, 0.7, 1.0]
		_crop_root.scale = Vector3.ONE * scales[stage]
