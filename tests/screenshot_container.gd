extends SceneTree
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --script tests/screenshot_container.gd -- OUTDIR
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for d in scene.interactables.values():
		if d["id"] == "footlocker":
			scene.container_ui.open(d)
	scene.container_ui.take("instant_coffee")
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out + "/container.png")
	quit()
