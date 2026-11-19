class_name PlayerDriver
extends RefCounted
## Reads one player's pad and keyboard into an ArcadeHandling.ControlFrame.

var slot := 1
var device := -1   ## -1 = any connected pad
var enabled := true
var _frame := ArcadeHandling.ControlFrame.new()


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
		return f
	f.throttle = Input.get_action_strength(_a("accelerate"))
	f.brake = Input.get_action_strength(_a("brake"))
	f.turbo = Input.is_action_pressed(_a("turbo"))
	f.fire_gun = Input.is_action_pressed(_a("fire_gun"))
	f.fire_special = Input.is_action_pressed(_a("fire_special"))
	f.look_back = Input.is_action_pressed(_a("look_back"))

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


func _stick_x() -> float:
	if device >= 0:
		return Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var best := 0.0
	for d in Input.get_connected_joypads():
		var v := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		if absf(v) > absf(best):
			best = v
	return best
