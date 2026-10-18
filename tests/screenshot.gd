extends SceneTree
## Renders a few frames to PNG (needs a display or xvfb and the compatibility renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script tests/screenshot.gd -- OUT_DIR

func _initialize() -> void:
	var out_dir := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame
	_save("%s/shot_room.png" % out_dir)

	scene._overlay.visible = true
	scene._overlay.queue_redraw()
	for i in 3:
		await process_frame
	_save("%s/shot_debug.png" % out_dir)

	scene._overlay.visible = false
	scene.ui.open(scene.interactables.values()[0])
	for i in 6:
		await process_frame
	_save("%s/shot_dialogue.png" % out_dir)

	scene.ui._sheet.visible = true
	for i in 3:
		await process_frame
	_save("%s/shot_sheet.png" % out_dir)
	quit(0)


func _save(path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	print("saved ", path, " err=", err)
