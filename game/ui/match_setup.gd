class_name MatchSetup
extends Control
## Before a match: pick the arena, how many bots, how hard they are, and whether
## they drive Scrap Drones or cars from the roster. Up / down picks a row, left /
## right changes it, A or Enter on Start (or anywhere) drives, B or Esc goes back.

signal start_pressed
signal back_pressed

var _rows: Array[Button] = []
var _blurb: Label
var _start: Button

const DIFFICULTY_TEXT := {
	"scrap": "SCRAP  -  slow to notice you, poor shots",
	"iron": "IRON  -  hunts close up, fires in bursts",
	"carnage": "CARNAGE  -  hunts across the arena, uses turbo and specials",
}
const BOT_CARS_TEXT := {
	"drones": "SCRAP DRONES",
	"roster": "ROSTER CARS  -  random cars with their own specials",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	GameSettings.load_settings()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UiStyle.SOOT
	add_child(bg)
	var top := UiStyle.hazard_strip(14)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 14
	add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UiStyle.label("SET UP THE MATCH", 40, UiStyle.HAZARD))
	col.add_child(UiStyle.label("Driving: %s" % GameData.load_vehicle(GameSettings.car, false).display_name, 18, UiStyle.DIM))
	for i in 4:
		var b := UiStyle.button("", _on_row.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(780, 0)
		b.gui_input.connect(_row_input.bind(i))
		col.add_child(b)
		_rows.append(b)
	_blurb = UiStyle.label("", 17, UiStyle.DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(780, 48)
	col.add_child(_blurb)
	_start = UiStyle.button("START", _go)
	_start.custom_minimum_size = Vector2(780, 0)
	col.add_child(_start)
	col.add_child(UiStyle.label("Up / down: pick   Left / right: change   A: start   B: back", 15, UiStyle.DIM))
	_refresh()
	_start.grab_focus()


func _refresh() -> void:
	_rows[0].text = "ARENA:  %s" % Arenas.display_name(GameSettings.arena).to_upper()
	_rows[1].text = "OPPONENTS:  %d" % GameSettings.bot_count
	_rows[2].text = "DIFFICULTY:  %s" % DIFFICULTY_TEXT[GameSettings.difficulty]
	_rows[3].text = "OPPONENT CARS:  %s" % BOT_CARS_TEXT[GameSettings.bot_cars]
	_blurb.text = Arenas.blurb(GameSettings.arena)


## Cycles row `i` by `step`.
func change(i: int, step: int) -> void:
	match i:
		0:
			var ids := Arenas.ids()
			GameSettings.arena = ids[(ids.find(GameSettings.arena) + step + ids.size()) % ids.size()]
		1:
			GameSettings.bot_count = clampi(GameSettings.bot_count + step, 1, 6)
		2:
			var d: Array = GameSettings.DIFFICULTIES
			GameSettings.difficulty = d[(d.find(GameSettings.difficulty) + step + d.size()) % d.size()]
		3:
			var c: Array = GameSettings.BOT_CARS
			GameSettings.bot_cars = c[(c.find(GameSettings.bot_cars) + step + c.size()) % c.size()]
	GameSettings.save_settings()
	GameAudio.play_ui("ui_click", 0.5)
	_refresh()


func _on_row(i: int) -> void:
	change(i, 1)


func _row_input(event: InputEvent, i: int) -> void:
	if event.is_action_pressed("ui_left"):
		change(i, -1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		change(i, 1)
		accept_event()


func _go() -> void:
	GameSettings.save_settings()
	start_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
