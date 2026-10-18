extends SceneTree
## Headless checks for the prototype. Run from the project folder with:
##   godot --headless --path . --import          (once, builds the class cache)
##   godot --headless --path . --script tests/run_tests.gd
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1


func _initialize() -> void:
	var skills := root.get_node("Skills")
	var state := root.get_node("GameState")
	await process_frame  # let the autoloads finish _ready()

	# --- skill data -----------------------------------------------------------
	check(skills.skills.size() == 24, "24 skills loaded (got %d)" % skills.skills.size())
	var groups_ok: bool = skills.groups.size() == 6
	for g in skills.groups:
		groups_ok = groups_ok and g["skills"].size() == 4
	check(groups_ok, "6 groups of 4 skills")

	# --- dice maths -----------------------------------------------------------
	check(absf(skills.success_chance(0, 5) - 30.0 / 36.0) < 1e-6, "level 0 vs Trivial 5 = 30/36")
	check(absf(skills.success_chance(0, 18) - 1.0 / 36.0) < 1e-6, "level 0 vs Legendary 18 = 1/36 (double six auto-succeeds)")
	check(absf(skills.success_chance(5, 2) - 35.0 / 36.0) < 1e-6, "level 5 vs target 2 = 35/36 (double one auto-fails)")
	var wins := 0
	var trials := 20000
	for i in trials:
		if skills.roll_active("smog", 14)["success"]:  # smog is level 4: needs a 10+
			wins += 1
	var expected: float = skills.success_chance(skills.get_level("smog"), 14)
	check(absf(wins / float(trials) - expected) < 0.02, "rolled success rate %.3f matches expected %.3f" % [wins / float(trials), expected])

	# --- passive checks -------------------------------------------------------
	check(skills.passes_passive("puzzle_palace", 12), "Puzzle Palace 5 + 7 passes Challenging 12")
	check(not skills.passes_passive("puzzle_palace", 13), "Puzzle Palace 5 + 7 fails 13")

	# --- white / red retry rules ----------------------------------------------
	check(state.can_attempt("t:white", "smog", false), "unattempted check is available")
	state.record_attempt("t:white", "smog", false)
	check(not state.can_attempt("t:white", "smog", false), "failed white check locked until skill rises")
	skills.set_level("smog", skills.get_level("smog") + 1)
	check(state.can_attempt("t:white", "smog", false), "failed white check reopens after level up")
	state.record_attempt("t:red", "smog", false)
	skills.set_level("smog", skills.get_level("smog") + 1)
	check(not state.can_attempt("t:red", "smog", true), "failed red check never reopens")
	skills.set_level("smog", skills.get_level("smog") - 2)
	state.check_log.clear()

	# --- data validation ------------------------------------------------------
	var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/room.json"))
	var dirs := ["N", "E", "S", "W"]
	var sprites_ok := true
	var cells_ok := true
	for p in room["props"]:
		sprites_ok = sprites_ok and dirs.has(p["dir"]) and FileAccess.file_exists("res://assets/kenney_library/Isometric/%s_%s.png" % [p["sprite"], p["dir"]])
		cells_ok = cells_ok and p["cell"][0] >= 0 and p["cell"][1] >= 0 and p["cell"][0] < room["width"] and p["cell"][1] < room["height"]
	check(sprites_ok, "every prop sprite file exists")
	check(cells_ok, "every prop is inside the room")
	var data_ok := true
	for id in room["interactables"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interactables/%s.json" % id))
		if d.get("kind", "dialogue") != "dialogue":
			data_ok = data_ok and FileAccess.file_exists(String(d["image"]))
			continue
		data_ok = data_ok and FileAccess.file_exists("res://assets/kenney_library/Isometric/%s_%s.png" % [d["sprite"], d["dir"]])
		for entry in d["passives"] + d["actives"]:
			data_ok = data_ok and skills.skills.has(entry["skill"]) and (typeof(entry["difficulty"]) != TYPE_STRING or skills.DIFFICULTIES.has(entry["difficulty"]))
	check(data_ok, "interactable data references valid skills, difficulties and sprites")

	# --- the room, end to end -------------------------------------------------
	Engine.time_scale = 10.0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.player != null and scene.solid.size() > 0, "room built (solid cells: %d)" % scene.solid.size())
	check(scene.interactables.size() > 0, "interactable registered")
	var data: Dictionary = scene.interactables.values()[0]
	scene._go_interact(data)
	check(scene.player.is_walking(), "clicking the interactable starts the player walking")
	var frames := 0
	while not scene.ui.is_open() and frames < 1500:
		await process_frame
		frames += 1
	check(scene.ui.is_open(), "player arrives and the dialogue opens (%d frames)" % frames)
	await process_frame
	check(scene.ui._log.get_child_count() == 5, "intro + 4 passing passive voices shown (got %d)" % scene.ui._log.get_child_count())
	var before: int = scene.ui._log.get_child_count()
	scene.ui._attempt(data["actives"][0])
	await process_frame
	var lock_ok: bool = state.check_log["display_case:lock"]["success"]
	check(scene.ui._log.get_child_count() == before + (3 if lock_ok else 2), "active check adds its prompt, a result window, and a '+XP' line on success")
	scene.ui.close()
	check(not scene.ui.is_open(), "dialogue closes")

	Engine.time_scale = 1.0
	print("\n%s (%d failed)" % ["ALL PASSED" if failures == 0 else "FAILURES", failures])
	quit(failures)
