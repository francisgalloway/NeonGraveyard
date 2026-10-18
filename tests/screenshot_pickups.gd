extends SceneTree
## Renders the room with pick-ups, the HUD under the dialogue, and the toasts:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script tests/screenshot_pickups.gd -- OUT_DIR

func _initialize() -> void:
	var out_dir := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame
	_save("%s/pick_room.png" % out_dir)

	scene.ui.open(scene.interactables[Vector2i(6, 4)])
	for i in 6:
		await process_frame
	_save("%s/pick_dialogue.png" % out_dir)
	scene.ui.close()

	var hat: Dictionary
	var wallet: Dictionary
	for t in scene.click_targets:
		if t["data"]["id"] == "hard_hat":
			hat = t["data"]
		elif t["data"]["id"] == "wallet":
			wallet = t["data"]
	scene._open(wallet)
	scene._open(hat)
	for i in 6:
		await process_frame
	_save("%s/pick_toast.png" % out_dir)
	scene.menu.open_inventory()
	scene.menu._selected_item = "hard_hat"
	scene.menu._refresh()
	for i in 4:
		await process_frame
	_save("%s/pick_inventory.png" % out_dir)
	quit(0)


func _save(path: String) -> void:
	print("saved ", path, " err=", root.get_texture().get_image().save_png(path))
