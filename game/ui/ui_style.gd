class_name UiStyle
extends RefCounted
## Shared look for menus: dark panels, rust edges, bone-white text.

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.05, 0.045, 0.94)
	panel.border_color = Color(0.45, 0.22, 0.1)
	panel.set_border_width_all(2)
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.1, 0.08)
	normal.border_color = Color(0.3, 0.17, 0.09)
	normal.set_border_width_all(1)
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
