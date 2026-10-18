extends SceneTree
## Headless checks for pick-ups, money containers and HUD layering. Run with:
##   godot --headless --path . --script tests/test_pickups.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1


func _wait(cond: Callable, max_frames: int = 1500) -> bool:
	var f := 0
	while not cond.call() and f < max_frames:
		await process_frame
		f += 1
	return cond.call()


func _find(scene: Node, id: String) -> Dictionary:
	for t in scene.click_targets:
		if t["data"]["id"] == id:
			return t["data"]
	return {}


func _initialize() -> void:
	var ch := root.get_node("Character")
	var state := root.get_node("GameState")
	await process_frame
	Engine.time_scale = 10.0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var hat := _find(scene, "hard_hat")
	var wallet := _find(scene, "wallet")
	check(not hat.is_empty() and not wallet.is_empty(), "hard hat and wallet are in the room")
	check(scene.click_targets.size() == 3, "room has 3 interactables (case, hat, wallet)")
	check(not scene.solid.has(Vector2i(6, 2)) and not scene.solid.has(Vector2i(2, 3)), "pick-ups do not block movement")
	check(scene.interactables.has(Vector2i(6, 2)) and scene.interactables.has(Vector2i(2, 3)), "pick-ups are interactable")

	# --- HUD layering ---------------------------------------------------------
	check(scene.menu._hud_layer.layer < scene.ui.layer and scene.ui.layer < scene.menu.layer, "health/morale HUD is behind the dialogue, which is behind the menus")

	# --- wallet: money-only container ----------------------------------------
	var money0: int = ch.money
	scene._go_interact(wallet)
	check(scene.player.is_walking(), "clicking the wallet sends the player to it")
	var got: bool = await _wait(func() -> bool: return ch.money != money0)
	check(got and ch.money == money0 + 10, "walking up to the wallet gives $10 (money %d -> %d)" % [money0, ch.money])
	check(scene.interactables.has(Vector2i(2, 3)) and _find(scene, "wallet") == wallet, "the wallet stays in the room")
	scene._open(wallet)
	check(ch.money == money0 + 10, "a looted wallet gives nothing more")
	check(scene.ui._toasts.get_child_count() >= 2, "toasts appeared for the loot and for the empty wallet")

	# --- hard hat: pick-up item ----------------------------------------------
	var inv0: int = ch.inventory.size()
	check(not ch.inventory.has("hard_hat") and not ch.is_worn("hard_hat"), "no hard hat before pickup")
	scene._go_interact(hat)
	var took: bool = await _wait(func() -> bool: return ch.inventory.has("hard_hat"))
	check(took and ch.inventory.size() == inv0 + 1, "walking up to the hard hat puts it in the inventory")
	await process_frame
	check(not scene.interactables.has(Vector2i(6, 2)), "the hat is no longer interactable")
	check(_find(scene, "hard_hat").is_empty() and scene.click_targets.size() == 2, "the hat's sprite is removed from the room")
	check(state.has_flag("taken:hard_hat"), "pick-up is recorded so it stays gone")

	# --- the hat works as clothing -------------------------------------------
	var hp0: int = ch.max_health()
	var hs0: int = root.get_node("Skills").get_level("hardscrabble")
	ch.equip("hard_hat")
	check(ch.equipment["headgear"] == "hard_hat", "the hat can be worn as headgear")
	check(root.get_node("Skills").get_level("hardscrabble") == hs0 + 1 and ch.max_health() == hp0 + 1, "the hat adds +1 Hardscrabble, which raises max health")

	Engine.time_scale = 1.0
	print("\n%s (%d failed)" % ["ALL PASSED" if failures == 0 else "FAILURES", failures])
	quit(failures)
