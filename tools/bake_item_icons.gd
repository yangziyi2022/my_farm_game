extends SceneTree

## Headless / CLI bake:
##   Godot --path . -s res://tools/bake_item_icons.gd
## Optional:
##   -- core   only milk / sheep_milk / wool / apple


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	host.name = "BakeHost"
	root.add_child(host)
	await process_frame

	var only_core := false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "core":
			only_core = true
	for arg in OS.get_cmdline_args():
		if str(arg) == "core":
			only_core = true

	print("ItemIconBaker: starting (%s)…" % ("core" if only_core else "all"))
	var result: Dictionary
	if only_core:
		result = await ItemIconBaker.bake_core(host)
	else:
		result = await ItemIconBaker.bake_all(host)
	print("ItemIconBaker: wrote %d icons" % int(result.get("count", 0)))
	var err := str(result.get("error", ""))
	if not err.is_empty():
		print("ItemIconBaker issues:\n", err)
	quit(0 if err.is_empty() else 1)
