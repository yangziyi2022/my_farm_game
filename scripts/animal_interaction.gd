class_name AnimalInteraction
extends RefCounted

## Shared feed / pet helpers for build feed mode and walk mode.


static func get_needs(animal: Node3D) -> AnimalNeeds:
	if animal == null or not is_instance_valid(animal):
		return null
	return animal.get_node_or_null("AnimalNeeds") as AnimalNeeds


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
	return {
		"ok": true,
		"consumed": true,
		"favorite": result.get("favorite", false),
		"message": result.get("message", ""),
	}


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
