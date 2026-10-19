extends SceneTree
## godot --headless --path . --script tests/test_containers.gd
var failures := 0

func check(cond: bool, msg: String) -> void:
	print("PASS  " if cond else "FAIL  ", msg)
	if not cond:
		failures += 1

func _wait(c: Callable, max_frames := 1500) -> void:
	var n := 0
	while not c.call() and n < max_frames:
		await process_frame
		n += 1

func _initialize() -> void:
	var ch := root.get_node("Character")
	var state := root.get_node("GameState")
	await process_frame
	Engine.time_scale = 10.0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var cui = scene.container_ui
	var data: Dictionary = {}
	for d in scene.interactables.values():
		if d["id"] == "footlocker":
			data = d
	check(not data.is_empty() and data["kind"] == "container", "footlocker registered as a container")
	check(not cui.is_open(), "container window starts closed")
	scene._go_interact(data)
	await _wait(func(): return cui.is_open())
	check(cui.is_open() and not scene.ui.is_open(), "walking to the footlocker opens the container window")
	check(scene._blocked(), "room input is blocked while it is open")
	var inv_before: int = ch.inventory.size()
	check(state.container_items(data).size() == 3, "footlocker holds 3 items")
	check(cui.take("instant_coffee") and ch.inventory.size() == inv_before + 1 and state.container_items(data).size() == 2, "taking moves an item to the inventory")
	check(not cui.take("instant_coffee"), "cannot take an item that is not there")
	check(cui.store("instant_coffee") and state.container_items(data).size() == 3 and ch.inventory.size() == inv_before, "storing moves it back")
	cui._take_all()
	check(state.container_items(data).is_empty() and ch.inventory.size() == inv_before + 3, "take all empties the container")
	check(ch.inventory.has("corduroy_slacks"), "taken clothes land in the inventory")
	await process_frame
	check(cui._left.get_child_count() == 1, "empty container shows a placeholder line")
	cui.close_window()
	check(not cui.is_open() and not scene._blocked(), "closing releases input")
	# contents persist across a reopen
	scene._open(data)
	check(cui.is_open() and state.container_items(data).is_empty(), "contents persist after reopening")
	cui.close_window()
	Engine.time_scale = 1.0
	print("\n%s (%d failed)" % ["ALL PASSED" if failures == 0 else "FAILURES", failures])
	quit(failures)
