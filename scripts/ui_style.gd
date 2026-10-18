class_name UIStyle
extends RefCounted
## Shared colours and theme for the late-90s terminal look.

const BG := Color("#0b130f")
const FG := Color("#b8f5c8")
const DIM := Color("#6e9a7c")
const BORDER := Color("#3fb06a")
const GOOD := Color("#7fe08f")
const BAD := Color("#e0705f")


static func box(border: Color, bg: Color = BG, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", FG)
	theme.set_color("font_color", "Button", FG)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", DIM)
	theme.set_stylebox("normal", "Button", box(DIM.darkened(0.4), BG, 1))
	theme.set_stylebox("hover", "Button", box(BORDER, Color("#12261b"), 1))
	theme.set_stylebox("pressed", "Button", box(BORDER, Color("#1a3a28"), 1))
	theme.set_stylebox("disabled", "Button", box(Color("#2a3a30"), BG, 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return theme
