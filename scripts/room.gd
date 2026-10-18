extends Node2D
## The prototype room: floor, props, player, interactables, click-to-move.
##
## Everything in the room comes from data/room.json and data/interactables/*.json.
## Controls: left-click to move, examine or pick up, E to examine something adjacent,
## C for the character sheet, I for the inventory, F1 for the debug grid,
## Esc closes whatever is open.

const ROOM_PATH := "res://data/room.json"
const INTERACTABLE_DIR := "res://data/interactables/"
const SPRITE_DIR := "res://assets/kenney_library/Isometric/"
const FLOOR_A := Color("#5c5a52")
const FLOOR_B := Color("#54524b")
const FLOOR_EDGE := Color("#3a3934")
const CAMERA_ZOOM := 1.0
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var width := 0
var height := 0
var solid: Dictionary = {}           # Vector2i -> true
var interactables: Dictionary = {}   # Vector2i -> interactable data
var click_targets: Array = []        # [{ "sprite": Sprite2D, "data": Dictionary }]
var astar := AStarGrid2D.new()
var player: Player
var ui: DialogueUI
var menu: CharacterMenu
var pending: Dictionary = {}         # interactable to open when the player arrives

var _decor: Node2D
var _entities: Node2D
var _overlay: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#15181a"))
	var room: Dictionary = _load_json(ROOM_PATH)
	width = int(room["width"])
	height = int(room["height"])

	var floor_node := Node2D.new()
	floor_node.draw.connect(_draw_floor.bind(floor_node))
	add_child(floor_node)

	_decor = Node2D.new()
	add_child(_decor)

	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)

	for p in room["props"]:
		var flat: bool = p.get("flat", false)
		_spawn_sprite(p, _decor if flat else _entities)
		if not flat:
			for c in p.get("solid", [p["cell"]]):
				solid[Vector2i(int(c[0]), int(c[1]))] = true

	for id in room["interactables"]:
		var data: Dictionary = _load_json("%s%s.json" % [INTERACTABLE_DIR, id])
		if String(data.get("kind", "dialogue")) == "pickup" and GameState.has_flag("taken:%s" % data["id"]):
			continue
		var spr := _spawn_sprite(data, _entities)
		click_targets.append({"sprite": spr, "data": data})
		var blocking: bool = data.get("blocking", true)
		for c in data.get("solid", [data["cell"]]):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if blocking:
				solid[cell] = true
			interactables[cell] = data

	_setup_pathfinding()

	player = Player.new()
	player.scale = Vector2(1.3, 1.3)
	var start: Array = room["player_start"]
	player.position = Iso.cell_to_world(Vector2(int(start[0]), int(start[1])))
	player.arrived.connect(_on_player_arrived)
	_entities.add_child(player)

	_overlay = Node2D.new()
	_overlay.visible = false
	_overlay.draw.connect(_draw_debug.bind(_overlay))
	add_child(_overlay)

	var camera := Camera2D.new()
	camera.position = Iso.cell_to_world(Vector2((width - 1) / 2.0, (height - 1) / 2.0)) + Vector2(0, -40)
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(camera)
	camera.make_current()

	ui = DialogueUI.new()
	add_child(ui)
	menu = CharacterMenu.new()
	add_child(menu)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not read %s" % path)
		return {}
	return parsed


func _spawn_sprite(d: Dictionary, parent: Node2D) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	if d.has("image"):
		# Standalone placeholder image: "origin" is the pixel that sits on the cell centre.
		spr.texture = load(String(d["image"]))
		spr.offset = -Vector2(float(d["origin"][0]), float(d["origin"][1]))
	else:
		spr.texture = load("%s%s_%s.png" % [SPRITE_DIR, d["sprite"], d["dir"]])
		spr.offset = -Iso.SPRITE_ORIGIN
	spr.position = Iso.cell_to_world(Vector2(float(d["cell"][0]), float(d["cell"][1])))
	parent.add_child(spr)
	return spr


func _setup_pathfinding() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cell in solid:
		astar.set_point_solid(cell, true)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not ui.is_open() and not menu.is_open():
			_handle_click(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and not ui.is_open() and not menu.is_open():
			_interact_adjacent()
		elif event.keycode == KEY_F1:
			_overlay.visible = not _overlay.visible
			_overlay.queue_redraw()


func _handle_click(global_pos: Vector2) -> void:
	# Clicking an interactable's visible pixels counts, not just its floor cell.
	for t in click_targets:
		var spr: Sprite2D = t["sprite"]
		var local := spr.to_local(global_pos)
		if spr.get_rect().has_point(local) and spr.is_pixel_opaque(local):
			_go_interact(t["data"])
			return
	var cell := Iso.world_to_cell(to_local(global_pos))
	if not _in_bounds(cell):
		return
	if interactables.has(cell):
		_go_interact(interactables[cell])
	elif not solid.has(cell):
		pending = {}
		_walk_to(cell)


func _interact_adjacent() -> void:
	var here := player_cell()
	for data in _unique_interactables():
		if _adjacent_to(here, _cells_of(data)):
			_open(data)
			return


# --- movement ----------------------------------------------------------------

func player_cell() -> Vector2i:
	var c := Iso.world_to_cell(player.position)
	return Vector2i(clampi(c.x, 0, width - 1), clampi(c.y, 0, height - 1))


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func _walk_to(cell: Vector2i) -> void:
	var path := astar.get_id_path(player_cell(), cell)
	if not path.is_empty():
		_follow(path)


func _follow(path: Array[Vector2i]) -> void:
	var points: Array[Vector2] = []
	for c in path:
		points.append(Iso.cell_to_world(Vector2(c)))
	player.walk(points)


func _go_interact(data: Dictionary) -> void:
	var start := player_cell()
	var cells := _cells_of(data)
	if _adjacent_to(start, cells):
		player.stop()
		_open(data)
		return
	var best: Array[Vector2i] = []
	for c in cells:
		for d in NEIGHBORS:
			var n: Vector2i = c + d
			if not _in_bounds(n) or solid.has(n):
				continue
			var p := astar.get_id_path(start, n)
			if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
				best = p
	if best.is_empty():
		return
	pending = data
	_follow(best)


func _on_player_arrived() -> void:
	if not pending.is_empty():
		var data := pending
		pending = {}
		_open(data)


## What happens when the player interacts with an object, by its "kind":
## "pickup" goes into the inventory and leaves the room, "money" gives cash once,
## anything else (the default, "dialogue") opens the dialogue panel.
func _open(data: Dictionary) -> void:
	pending = {}
	match String(data.get("kind", "dialogue")):
		"pickup":
			_pick_up(data)
		"money":
			_loot_money(data)
		_:
			ui.open(data)


func _pick_up(data: Dictionary) -> void:
	var item_id := String(data["item"])
	Character.add_item(item_id)
	GameState.set_flag("taken:%s" % data["id"])
	_remove_interactable(data)
	ui.toast("Picked up: %s" % Character.item_name(item_id), UIStyle.GOOD)


func _loot_money(data: Dictionary) -> void:
	var key := "looted:%s" % data["id"]
	if GameState.has_flag(key):
		ui.toast("The %s is empty." % String(data["name"]).to_lower(), UIStyle.DIM)
		return
	GameState.set_flag(key)
	var amount := int(data["amount"])
	Character.add_money(amount)
	ui.toast("+%s%d  from the %s" % [Character.currency, amount, String(data["name"]).to_lower()], UIStyle.GOOD)


func _remove_interactable(data: Dictionary) -> void:
	for cell in _cells_of(data):
		interactables.erase(cell)
		solid.erase(cell)
		if astar.is_in_boundsv(cell):
			astar.set_point_solid(cell, false)
	for i in range(click_targets.size() - 1, -1, -1):
		if is_same(click_targets[i]["data"], data):
			click_targets[i]["sprite"].queue_free()
			click_targets.remove_at(i)


func _cells_of(data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in data.get("solid", [data["cell"]]):
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


func _unique_interactables() -> Array:
	var seen: Array = []
	for cell in interactables:
		if not seen.has(interactables[cell]):
			seen.append(interactables[cell])
	return seen


func _adjacent_to(cell: Vector2i, targets: Array[Vector2i]) -> bool:
	for t in targets:
		if maxi(absi(cell.x - t.x), absi(cell.y - t.y)) <= 1:
			return true
	return false


# --- drawing -----------------------------------------------------------------

func _diamond(center: Vector2) -> PackedVector2Array:
	var hw := Iso.TILE_W * 0.5
	var hh := Iso.TILE_H * 0.5
	return PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0),
	])


func _draw_floor(node: Node2D) -> void:
	for y in height:
		for x in width:
			var pts := _diamond(Iso.cell_to_world(Vector2(x, y)))
			node.draw_colored_polygon(pts, FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
			node.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), FLOOR_EDGE, 1.0)


func _draw_debug(node: Node2D) -> void:
	for cell in solid:
		var color := Color(1, 0.85, 0.2, 0.45) if interactables.has(cell) else Color(1, 0.2, 0.2, 0.4)
		node.draw_colored_polygon(_diamond(Iso.cell_to_world(Vector2(cell))), color)
