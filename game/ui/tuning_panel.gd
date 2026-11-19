class_name TuningPanel
extends Control
## Live handling tuning. Open with View (pad) or F1, move with the D-pad,
## change a value with left/right, close and drive. "Save" keeps the numbers for
## next time (user://tuning/<car>.json); "Copy" puts them on the clipboard so they
## can be pasted into data/vehicles/<car>.json.

signal closed

var vehicle: ArcadeVehicle
var _rows: VBoxContainer
var _status: Label
var _first: Control
var _value_labels := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -560
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiStyle.label("HANDLING TUNING", 28, Color(0.95, 0.6, 0.2)))
	col.add_child(UiStyle.label("D-pad up/down: pick   left/right: change   B: close", 15, Color(0.7, 0.66, 0.6)))
	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	var save := UiStyle.button("Save", _save)
	save.custom_minimum_size = Vector2(110, 0)
	buttons.add_child(save)
	var copy := UiStyle.button("Copy", _copy)
	copy.custom_minimum_size = Vector2(110, 0)
	buttons.add_child(copy)
	var reset := UiStyle.button("Reset", _reset)
	reset.custom_minimum_size = Vector2(110, 0)
	buttons.add_child(reset)
	var close := UiStyle.button("Close", close_panel)
	close.custom_minimum_size = Vector2(110, 0)
	buttons.add_child(close)
	_first = save
	_status = UiStyle.label("", 15, Color(0.7, 0.66, 0.6))
	col.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	visible = false


func open(v: ArcadeVehicle) -> void:
	vehicle = v
	_build_rows()
	visible = true
	get_tree().paused = true
	_status.text = "Tuning %s. Changes apply when you close." % vehicle.stats.display_name
	_first.grab_focus()


func close_panel() -> void:
	visible = false
	get_tree().paused = false
	if vehicle:
		vehicle.apply_stats()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputSetup.action(1, "tuning")):
		get_viewport().set_input_as_handled()
		close_panel()


func _build_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_value_labels.clear()
	for entry in VehicleStats.TUNABLE:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := UiStyle.label(key.replace("_", " "), 16)
		name_label.custom_minimum_size = Vector2(210, 0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = entry[1]
		slider.max_value = entry[2]
		slider.step = entry[3]
		slider.value = vehicle.stats.get(key)
		slider.focus_mode = Control.FOCUS_ALL
		slider.custom_minimum_size = Vector2(190, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_value.bind(key))
		row.add_child(slider)
		var value_label := UiStyle.label(_fmt(vehicle.stats.get(key)), 16)
		value_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(value_label)
		_value_labels[key] = value_label
		_rows.add_child(row)


func _on_value(value: float, key: String) -> void:
	vehicle.stats.set(key, value)
	if _value_labels.has(key):
		(_value_labels[key] as Label).text = _fmt(value)


func _fmt(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")


func _save() -> void:
	var path := GameData.save_tuning(vehicle.stats)
	_status.text = "Saved to %s" % path if path != "" else "Could not save."


func _copy() -> void:
	DisplayServer.clipboard_set(JSON.stringify(vehicle.stats.to_tuning_dict(), "  "))
	_status.text = "Copied the numbers to the clipboard."


func _reset() -> void:
	GameData.clear_tuning(vehicle.stats.id)
	var fresh := GameData.load_vehicle(vehicle.stats.id, false)
	if fresh != null:
		for entry in VehicleStats.TUNABLE:
			vehicle.stats.set(entry[0], fresh.get(entry[0]))
	_build_rows()
	_status.text = "Back to the numbers in data/vehicles/%s.json." % vehicle.stats.id
	_first.grab_focus()
