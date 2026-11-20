class_name InputSetup
extends RefCounted
## Builds per-player input actions for Xbox-style pads and the keyboard.
##
## Actions are named "p<slot>_<action>" so split-screen (Milestone 3) can give each
## player their own pad. Button indices follow Godot's SDL layout: A, B, X, Y are
## the bottom, right, left and top face buttons on every pad brand.

const ACTIONS := [
	"accelerate", "brake", "steer_left", "steer_right", "tight_turn",
	"fire_gun", "fire_special", "special_prev", "special_next",
	"turbo", "look_back", "pause", "view_mod",
	"view_cycle", "radar", "rear_mirror", "enemies_left",
	"tuning", "debug",
	"combo_up", "combo_down", "combo_left", "combo_right", "combo_hold",
]

## Pad layouts. The first four follow the classic 1990s arcade-combat pad layouts,
## moved to the Xbox pad button for button (Cross = A, Circle = B, Square = X,
## Triangle = Y, L1/R1 = LB/RB, L2/R2 = LT/RT, Select = View, Start = Menu). In those
## four the D-pad drives as well: up is gas, down is brake, left and right steer,
## and the same D-pad enters combo moves. Modern is our own stick-and-trigger layout.
const PRESETS := ["standard", "alt1", "alt2", "shoulders", "modern"]

const DEFAULT_PRESET := "standard"

const PRESET_NAMES := {
	"standard": "Standard",
	"alt1": "Alternate 1 (A gas, X guns)",
	"alt2": "Alternate 2 (A gas, B guns)",
	"shoulders": "Shoulders (drive on bumpers)",
	"modern": "Modern (stick and triggers)",
}

## Preset ids from earlier builds and what they became.
const RENAMED := {"classic": "standard"}

## Button for each action in the four D-pad layouts (A B X Y LB RB LT RT).
const RETRO_LAYOUTS := {
	"standard": {
		"accelerate": "X", "brake": "B", "turbo": "Y", "tight_turn": "A",
		"special_next": "RB", "special_prev": "LB", "fire_special": "LT", "fire_gun": "RT",
	},
	"alt1": {
		"accelerate": "A", "brake": "LT", "turbo": "Y", "tight_turn": "RT",
		"special_next": "RB", "special_prev": "LB", "fire_special": "B", "fire_gun": "X",
	},
	"alt2": {
		"accelerate": "A", "brake": "LT", "turbo": "Y", "tight_turn": "RT",
		"special_next": "RB", "special_prev": "LB", "fire_special": "X", "fire_gun": "B",
	},
	"shoulders": {
		"accelerate": "RT", "brake": "RB", "turbo": "LB", "tight_turn": "LT",
		"special_next": "Y", "special_prev": "B", "fire_special": "A", "fire_gun": "X",
	},
}

const MODERN_LAYOUT := {
	"accelerate": "RT", "brake": "LT", "turbo": "A", "tight_turn": "B",
	"special_next": "Y", "special_prev": "LB", "fire_special": "X", "fire_gun": "RB",
}

## Hold the view button (Menu, or View in Modern) and press these for camera and
## info commands. Tapping it on its own pauses.
const VIEW_COMMANDS := {
	"up": "view_next", "down": "view_prev", "left": "radar", "right": "rear_mirror",
}

const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.08


static func action(slot: int, name: String) -> StringName:
	return StringName("p%d_%s" % [slot, name])


## Maps an old saved preset id to a current one.
static func resolve_preset(preset: String) -> String:
	preset = RENAMED.get(preset, preset)
	return preset if PRESETS.has(preset) else DEFAULT_PRESET


## (Re)binds every action for one player. device -1 = any connected pad.
static func apply_preset(slot: int, device: int, preset: String, with_keyboard: bool) -> void:
	preset = resolve_preset(preset)
	for a in ACTIONS:
		var act := action(slot, a)
		if InputMap.has_action(act):
			InputMap.action_erase_events(act)
		else:
			InputMap.add_action(act)
		InputMap.action_set_deadzone(act, STICK_DEADZONE)
	for a in ["accelerate", "brake", "fire_gun", "fire_special", "turbo", "tight_turn"]:
		InputMap.action_set_deadzone(action(slot, a), TRIGGER_DEADZONE)
	InputMap.action_set_deadzone(action(slot, "combo_hold"), 0.5)

	# Every layout: analog steering on the left stick, combo moves on the D-pad,
	# RT (the old R2) as the combo hold, tuning panel on the left stick click.
	_axis(slot, "steer_left", device, JOY_AXIS_LEFT_X, -1.0)
	_axis(slot, "steer_right", device, JOY_AXIS_LEFT_X, 1.0)
	_button(slot, "combo_up", device, JOY_BUTTON_DPAD_UP)
	_button(slot, "combo_down", device, JOY_BUTTON_DPAD_DOWN)
	_button(slot, "combo_left", device, JOY_BUTTON_DPAD_LEFT)
	_button(slot, "combo_right", device, JOY_BUTTON_DPAD_RIGHT)
	_axis(slot, "combo_hold", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button(slot, "tuning", device, JOY_BUTTON_LEFT_STICK)

	if preset == "modern":
		_apply_layout(slot, device, MODERN_LAYOUT)
		_button(slot, "look_back", device, JOY_BUTTON_RIGHT_STICK)
		_button(slot, "pause", device, JOY_BUTTON_START)
		_button(slot, "view_mod", device, JOY_BUTTON_BACK)
	else:
		_apply_layout(slot, device, RETRO_LAYOUTS[preset])
		# The D-pad drives too: up is gas, down is brake, left/right steer.
		_button(slot, "accelerate", device, JOY_BUTTON_DPAD_UP)
		_button(slot, "brake", device, JOY_BUTTON_DPAD_DOWN)
		_button(slot, "steer_left", device, JOY_BUTTON_DPAD_LEFT)
		_button(slot, "steer_right", device, JOY_BUTTON_DPAD_RIGHT)
		_button(slot, "pause", device, JOY_BUTTON_BACK)
		_button(slot, "view_mod", device, JOY_BUTTON_START)
		_button(slot, "look_back", device, JOY_BUTTON_RIGHT_STICK)

	if with_keyboard:
		_keys(slot, "accelerate", [KEY_W, KEY_UP])
		_keys(slot, "brake", [KEY_S, KEY_DOWN])
		_keys(slot, "steer_left", [KEY_A, KEY_LEFT])
		_keys(slot, "steer_right", [KEY_D, KEY_RIGHT])
		_keys(slot, "tight_turn", [KEY_X])
		_keys(slot, "fire_gun", [KEY_SPACE])
		_keys(slot, "fire_special", [KEY_F])
		_keys(slot, "special_prev", [KEY_Q])
		_keys(slot, "special_next", [KEY_E])
		_keys(slot, "turbo", [KEY_SHIFT])
		_keys(slot, "look_back", [KEY_C])
		_keys(slot, "pause", [KEY_ESCAPE])
		_keys(slot, "view_cycle", [KEY_V])
		_keys(slot, "radar", [KEY_R])
		_keys(slot, "rear_mirror", [KEY_M])
		_keys(slot, "enemies_left", [KEY_TAB])
		_keys(slot, "tuning", [KEY_F1])
		_keys(slot, "debug", [KEY_F3])
		_keys(slot, "combo_up", [KEY_I])
		_keys(slot, "combo_down", [KEY_K])
		_keys(slot, "combo_left", [KEY_J])
		_keys(slot, "combo_right", [KEY_L])
		_keys(slot, "combo_hold", [KEY_CTRL])


static func _apply_layout(slot: int, device: int, layout: Dictionary) -> void:
	for a in layout:
		match String(layout[a]):
			"A": _button(slot, a, device, JOY_BUTTON_A)
			"B": _button(slot, a, device, JOY_BUTTON_B)
			"X": _button(slot, a, device, JOY_BUTTON_X)
			"Y": _button(slot, a, device, JOY_BUTTON_Y)
			"LB": _button(slot, a, device, JOY_BUTTON_LEFT_SHOULDER)
			"RB": _button(slot, a, device, JOY_BUTTON_RIGHT_SHOULDER)
			"LT": _axis(slot, a, device, JOY_AXIS_TRIGGER_LEFT, 1.0)
			"RT": _axis(slot, a, device, JOY_AXIS_TRIGGER_RIGHT, 1.0)


static func _button(slot: int, name: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action(slot, name), ev)


static func _axis(slot: int, name: String, device: int, axis: JoyAxis, direction: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = direction
	InputMap.action_add_event(action(slot, name), ev)


static func _keys(slot: int, name: String, keys: Array) -> void:
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action(slot, name), ev)
