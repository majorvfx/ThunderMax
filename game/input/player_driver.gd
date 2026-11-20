class_name PlayerDriver
extends RefCounted
## Reads one player's pad and keyboard into an ArcadeHandling.ControlFrame.

var slot := 1
var device := -1   ## -1 = any connected pad
var enabled := true
var _frame := ArcadeHandling.ControlFrame.new()

const COMBO_DIRECTIONS := ["up", "down", "left", "right"]


func _init(player_slot: int = 1, pad_device: int = -1) -> void:
	slot = player_slot
	device = pad_device


func get_frame(_vehicle: Node, _dt: float) -> ArcadeHandling.ControlFrame:
	var f := _frame
	if not enabled:
		f.throttle = 0.0
		f.brake = 0.0
		f.steer = 0.0
		f.turbo = false
		f.fire_gun = false
		f.fire_special = false
		f.look_back = false
		f.combo_presses.clear()
		f.combo_hold = false
		f.cycle_special = 0
		return f
	f.throttle = Input.get_action_strength(_a("accelerate"))
	f.brake = Input.get_action_strength(_a("brake"))
	f.turbo = Input.is_action_pressed(_a("turbo"))
	f.fire_gun = Input.is_action_pressed(_a("fire_gun"))
	f.fire_special = Input.is_action_pressed(_a("fire_special"))
	f.look_back = Input.is_action_pressed(_a("look_back"))
	# D-pad combo presses (read from the remappable combo actions).
	f.combo_hold = Input.is_action_pressed(_a("combo_hold"))
	for dir in COMBO_DIRECTIONS:
		if Input.is_action_just_pressed(_a("combo_" + dir)):
			f.combo_presses.append(dir)
	if Input.is_action_just_pressed(_a("special_next")):
		f.cycle_special = 1
	elif Input.is_action_just_pressed(_a("special_prev")):
		f.cycle_special = -1

	# Stick beats D-pad/keys when it is pushed past the deadzone.
	var stick := _stick_x()
	if absf(stick) > InputSetup.STICK_DEADZONE:
		var mag := (absf(stick) - InputSetup.STICK_DEADZONE) / (1.0 - InputSetup.STICK_DEADZONE)
		f.steer = signf(stick) * clampf(mag, 0.0, 1.0)
		f.steer_digital = false
	else:
		var digital := 0.0
		if Input.is_action_pressed(_a("steer_left")):
			digital -= 1.0
		if Input.is_action_pressed(_a("steer_right")):
			digital += 1.0
		f.steer = digital
		f.steer_digital = true
	return f


func _a(name: String) -> StringName:
	return InputSetup.action(slot, name)


## Analog steering from whatever stick axes are bound to steer left / right
## (the left stick by default). Reads the raw axis so the deadzone ramp above applies.
func _stick_x() -> float:
	var right := _axis_event("steer_right")
	var left := _axis_event("steer_left")
	if right == null and left == null:
		return 0.0
	var devices: Array = [device] if device >= 0 else Input.get_connected_joypads()
	var best := 0.0
	for d in devices:
		var v := 0.0
		if right != null:
			v += maxf(0.0, Input.get_joy_axis(d, right.axis) * signf(right.axis_value))
		if left != null:
			v -= maxf(0.0, Input.get_joy_axis(d, left.axis) * signf(left.axis_value))
		if absf(v) > absf(best):
			best = v
	return clampf(best, -1.0, 1.0)


func _axis_event(name: String) -> InputEventJoypadMotion:
	for ev in InputMap.action_get_events(_a(name)):
		if ev is InputEventJoypadMotion:
			return ev
	return null
