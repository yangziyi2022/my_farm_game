# Item Icon Baker

Bake inventory / ground-loot PNGs into `assets/icons/items/`.

## Editor

1. Enable plugin **Item Icon Baker** (Project → Project Settings → Plugins) — already enabled in `project.godot`.
2. Open the **Item Icons** dock (right side).
3. **Bake Milk / Wool / Apple** — core produce icons (2D / tree-texture).
4. **Bake All Inventory Icons** — also SubViewport-captures GLBs (wheat, carrot, sickle, …). Needs the editor GUI (not `--headless`).

## CLI

```bash
# Core icons (works headless)
Godot --path . --headless -s res://tools/bake_item_icons.gd -- core

# All icons (needs a display for GLB SubViewport captures)
Godot --path . -s res://tools/bake_item_icons.gd
```

Icons are loaded by `InventoryData.get_icon()` from `res://assets/icons/items/<id>.png`, with the old color-letter block as fallback.
