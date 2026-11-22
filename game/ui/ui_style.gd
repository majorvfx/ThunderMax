class_name UiStyle
extends RefCounted
## Shared look for menus: stamped steel plates with rust edges and a hazard-amber
## top lip, bone-white stencil text, rust-red accents.

const INK := Color(0.9, 0.86, 0.78)        ## bone-white text
const DIM := Color(0.6, 0.55, 0.5)         ## secondary text
const RUST := Color(0.72, 0.22, 0.09)      ## rust-red accent
const HAZARD := Color(0.95, 0.6, 0.18)     ## hazard amber
const SOOT := Color(0.035, 0.03, 0.025)    ## deepest background

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.095, 0.085, 0.95)   # dull steel plate
	panel.border_color = Color(0.45, 0.22, 0.1)
	panel.set_border_width_all(2)
	panel.border_width_top = 5
	panel.set_corner_radius_all(1)
	panel.shadow_color = Color(0, 0, 0, 0.6)
	panel.shadow_size = 6
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.14, 0.125)
	normal.border_color = Color(0.32, 0.2, 0.12)
	normal.set_border_width_all(1)
	normal.border_width_bottom = 3
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.4, 0.17, 0.07)
	focus.border_color = Color(0.95, 0.6, 0.2)
	focus.set_border_width_all(2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("pressed", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.9, 0.86, 0.78))
	t.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_color", "Label", Color(0.9, 0.86, 0.78))
	var slider_focus := StyleBoxFlat.new()
	slider_focus.bg_color = Color(0, 0, 0, 0)
	slider_focus.border_color = Color(0.95, 0.6, 0.2)
	slider_focus.set_border_width_all(2)
	t.set_stylebox("focus", "HSlider", slider_focus)
	_theme = t
	return t


static func label(text: String, size: int = 20, color: Color = Color(0.9, 0.86, 0.78)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(320, 0)
	b.pressed.connect(on_press)
	b.pressed.connect(func(): GameAudio.play_ui("ui_click", 0.6))
	return b


## A strip of yellow-and-black hazard stripes, like the tape on a loading dock.
static func hazard_strip(height: float = 14.0) -> Control:
	var strip := HazardStrip.new()
	strip.custom_minimum_size = Vector2(0, height)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return strip


class HazardStrip extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.04))
		var x := -h
		var dark := Color(0.08, 0.07, 0.05)
		var amber := Color(0.78, 0.55, 0.14)
		while x < size.x + h:
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h * 1.8, 0), Vector2(x + h * 0.8, h)]), amber)
			x += h * 2.0
		# Grime: the paint is worn darker along the bottom edge.
		draw_rect(Rect2(0, h * 0.7, size.x, h * 0.3), Color(dark, 0.45))
