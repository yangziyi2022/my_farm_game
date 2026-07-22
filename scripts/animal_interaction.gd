class_name AnimalInteraction
extends RefCounted

## Shared feed / pet helpers for build feed mode and walk mode.


static func get_needs(animal: Node3D) -> AnimalNeeds:
	if animal == null or not is_instance_valid(animal):
		return null
	return animal.get_node_or_null("AnimalNeeds") as AnimalNeeds


static func try_feed(
	animal: Node3D,
	food: InventoryData.Item,
	inventory_manager: InventoryManager
) -> Dictionary:
	## { ok, message, consumed }. Rejected food is not consumed.
	var needs := get_needs(animal)
	if needs == null:
		return {"ok": false, "consumed": false, "message": "Can't feed that"}
	var animal_type: ItemData.ItemType = animal.get_meta("item_type")
	if not AnimalDiet.can_eat(animal_type, food):
		return {
			"ok": false,
			"consumed": false,
			"message": "%s won't eat %s" % [
				ItemData.get_item_name(animal_type),
				InventoryData.get_item_name(food),
			],
		}
	if inventory_manager and not inventory_manager.remove_item(food):
		return {
			"ok": false,
			"consumed": false,
			"message": "No %s left" % InventoryData.get_item_name(food),
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
		return {"ok": false, "message": "Can't pet that"}
	var result := needs.try_pet()
	if result.get("ok", false):
		AudioManager.play_animal_for_item(
			animal.get_meta("item_type"),
			false,
			animal.global_position
		)
	return result
