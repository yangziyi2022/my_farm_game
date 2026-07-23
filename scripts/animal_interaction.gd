class_name AnimalInteraction
extends RefCounted

## Shared feed / pet helpers for build feed mode and walk mode.


static func get_needs(animal: Node3D) -> AnimalNeeds:
	if animal == null or not is_instance_valid(animal):
		return null
	return animal.get_node_or_null("AnimalNeeds") as AnimalNeeds


static func get_life(animal: Node3D) -> AnimalLife:
	if animal == null or not is_instance_valid(animal):
		return null
	return animal.get_node_or_null("AnimalLife") as AnimalLife


static func get_display_name(animal: Node3D) -> String:
	if animal == null or not is_instance_valid(animal):
		return ""
	if animal.has_meta("custom_name"):
		var custom := str(animal.get_meta("custom_name")).strip_edges()
		if not custom.is_empty():
			return custom
	if animal.has_meta("item_type"):
		return ItemData.get_item_name(animal.get_meta("item_type"))
	return ""


static func set_custom_name(animal: Node3D, new_name: String) -> Dictionary:
	## { ok, message, name }. Empty name clears the custom label.
	if animal == null or not is_instance_valid(animal):
		return {"ok": false, "message": LocaleManager.t("Can't rename that"), "name": ""}
	if not animal.has_meta("item_type") or not ItemData.is_animal(animal.get_meta("item_type")):
		return {"ok": false, "message": LocaleManager.t("Can't rename that"), "name": ""}
	var cleaned := new_name.strip_edges()
	# Collapse internal runs of whitespace.
	cleaned = " ".join(cleaned.split(" ", false))
	if cleaned.length() > 20:
		cleaned = cleaned.substr(0, 20).strip_edges()
	if cleaned.is_empty():
		if animal.has_meta("custom_name"):
			animal.remove_meta("custom_name")
		var species := ItemData.get_item_name(animal.get_meta("item_type"))
		return {
			"ok": true,
			"name": species,
			"message": LocaleManager.tf("Name reset to %s", [species]),
		}
	animal.set_meta("custom_name", cleaned)
	return {
		"ok": true,
		"name": cleaned,
		"message": LocaleManager.tf("Named %s", [cleaned]),
	}


static func try_feed(
	animal: Node3D,
	food: InventoryData.Item,
	inventory_manager: InventoryManager
) -> Dictionary:
	## { ok, message, consumed }. Rejected food is not consumed.
	var needs := get_needs(animal)
	if needs == null:
		return {"ok": false, "consumed": false, "message": LocaleManager.t("Can't feed that")}
	var animal_type: ItemData.ItemType = animal.get_meta("item_type")
	if not AnimalDiet.can_eat(animal_type, food):
		return {
			"ok": false,
			"consumed": false,
			"message": LocaleManager.tf("%s won't eat %s", [
				get_display_name(animal),
				InventoryData.get_item_name(food),
			]),
		}
	if inventory_manager and not inventory_manager.remove_item(food):
		return {
			"ok": false,
			"consumed": false,
			"message": LocaleManager.tf("No %s left", [InventoryData.get_item_name(food)]),
		}
	var result := needs.try_feed(food)
	AnimalFeedEffect.play(animal)
	AudioManager.play("feed")
	AudioManager.play_animal_for_item(animal_type, false, animal.global_position)
	var breed_msg := ""
	if result.get("ok", false):
		var life := get_life(animal)
		if life:
			life.mark_player_fed()
		breed_msg = _try_breed_after_feed(animal, inventory_manager)
	var message := str(result.get("message", ""))
	if not breed_msg.is_empty():
		message = "%s\n%s" % [message, breed_msg]
	return {
		"ok": true,
		"consumed": true,
		"favorite": result.get("favorite", false),
		"message": message,
	}


static func try_collect_produce(animal: Node3D, _inventory_manager: InventoryManager = null) -> Dictionary:
	## Marks produce collected; caller spawns GroundLoot (does not add to bag).
	var life := get_life(animal)
	if life == null:
		return {"ok": false, "message": LocaleManager.t("Can't collect from that")}
	var result := life.collect_produce()
	if not result.get("ok", false):
		return result
	var item = result.get("item")
	if item == null:
		return {"ok": false, "message": LocaleManager.t("Can't collect from that")}
	AudioManager.play("harvest")
	return result


static func _try_breed_after_feed(animal: Node3D, _inventory_manager: InventoryManager) -> String:
	## If a compatible adult partner is nearby and both are ready, spawn a baby.
	var life := get_life(animal)
	var needs := get_needs(animal)
	if life == null or needs == null or not life.can_breed() or not life.meets_breed_needs(needs):
		return ""
	if not animal.has_meta("item_type") or not animal.has_meta("grid_pos"):
		return ""
	var animal_type: ItemData.ItemType = animal.get_meta("item_type")
	if not ItemData.can_breed(animal_type):
		return ""
	var grid := _find_grid(animal)
	if grid == null:
		return ""
	var partner := _find_breed_partner(animal, animal_type, grid)
	if partner == null:
		return ""
	var partner_life := get_life(partner)
	var partner_needs := get_needs(partner)
	if partner_life == null or partner_needs == null:
		return ""
	if not partner_life.can_breed() or not partner_life.meets_breed_needs(partner_needs):
		return ""
	var baby_cell := _find_birth_cell(animal, partner, grid)
	if baby_cell.x < -9000:
		return ""
	var baby := grid.spawn_animal_baby(animal_type, baby_cell)
	if baby == null:
		return ""
	life.mark_bred()
	partner_life.mark_bred()
	AnimalFeedEffect.play(baby)
	return LocaleManager.tf("A baby %s was born!", [ItemData.get_item_name(animal_type)])


static func _find_grid(animal: Node3D) -> GridManager:
	var life := get_life(animal)
	if life:
		var g := life.get_grid()
		if g:
			return g
	var n: Node = animal
	while n:
		if n is GridManager:
			return n as GridManager
		var gm := n.get_node_or_null("GridManager") as GridManager
		if gm:
			return gm
		n = n.get_parent()
	return null


static func _find_breed_partner(
	animal: Node3D,
	animal_type: ItemData.ItemType,
	grid: GridManager
) -> Node3D:
	var from: Vector2i = animal.get_meta("grid_pos")
	var best: Node3D = null
	var best_dist := 999
	for dx in range(-AnimalLife.BREED_SEARCH_RADIUS, AnimalLife.BREED_SEARCH_RADIUS + 1):
		for dy in range(-AnimalLife.BREED_SEARCH_RADIUS, AnimalLife.BREED_SEARCH_RADIUS + 1):
			if dx == 0 and dy == 0:
				continue
			var cell := from + Vector2i(dx, dy)
			var other := grid.get_animal_at(cell)
			if other == null or other == animal:
				continue
			if not other.has_meta("item_type") or other.get_meta("item_type") != animal_type:
				continue
			var dist := maxi(absi(dx), absi(dy))
			if dist < best_dist:
				best_dist = dist
				best = other
	return best


static func _find_birth_cell(a: Node3D, b: Node3D, grid: GridManager) -> Vector2i:
	var cells: Array[Vector2i] = []
	for origin_animal in [a, b]:
		var origin: Vector2i = origin_animal.get_meta("grid_pos")
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cell: Vector2i = origin + dir
			if cell in cells:
				continue
			cells.append(cell)
	cells.shuffle()
	for cell in cells:
		if grid.can_place_at(cell, a.get_meta("item_type"), 0):
			return cell
	return Vector2i(-9999, -9999)


static func try_pet(animal: Node3D) -> Dictionary:
	var needs := get_needs(animal)
	if needs == null:
		return {"ok": false, "message": LocaleManager.t("Can't pet that")}
	var result := needs.try_pet()
	if result.get("ok", false):
		AudioManager.play_animal_for_item(
			animal.get_meta("item_type"),
			false,
			animal.global_position
		)
	return result
