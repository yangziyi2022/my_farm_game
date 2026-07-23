class_name GroundLoot
extends Node3D

## World pickup: item icon on the ground.
## Walk mode adsorbs on proximity; build mode needs a click (float into bag).

signal collected(item: InventoryData.Item)

const IDLE_BOB: float = 0.02
const PICK_RADIUS: float = 0.85
## World size of one texture pixel — keep ground drops small (~0.5–0.6 m).
const SPRITE_PIXEL_SIZE: float = 0.0022

var item: InventoryData.Item = InventoryData.Item.WHEAT
var ready_to_pick: bool = false

var _sprite: Sprite3D
var _busy: bool = false
var _bob_t: float = 0.0
var _base_y: float = 0.12
var _grid: GridManager


static func spawn(
	parent: Node,
	loot_item: InventoryData.Item,
	land_pos: Vector3,
	grid: GridManager = null,
	fall_from: Vector3 = Vector3.ZERO
) -> GroundLoot:
	if parent == null or not is_instance_valid(parent):
		return null
	var loot := GroundLoot.new()
	loot.name = "GroundLoot"
	loot.item = loot_item
	loot._grid = grid
	parent.add_child(loot)
	if fall_from != Vector3.ZERO:
		loot.global_position = fall_from
		loot._play_fall(land_pos)
	else:
		loot.global_position = land_pos
		loot._base_y = land_pos.y
		loot.ready_to_pick = true
		loot._spawn_plop()
	if grid:
		grid.register_ground_loot(loot)
	return loot


func _ready() -> void:
	_build_visual()
	_bob_t = randf() * TAU


func _build_visual() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "Icon"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture = InventoryData.get_icon(item)
	_sprite.pixel_size = SPRITE_PIXEL_SIZE
	_sprite.centered = true
	_sprite.position = Vector3(0.0, 0.02, 0.0)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Soft shadow disc under the icon.
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.015
	shadow.mesh = disc
	shadow.position = Vector3(0.0, 0.008, 0.0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.22)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = sm
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	add_child(_sprite)


func _process(delta: float) -> void:
	if not ready_to_pick or _busy:
		return
	_bob_t += delta * 2.4
	if _sprite:
		_sprite.position.y = 0.02 + sin(_bob_t) * IDLE_BOB


func _play_fall(land_pos: Vector3) -> void:
	ready_to_pick = false
	_base_y = land_pos.y
	var mid := (global_position + land_pos) * 0.5
	mid.y = maxf(global_position.y, land_pos.y) + 0.35
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", mid, 0.18)
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", land_pos, 0.42)
	tw.tween_callback(func() -> void:
		ready_to_pick = true
		_spawn_plop()
	)


func _spawn_plop() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	_sprite.scale = Vector3.ONE * 0.55
	tw.tween_property(_sprite, "scale", Vector3.ONE * 1.12, 0.1)
	tw.tween_property(_sprite, "scale", Vector3.ONE, 0.12)


func adsorb_to(target: Node3D, inventory: InventoryManager) -> bool:
	## Walk-mode magnet pickup.
	if not ready_to_pick or _busy or target == null or not is_instance_valid(target):
		return false
	if inventory == null:
		return false
	_busy = true
	ready_to_pick = false
	var dest := target.global_position + Vector3(0.0, 0.7, 0.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", dest, 0.22)
	if _sprite:
		tw.parallel().tween_property(_sprite, "scale", Vector3.ONE * 0.35, 0.22)
	tw.tween_callback(func() -> void:
		_finish_collect(inventory)
	)
	return true


func collect_float(inventory: InventoryManager) -> bool:
	## Build-mode click: float up into the bag (classic harvest feel).
	if not ready_to_pick or _busy:
		return false
	if inventory == null:
		return false
	_busy = true
	ready_to_pick = false
	var start_y := global_position.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", start_y + 1.35, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:y", rotation.y + 0.8, 0.7)
	if _sprite:
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_sprite, "scale", Vector3.ONE * 0.45, 0.7)
	tw.chain().tween_callback(func() -> void:
		_finish_collect(inventory)
	)
	AudioManager.play("harvest")
	return true


func _finish_collect(inventory: InventoryManager) -> void:
	if inventory:
		inventory.add_item(item, 1)
	collected.emit(item)
	if _grid:
		_grid.unregister_ground_loot(self)
	queue_free()


func xz_distance_to(world_pos: Vector3) -> float:
	var dx := global_position.x - world_pos.x
	var dz := global_position.z - world_pos.z
	return sqrt(dx * dx + dz * dz)
