class_name PauseMenu
extends Control
## Pause menu, fully usable with a pad: D-pad/stick to move, A to choose, B or Menu to resume.

signal resumed
signal restart_requested
signal quit_requested
signal settings_changed

var governor: FrameGovernor
var _first: Button
var _controls_btn: Button
var _fps_btn: Button
var _quality_btn: Button
var _help: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	panel.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	col.add_child(UiStyle.label("PAUSED", 34, Color(0.95, 0.6, 0.2)))
	_first = UiStyle.button("Resume", _resume)
	col.add_child(_first)
	_controls_btn = UiStyle.button("", _toggle_controls)
	col.add_child(_controls_btn)
	_fps_btn = UiStyle.button("", _toggle_fps)
	col.add_child(_fps_btn)
	_quality_btn = UiStyle.button("", _toggle_quality)
	col.add_child(_quality_btn)
	col.add_child(UiStyle.button("Restart the Yard", func(): restart_requested.emit()))
	col.add_child(UiStyle.button("Quit to title", func(): quit_requested.emit()))

	_help = VBoxContainer.new()
	_help.add_theme_constant_override("separation", 4)
	row.add_child(_help)
	_refresh()
	visible = false


func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()
	_first.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputSetup.action(1, "pause")):
		get_viewport().set_input_as_handled()
		_resume()


func _toggle_controls() -> void:
	GameSettings.control_preset = GameSettings.next_in(InputSetup.PRESETS, GameSettings.control_preset)
	GameSettings.apply_controls()
	GameSettings.save_settings()
	_refresh()


func _toggle_fps() -> void:
	GameSettings.fps_mode = GameSettings.next_in(GameSettings.FPS_MODES, GameSettings.fps_mode)
	GameSettings.save_settings()
	if governor:
		governor.apply()
	_refresh()


func _toggle_quality() -> void:
	GameSettings.quality = GameSettings.next_in(GameSettings.QUALITIES, GameSettings.quality)
	GameSettings.save_settings()
	settings_changed.emit()
	_refresh()


func _refresh() -> void:
	_controls_btn.text = "Controls: %s" % InputSetup.PRESET_NAMES[GameSettings.control_preset]
	_fps_btn.text = "Frame rate: %s" % (governor.label() if governor else GameSettings.fps_mode)
	_quality_btn.text = "Graphics: %s" % GameSettings.quality.capitalize()
	for c in _help.get_children():
		c.queue_free()
	_help.add_child(UiStyle.label("XBOX CONTROLLER", 18, Color(0.95, 0.6, 0.2)))
	for pair in InputSetup.PRESET_HELP[GameSettings.control_preset]:
		_help.add_child(UiStyle.label("%-18s %s" % [pair[0], pair[1]], 17))
	_help.add_child(UiStyle.label(" ", 8))
	_help.add_child(UiStyle.label("KEYBOARD", 18, Color(0.95, 0.6, 0.2)))
	for pair in InputSetup.KEYBOARD_HELP:
		_help.add_child(UiStyle.label("%-18s %s" % [pair[0], pair[1]], 15, Color(0.7, 0.66, 0.6)))
