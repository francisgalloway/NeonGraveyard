class_name DialogueUI
extends CanvasLayer
## DOS-style dialogue panel with inner-voice "windows", plus a skill sheet (Tab).
##
## open(data) takes an interactable dictionary (see data/interactables/*.json):
## shows the intro, fires any passive checks that pass as voice windows, then
## lists the active checks as choices with their success chance.

signal closed

const BG := Color("#0b130f")
const FG := Color("#b8f5c8")
const DIM := Color("#6e9a7c")
const BORDER := Color("#3fb06a")

var _theme := Theme.new()
var _root: Control
var _panel: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _log: VBoxContainer
var _choices: VBoxContainer
var _sheet: PanelContainer
var _data: Dictionary = {}
var _is_open := false


func is_open() -> bool:
	return _is_open


func _ready() -> void:
	layer = 10
	_build_theme()
	_root = Control.new()
	_root.theme = _theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_dialogue()
	_build_sheet()
	_build_hint()


# --- building the UI ---------------------------------------------------------

func _box(border: Color, bg: Color = BG, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb


func _build_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_theme.default_font = font
	_theme.default_font_size = 16
	_theme.set_color("font_color", "Label", FG)
	_theme.set_color("font_color", "Button", FG)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", DIM)
	_theme.set_stylebox("normal", "Button", _box(DIM.darkened(0.4), BG, 1))
	_theme.set_stylebox("hover", "Button", _box(BORDER, Color("#12261b"), 1))
	_theme.set_stylebox("pressed", "Button", _box(BORDER, Color("#1a3a28"), 1))
	_theme.set_stylebox("disabled", "Button", _box(Color("#2a3a30"), BG, 1))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())


func _build_dialogue() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(BORDER))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.02
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.07
	_panel.anchor_bottom = 0.97
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	_panel.visible = false
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	_title = Label.new()
	_title.add_theme_color_override("font_color", BORDER)
	vb.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)

	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 8)
	_scroll.add_child(_log)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	vb.add_child(_choices)


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", _box(BORDER))
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	_sheet.visible = false
	_root.add_child(_sheet)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_sheet.add_child(outer)
	var head := Label.new()
	head.text = "> SKILLS.EXE   [Tab] close"
	head.add_theme_color_override("font_color", BORDER)
	outer.add_child(head)

	var cols := GridContainer.new()
	cols.columns = 3
	cols.add_theme_constant_override("h_separation", 40)
	cols.add_theme_constant_override("v_separation", 16)
	outer.add_child(cols)
	for g in Skills.groups:
		var col := VBoxContainer.new()
		cols.add_child(col)
		var gl := Label.new()
		gl.text = String(g["name"]).to_upper()
		gl.add_theme_color_override("font_color", g["color"])
		col.add_child(gl)
		for id in g["skills"]:
			var row := HBoxContainer.new()
			col.add_child(row)
			var n := Label.new()
			n.text = Skills.skill_name(id)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.tooltip_text = String(Skills.skills[id]["description"])
			row.add_child(n)
			var lv := Label.new()
			lv.text = str(Skills.get_level(id))
			lv.add_theme_color_override("font_color", g["color"])
			row.add_child(lv)


func _build_hint() -> void:
	var hint := Label.new()
	hint.text = "LMB: move / examine    E: examine adjacent    Tab: skills    F1: debug grid    Esc: close"
	hint.add_theme_color_override("font_color", DIM)
	hint.position = Vector2(12, 8)
	_root.add_child(hint)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_sheet.visible = not _sheet.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_open:
			close()
			get_viewport().set_input_as_handled()


# --- dialogue ----------------------------------------------------------------

func open(data: Dictionary) -> void:
	_data = data
	_is_open = true
	for c in _log.get_children():
		c.queue_free()
	_title.text = "> %s" % String(data["name"]).to_upper()
	_panel.visible = true
	_add_text(String(data["intro"]))
	_run_passives()
	_rebuild_choices()
	_scroll_to_bottom()


func close() -> void:
	_is_open = false
	_panel.visible = false
	closed.emit()


func _run_passives() -> void:
	var i := 0
	for p in _data.get("passives", []):
		var key := "passive:%s:%d" % [_data["id"], i]
		i += 1
		if GameState.has_flag(key):
			continue
		var target := Skills.target_for(p["difficulty"])
		if Skills.passes_passive(p["skill"], target):
			GameState.set_flag(key)
			_add_voice(p["skill"], "Passive: %s %d" % [Skills.difficulty_label(target), target], String(p["line"]))


func _rebuild_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	for a in _data.get("actives", []):
		var skill: String = a["skill"]
		var key := "%s:%s" % [_data["id"], a["id"]]
		var red: bool = a.get("red", false)
		var target := Skills.target_for(a["difficulty"])
		var attempted: bool = GameState.check_log.has(key)
		if attempted and GameState.check_log[key]["success"]:
			continue
		var pct := roundi(Skills.success_chance(Skills.get_level(skill), target) * 100.0)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "[%s - %s %d - %d%% - %s] %s" % [
			Skills.skill_name(skill), Skills.difficulty_label(target), target, pct,
			"Red" if red else "White", a["label"]]
		if GameState.can_attempt(key, skill, red):
			b.pressed.connect(_attempt.bind(a))
		else:
			b.disabled = true
			b.text += "   (failed: %s)" % ("locked for good" if red else "retry when %s improves" % Skills.skill_name(skill))
		_choices.add_child(b)
	var leave := Button.new()
	leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	leave.text = "[Leave]"
	leave.pressed.connect(close)
	_choices.add_child(leave)


func _attempt(a: Dictionary) -> void:
	var skill: String = a["skill"]
	var target := Skills.target_for(a["difficulty"])
	var r := Skills.roll_active(skill, target)
	var ok: bool = r["success"]
	GameState.record_attempt("%s:%s" % [_data["id"], a["id"]], skill, ok)
	var d: Array = r["dice"]
	var roll_text := "Roll: %d + %d + %s %d = %d vs %d" % [d[0], d[1], Skills.skill_name(skill), r["level"], r["total"], target]
	if r["auto"] == "success":
		roll_text += "  (double six: automatic success)"
	elif r["auto"] == "fail":
		roll_text += "  (double one: automatic failure)"
	_add_text("> %s" % String(a["label"]), DIM)
	_add_voice(skill, "Active: %s %d - %s" % [Skills.difficulty_label(target), target, "SUCCESS" if ok else "FAILURE"],
		"%s\n%s" % [String(a["success"] if ok else a["failure"]), roll_text])
	_rebuild_choices()
	_scroll_to_bottom()


func _add_text(text: String, color: Color = FG) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	_log.add_child(l)


func _add_voice(skill: String, tag: String, line: String) -> void:
	var c := Skills.skill_color(skill)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _box(c, Color(c.r * 0.12, c.g * 0.12, c.b * 0.12), 2))
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var head := Label.new()
	head.text = "%s.EXE  [%s]" % [Skills.skill_name(skill).to_upper(), tag]
	head.add_theme_color_override("font_color", c)
	vb.add_child(head)
	var body := Label.new()
	body.text = line
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(300, 0)
	vb.add_child(body)
	_log.add_child(pc)


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
