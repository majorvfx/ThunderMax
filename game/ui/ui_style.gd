class_name UiStyle
extends RefCounted
## Shared look for menus: night-blue panels, neon edges, cold white text (see Neon).

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Neon.PANEL
	panel.border_color = Color(Neon.MAGENTA, 0.85)
	panel.set_border_width_all(2)
	panel.shadow_color = Color(Neon.MAGENTA, 0.25)
	panel.shadow_size = 8
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.05, 0.14)
	normal.border_color = Color(0.3, 0.2, 0.5)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.32, 0.04, 0.26)
	focus.border_color = Neon.CYAN
	focus.set_border_width_all(2)
	focus.shadow_color = Color(Neon.CYAN, 0.35)
	focus.shadow_size = 6
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("pressed", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Neon.INK)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", Neon.INK)
	var slider_focus := StyleBoxFlat.new()
	slider_focus.bg_color = Color(0, 0, 0, 0)
	slider_focus.border_color = Neon.CYAN
	slider_focus.set_border_width_all(2)
	t.set_stylebox("focus", "HSlider", slider_focus)
	_theme = t
	return t


static func label(text: String, size: int = 20, color: Color = Neon.INK) -> Label:
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


## A heading in the slanted display face, with a soft neon outline.
static func heading(text: String, size: int, color: Color = Neon.MAGENTA) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", Neon.display_font())
	l.add_theme_color_override("font_outline_color", Color(color, 0.3))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	return l
