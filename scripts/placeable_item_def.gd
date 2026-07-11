class_name PlaceableItemDef
extends Resource

## Data-driven definition for one placeable item's art + UI.
## Gameplay still keys off ItemData.ItemType + stable string id for saves.

@export var id: String = ""
@export var display_name: String = ""
@export_file("*.tscn", "*.scn", "*.glb", "*.gltf") var visual_scene_path: String = ""
@export var visual_scene: PackedScene
@export var icon: Texture2D
@export var category: ItemData.Category = ItemData.Category.STRUCTURE
@export var rotatable: bool = true
## Uniform scale applied when the visual scene is instanced onto the grid.
@export_range(0.01, 5.0, 0.01) var visual_scale: float = 1.0
## Lift/sink the visual so feet sit on the tile (positive = up).
@export var visual_y_offset: float = 0.0
## How many grid cells this item occupies (gameplay footprint, not mesh size).
@export var footprint_size: Vector2i = Vector2i(1, 1)


func resolve_visual_scene() -> PackedScene:
	if visual_scene:
		return visual_scene
	if visual_scene_path.is_empty():
		return null
	if not ResourceLoader.exists(visual_scene_path):
		push_warning("PlaceableItemDef '%s': missing visual at %s" % [id, visual_scene_path])
		return null
	return load(visual_scene_path) as PackedScene
