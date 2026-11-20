class_name TitleScreen
extends Control
## Title card: a dead city's idea of tomorrow. A banded sun sinking behind a
## jagged ridge, a neon grid rolling toward you, ash drifting up, chrome lettering.
## A or Enter starts.

signal start_pressed

const HORIZON := 0.62          ## horizon height as a fraction of the screen
const GRID_SPEED := 0.55       ## grid rows per second
const DEAD_LINES := [-5, 2, 7] ## grid columns that flicker like failing tubes

var _status: Label
var _prompt: Label
var _title: Label
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array[Vector3] = []   ## x, y as screen fractions; z = brightness
var _ridge: Array[Vector2] = []   ## x fraction, height in horizon units
var _ash: Array[Vector3] = []     ## x, y fractions; z = speed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	_rng.seed = 1984
	for i in 90:
		_stars.append(Vector3(_rng.randf(), _rng.randf() * HORIZON * 0.7, _rng.randf_range(0.25, 1.0)))
	var x := 0.0
	while x < 1.0:
		_ridge.append(Vector2(x, _rng.randf_range(0.02, 0.09) if _ridge.size() % 2 == 1 else _rng.randf_range(0.0, 0.03)))
		x += _rng.randf_range(0.025, 0.07)
	_ridge.append(Vector2(1.0, 0.01))
	for i in 40:
		_ash.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.015, 0.05)))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.anchor_top = 0.3
	col.anchor_bottom = 0.3
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	_title = _chrome_label("THUNDER MAX", 104)
	col.add_child(_title)
	var sub := UiStyle.heading("METAL  ROAD", 46, Neon.CYAN)
	sub.add_theme_font_override("font", Neon.display_font(0.18, 14))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var low := VBoxContainer.new()
	low.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	low.anchor_top = 0.82
	low.anchor_bottom = 0.82
	low.grow_horizontal = Control.GROW_DIRECTION_BOTH
	low.grow_vertical = Control.GROW_DIRECTION_BOTH
	low.alignment = BoxContainer.ALIGNMENT_CENTER
	low.add_theme_constant_override("separation", 6)
	add_child(low)
	var tag := UiStyle.label("The road only goes one way.", 20, Color(Neon.INK, 0.8))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(tag)
	low.add_child(tag)
	_prompt = UiStyle.heading("PRESS A OR ENTER", 30, Neon.AMBER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	low.add_child(_prompt)
	_status = UiStyle.label("", 16, Neon.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_status)
	low.add_child(_status)

	var build := UiStyle.label("Milestone 2 build  -  placeholder art and audio", 14, Color(Neon.DIM, 0.8))
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build.position = Vector2(16, -30)
	_shadowed(build)
	add_child(build)
	_refresh_status()
	Input.joy_connection_changed.connect(func(_d, _c): _refresh_status())


## Chrome lettering: sky-blue to white above a hard horizon line, dusk below,
## with a magenta tube edge and a cyan drop glow.
func _chrome_label(text: String, font_size: int) -> Label:
	var l := UiStyle.label(text, font_size, Color.WHITE)
	var font := Neon.display_font(0.2, 4)
	l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Neon.MAGENTA)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_shadow_color", Color(Neon.CYAN, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.add_theme_constant_override("shadow_outline_size", 10)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float y_top = 0.0;
uniform float y_bottom = 100.0;
varying float local_y;
varying vec4 vcol;

void vertex() {
	local_y = VERTEX.y;
	vcol = COLOR;
}

void fragment() {
	// Only the white fill turns to chrome; outline and glow keep their colour.
	float fill = step(0.95, min(vcol.r, min(vcol.g, vcol.b)));
	float t = clamp((local_y - y_top) / (y_bottom - y_top), 0.0, 1.0);
	vec3 upper = mix(vec3(0.45, 0.8, 1.0), vec3(1.0), smoothstep(0.0, 0.5, t));
	vec3 lower = mix(vec3(0.16, 0.04, 0.28), vec3(1.0, 0.5, 0.78), smoothstep(0.54, 1.0, t));
	vec3 chrome = t < 0.52 ? upper : lower;
	chrome += vec3(1.0) * smoothstep(0.03, 0.0, abs(t - 0.53)) * 0.8;
	COLOR.rgb = mix(COLOR.rgb, chrome, fill);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var ascent := font.get_ascent(font_size)
	mat.set_shader_parameter("y_top", ascent - font_size * 0.74)
	mat.set_shader_parameter("y_bottom", ascent)
	l.material = mat
	return l


func _shadowed(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)


func _refresh_status() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_status.text = "No controller found. Keyboard works; plug in a pad any time."
	else:
		_status.text = "Controller: %s" % Input.get_joy_name(pads[0])


func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	for i in _ash.size():
		var a := _ash[i]
		a.y -= a.z * delta
		a.x += sin(_time * 0.7 + i) * 0.004 * delta
		if a.y < 0.0:
			a = Vector3(_rng.randf(), 1.0, _rng.randf_range(0.015, 0.05))
		_ash[i] = a
	queue_redraw()


func _draw() -> void:
	var s := size
	var hy := s.y * HORIZON
	# Sky: night overhead, bruised violet, a magenta smear at the horizon.
	var mid_y := hy * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([Neon.NIGHT, Neon.NIGHT, Color(0.16, 0.03, 0.24), Color(0.16, 0.03, 0.24)]))
	draw_polygon(PackedVector2Array([Vector2(0, mid_y), Vector2(s.x, mid_y), Vector2(s.x, hy), Vector2(0, hy)]),
		PackedColorArray([Color(0.16, 0.03, 0.24), Color(0.16, 0.03, 0.24), Color(0.8, 0.13, 0.4), Color(0.8, 0.13, 0.4)]))
	for st in _stars:
		var twinkle := 0.6 + 0.4 * sin(_time * 2.0 + st.x * 40.0)
		draw_rect(Rect2(Vector2(st.x * s.x, st.y * s.y), Vector2(2, 2)), Color(1, 1, 1, st.z * twinkle * 0.8))

	# The sun: warm glow, then the disc, banded across its lower half.
	var r := s.y * 0.24
	var c := Vector2(s.x * 0.5, hy - r * 0.42)
	for k in 4:
		draw_circle(c, r * (1.15 + 0.22 * k), Color(1.0, 0.2, 0.5, 0.07))
	var row := -r
	while row < r:
		var v := (row + r) / (2.0 * r)
		var keep := true
		if v > 0.45:
			var u := (v - 0.45) / 0.55
			keep = fmod(u * 7.0 + _time * 0.15, 1.0) > lerpf(0.12, 0.6, u)
		if keep:
			var half := sqrt(maxf(r * r - row * row, 0.0))
			var col := Color(1.0, 0.86, 0.3).lerp(Color(1.0, 0.16, 0.55), smoothstep(0.1, 0.95, v))
			draw_line(Vector2(c.x - half, c.y + row), Vector2(c.x + half, c.y + row), col, 2.0)
		row += 2.0

	# A jagged ridge in front of the sun, edged in cyan.
	var ridge := PackedVector2Array()
	for p in _ridge:
		ridge.append(Vector2(p.x * s.x, hy - p.y * s.y))
	var fill := ridge.duplicate()
	fill.append(Vector2(s.x, hy + 1))
	fill.append(Vector2(0, hy + 1))
	draw_colored_polygon(fill, Color(0.05, 0.02, 0.1))
	draw_polyline(ridge, Color(Neon.CYAN, 0.85), 2.0, true)

	# Ground: a neon grid rolling in, some of it failing.
	draw_rect(Rect2(0, hy, s.x, s.y - hy), Color(0.03, 0.01, 0.06))
	var ground := s.y - hy
	var phase := fmod(_time * GRID_SPEED, 1.0)
	for k in 40:
		var z := float(k) + 1.0 - phase
		if z < 0.35:
			continue
		var y := hy + ground * (0.35 / z)
		var a := clampf((y - hy) / (ground * 0.25), 0.0, 1.0)
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(Neon.MAGENTA, 0.75 * a), 2.0)
	var vp := Vector2(s.x * 0.5, hy)
	for i in range(-14, 15):
		var a := 0.8
		if DEAD_LINES.has(i):
			a *= 0.15 if sin(_time * 23.0 + i * 3.1) > 0.3 else 0.9
		var foot := Vector2(s.x * 0.5 + i * s.x * 0.11, s.y)
		draw_line(vp, foot, Color(Neon.MAGENTA, a * 0.75), 2.0, true)
	draw_line(Vector2(0, hy), Vector2(s.x, hy), Color(1.0, 0.55, 0.8), 3.0)

	# Ash and embers drifting up from somewhere you can't see.
	for i in _ash.size():
		var e := _ash[i]
		var ember := i % 5 == 0
		var col := Color(Neon.AMBER, 0.8) if ember else Color(0.7, 0.65, 0.8, 0.35)
		draw_rect(Rect2(Vector2(e.x * s.x, e.y * s.y), Vector2(3, 3) if ember else Vector2(2, 2)), col)

	# Scanlines: it's being shown on a set nobody has fixed.
	var y2 := 0.0
	while y2 < s.y:
		draw_line(Vector2(0, y2), Vector2(s.x, y2), Color(0, 0, 0, 0.16), 1.0)
		y2 += 3.0


func _unhandled_input(event: InputEvent) -> void:
	var go := event.is_action_pressed("ui_accept")
	go = go or event.is_action_pressed(InputSetup.action(1, "pause"))
	go = go or event.is_action_pressed(InputSetup.action(1, "view_mod"))
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		GameAudio.play_ui("ui_click", 0.8)
		start_pressed.emit()
