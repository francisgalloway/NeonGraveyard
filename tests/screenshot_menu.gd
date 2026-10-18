extends SceneTree
## Renders the HUD, character sheet and inventory to PNG (needs a display or xvfb):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script tests/screenshot_menu.gd -- OUT_DIR

func _initialize() -> void:
	var out_dir := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame
	_save("%s/menu_hud.png" % out_dir)
	scene.menu.open_sheet()
	scene.menu._selected_skill = "puzzle_palace"
	scene.menu._refresh()
	for i in 4:
		await process_frame
	_save("%s/menu_sheet.png" % out_dir)
	scene.menu._selected_item = "company_blazer"
	scene.menu.open_inventory()
	for i in 4:
		await process_frame
	_save("%s/menu_inventory.png" % out_dir)
	quit(0)


func _save(path: String) -> void:
	print("saved ", path, " err=", root.get_texture().get_image().save_png(path))
