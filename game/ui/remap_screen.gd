class_name RemapScreen
extends Control
## Remap every action on the controller and the keyboard. Opened from the pause menu.
##
## Pick a cell with the D-pad (or mouse) and press A / Enter, then press the new
## button or key. If another action already used it, the two swap. Changes are
## saved straight away. Esc (keyboard) or waiting 5 seconds cancels a capture.

signal closed

const CAPTURE_SECONDS := 5.0
const AXIS_THRESHOLD := 0.6
const AFTER_CAPTURE_SECONDS := 0.3
const ACCENT := Neon.CYAN
const DIM := Neon.DIM

var slot := 1
var _title: Label
var _status: Label
var _grid: GridContainer
var _layout_btn: Button
var _reset_btn: Button
var _back_btn: Button
var _cells := {}   ## "action|pad" / "action|key0" / "action|key1" -> Button

var _capture_action := ""
var _capture_target := ""   ## "pad", "key0", "key1"
var _capture_left := 0.0
var _quiet_left := 0.0
var _confirm_reset := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	_title = UiStyle.label("", 28, ACCENT)
	col.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.follow_focus = true
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)

	for h in ["ACTION", "CONTROLLER", "KEY", "ALT KEY"]:
		_grid.add_child(UiStyle.label(h, 15, DIM))
	for a in InputBindings.LABELS:
		_grid.add_child(UiStyle.label(InputBindings.LABELS[a], 17))
		_grid.add_child(_cell(a, "pad", 230))
		_grid.add_child(_cell(a, "key0", 150))
		_grid.add_child(_cell(a, "key1", 150))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_layout_btn = _small_button("", _toggle_layout)
	row.add_child(_layout_btn)
	_reset_btn = _small_button("", _reset)
	row.add_child(_reset_btn)
	_back_btn = _small_button("Back", close)
	row.add_child(_back_btn)

	_status = UiStyle.label("", 16, DIM)
	_status.custom_minimum_size = Vector2(0, 24)
	col.add_child(_status)
	visible = false


func _cell(action: String, target: String, width: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(width, 0)
	b.add_theme_font_size_override("font_size", 17)
	b.clip_text = true
	b.pressed.connect(_start_capture.bind(action, target))
	b.pressed.connect(func(): GameAudio.play_ui("ui_click", 0.6))
	_cells["%s|%s" % [action, target]] = b
	return b


func _small_button(text: String, on_press: Callable) -> Button:
	var b := UiStyle.button(text, on_press)
	b.custom_minimum_size = Vector2(200, 0)
	return b


func open() -> void:
	visible = true
	_confirm_reset = false
	_refresh()
	_status.text = "Pick an action and press A / Enter, then press the new button or key."
	(_cells["accelerate|pad"] as Button).grab_focus()


func close() -> void:
	if _capture_action != "":
		_end_capture()
	visible = false
	closed.emit()


func _refresh() -> void:
	var preset := GameSettings.control_preset
	_title.text = "CONTROLS  -  %s" % InputSetup.PRESET_NAMES[preset]
	_layout_btn.text = "Layout: %s" % preset.capitalize()
	_reset_btn.text = "Press again to reset" if _confirm_reset else "Reset to defaults"
	for a in InputBindings.LABELS:
		(_cells[a + "|pad"] as Button).text = InputBindings.pad_text(slot, a)
		var keys := InputBindings.key_codes(slot, a)
		for i in InputBindings.KEY_SLOTS:
			(_cells["%s|key%d" % [a, i]] as Button).text = InputBindings.describe(keys[i])


func _toggle_layout() -> void:
	_confirm_reset = false
	GameSettings.control_preset = GameSettings.next_in(InputSetup.PRESETS, GameSettings.control_preset)
	GameSettings.apply_controls()
	GameSettings.save_settings()
	_refresh()
	_status.text = "Controller remaps are kept separately for each layout."


func _reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_refresh()
		_status.text = "Resets the %s controller layout and the keyboard to their defaults." % GameSettings.control_preset.capitalize()
		return
	_confirm_reset = false
	InputBindings.reset(GameSettings.control_preset)
	GameSettings.apply_controls()
	GameSettings.save_settings()
	_refresh()
	_status.text = "Controls reset to defaults."


# --- Capture ------------------------------------------------------------------------

func _start_capture(action: String, target: String) -> void:
	_confirm_reset = false
	_refresh()
	_capture_action = action
	_capture_target = target
	_capture_left = CAPTURE_SECONDS
	var cell := _cells["%s|%s" % [action, target]] as Button
	cell.text = "..."
	if target == "pad":
		_status.text = "Press a controller button, trigger or stick for %s  (wait 5 s to cancel)" % InputBindings.LABELS[action]
	else:
		_status.text = "Press a key for %s  (Backspace clears, Esc or wait 5 s to cancel)" % InputBindings.LABELS[action]
	_status.add_theme_color_override("font_color", ACCENT)


func _end_capture() -> void:
	var cell := _cells.get("%s|%s" % [_capture_action, _capture_target]) as Button
	_capture_action = ""
	_capture_target = ""
	_quiet_left = AFTER_CAPTURE_SECONDS
	_status.add_theme_color_override("font_color", DIM)
	_refresh()
	if cell:
		cell.grab_focus()


func _process(delta: float) -> void:
	if _quiet_left > 0.0:
		_quiet_left -= delta
	if _capture_action == "":
		return
	_capture_left -= delta
	if _capture_left <= 0.0:
		_end_capture()
		_status.text = "No change."


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _capture_action == "":
		# Swallow the tail of the press that was just captured (a held trigger, a release).
		if _quiet_left > 0.0 and (InputBindings.is_pad(event) or event is InputEventKey):
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		if _capture_target == "pad":
			return
		var action := _capture_action
		var index := int(_capture_target.trim_prefix("key"))
		if event.physical_keycode == KEY_ESCAPE:
			_end_capture()
			_status.text = "No change."
			return
		if event.physical_keycode == KEY_BACKSPACE:
			InputBindings.clear_key(slot, action, index)
			_commit()
			_status.text = "%s: key cleared." % InputBindings.LABELS[action]
			return
		var code := InputBindings.encode(event)
		var swapped := InputBindings.set_key(slot, action, index, code)
		_commit()
		_report(action, code, swapped)
	elif InputBindings.is_pad(event):
		if _capture_target != "pad":
			return
		var code := ""
		if event is InputEventJoypadButton and event.pressed:
			code = InputBindings.encode(event)
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= AXIS_THRESHOLD:
			code = InputBindings.encode(event)
		if code == "":
			return
		var action := _capture_action
		var swapped := InputBindings.set_pad(slot, GameSettings.control_preset, action, code)
		_commit()
		_report(action, code, swapped)


func _commit() -> void:
	GameSettings.apply_controls()
	GameSettings.save_settings()
	_end_capture()


func _report(action: String, code: String, swapped: String) -> void:
	var msg := "%s is now %s." % [InputBindings.LABELS[action], InputBindings.describe(code)]
	if swapped != "":
		msg += "  Swapped with %s." % InputBindings.LABELS[swapped]
	_status.text = msg


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _capture_action != "":
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputSetup.action(slot, "pause")):
		get_viewport().set_input_as_handled()
		close()
