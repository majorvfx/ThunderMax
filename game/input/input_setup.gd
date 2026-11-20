class_name InputSetup
extends RefCounted
## Builds per-player input actions for Xbox-style pads and the keyboard.
##
## Actions are named "p<slot>_<action>" so split-screen (Milestone 3) can give each
## player their own pad. Button indices follow Godot's SDL layout: A, B, X, Y are
## the bottom, right, left and top face buttons on every pad brand.

const ACTIONS := [
	"accelerate", "brake", "steer_left", "steer_right",
	"fire_gun", "fire_special", "special_prev", "special_next",
	"turbo", "look_back", "pause", "tuning", "debug",
	"combo_up", "combo_down", "combo_left", "combo_right",
]

const PRESETS := ["modern", "classic"]

const PRESET_NAMES := {
	"modern": "Modern (triggers)",
	"classic": "Classic (face buttons)",
}

## What each control does per preset, for menus and the README.
const PRESET_HELP := {
	"modern": [
		["Accelerate", "RT"], ["Brake / reverse", "LT"], ["Steer", "Left stick"],
		["Machine gun", "RB"], ["Special weapon", "X"], ["Turbo", "A"],
		["Look back", "B"], ["Cycle specials", "LB / Y"],
		["Combo moves", "D-pad"], ["Pause", "Menu"], ["Tuning panel", "View"],
	],
	"classic": [
		["Accelerate", "A"], ["Brake / reverse", "X"], ["Steer", "D-pad or left stick"],
		["Machine gun", "B"], ["Special weapon", "Y"], ["Turbo", "LT"],
		["Look back", "RT"], ["Cycle specials", "LB / RB"],
		["Combo moves", "D-pad"], ["Pause", "Menu"], ["Tuning panel", "View"],
	],
}

const KEYBOARD_HELP := [
	["Accelerate", "W / Up"], ["Brake / reverse", "S / Down"], ["Steer", "A D / Left Right"],
	["Machine gun", "Space"], ["Special weapon", "F"], ["Turbo", "Shift"],
	["Look back", "C"], ["Cycle specials", "Q / E"], ["Combo moves", "I J K L"], ["Pause", "Esc"],
	["Tuning panel", "F1"], ["Debug readout", "F3"],
]

const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.08


static func action(slot: int, name: String) -> StringName:
	return StringName("p%d_%s" % [slot, name])


## (Re)binds every action for one player. device -1 = any connected pad.
static func apply_preset(slot: int, device: int, preset: String, with_keyboard: bool) -> void:
	for a in ACTIONS:
		var act := action(slot, a)
		if InputMap.has_action(act):
			InputMap.action_erase_events(act)
		else:
			InputMap.add_action(act)
		InputMap.action_set_deadzone(act, STICK_DEADZONE)
	InputMap.action_set_deadzone(action(slot, "accelerate"), TRIGGER_DEADZONE)
	InputMap.action_set_deadzone(action(slot, "brake"), TRIGGER_DEADZONE)

	# Shared by both presets.
	_axis(slot, "steer_left", device, JOY_AXIS_LEFT_X, -1.0)
	_axis(slot, "steer_right", device, JOY_AXIS_LEFT_X, 1.0)
	_button(slot, "pause", device, JOY_BUTTON_START)
	_button(slot, "tuning", device, JOY_BUTTON_BACK)
	# Combo moves are D-pad sequences in both layouts (remappable like everything else).
	_button(slot, "combo_up", device, JOY_BUTTON_DPAD_UP)
	_button(slot, "combo_down", device, JOY_BUTTON_DPAD_DOWN)
	_button(slot, "combo_left", device, JOY_BUTTON_DPAD_LEFT)
	_button(slot, "combo_right", device, JOY_BUTTON_DPAD_RIGHT)

	if preset == "classic":
		_button(slot, "accelerate", device, JOY_BUTTON_A)
		_button(slot, "brake", device, JOY_BUTTON_X)
		_button(slot, "steer_left", device, JOY_BUTTON_DPAD_LEFT)
		_button(slot, "steer_right", device, JOY_BUTTON_DPAD_RIGHT)
		_button(slot, "fire_gun", device, JOY_BUTTON_B)
		_button(slot, "fire_special", device, JOY_BUTTON_Y)
		_button(slot, "special_prev", device, JOY_BUTTON_LEFT_SHOULDER)
		_button(slot, "special_next", device, JOY_BUTTON_RIGHT_SHOULDER)
		_axis(slot, "turbo", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_axis(slot, "look_back", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	else:
		_axis(slot, "accelerate", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		_axis(slot, "brake", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_button(slot, "fire_gun", device, JOY_BUTTON_RIGHT_SHOULDER)
		_button(slot, "fire_special", device, JOY_BUTTON_X)
		_button(slot, "turbo", device, JOY_BUTTON_A)
		_button(slot, "look_back", device, JOY_BUTTON_B)
		_button(slot, "special_prev", device, JOY_BUTTON_LEFT_SHOULDER)
		_button(slot, "special_next", device, JOY_BUTTON_Y)

	if with_keyboard:
		_keys(slot, "accelerate", [KEY_W, KEY_UP])
		_keys(slot, "brake", [KEY_S, KEY_DOWN])
		_keys(slot, "steer_left", [KEY_A, KEY_LEFT])
		_keys(slot, "steer_right", [KEY_D, KEY_RIGHT])
		_keys(slot, "fire_gun", [KEY_SPACE])
		_keys(slot, "fire_special", [KEY_F])
		_keys(slot, "special_prev", [KEY_Q])
		_keys(slot, "special_next", [KEY_E])
		_keys(slot, "turbo", [KEY_SHIFT])
		_keys(slot, "look_back", [KEY_C])
		_keys(slot, "pause", [KEY_ESCAPE])
		_keys(slot, "tuning", [KEY_F1])
		_keys(slot, "debug", [KEY_F3])
		_keys(slot, "combo_up", [KEY_I])
		_keys(slot, "combo_down", [KEY_K])
		_keys(slot, "combo_left", [KEY_J])
		_keys(slot, "combo_right", [KEY_L])


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
