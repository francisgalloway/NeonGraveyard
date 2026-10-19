class_name ContainerUI
extends CanvasLayer
## Pop-up for "container" objects: the container's contents on the left, the
## player's inventory on the right. Click an item to move it to the other side.

const PANEL_BG := Color(0.04, 0.07, 0.06, 0.97)

var _root: Control
var _panel: PanelContainer
var _title: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _data: Dictionary = {}


func is_open() -> bool:
	return _panel.visible


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.theme = UIStyle.make_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BORDER, PANEL_BG))
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 0.12
	_panel.anchor_bottom = 0.78
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	_panel.visible = false
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	_title = Label.new()
	_title.add_theme_color_override("font_color", UIStyle.BORDER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var take_all := Button.new()
	take_all.text = "TAKE ALL"
	take_all.pressed.connect(_take_all)
	head.add_child(take_all)
	var close := Button.new()
	close.text = "CLOSE [Esc]"
	close.pressed.connect(close_window)
	head.add_child(close)
	vb.add_child(head)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	vb.add_child(cols)
	_left = _column(cols, "CONTAINS")
	_right = _column(cols, "YOUR INVENTORY")
	vb.add_child(_hint())
	Character.changed.connect(_refresh)


func _hint() -> Label:
	var l := Label.new()
	l.text = "Click an item to move it to the other side."
	l.add_theme_color_override("font_color", UIStyle.DIM)
	return l


func _column(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var h := Label.new()
	h.name = "Head"
	h.text = title
	h.add_theme_color_override("font_color", UIStyle.DIM)
	box.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	parent.add_child(box)
	return list


func open(data: Dictionary) -> void:
	_data = data
	_title.text = String(data["name"]).to_upper()
	_panel.visible = true
	_refresh()


func close_window() -> void:
	_panel.visible = false
	_data = {}


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_window()
		get_viewport().set_input_as_handled()


func take(item_id: String) -> bool:
	if _data.is_empty():
		return false
	var contents := GameState.container_items(_data)
	var i := contents.find(item_id)
	if i < 0 or not Character.add_item(item_id):
		return false
	contents.remove_at(i)
	_refresh()
	return true


func store(item_id: String) -> bool:
	if _data.is_empty() or not Character.remove_item(item_id):
		return false
	GameState.container_items(_data).append(item_id)
	_refresh()
	return true


func _take_all() -> void:
	if _data.is_empty():
		return
	for id in GameState.container_items(_data).duplicate():
		take(id)


func _refresh() -> void:
	if not is_open():
		return
	_fill(_left, GameState.container_items(_data), "(empty)", take, "TAKE")
	_fill(_right, Character.inventory, "(nothing carried)", store, "STORE")


func _fill(list: VBoxContainer, ids: Array, empty_text: String, action: Callable, verb: String) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if ids.is_empty():
		var l := Label.new()
		l.text = empty_text
		l.add_theme_color_override("font_color", UIStyle.DIM)
		list.add_child(l)
		return
	for id in ids:
		var b := Button.new()
		b.text = "%s   [%s]" % [Character.item_name(String(id)), verb]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(Character.items[id]["description"])
		b.pressed.connect(action.bind(String(id)))
		list.add_child(b)
