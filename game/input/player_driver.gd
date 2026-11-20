class_name PlayerDriver
extends RefCounted
## Reads one player's pad and keyboard into an ArcadeHandling.ControlFrame.

var slot := 1
var device := -1   ## -1 = any connected pad
var enabled := true
var _frame := ArcadeHandling.ControlFrame.new()
var _mod_time := 0.0
var _mod_used := false
var _mod_seen := false
var _pad_a_was := false
var _held := {}

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
		f.tight_turn = false
		f.cycle_special = 0
		return f
	f.throttle = Input.get_action_strength(_a("accelerate"))
	f.brake = Input.get_action_strength(_a("brake"))
	f.turbo = Input.is_action_pressed(_a("turbo"))
	f.fire_gun = Input.is_action_pressed(_a("fire_gun"))
	f.fire_special = Input.is_action_pressed(_a("fire_special"))
	f.look_back = Input.is_action_pressed(_a("look_back"))
	f.tight_turn = Input.is_action_pressed(_a("tight_turn"))
	# D-pad combo presses (read from the remappable combo actions). While the view
	# button is held the D-pad gives view commands instead (see poll_commands).
	f.combo_hold = Input.is_action_pressed(_a("combo_hold"))
	if not Input.is_action_pressed(_a("view_mod")):
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


## Camera and info commands, read once per rendered frame by the match:
## "view_next", "view_prev", "radar", "rear_mirror", "enemies_left" and "pause".
## On the pad they are the view button (Menu) held with a D-pad direction or A,
## and a tap of the view button on its own pauses. Keys can be bound to each directly.
## Edges come from comparing with the last poll, so it works at any frame rate.
func poll_commands(delta: float) -> Array[String]:
	var out: Array[String] = []
	if not enabled:
		return out
	if _held.is_empty():
		# First poll: take what's already held as the starting state (no edges).
		for n in ["view_mod", "view_cycle", "radar", "rear_mirror", "enemies_left",
				"combo_up", "combo_down", "combo_left", "combo_right"]:
			_held[n] = Input.is_action_pressed(_a(n))
		_pad_a_was = _pad_a_down()
	var mod := _edge("view_mod")
	var holding := Input.is_action_pressed(_a("view_mod"))
	if mod > 0:
		_mod_time = 0.0
		_mod_used = false
		_mod_seen = true
	if holding:
		_mod_time += delta
	for dir in COMBO_DIRECTIONS:
		if _edge("combo_" + dir) > 0 and holding:
			out.append(InputSetup.VIEW_COMMANDS[dir])
			_mod_used = true
	var pad_a := _pad_a_down()
	if pad_a and not _pad_a_was and holding:
		out.append("enemies_left")
		_mod_used = true
	_pad_a_was = pad_a
	if mod < 0:
		# Only a tap we saw start counts (not the release of the press that closed the menu).
		if _mod_seen and not _mod_used and _mod_time < 0.4:
			out.append("pause")
		_mod_seen = false
	if _edge("view_cycle") > 0:
		out.append("view_next")
	for cmd in ["radar", "rear_mirror", "enemies_left"]:
		if _edge(cmd) > 0:
			out.append(cmd)
	return out


## +1 when an action went down since the last poll, -1 when it came up, else 0.
func _edge(name: String) -> int:
	var now := Input.is_action_pressed(_a(name))
	var was: bool = _held.get(name, now)
	_held[name] = now
	if now == was:
		return 0
	return 1 if now else -1


func _pad_a_down() -> bool:
	var devices: Array = [device] if device >= 0 else Input.get_connected_joypads()
	for d in devices:
		if Input.is_joy_button_pressed(d, JOY_BUTTON_A):
			return true
	return false


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
