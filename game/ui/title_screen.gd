class_name TitleScreen
extends Control
## Title card: IRON CARNAGE stencilled on a scratched steel plate between two
## strips of hazard tape, smoke drifting up from below. A or Enter starts.

signal start_pressed

var _status: Label
var _prompt: Label
var _time := 0.0
var _smoke: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.85, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.045, 0.04), Color(0.11, 0.08, 0.055), Color(0.26, 0.11, 0.04), Color(0.45, 0.17, 0.04)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 256
	bg.texture = gt
	add_child(bg)
	# Slow smoke columns rising from the fires below the frame.
	var pg := Gradient.new()
	pg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	pg.colors = PackedColorArray([Color(0.02, 0.018, 0.015, 0.55), Color(0.02, 0.018, 0.015, 0.25), Color(0.02, 0.018, 0.015, 0.0)])
	var puff_tex := GradientTexture2D.new()
	puff_tex.gradient = pg
	puff_tex.fill = GradientTexture2D.FILL_RADIAL
	puff_tex.fill_from = Vector2(0.5, 0.5)
	puff_tex.fill_to = Vector2(0.5, 0.0)
	puff_tex.width = 128
	puff_tex.height = 128
	for i in 12:
		var puff := TextureRect.new()
		puff.texture = puff_tex
		puff.stretch_mode = TextureRect.STRETCH_SCALE
		puff.size = Vector2(340, 340) * (0.8 + 0.15 * (i % 4))
		puff.position = Vector2(-120 + (i % 6) * 250, 360 + 200 * (i / 6))
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(puff)
		_smoke.append(puff)

	var top := UiStyle.hazard_strip(18)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 18
	add_child(top)
	var bottom := UiStyle.hazard_strip(18)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -18
	add_child(bottom)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var plate := PanelContainer.new()
	col.add_child(plate)
	var plate_col := VBoxContainer.new()
	plate_col.add_theme_constant_override("separation", 0)
	plate.add_child(plate_col)
	var title := UiStyle.label("IRON CARNAGE", 104, UiStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.08, 0.03))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 6)
	plate_col.add_child(title)
	var bar := UiStyle.hazard_strip(10)
	plate_col.add_child(bar)
	var sub := UiStyle.label("THE LAST FUEL IN THE RUST BELT", 30, UiStyle.HAZARD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_col.add_child(sub)
	var tag := UiStyle.label("Last car running gets the ration and the pass.", 20, UiStyle.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	col.add_child(UiStyle.label(" ", 24))
	_prompt = UiStyle.label("Press A or Enter", 26, UiStyle.INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt)
	_status = UiStyle.label("", 16, UiStyle.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var build := UiStyle.label("Update 3 build  -  placeholder art and audio", 14, Color(0.45, 0.4, 0.36))
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build.position = Vector2(16, -48)
	add_child(build)
	_refresh_status()
	Input.joy_connection_changed.connect(func(_d, _c): _refresh_status())


func _refresh_status() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_status.text = "No controller found. Keyboard works; plug in a pad any time."
	else:
		_status.text = "Controller: %s" % Input.get_joy_name(pads[0])


func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	for i in _smoke.size():
		var p := _smoke[i]
		p.position.y -= delta * (10.0 + 3.0 * i)
		p.position.x += sin(_time * 0.4 + i) * delta * 6.0
		if p.position.y < -p.size.y:
			p.position.y = size.y + 40.0
		p.modulate.a = clampf(p.position.y / maxf(size.y, 1.0) * 1.6, 0.0, 1.0)   # thins out as it rises


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
