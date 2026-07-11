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


func resolve_visual_scene() -> PackedScene:
	if visual_scene:
		return visual_scene
	if visual_scene_path.is_empty():
		return null
	if not ResourceLoader.exists(visual_scene_path):
		push_warning("PlaceableItemDef '%s': missing visual at %s" % [id, visual_scene_path])
		return null
	return load(visual_scene_path) as PackedScene
