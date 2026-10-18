extends SceneTree
## Headless checks for the character state and menu. Run with:
##   godot --headless --path . --script tests/test_character.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS  ", msg)
	else:
		print("FAIL  ", msg)
		failures += 1


func _initialize() -> void:
	var skills := root.get_node("Skills")
	var ch := root.get_node("Character")
	await process_frame  # let the autoloads finish _ready()

	# --- starting state -------------------------------------------------------
	check(ch.money == 23 and ch.level == 2 and ch.xp == 40 and ch.skill_points == 2, "starting money, level, XP and skill points load")
	check(ch.items.size() == 11, "11 items loaded (got %d)" % ch.items.size())

	# --- data validation ------------------------------------------------------
	var items_ok := true
	for id in ch.items:
		var it: Dictionary = ch.items[id]
		for skill_id in it.get("modifiers", {}):
			items_ok = items_ok and skills.skills.has(skill_id)
		if it["type"] == "clothes":
			items_ok = items_ok and ch.SLOTS.has(it["slot"])
	check(items_ok, "every item modifier names a real skill and every clothes item a real slot")
	var loadout_ok := true
	for slot in ch.equipment:
		var id: String = ch.equipment[slot]
		loadout_ok = loadout_ok and (id == "" or (ch.items.has(id) and ch.items[id]["slot"] == slot))
	for id in ch.inventory:
		loadout_ok = loadout_ok and ch.items.has(id)
	check(loadout_ok, "starting equipment fits its slots and the inventory only holds known items")

	# --- clothing modifiers ---------------------------------------------------
	check(skills.get_base_level("main_street") == 3 and skills.get_level("main_street") == 5, "Main Street 3 base + blazer 1 + lanyard 1 = 5")
	check(skills.get_level("neon") == 1, "Neon 2 base - 1 from the blazer = 1")
	var pp_before: int = skills.get_level("puzzle_palace")
	ch.equip("wire_rim_glasses")
	check(skills.get_level("puzzle_palace") == pp_before + 1 and skills.get_level("asphalt") == 3 + 1 - 1, "equipping glasses gives +1 Puzzle Palace and -1 Asphalt")
	check(ch.is_worn("wire_rim_glasses") and not ch.inventory.has("wire_rim_glasses"), "worn item leaves the inventory list")
	ch.equip("sun_cap")
	ch.equip("wire_rim_glasses")  # re-equipping the same item must not duplicate it
	check(ch.inventory.count("wire_rim_glasses") == 0, "re-equipping does not duplicate")
	ch.unequip("eyewear")
	check(skills.get_level("puzzle_palace") == pp_before and ch.inventory.has("wire_rim_glasses"), "unequipping restores the level and returns the item")
	ch.unequip("headgear")
	ch.equip("company_blazer")  # already worn
	check(ch.inventory.count("company_blazer") == 0, "equipping an already-worn item keeps it single")

	# --- learning cap, raise and revert ---------------------------------------
	check(ch.skill_cap("puzzle_palace") == 6 and ch.skill_cap("shoestring") == 5 and ch.skill_cap("smog") == 4, "caps: Psyche 5 + signature = 6, Abstract 5, Sensory 4")
	check(ch.can_raise("puzzle_palace") and not ch.can_raise("hardscrabble"), "can raise below the cap, not at it")
	var pts: int = ch.skill_points
	check(ch.raise_skill("puzzle_palace") and skills.get_base_level("puzzle_palace") == 6 and ch.skill_points == pts - 1, "raising spends a point")
	check(not ch.raise_skill("puzzle_palace"), "cannot raise past the cap")
	check(ch.has_pending(), "raise is pending until the sheet closes")
	ch.revert_pending()
	check(skills.get_base_level("puzzle_palace") == 5 and ch.skill_points == pts and not ch.has_pending(), "Revert gives the point back")
	ch.raise_skill("puzzle_palace")
	ch.commit_pending()
	ch.revert_pending()
	check(skills.get_base_level("puzzle_palace") == 6, "a committed raise cannot be reverted")
	ch.skill_points = 0
	check(not ch.can_raise("smog"), "no points, no raise")

	# --- XP and levels --------------------------------------------------------
	ch.skill_points = 0
	ch.level = 2
	ch.xp = 0
	ch.add_xp(150)
	check(ch.level == 3 and ch.xp == 0 and ch.skill_points == 1, "150 XP at level 2 (needs 150) levels up once and grants 1 point")
	ch.add_xp(10000)
	check(ch.level == ch.max_level and ch.skill_points == 1 + (ch.max_level - 3), "lots of XP stops at the cap with 1 point per level")
	check(ch.xp_needed() == 0, "no XP needed at the cap")

	# --- health, morale, healing ----------------------------------------------
	ch.load_data()
	skills.load_skills()
	check(ch.max_health() == 4 and ch.health() == 3, "max health follows Hardscrabble (4), 1 damage taken")
	check(ch.max_morale() == 2 and ch.morale() == 2, "max morale follows Keel (2)")
	check(ch.heal("health") and ch.health() == 4 and ch.health_charges == 1, "healing spends a charge and restores a point")
	check(not ch.heal("health"), "cannot heal at full health")
	check(not ch.heal("morale"), "cannot heal morale with no damage")
	ch.damage_morale(5)
	check(ch.morale() == 0, "morale damage clamps at zero")
	check(ch.heal("morale") and not ch.heal("morale"), "one morale charge, one heal")

	# --- the menu ------------------------------------------------------------
	ch.load_data()
	skills.load_skills()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var menu = scene.menu
	check(menu != null and not menu.is_open(), "menu exists and starts closed")
	menu.open_sheet()
	await process_frame
	check(menu.is_open() and menu._sheet.visible and not menu._inv.visible, "character sheet opens")
	check(menu._sheet_body.get_child_count() >= 2, "character sheet is populated")
	menu._selected_skill = "puzzle_palace"
	var before: int = skills.get_base_level("puzzle_palace")
	ch.raise_skill("puzzle_palace")
	await process_frame
	check(skills.get_base_level("puzzle_palace") == before + 1, "raising from the sheet works")
	menu.open_inventory()
	await process_frame
	check(menu._inv.visible and not menu._sheet.visible and not ch.has_pending(), "inventory opens and the sheet commits its pending raises")
	check(menu._inv_body.get_child_count() >= 2, "inventory is populated")
	ch.equip("sun_cap")
	await process_frame
	check(ch.equipment["headgear"] == "sun_cap", "equipping from the inventory works")
	menu.close_all()
	check(not menu.is_open(), "Esc/close closes everything")

	print("\n%s (%d failed)" % ["ALL PASSED" if failures == 0 else "FAILURES", failures])
	quit(failures)
