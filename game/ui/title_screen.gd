class_name TitleScreen
extends Control
## Title card. A or Enter starts.

signal start_pressed

var _status: Label
var _prompt: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.02, 0.015, 0.015), Color(0.12, 0.05, 0.025), Color(0.32, 0.12, 0.04)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 256
	bg.texture = gt
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var title := UiStyle.label("THUNDER MAX", 96, Color(0.92, 0.86, 0.76))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.1, 0.03))
	title.add_theme_constant_override("outline_size", 12)
	col.add_child(title)
	var sub := UiStyle.label("METAL ROAD", 44, Color(0.95, 0.55, 0.18))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var tag := UiStyle.label("The road only goes one way.", 20, Color(0.6, 0.55, 0.5))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	col.add_child(UiStyle.label(" ", 30))
	_prompt = UiStyle.label("Press A or Enter", 26, Color(0.92, 0.86, 0.76))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt)
	_status = UiStyle.label("", 16, Color(0.6, 0.55, 0.5))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var build := UiStyle.label("Milestone 2 build  -  placeholder art and audio", 14, Color(0.45, 0.4, 0.36))
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build.position = Vector2(16, -30)
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
