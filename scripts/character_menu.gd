class_name CharacterMenu
extends CanvasLayer
## HUD (health, morale, money, menu buttons) plus the character sheet (C) and
## the inventory (I), modelled on Disco Elysium's screens.
##
## Character sheet: level and XP bar, skill points, skills in grouped rows with a
## detail pane (learned level, clothing modifiers, learning cap), raise and Revert.
## Inventory: health and morale with healing charges, clothing modifiers, a paper
## doll with named slots, and an items list with Clothes / Other tabs.

const HEALTH_COLOR := Color("#e0554f")
const MORALE_COLOR := Color("#4f9be0")
const PANEL_BG := Color(0.04, 0.07, 0.06, 0.97)

var _root: Control
var _hud_layer: CanvasLayer
var _sheet: PanelContainer
var _sheet_body: VBoxContainer
var _inv: PanelContainer
var _inv_body: VBoxContainer
var _money_label: Label
var _hud_health_pips: HBoxContainer
var _hud_morale_pips: HBoxContainer
var _hud_health_plus: Button
var _hud_morale_plus: Button
var _selected_skill := ""
var _selected_item := ""
var _item_tab := "clothes"


func is_open() -> bool:
	return _sheet.visible or _inv.visible


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.theme = UIStyle.make_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_sheet = _make_screen()
	_sheet_body = _screen_body(_sheet)
	_inv = _make_screen()
	_inv_body = _screen_body(_inv)
	_build_hud()

	_selected_skill = String(Skills.groups[0]["skills"][0])
	Character.changed.connect(_refresh)
	_refresh()


# --- opening and closing -----------------------------------------------------

func open_sheet() -> void:
	_inv.visible = false
	_sheet.visible = true
	_refresh()


func open_inventory() -> void:
	_close_sheet_commit()
	_inv.visible = true
	_refresh()


func close_all() -> void:
	_close_sheet_commit()
	_inv.visible = false


func toggle_sheet() -> void:
	if _sheet.visible:
		close_all()
	else:
		open_sheet()


func toggle_inventory() -> void:
	if _inv.visible:
		close_all()
	else:
		open_inventory()


func _close_sheet_commit() -> void:
	if _sheet.visible:
		Character.commit_pending()
	_sheet.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_C:
			toggle_sheet()
		KEY_I:
			toggle_inventory()
		KEY_ESCAPE:
			if is_open():
				close_all()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


# --- small building blocks ---------------------------------------------------

func _make_screen() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BORDER, PANEL_BG))
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.anchor_left = 0.03
	p.anchor_right = 0.97
	p.anchor_top = 0.06
	p.anchor_bottom = 0.82
	p.offset_left = 0
	p.offset_right = 0
	p.offset_top = 0
	p.offset_bottom = 0
	p.visible = false
	_root.add_child(p)
	return p


func _screen_body(panel: PanelContainer) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	return vb


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _label(text: String, color: Color = UIStyle.FG) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(text: String, color: Color = UIStyle.FG, min_width: float = 300.0) -> Label:
	var l := _label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min_width, 0)
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _kv(key: String, value: String, value_color: Color = UIStyle.FG) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k := _label(key, UIStyle.DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	row.add_child(_label(value, value_color))
	return row


func _signed_color(v: int) -> Color:
	return UIStyle.GOOD if v > 0 else UIStyle.BAD


func _style_button(b: Button, color: Color, selected: bool) -> void:
	var dark := Color(color.r * 0.22, color.g * 0.22, color.b * 0.22)
	var sb := UIStyle.box(color, dark if selected else UIStyle.BG, 3 if selected else 1)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)


# --- HUD ---------------------------------------------------------------------

func _bar_row(title: String, color: Color, kind: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(title, color)
	name_label.custom_minimum_size = Vector2(84, 0)
	row.add_child(name_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	var plus := Button.new()
	plus.pressed.connect(func() -> void: Character.heal(kind))
	row.add_child(plus)
	return [row, pips, plus]


func _fill_pips(pips: HBoxContainer, current: int, maximum: int, color: Color) -> void:
	_clear(pips)
	for i in maximum:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(12, 18)
		r.color = color if i < current else color.darkened(0.75)
		pips.add_child(r)


func _update_bars(health_pips: HBoxContainer, health_plus: Button, morale_pips: HBoxContainer, morale_plus: Button) -> void:
	_fill_pips(health_pips, Character.health(), Character.max_health(), HEALTH_COLOR)
	_fill_pips(morale_pips, Character.morale(), Character.max_morale(), MORALE_COLOR)
	health_plus.text = "+%d" % Character.health_charges
	health_plus.disabled = Character.health_charges <= 0
	morale_plus.text = "+%d" % Character.morale_charges
	morale_plus.disabled = Character.morale_charges <= 0


func _build_hud() -> void:
	# Health and morale live on a low layer so dialogue and menu windows draw over them.
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	var hud_root := Control.new()
	hud_root.theme = UIStyle.make_theme()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(hud_root)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.DIM.darkened(0.3), Color(0.04, 0.07, 0.06, 0.88), 1))
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_root.add_child(box)
	var vb := VBoxContainer.new()
	box.add_child(vb)
	var h := _bar_row("HEALTH", HEALTH_COLOR, "health")
	var m := _bar_row("MORALE", MORALE_COLOR, "morale")
	vb.add_child(h[0])
	vb.add_child(m[0])
	_hud_health_pips = h[1]
	_hud_health_plus = h[2]
	_hud_morale_pips = m[1]
	_hud_morale_plus = m[2]

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(bar)
	var char_button := Button.new()
	char_button.text = "CHARACTER [C]"
	char_button.pressed.connect(toggle_sheet)
	bar.add_child(char_button)
	var inv_button := Button.new()
	inv_button.text = "INVENTORY [I]"
	inv_button.pressed.connect(toggle_inventory)
	bar.add_child(inv_button)

	_money_label = _label("", UIStyle.FG)
	_money_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_money_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_money_label)


# --- refresh -----------------------------------------------------------------

func _refresh() -> void:
	_money_label.text = "%s%d" % [Character.currency, Character.money]
	_update_bars(_hud_health_pips, _hud_health_plus, _hud_morale_pips, _hud_morale_plus)
	if _sheet.visible:
		_refresh_sheet()
	if _inv.visible:
		_refresh_inventory()


# --- character sheet ---------------------------------------------------------

func _refresh_sheet() -> void:
	_clear(_sheet_body)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_sheet_body.add_child(head)
	head.add_child(_label("> CHARACTER.EXE", UIStyle.BORDER))
	head.add_child(_spacer())
	head.add_child(_label("LEVEL %d" % Character.level))
	var needed := Character.xp_needed()
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxf(float(needed), 1.0)
	bar.value = float(Character.xp) if needed > 0 else bar.max_value
	bar.add_theme_stylebox_override("background", UIStyle.box(UIStyle.DIM.darkened(0.4), UIStyle.BG, 1))
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.BORDER
	bar.add_theme_stylebox_override("fill", fill)
	head.add_child(bar)
	head.add_child(_label("XP %d / %d" % [Character.xp, needed] if needed > 0 else "XP MAX", UIStyle.DIM))
	head.add_child(_label("SKILL POINTS: %d" % Character.skill_points, UIStyle.GOOD if Character.skill_points > 0 else UIStyle.DIM))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_body.add_child(body)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rows)
	for g in Skills.groups:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		var title := VBoxContainer.new()
		title.custom_minimum_size = Vector2(125, 0)
		title.add_child(_label(String(g["name"]).to_upper(), g["color"]))
		var cap_text := "cap %d" % (int(g["score"]) + (1 if _signature_in_group(g) else 0))
		title.add_child(_label(cap_text, UIStyle.DIM))
		row.add_child(title)
		for id in g["skills"]:
			row.add_child(_skill_tile(id, g["color"]))

	body.add_child(_skill_details())


func _signature_in_group(g: Dictionary) -> bool:
	return Character.signature_skill != "" and g["skills"].has(Character.signature_skill)


func _skill_tile(id: String, color: Color) -> Button:
	var b := Button.new()
	var total := Skills.get_level(id)
	var base := Skills.get_base_level(id)
	b.text = "%s  %d%s" % [Skills.skill_name(id), total, "  +" if Character.can_raise(id) else ""]
	b.custom_minimum_size = Vector2(120, 52)
	b.add_theme_font_size_override("font_size", 14)
	_style_button(b, color, id == _selected_skill)
	var text_color := UIStyle.FG
	if total > base:
		text_color = UIStyle.GOOD
	elif total < base:
		text_color = UIStyle.BAD
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.pressed.connect(func() -> void:
		_selected_skill = id
		_refresh())
	return b


func _skill_details() -> PanelContainer:
	var id := _selected_skill
	var s: Dictionary = Skills.skills[id]
	var color: Color = s["color"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.box(color))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	vb.add_child(_label(String(s["name"]).to_upper(), color))
	vb.add_child(_label("%s  |  learning cap %d" % [String(s["group"]), Character.skill_cap(id)], UIStyle.DIM))
	vb.add_child(_wrap(String(s["description"]), UIStyle.FG, 290))
	vb.add_child(_wrap("\"%s\"" % String(s["voice"]), UIStyle.DIM, 290))
	vb.add_child(HSeparator.new())
	vb.add_child(_kv("Learned", str(Skills.get_base_level(id))))
	for src in Character.bonus_sources(id):
		vb.add_child(_kv(String(src["name"]), "%+d" % int(src["value"]), _signed_color(int(src["value"]))))
	vb.add_child(_kv("Total", str(Skills.get_level(id))))
	vb.add_child(Control.new())

	var raise_button := Button.new()
	raise_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if Character.can_raise(id):
		raise_button.text = "[+] RAISE  (1 skill point)"
		raise_button.pressed.connect(func() -> void: Character.raise_skill(id))
	else:
		raise_button.disabled = true
		raise_button.text = "At learning cap" if Skills.get_base_level(id) >= Character.skill_cap(id) else "No skill points"
	vb.add_child(raise_button)

	var revert := Button.new()
	revert.alignment = HORIZONTAL_ALIGNMENT_LEFT
	revert.text = "[Revert]"
	revert.disabled = not Character.has_pending()
	revert.pressed.connect(Character.revert_pending)
	vb.add_child(revert)
	return panel


# --- inventory ---------------------------------------------------------------

func _refresh_inventory() -> void:
	_clear(_inv_body)

	var head := HBoxContainer.new()
	_inv_body.add_child(head)
	head.add_child(_label("> INVENTORY.EXE", UIStyle.BORDER))
	head.add_child(_spacer())
	head.add_child(_label("MONEY: %s%d" % [Character.currency, Character.money]))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_body.add_child(body)

	body.add_child(_inventory_left())
	body.add_child(_paper_doll())
	body.add_child(_inventory_right())


func _inventory_left() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(290, 0)
	var h := _bar_row("HEALTH", HEALTH_COLOR, "health")
	var m := _bar_row("MORALE", MORALE_COLOR, "morale")
	_update_bars(h[1], h[2], m[1], m[2])
	vb.add_child(h[0])
	vb.add_child(m[0])
	vb.add_child(HSeparator.new())
	vb.add_child(_label("CLOTHING MODIFIERS", UIStyle.BORDER))
	var mods := Character.total_modifiers()
	if mods.is_empty():
		vb.add_child(_label("none", UIStyle.DIM))
	for skill_id in mods:
		var v: int = mods[skill_id]
		vb.add_child(_label("%+d %s" % [v, Skills.skill_name(skill_id)], _signed_color(v)))
	return vb


func _paper_doll() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key in ["headgear", "eyewear", "neckwear", "jacket", "FIGURE", "shirt", "gloves", "pants", "shoes"]:
		if key == "FIGURE":
			grid.add_child(_figure())
		else:
			grid.add_child(_slot_button(key))
	return grid


func _figure() -> Control:
	var fig := Control.new()
	fig.custom_minimum_size = Vector2(156, 76)
	fig.draw.connect(func() -> void:
		fig.draw_rect(Rect2(60, 28, 36, 44), Color("#d8d2b8"))
		fig.draw_circle(Vector2(78, 18), 11.0, Color("#d8d2b8"))
		fig.draw_rect(Rect2(60, 40, 36, 4), Color("#ff4fa3")))
	return fig


func _slot_button(slot: String) -> Button:
	var b := Button.new()
	var item_id := String(Character.equipment.get(slot, ""))
	var label := String(Character.SLOT_LABELS[slot]).to_upper()
	b.text = "%s\n%s" % [label, Character.item_name(item_id) if item_id != "" else "- empty -"]
	b.custom_minimum_size = Vector2(156, 76)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 14)
	_style_button(b, UIStyle.BORDER if item_id != "" else UIStyle.DIM, item_id != "" and item_id == _selected_item)
	if item_id == "":
		b.add_theme_color_override("font_color", UIStyle.DIM)
	b.pressed.connect(func() -> void:
		if item_id != "":
			_selected_item = item_id
			_item_tab = "clothes"
			_refresh())
	return b


func _inventory_right() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	for tab in ["clothes", "other"]:
		var tb := Button.new()
		tb.text = tab.to_upper()
		_style_button(tb, UIStyle.BORDER, tab == _item_tab)
		tb.pressed.connect(func() -> void:
			_item_tab = tab
			_refresh())
		tabs.add_child(tb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var ids := Character.owned_items(_item_tab)
	if ids.is_empty():
		list.add_child(_label("nothing here", UIStyle.DIM))
	for id in ids:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s%s" % [Character.item_name(id), "   [worn]" if Character.is_worn(id) else ""]
		_style_button(b, UIStyle.BORDER, id == _selected_item)
		b.pressed.connect(func() -> void:
			_selected_item = id
			_refresh())
		list.add_child(b)

	vb.add_child(_item_details())
	return vb


func _item_details() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 170)
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.DIM))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	if _selected_item == "" or not Character.items.has(_selected_item):
		vb.add_child(_label("Select an item.", UIStyle.DIM))
		return panel
	var item: Dictionary = Character.items[_selected_item]
	vb.add_child(_label(String(item["name"]).to_upper(), UIStyle.BORDER))
	if item["type"] == "clothes":
		vb.add_child(_label(String(Character.SLOT_LABELS[item["slot"]]), UIStyle.DIM))
	vb.add_child(_wrap(String(item["description"]), UIStyle.FG, 280))
	for skill_id in item.get("modifiers", {}):
		var v := int(item["modifiers"][skill_id])
		vb.add_child(_label("%+d %s" % [v, Skills.skill_name(skill_id)], _signed_color(v)))
	if item["type"] == "clothes":
		var id := _selected_item
		var action := Button.new()
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if Character.is_worn(id):
			action.text = "[Unequip]"
			action.pressed.connect(func() -> void: Character.unequip(String(item["slot"])))
		else:
			action.text = "[Equip]"
			action.pressed.connect(func() -> void: Character.equip(id))
		vb.add_child(action)
	return panel
