extends SceneTree
## Headless test runner for Iron Carnage.
##
##   godot --headless --path . --import
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
##
## 1. Core rule tests (pure logic, no physics).
## 2. Handling measurements on a flat test pad, checked against
##    data/handling_targets.json and written to docs/handling_report.md.
## 3. Combo moves and special weapons on the test pad.
## 4. Arena smoke test: drones lap the Foundry Yard, fight back, and the gun wrecks a drone.

var _pass := 0
var _fail := 0
var _failures: Array[String] = []
var _measure := {}
var _half_turn_s := 0.0


class ScriptedDriver:
	extends RefCounted
	var frame := ArcadeHandling.ControlFrame.new()
	func get_frame(_v: Node, _dt: float) -> ArcadeHandling.ControlFrame:
		return frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Core rules ==")
	_test_data()
	_test_handling_math()
	_test_combat_rules()
	_test_input()
	_test_remap()
	await _test_view_commands()
	_test_combo_buffer()
	_test_status_effects()
	print("== Handling measurements ==")
	await _handling_measurements()
	print("== Combo moves and specials ==")
	await _combo_moves()
	await _weapon_curve()
	print("== Cars and their own specials ==")
	await _roster_driving()
	await _signature_specials()
	await _new_car_specials()
	await _new_pickup_weapons()
	await _projectile_tuning()
	await _car_select()
	print("== Arena smoke test ==")
	await _arena_smoke()
	print("== Arenas, surfaces and bots ==")
	await _all_arenas()
	await _surfaces()
	await _bot_settings()
	_write_report()
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	for f in _failures:
		print("  FAIL: ", f)
	quit(1 if _fail > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_failures.append(what)
		print("  FAIL ", what)


func near(a: float, b: float, tol: float, what: String) -> void:
	check(absf(a - b) <= tol, "%s (got %.4f, want %.4f +/- %.4f)" % [what, a, b, tol])


# --- Core -------------------------------------------------------------------------

func _test_data() -> void:
	var s := GameData.load_vehicle("rustjaw", false)
	check(s != null, "rustjaw.json loads")
	check(s.display_name == "Rustjaw", "name maps to display_name")
	near(s.max_speed, 30.0, 0.001, "nested drive section is flattened")
	near(s.ram_power, 1.2, 0.001, "combat section applies")
	var d := GameData.load_vehicle("scrap_drone", false)
	check(d != null and d.max_health == 40.0, "scrap_drone.json loads")
	check(GameData.weapon("machine_gun").has("damage"), "weapons.json has the machine gun")
	check(GameData.pickups().has("health") and GameData.pickups().has("turbo"), "pickups.json has health and turbo")
	var copy := s.duplicate_stats()
	copy.max_speed = 1.0
	check(s.max_speed == 30.0, "duplicate_stats is a deep copy")
	var g := s.duplicate_stats()
	g.apply_grip_preset()
	check(g.coast_decel > s.coast_decel * 2.0 and g.drift_grip > s.drift_grip and g.steer_return_time < s.steer_return_time, "the Grip preset stops quicker, slides less and straightens faster")
	var t := s.to_tuning_dict()
	check(t.size() == VehicleStats.TUNABLE.size(), "tuning dict has every tunable")
	# The roster: every car loads, keeps its own name, and has its own special.
	var roster := GameData.roster()
	check(roster.size() == 12 and roster[0] == "rustjaw", "the roster has twelve cars, Rustjaw first")
	var paints := {}
	for id in roster:
		var car := GameData.load_vehicle(id, false)
		check(car != null and car.id == id, "%s.json loads" % id)
		check(car.display_name.to_lower() == id, "%s keeps its own name (the special's name doesn't leak in)" % id)
		var sig := GameData.signature(id)
		check(sig.has("id") and sig.has("kind") and float(sig.get("recharge_s", 0.0)) > 0.0, "%s has its own recharging special" % id)
		paints[car.paint] = true
	check(paints.size() == roster.size(), "every car has its own look")
	var cinder := GameData.load_vehicle("cinder", false)
	var hog := GameData.load_vehicle("hogshead", false)
	check(cinder.max_speed > s.max_speed and cinder.max_health < s.max_health, "Cinder is faster and more fragile than Rustjaw")
	check(hog.max_health > s.max_health and hog.mass > s.mass and hog.max_speed < s.max_speed, "Hogshead is heavier, tougher and slower")
	check(GameData.signature("scrap_drone").is_empty(), "drones have no special of their own")


func _test_handling_math() -> void:
	var s := GameData.load_vehicle("rustjaw", false)
	var dt := 1.0 / 60.0
	# Acceleration and top speed.
	var v := 0.0
	for i in 600:
		v = ArcadeHandling.step_forward_speed(s, v, 1.0, 0.0, false, false, dt)
	near(v, s.max_speed, 0.01, "full throttle settles at top speed")
	# Partial throttle caps lower.
	v = 0.0
	for i in 600:
		v = ArcadeHandling.step_forward_speed(s, v, 0.5, 0.0, false, false, dt)
	near(v, s.max_speed * 0.5, 0.05, "half throttle holds half top speed")
	# Brake to a stop, then reverse.
	v = 20.0
	for i in 60:
		v = ArcadeHandling.step_forward_speed(s, v, 0.0, 1.0, false, false, dt)
	check(v <= 0.0, "brake stops the car within a second from 20 m/s")
	for i in 300:
		v = ArcadeHandling.step_forward_speed(s, v, 0.0, 1.0, false, false, dt)
	near(v, -s.reverse_max_speed, 0.01, "holding brake reverses to reverse top speed")
	# Coasting slows down.
	v = 10.0
	v = ArcadeHandling.step_forward_speed(s, v, 0.0, 0.0, false, false, 1.0)
	near(v, 10.0 - s.coast_decel, 0.001, "coasting decelerates at coast_decel")
	# Turbo raises top speed.
	v = 0.0
	for i in 600:
		v = ArcadeHandling.step_forward_speed(s, v, 1.0, 0.0, true, false, dt)
	near(v, s.max_speed * s.turbo_speed_mult, 0.05, "turbo top speed")
	# Yaw direction: steer right = negative yaw (clockwise from above), reversed when backing up.
	check(ArcadeHandling.target_yaw_rate(s, 20.0, 1.0) < 0.0, "steer right turns right")
	check(ArcadeHandling.target_yaw_rate(s, -5.0, 1.0) > 0.0, "steering is mirrored in reverse")
	check(absf(ArcadeHandling.target_yaw_rate(s, 0.0, 1.0)) > 0.0, "a stopped car can pivot a little")
	var slow := absf(ArcadeHandling.target_yaw_rate(s, 8.0, 1.0))
	var fast := absf(ArcadeHandling.target_yaw_rate(s, 30.0, 1.0))
	check(fast < slow, "turn rate loosens at top speed")
	near(fast, deg_to_rad(s.turn_rate_deg) * s.high_speed_turn_scale, 0.001, "turn rate at top speed")
	# Digital steering ramps in.
	var st := 0.0
	var frames := 0
	while st < 0.999 and frames < 600:
		st = ArcadeHandling.step_steer(s, st, 1.0, true, dt)
		frames += 1
	near(frames * dt, s.steer_ramp_time, dt * 1.5, "digital steering reaches full lock in steer_ramp_time")
	check(ArcadeHandling.step_steer(s, 0.0, 0.5, false, dt) < 0.5, "analog response curve softens small inputs")
	# Lateral slide decays; slower in a drift.
	var grip_lat := ArcadeHandling.step_lateral(s, 5.0, false, 0.1)
	var drift_lat := ArcadeHandling.step_lateral(s, 5.0, true, 0.1)
	check(grip_lat < drift_lat and drift_lat < 5.0, "drift keeps more slide than normal grip")
	# Turbo meter drains and regenerates.
	var state := ArcadeHandling.DriveState.new()
	state.turbo = 50.0
	var c := ArcadeHandling.ControlFrame.new()
	c.turbo = true
	ArcadeHandling.step(s, state, c, true, 1.0)
	check(state.ignited, "turbo lights on the first boosted step")
	near(state.turbo, 50.0 - s.turbo_drain - s.turbo_kick_cost, 0.001, "turbo drains while boosting, plus the kick")
	c.turbo = false
	ArcadeHandling.step(s, state, c, true, 1.0)
	near(state.turbo, 50.0 - s.turbo_drain - s.turbo_kick_cost + s.turbo_regen, 0.001, "turbo regenerates when released")
	state.turbo = 0.0
	c.turbo = true
	ArcadeHandling.step(s, state, c, true, dt)
	check(not state.boosting, "no boost with an empty meter")
	# Nitrous kick: lighting the turbo shoves the car forward once, not every step.
	state = ArcadeHandling.DriveState.new()
	state.speed = 10.0
	c = ArcadeHandling.ControlFrame.new()
	c.turbo = true
	ArcadeHandling.step(s, state, c, true, dt)
	check(state.speed >= 10.0 + s.turbo_kick, "turbo kick adds speed when it lights (%.2f m/s)" % state.speed)
	var after_kick := state.speed
	ArcadeHandling.step(s, state, c, true, dt)
	check(state.speed - after_kick < s.turbo_kick * 0.5 and not state.ignited, "the kick happens once per light-up")
	# Rocket push doesn't fade: near top speed the boost still pulls hard.
	var pull_fast := ArcadeHandling.step_forward_speed(s, s.max_speed, 1.0, 0.0, true, false, dt) - s.max_speed
	var pull_plain := ArcadeHandling.step_forward_speed(s, s.max_speed * 0.9, 1.0, 0.0, false, false, dt) - s.max_speed * 0.9
	check(pull_fast > pull_plain * 2.0, "turbo still pulls hard at top speed (%.3f vs %.3f m/s per step)" % [pull_fast, pull_plain])
	# Turbo in the air: forward thrust and lift while falling, no lift while rising.
	state = ArcadeHandling.DriveState.new()
	state.speed = 5.0
	state.vertical = -4.0
	ArcadeHandling.step(s, state, c, false, dt)
	check(state.boosting, "turbo works in the air")
	check(state.air_push > s.turbo_air_thrust * dt * 0.99, "air turbo pushes forward")
	near(state.air_lift, s.turbo_air_lift * dt, 0.0001, "air turbo holds off the fall")
	state.vertical = 6.0
	ArcadeHandling.step(s, state, c, false, dt)
	near(state.air_lift, 0.0, 0.0001, "air turbo adds no lift on the way up")
	state.speed = s.max_speed * s.turbo_speed_mult
	ArcadeHandling.step(s, state, c, false, dt)
	near(state.air_push, 0.0, 0.0001, "air turbo stops pushing at turbo top speed")
	c.turbo = false
	ArcadeHandling.step(s, state, c, false, dt)
	check(not state.boosting and state.air_push == 0.0, "no air push without turbo")
	# Power slide needs speed, brake and steer.
	state = ArcadeHandling.DriveState.new()
	state.speed = 25.0
	state.steer = 1.0
	c = ArcadeHandling.ControlFrame.new()
	c.brake = 1.0
	c.steer = 1.0
	c.steer_digital = false
	ArcadeHandling.step(s, state, c, true, dt)
	check(state.drifting, "brake + steer at speed starts a power slide")


func _test_combat_rules() -> void:
	var h := CombatRules.Health.new(100.0)
	near(h.damage(30.0), 30.0, 0.001, "damage applies")
	near(h.heal(50.0), 30.0, 0.001, "heal clamps to max")
	h.damage(500.0)
	check(h.is_dead() and h.current == 0.0, "health floors at zero")
	near(h.heal(10.0), 0.0, 0.001, "the dead cannot be healed")
	var g := CombatRules.GunState.new()
	g.configure(GameData.weapon("machine_gun"))
	var shots := 0
	var t := 0.0
	while not g.overheated and t < 30.0:
		shots += g.tick(1.0 / 60.0, true)
		t += 1.0 / 60.0
	check(g.overheated, "holding the trigger overheats the gun")
	check(t > 1.5 and t < 4.0, "overheat takes 1.5-4 s of fire (took %.2f s, %d shots)" % [t, shots])
	check(g.tick(1.0 / 60.0, true) == 0, "an overheated gun does not fire")
	var cool := 0.0
	while g.overheated and cool < 10.0:
		g.tick(1.0 / 60.0, false)
		cool += 1.0 / 60.0
	check(not g.overheated and cool < 3.0, "the gun recovers after cooling (%.2f s)" % cool)
	near(CombatRules.impact_damage(5.0, 1.0, 1.0), 0.0, 0.001, "gentle bumps do no damage")
	check(CombatRules.impact_damage(20.0, 1.0, 1.0) > CombatRules.impact_damage(12.0, 1.0, 1.0), "harder rams hurt more")
	check(CombatRules.impact_damage(20.0, 1.0, 2.0) < CombatRules.impact_damage(20.0, 1.0, 1.0), "ram armor reduces damage")
	near(CombatRules.splash_damage(0.0, 8.0, 30.0), 30.0, 0.001, "splash is full at the centre")
	near(CombatRules.splash_damage(8.0, 8.0, 30.0), 0.0, 0.001, "splash is zero at the edge")
	var hp := CombatRules.Health.new(100.0)
	var drive := ArcadeHandling.DriveState.new()
	drive.turbo = 100.0
	check(not CombatRules.apply_pickup("health", 35.0, hp, drive, 100.0), "health pickup is left alone at full health")
	check(not CombatRules.apply_pickup("turbo", 100.0, hp, drive, 100.0), "turbo pickup is left alone with a full meter")
	hp.damage(50.0)
	drive.turbo = 10.0
	check(CombatRules.apply_pickup("health", 35.0, hp, drive, 100.0) and hp.current == 85.0, "health pickup heals")
	check(CombatRules.apply_pickup("turbo", 100.0, hp, drive, 100.0) and drive.turbo == 100.0, "turbo pickup refills")


func _test_input() -> void:
	for preset in InputSetup.PRESETS:
		InputSetup.apply_preset(1, -1, preset, true)
		for a in InputSetup.ACTIONS:
			var act := InputSetup.action(1, a)
			check(InputMap.has_action(act), "%s: action %s exists" % [preset, act])
		var has_pad := false
		for ev in InputMap.action_get_events(InputSetup.action(1, "accelerate")):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		check(has_pad, "%s: accelerate is on the pad" % preset)
	# The four D-pad layouts, checked against the controls table Mathias sent
	# (PlayStation buttons moved to Xbox: Cross A, Circle B, Square X, Triangle Y,
	# L1/R1 LB/RB, L2/R2 LT/RT, Select View, Start Menu).
	var A := "btn:%d" % JOY_BUTTON_A
	var B := "btn:%d" % JOY_BUTTON_B
	var X := "btn:%d" % JOY_BUTTON_X
	var Y := "btn:%d" % JOY_BUTTON_Y
	var LB := "btn:%d" % JOY_BUTTON_LEFT_SHOULDER
	var RB := "btn:%d" % JOY_BUTTON_RIGHT_SHOULDER
	var LT := "axis:%d:+" % JOY_AXIS_TRIGGER_LEFT
	var RT := "axis:%d:+" % JOY_AXIS_TRIGGER_RIGHT
	var expected := {
		"standard": {"accelerate": X, "brake": B, "turbo": Y, "tight_turn": A,
			"special_next": RB, "special_prev": LB, "fire_special": LT, "fire_gun": RT},
		"alt1": {"accelerate": A, "brake": LT, "turbo": Y, "tight_turn": RT,
			"special_next": RB, "special_prev": LB, "fire_special": B, "fire_gun": X},
		"alt2": {"accelerate": A, "brake": LT, "turbo": Y, "tight_turn": RT,
			"special_next": RB, "special_prev": LB, "fire_special": X, "fire_gun": B},
		"shoulders": {"accelerate": RT, "brake": RB, "turbo": LB, "tight_turn": LT,
			"special_next": Y, "special_prev": B, "fire_special": A, "fire_gun": X},
	}
	for preset in expected:
		InputSetup.apply_preset(1, -1, preset, false)
		for a in expected[preset]:
			check(_has_code(a, expected[preset][a]), "%s: %s on %s" % [preset, a, InputBindings.describe(expected[preset][a])])
		check(_has_code("accelerate", "btn:%d" % JOY_BUTTON_DPAD_UP), "%s: D-pad up is gas" % preset)
		check(_has_code("brake", "btn:%d" % JOY_BUTTON_DPAD_DOWN), "%s: D-pad down is brake" % preset)
		for dir in ["left", "right"]:
			var code := "btn:%d" % (JOY_BUTTON_DPAD_LEFT if dir == "left" else JOY_BUTTON_DPAD_RIGHT)
			check(_has_code("steer_" + dir, code) and _has_code("combo_" + dir, code), "%s: D-pad %s steers and enters combos" % [preset, dir])
		check(_has_code("pause", "btn:%d" % JOY_BUTTON_BACK), "%s: View pauses" % preset)
		check(_has_code("view_mod", "btn:%d" % JOY_BUTTON_START), "%s: Menu is the view button" % preset)
	check(InputSetup.DEFAULT_PRESET == "standard" and InputSetup.PRESETS[0] == "standard", "Standard is the default layout")
	check(InputSetup.resolve_preset("classic") == "standard", "the old Classic setting becomes Standard")
	check(InputSetup.resolve_preset("junk") == "standard", "an unknown layout falls back to Standard")
	# Modern: our own stick-and-trigger layout.
	InputSetup.apply_preset(1, -1, "modern", false)
	check(_has_code("accelerate", RT) and _has_code("brake", LT) and _has_code("tight_turn", B), "modern: RT gas, LT brake, B tight turn")
	for preset in InputSetup.PRESETS:
		InputSetup.apply_preset(1, -1, preset, true)
		check(_has_code("combo_hold", RT), "%s: RT is the combo hold" % preset)
	InputSetup.apply_preset(1, -1, "modern", true)


func _has_code(action: String, code: String) -> bool:
	for ev in InputMap.action_get_events(InputSetup.action(1, action)):
		if InputBindings.encode(ev) == code:
			return true
	return false


func _apply_with_remaps(preset: String) -> void:
	InputSetup.apply_preset(1, -1, preset, true)
	InputBindings.apply(1, -1, preset)


func _test_remap() -> void:
	var saved: Dictionary = InputBindings.overrides
	InputBindings.overrides = {}
	# Codes survive a round trip.
	for code in ["btn:0", "btn:12", "axis:5:+", "axis:0:-", "key:87"]:
		check(InputBindings.encode(InputBindings.decode(code)) == code, "remap: %s round-trips" % code)
	check(InputBindings.decode("junk") == null, "remap: junk code is rejected")
	check(InputBindings.describe("axis:5:+") == "RT", "remap: RT has a readable name")

	# Pad remap with swap: put the gun on A (turbo's button in Modern).
	_apply_with_remaps("modern")
	var swapped := InputBindings.set_pad(1, "modern", "fire_gun", "btn:%d" % JOY_BUTTON_A)
	_apply_with_remaps("modern")
	check(swapped == "turbo", "remap: gun onto A swaps with turbo")
	check(_has_code("fire_gun", "btn:%d" % JOY_BUTTON_A), "remap: gun is on A")
	check(not _has_code("fire_gun", "btn:%d" % JOY_BUTTON_RIGHT_SHOULDER), "remap: gun is off RB")
	check(_has_code("turbo", "btn:%d" % JOY_BUTTON_RIGHT_SHOULDER), "remap: turbo took RB")
	check(not _has_code("turbo", "btn:%d" % JOY_BUTTON_A), "remap: turbo is off A")
	check(_has_code("fire_gun", "key:%d" % KEY_SPACE), "remap: pad remap leaves keyboard alone")

	# Pad remaps are per layout.
	_apply_with_remaps("standard")
	check(_has_code("fire_gun", "axis:%d:+" % JOY_AXIS_TRIGGER_RIGHT), "remap: standard layout is untouched")

	# Keyboard remap with swap: accelerate main key to Space (the gun's key).
	_apply_with_remaps("modern")
	swapped = InputBindings.set_key(1, "accelerate", 0, "key:%d" % KEY_SPACE)
	_apply_with_remaps("modern")
	check(swapped == "fire_gun", "remap: Space swaps with the gun")
	check(_has_code("accelerate", "key:%d" % KEY_SPACE), "remap: accelerate on Space")
	check(_has_code("accelerate", "key:%d" % KEY_UP), "remap: accelerate keeps its alt key")
	check(_has_code("fire_gun", "key:%d" % KEY_W), "remap: gun took W")
	InputBindings.clear_key(1, "accelerate", 1)
	_apply_with_remaps("modern")
	check(not _has_code("accelerate", "key:%d" % KEY_UP), "remap: alt key cleared")

	# Remapping steering to the right stick moves analog steering with it.
	InputBindings.set_pad(1, "modern", "steer_left", "axis:%d:-" % JOY_AXIS_RIGHT_X)
	_apply_with_remaps("modern")
	check(_has_code("steer_left", "axis:%d:-" % JOY_AXIS_RIGHT_X), "remap: steer left on right stick")

	# Saved and loaded through a config file.
	var cfg := ConfigFile.new()
	InputBindings.save_to(cfg)
	var before: Dictionary = InputBindings.overrides.duplicate(true)
	InputBindings.overrides = {}
	InputBindings.load_from(cfg)
	check(InputBindings.overrides == before, "remap: overrides survive save and load")

	# Reset puts the defaults back.
	InputBindings.reset("modern")
	_apply_with_remaps("modern")
	check(_has_code("fire_gun", "btn:%d" % JOY_BUTTON_RIGHT_SHOULDER), "remap: reset puts the gun back on RB")
	check(_has_code("accelerate", "key:%d" % KEY_W), "remap: reset puts W back")
	check(not InputBindings.has_overrides("modern"), "remap: nothing left after reset")

	InputBindings.overrides = saved
	InputSetup.apply_preset(1, -1, "modern", true)


## Simulated presses register as "just pressed" on the next rendered frame, which is
## when the match polls these commands too.
func _poll_after(pd: PlayerDriver) -> Array[String]:
	await process_frame
	return pd.poll_commands(1.0 / 60.0)


func _test_view_commands() -> void:
	InputSetup.apply_preset(1, -1, "standard", true)
	var pd := PlayerDriver.new(1, -1)
	var mod := InputSetup.action(1, "view_mod")
	var up := InputSetup.action(1, "combo_up")
	await _poll_after(pd)   # first poll only records what's held
	Input.action_press(mod)
	await _poll_after(pd)
	Input.action_press(up)
	var out: Array[String] = await _poll_after(pd)
	check(out == ["view_next"], "Menu + D-pad up changes the view (got %s)" % str(out))
	var f := pd.get_frame(null, 1.0 / 60.0)
	check(f.combo_presses.is_empty(), "D-pad presses with Menu held aren't combo presses")
	Input.action_release(up)
	Input.action_release(mod)
	out = await _poll_after(pd)
	check(not ("pause" in out), "releasing Menu after a view command doesn't pause")
	Input.action_press(mod)
	await _poll_after(pd)
	Input.action_release(mod)
	out = await _poll_after(pd)
	check(out == ["pause"], "tapping Menu on its own pauses (got %s)" % str(out))
	Input.action_press(InputSetup.action(1, "radar"))
	out = await _poll_after(pd)
	Input.action_release(InputSetup.action(1, "radar"))
	check(out == ["radar"], "the radar key toggles the radar (got %s)" % str(out))
	await process_frame
	InputSetup.apply_preset(1, -1, "modern", true)


func _test_combo_buffer() -> void:
	var data: Dictionary = GameData.load_json(GameData.COMBOS_PATH)
	var moves: Dictionary = data["moves"]
	check(moves.size() >= 5, "combos.json has at least five moves")
	var seen := {}
	for id in moves:
		var key := ",".join(moves[id]["inputs"])
		check(not seen.has(key), "combo %s has its own inputs" % id)
		seen[key] = true
		check(moves[id]["inputs"].size() >= 3, "combo %s takes three or more presses" % id)
	var b := ComboBuffer.new()
	b.configure(moves, 0.45)
	# Each move fires on its own sequence, tapped 0.1 s apart.
	var t := 10.0
	for id in moves:
		var got := ""
		var hold := bool(moves[id].get("hold", false))
		for d in moves[id]["inputs"]:
			t += 0.1
			got = b.push(d, t, hold)
		check(got == id, "combo buffer recognises %s" % id)
		check(b.pending().is_empty(), "combo buffer clears after %s" % id)
		t += 1.0
	# Too slow: a gap longer than the window starts over.
	check(b.push("down", 20.0) == "" and b.push("down", 20.1) == "", "slow combo: first presses")
	check(b.push("up", 20.8) == "", "slow combo does not fire")
	check(b.pending() == ["up"], "a late press starts a new sequence")
	# Steering-style taps on left and right alone never fire a move.
	b.reset()
	var fired := false
	for i in 12:
		if b.push(["left", "right"][i % 2], 30.0 + i * 0.1) != "":
			fired = true
	check(not fired, "left/right steering taps fire nothing")
	# Held moves: Rivet Storm needs the hold control, and with it held the long code
	# never sets off a short move partway through.
	var storm: Array = moves["rivet_storm"]["inputs"]
	check(storm.size() == 8 and bool(moves["rivet_storm"]["hold"]), "Rivet Storm is the long held code")
	b.reset()
	var fired_ids: Array[String] = []
	for i in storm.size():
		var id := b.push(storm[i], 40.0 + i * 0.1, false)
		if id != "":
			fired_ids.append(id)
	check(not ("rivet_storm" in fired_ids), "Rivet Storm doesn't fire without the hold")
	b.reset()
	fired_ids.clear()
	for i in storm.size():
		var id := b.push(storm[i], 50.0 + i * 0.1, true)
		if id != "":
			fired_ids.append(id)
	check(fired_ids == ["rivet_storm"], "held: the long code fires only Rivet Storm (got %s)" % str(fired_ids))
	# Holding RT (it accelerates in Modern) doesn't block the short moves.
	b.reset()
	var napalm: Array = moves["fire_jug"]["inputs"]
	var got_napalm := ""
	for i in napalm.size():
		got_napalm = b.push(napalm[i], 60.0 + i * 0.1, true)
	check(got_napalm == "fire_jug", "short moves still fire while RT is held")
	# Longest sequence wins when two moves end on the same presses.
	var nested := ComboBuffer.new()
	nested.configure({"short": {"inputs": ["down", "up"]}, "long": {"inputs": ["down", "down", "up"]}}, 0.45)
	nested.push("down", 0.0)
	nested.push("down", 0.1)
	check(nested.push("up", 0.2) == "long", "longest matching combo wins")


func _test_status_effects() -> void:
	var st := StatusEffects.new()
	st.configure(100.0, 6.0)
	check(st.try_spend("jack", 25.0, 0.5) and st.energy == 75.0, "a move spends its energy")
	check(not st.try_spend("jack", 25.0, 0.5), "a move is blocked by its cooldown")
	check(st.try_spend("other", 25.0, 0.5), "cooldowns are per move")
	st.tick(0.6)
	near(st.energy, 50.0 + 3.6, 0.001, "energy regenerates")
	check(st.try_spend("jack", 25.0, 0.5), "a move is ready after its cooldown")
	check(not st.try_spend("big", 100.0, 0.5), "a move needs enough energy")
	st.reset()
	st.freeze(2.0)
	check(st.is_frozen(), "freeze freezes")
	st.tick(2.1)
	check(not st.is_frozen(), "freeze wears off")
	st.ignite(2.0, 5.0, null)
	near(st.tick(1.0), 5.0, 0.001, "burning deals damage over time")
	near(st.tick(5.0), 5.0, 0.001, "burning stops when its time runs out")
	check(not st.is_burning(), "burn wears off")
	st.ignite(3.0, 5.0, null)
	st.freeze(3.0)
	st.shield(2.0)
	check(st.is_shielded() and not st.is_burning() and not st.is_frozen(), "the shield puts out fire and thaws")
	st.freeze(2.0)
	st.ignite(2.0, 5.0, null)
	check(not st.is_frozen() and not st.is_burning(), "the shield blocks freeze and fire")
	st.tick(2.1)
	check(not st.is_shielded(), "the shield wears off")
	st.cloak(4.0)
	check(st.is_cloaked(), "Blackout cloaks")
	st.reveal()
	check(not st.is_cloaked(), "firing reveals a cloaked car")
	st.overdrive(1.0)
	check(st.is_overdriven(), "Rivet Storm overdrives the guns")
	st.tick(1.1)
	check(not st.is_overdriven(), "Rivet Storm wears off")


# --- Handling on a test pad -----------------------------------------------------------

func _make_pad() -> Node3D:
	var world := Node3D.new()
	world.name = "TestPad"
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = ArcadeVehicle.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 800)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	return world


func _add_ramp(world: Node3D, bottom: Vector3, top: Vector3, width: float) -> void:
	var dir := top - bottom
	var zz := -dir.normalized()
	var xx := Vector3.UP.cross(zz).normalized()
	var yy := zz.cross(xx).normalized()
	var body := StaticBody3D.new()
	body.collision_layer = ArcadeVehicle.LAYER_WORLD
	body.transform = Transform3D(Basis(xx, yy, zz), (bottom + top) * 0.5 - yy * 0.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, dir.length())
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)


func _spawn(world: Node3D, id: String, at: Vector3, yaw: float = 0.0) -> Array:
	var driver := ScriptedDriver.new()
	var v := VehicleFactory.create(id, driver, false, false)
	world.add_child(v)
	v.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	v.reset_physics_interpolation()
	return [v, driver]


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Drives at the kicker ramp at full throttle and measures the jump. With turbo_in_air,
## the turbo is held from the moment the car leaves the ramp until it lands.
func _ramp_jump(turbo_in_air: bool) -> Dictionary:
	var dt := 1.0 / 60.0
	var world := _make_pad()
	_add_ramp(world, Vector3(0, 0, -100), Vector3(0, 2.2, -109), 8.0)
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 60))
	var v: ArcadeVehicle = pair[0]
	var drv: ScriptedDriver = pair[1]
	drv.frame.throttle = 1.0
	var out := {"takeoff_speed": 0.0, "distance": -1.0, "airtime": 0.0, "upright": false, "max_tilt": 0.0}
	var left_ground := false
	var takeoff := Vector3.ZERO
	var landed := Vector3.ZERO
	var t := 0.0
	while t < 12.0:
		await physics_frame
		t += dt
		if not left_ground and not v.grounded and v.global_position.z < -100.0:
			left_ground = true
			takeoff = v.global_position
			out["takeoff_speed"] = v.linear_velocity.length()
			drv.frame.turbo = turbo_in_air
		elif left_ground and v.grounded and landed == Vector3.ZERO:
			landed = v.global_position
			drv.frame.turbo = false
		if left_ground and landed == Vector3.ZERO:
			out["airtime"] += dt
		if left_ground:
			out["max_tilt"] = maxf(out["max_tilt"], rad_to_deg(acos(clampf(v.global_transform.basis.y.y, -1.0, 1.0))))
		if landed != Vector3.ZERO and v.global_position.z < landed.z - 20.0:
			break
	if landed != Vector3.ZERO:
		out["distance"] = _flat(landed - takeoff).length()
	out["upright"] = v.global_transform.basis.y.y > 0.9
	world.queue_free()
	await _frames(2)
	return out


func _handling_measurements() -> void:
	var dt := 1.0 / 60.0
	var stats := GameData.load_vehicle("rustjaw", false)

	# 1. Launch: 0 to 90% of top speed, and top speed.
	var world := _make_pad()
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 300))
	var v: ArcadeVehicle = pair[0]
	var drv: ScriptedDriver = pair[1]
	drv.frame.throttle = 1.0
	var t := 0.0
	var t90 := -1.0
	while t < 8.0:
		await physics_frame
		t += dt
		if t90 < 0.0 and v.drive.speed >= stats.max_speed * 0.9:
			t90 = t
	_measure["time_to_90pct_top_speed_s"] = t90
	_measure["top_speed_ms"] = v.drive.speed

	# 2. Stopping distance from top speed.
	var start := v.global_position
	drv.frame.throttle = 0.0
	drv.frame.brake = 1.0
	t = 0.0
	while v.drive.speed > 0.3 and t < 5.0:
		await physics_frame
		t += dt
	_measure["stop_distance_from_top_m"] = _flat(v.global_position - start).length()
	_measure["stop_time_s"] = t
	world.queue_free()
	await _frames(2)

	# 3. Turning circles at half and full throttle (stick at full lock).
	_measure["turn_circle_half_speed_m"] = await _turn_circle(0.5)
	_measure["turn_circle_top_speed_m"] = await _turn_circle(1.0)
	_measure["tight_turn_circle_top_speed_m"] = await _turn_circle(1.0, true)
	_measure["tight_turn_180_from_top_speed_s"] = _half_turn_s

	# 4. Digital steering: time to full lock on the D-pad.
	world = _make_pad()
	pair = await _spawn_settled(world, Vector3(0, 1.0, 0))
	v = pair[0]
	drv = pair[1]
	drv.frame.steer = 1.0
	drv.frame.steer_digital = true
	t = 0.0
	while v.drive.steer < 0.999 and t < 2.0:
		await physics_frame
		t += dt
	_measure["digital_full_lock_s"] = t
	world.queue_free()
	await _frames(2)

	# 5. Jump: a 9 m kicker rising 2.2 m (the Foundry Yard's east-lane ramp) at full throttle.
	var jump := await _ramp_jump(false)
	_measure["ramp_takeoff_speed_ms"] = jump["takeoff_speed"]
	_measure["ramp_jump_distance_m"] = jump["distance"]
	_measure["ramp_airtime_s"] = jump["airtime"]
	_measure["upright_after_landing"] = jump["upright"]
	_measure["max_tilt_in_air_deg"] = jump["max_tilt"]
	# The same jump with the turbo lit only once the car leaves the ramp.
	var rocket := await _ramp_jump(true)
	_measure["ramp_jump_turbo_in_air_m"] = rocket["distance"]
	_measure["ramp_airtime_turbo_in_air_s"] = rocket["airtime"]
	check(rocket["distance"] > jump["distance"] + 5.0, "turbo in the air carries a jump further (%.1f m vs %.1f m)" % [rocket["distance"], jump["distance"]])
	check(rocket["upright"], "lands upright after a turbo jump")

	# 5b. Spring Jack from a standstill, then turbo in the air: the rockets drive you forward.
	world = _make_pad()
	pair = await _spawn_settled(world, Vector3(0, 1.0, 0))
	v = pair[0]
	drv = pair[1]
	var hop_start := v.global_position
	var lv := v.linear_velocity
	lv.y = 11.0
	v.linear_velocity = lv
	drv.frame.turbo = true
	await _frames(6)
	check(not v.grounded, "spring hop leaves the ground")
	var hop_frames := 0
	while not v.grounded and hop_frames < 240:
		await physics_frame
		hop_frames += 1
	var hop_forward := -(v.global_position - hop_start).z
	_measure["standing_hop_turbo_forward_m"] = hop_forward
	check(hop_forward > 8.0, "turbo drives a standing hop forward (%.1f m)" % hop_forward)
	drv.frame.turbo = false
	world.queue_free()
	await _frames(2)

	# 6. T-bone ram at top speed into a parked car.
	world = _make_pad()
	var target_pair := await _spawn_settled(world, Vector3(0, 1.0, 0), PI * 0.5)
	var parked: ArcadeVehicle = target_pair[0]
	pair = await _spawn_settled(world, Vector3(0, 1.0, 70))
	v = pair[0]
	drv = pair[1]
	drv.frame.throttle = 1.0
	t = 0.0
	var parked_hp := parked.health.current
	var rammer_hp := v.health.current
	while t < 6.0:
		await physics_frame
		t += dt
	drv.frame.throttle = 0.0
	await _frames(120)
	_measure["ram_damage_to_parked"] = parked_hp - parked.health.current
	_measure["ram_damage_to_rammer"] = rammer_hp - v.health.current
	_measure["stays_upright_after_ram"] = parked.global_transform.basis.y.y > 0.7 and v.global_transform.basis.y.y > 0.7
	_measure["parked_shoved_m"] = _flat(parked.global_position).length()
	world.queue_free()
	await _frames(2)

	# 7. A car dropped on its roof is set back on its wheels.
	world = _make_pad()
	pair = _spawn(world, "rustjaw", Vector3(0, 1.5, 0))
	v = pair[0]
	v.global_transform = Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0, 1.5, 0))
	await _frames(60 * 4)
	check(v.global_transform.basis.y.y > 0.9, "a car on its roof recovers within 4 s")
	world.queue_free()
	await _frames(2)

	# Check against design targets.
	var targets: Dictionary = GameData.load_json("res://data/handling_targets.json")["rustjaw"]
	for key in targets.keys():
		var want: Variant = targets[key]
		var got: Variant = _measure.get(key)
		if typeof(want) == TYPE_ARRAY:
			check(got != null and float(got) >= float(want[0]) and float(got) <= float(want[1]),
				"handling %s = %s, target %s-%s" % [key, _fmt(got), want[0], want[1]])
		else:
			check(got == want, "handling %s = %s, target %s" % [key, str(got), str(want)])
	check(_measure["upright_after_landing"], "lands the kicker jump on its wheels")
	check(float(_measure["tight_turn_circle_top_speed_m"]) < float(_measure["turn_circle_top_speed_m"]) * 0.8,
		"the tight turn button turns much tighter at top speed")
	check(float(_measure["ram_damage_to_parked"]) > 0.0, "a top-speed T-bone damages the parked car")
	for k in _measure.keys():
		print("  %-30s %s" % [k, _fmt(_measure[k])])


func _spawn_settled(world: Node3D, at: Vector3, yaw: float = 0.0) -> Array:
	var pair := _spawn(world, "rustjaw", at, yaw)
	await _frames(45)
	return pair


func _turn_circle(throttle: float, tight: bool = false) -> float:
	var world := _make_pad()
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 0))
	var v: ArcadeVehicle = pair[0]
	var drv: ScriptedDriver = pair[1]
	drv.frame.throttle = throttle
	await _frames(240)
	drv.frame.steer = 1.0
	drv.frame.steer_digital = false
	drv.frame.tight_turn = tight
	await _frames(240 if not tight else 30)
	var pts: Array[Vector3] = []
	var yaw_total := 0.0
	var last_fwd := _flat(-v.global_transform.basis.z).normalized()
	var guard := 0
	_half_turn_s = 0.0
	while yaw_total < TAU and guard < 2000:
		await physics_frame
		guard += 1
		var f := _flat(-v.global_transform.basis.z).normalized()
		yaw_total += absf(last_fwd.signed_angle_to(f, Vector3.UP))
		if _half_turn_s == 0.0 and yaw_total >= PI:
			_half_turn_s = guard / 60.0
		last_fwd = f
		pts.append(_flat(v.global_position))
	var diameter := 0.0
	for i in range(0, pts.size(), 4):
		for j in range(i, pts.size(), 4):
			diameter = maxf(diameter, pts[i].distance_to(pts[j]))
	world.queue_free()
	await _frames(2)
	return diameter


func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


func _fmt(x: Variant) -> String:
	if typeof(x) == TYPE_FLOAT:
		return "%.2f" % x
	return str(x)


# --- Combo moves and specials -----------------------------------------------------------

## Taps a D-pad sequence the way a player would: one press every few physics steps.
## `hold` keeps the combo hold control (RT) down while the code goes in.
func _tap(drv: ScriptedDriver, seq: Array, hold: bool = false) -> void:
	drv.frame.combo_hold = hold
	for d in seq:
		drv.frame.combo_presses.append(d)
		await _frames(4)
	drv.frame.combo_hold = false


func _inputs(id: String) -> Array:
	return GameData.load_json(GameData.COMBOS_PATH)["moves"][id]["inputs"]


func _count_nodes(parent: Node, script_class: String) -> Array:
	var out := []
	for c in parent.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == script_class:
			out.append(c)
	return out


func _combo_moves() -> void:
	var world := _make_pad()
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 0))
	var v: ArcadeVehicle = pair[0]
	var drv: ScriptedDriver = pair[1]
	var used: Array[String] = []
	var failed: Array[String] = []
	v.combos.move_used.connect(func(_v, id, _n): used.append(id))
	v.combos.move_failed.connect(func(_v, id, why): failed.append("%s:%s" % [id, why]))
	var target: ArcadeVehicle = _spawn(world, "scrap_drone", Vector3(0, 1.0, -22), 0.0)[0]
	await _frames(45)

	# Spring Jack: down, down, up launches the car.
	var y0 := v.global_position.y
	var e0 := v.status.energy
	await _tap(drv, _inputs("spring_jack"))
	var peak := y0
	for i in 40:
		await physics_frame
		peak = maxf(peak, v.global_position.y)
	check("spring_jack" in used, "Spring Jack fires from its D-pad combo")
	check(peak - y0 > 2.0, "Spring Jack lifts the car (%.1f m)" % (peak - y0))
	check(v.status.energy < e0, "Spring Jack costs energy")
	_measure["spring_jack_height_m"] = peak - y0
	await _frames(90)

	# Bulwark: no damage while it is up.
	v.status.reset()
	await _tap(drv, _inputs("bulwark"))
	check(v.status.is_shielded(), "Bulwark raises the shield")
	var hp := v.health.current
	var blocked := [0.0]
	v.shield_blocked.connect(func(_v, amount): blocked[0] += amount)
	v.take_damage(20.0, target)
	check(v.health.current == hp and blocked[0] == 20.0, "Bulwark blocks damage")
	v.status.shield_time = 0.0
	v.take_damage(5.0, target)
	check(v.health.current == hp - 5.0, "damage lands once Bulwark drops")

	# Not enough energy: the move fails and nothing happens.
	v.status.reset()
	v.status.energy = 10.0
	await _tap(drv, _inputs("bulwark"))
	check(not v.status.is_shielded() and "bulwark:energy" in failed, "Bulwark needs energy")

	# Cold Snap: freezes the drone in front.
	v.status.reset()
	await _tap(drv, _inputs("cold_snap"))
	var t := 0.0
	while not target.status.is_frozen() and t < 2.0:
		await physics_frame
		t += 1.0 / 60.0
	check(target.status.is_frozen(), "Cold Snap freezes the car in front (%.2f s)" % t)
	# A frozen car cannot drive.
	var tdrv: ScriptedDriver = target.driver
	tdrv.frame.throttle = 1.0
	var tz := target.global_position
	await _frames(40)
	check(target.global_position.distance_to(tz) < 1.0, "a frozen car cannot drive")
	await _frames(120)
	check(not target.status.is_frozen(), "the freeze thaws")
	tdrv.frame.throttle = 0.0
	await _frames(60)

	# Scrap Mine: dropped behind, blows up the next car over it.
	v.status.reset()
	await _tap(drv, _inputs("scrap_mine"))
	var mines := get_nodes_in_group("mines")
	check(mines.size() == 1, "Scrap Mine drops a mine")
	if mines.size() == 1:
		var mine: Node3D = mines[0]
		var behind := (mine.global_position - v.global_position).dot(v.global_transform.basis.z)
		check(behind > 1.5, "the mine lands behind the car")
		await _frames(45)
		var thp := target.health.current
		target.global_transform = Transform3D(Basis.IDENTITY, mine.global_position + Vector3.UP * 0.8)
		target.linear_velocity = Vector3.ZERO
		target.reset_physics_interpolation()
		await _frames(10)
		check(target.health.current < thp, "the mine damages the car that hits it")
		check(not is_instance_valid(mine) or mine.is_queued_for_deletion(), "the mine is used up")
	target.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -22))
	target.linear_velocity = Vector3.ZERO
	target.reset_physics_interpolation()
	target.health.current = target.stats.max_health
	await _frames(45)

	# Fire Jug: a lobbed bomb that leaves burning fuel.
	v.status.reset()
	await _tap(drv, _inputs("fire_jug"))
	var pools: Array = []
	t = 0.0
	while pools.is_empty() and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
		pools = _count_nodes(world, "FirePool")
	check(not pools.is_empty(), "Fire Jug leaves a fire pool")
	if not pools.is_empty():
		var pool: Node3D = pools[0]
		var lob := _flat(pool.global_position - v.global_position).length()
		check(lob > 8.0, "Fire Jug is thrown ahead (%.1f m)" % lob)
		_measure["fire_jug_range_m"] = lob
		var thp := target.health.current
		target.global_transform = Transform3D(Basis.IDENTITY, pool.global_position + Vector3.UP * 0.8)
		target.linear_velocity = Vector3.ZERO
		target.reset_physics_interpolation()
		await _frames(60)
		check(target.status.is_burning(), "the fire pool sets cars alight")
		check(target.health.current < thp, "burning hurts")
	# The shield puts the fire out.
	target.combos.request_move("bulwark")
	check(not target.status.is_burning(), "Bulwark puts out the fire")
	target.status.reset()
	target.health.current = target.stats.max_health
	target.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -22))
	target.linear_velocity = Vector3.ZERO
	target.reset_physics_interpolation()
	await _frames(45)

	# Tailgunner with no special: a freeze blast out the back, paid for with energy.
	# (The car's own special counts as a selected weapon, so it starts recharging here.)
	v.status.reset()
	v.specials.clear()
	v.specials.signature_charge = 0.0
	target.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 18))
	target.linear_velocity = Vector3.ZERO
	target.reset_physics_interpolation()
	await _frames(30)
	var tail_cost := float(GameData.load_json(GameData.COMBOS_PATH)["moves"]["tailgunner"]["cost"])
	var e_tail := v.status.energy
	await _tap(drv, _inputs("tailgunner"))
	check("tailgunner" in used, "Tailgunner fires from its D-pad combo")
	near(v.status.energy, e_tail - tail_cost, 2.0, "with no special, Tailgunner costs energy")
	t = 0.0
	while not target.status.is_frozen() and t < 1.5:
		await physics_frame
		t += 1.0 / 60.0
	check(target.status.is_frozen(), "with no special, Tailgunner freezes the car behind (%.2f s)" % t)
	target.status.reset()
	await _frames(45)

	# With a special selected: that weapon goes out the back, using ammo, not energy.
	v.status.reset()
	v.specials.add("seeker", 1)
	var thp3 := target.health.current
	await _tap(drv, _inputs("tailgunner"))
	check(v.status.energy >= v.status.energy_max - 0.01, "a rear special shot costs no energy")
	check(v.specials.count("seeker") == 0, "a rear special shot uses one of its shots")
	t = 0.0
	while target.health.current >= thp3 and t < 1.5:
		await physics_frame
		t += 1.0 / 60.0
	check(target.health.current < thp3, "Tailgunner fires the selected Seeker at the car behind (%.2f s)" % t)
	check(not target.status.is_frozen(), "a rear special shot is the special, not a freeze")
	await _frames(45)

	# Out of ammo: back to the freeze blast for energy.
	var e_tail2 := v.status.energy
	await _tap(drv, _inputs("tailgunner"))
	near(v.status.energy, e_tail2 - tail_cost, 2.0, "out of ammo, Tailgunner uses energy again")
	await _frames(45)
	# No special and not enough energy: nothing fires.
	v.status.reset()
	v.status.energy = 10.0
	failed.clear()
	await _tap(drv, _inputs("tailgunner"))
	check("tailgunner:energy" in failed, "with no special and no energy, Tailgunner fails")
	v.status.reset()
	target.status.reset()
	target.health.current = target.stats.max_health
	target.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -22))
	target.linear_velocity = Vector3.ZERO
	target.reset_physics_interpolation()
	await _frames(45)

	# Blackout: a cloaked car can't be locked on or hunted, and firing gives it away.
	var gun: MachineGun = v.get_node("MachineGun")
	check(gun.current_target == target, "the gun locks on to the drone ahead")
	target.combos.request_move("blackout")
	await _frames(2)
	check(target.status.is_cloaked(), "Blackout cloaks the car")
	check(gun.current_target == null, "a cloaked car can't be locked on")
	v.add_to_group("players")
	var hunter := DroneDriver.new([Vector3.ZERO] as Array[Vector3])
	check(hunter._find_prey(target) == v, "a drone hunts a visible player")
	v.combos.request_move("blackout")
	check(hunter._find_prey(target) == null, "a drone can't find a cloaked player")
	v.remove_from_group("players")
	v.status.reset()
	var tdrv2: ScriptedDriver = target.driver
	tdrv2.frame.fire_gun = true
	await _frames(10)
	tdrv2.frame.fire_gun = false
	check(not target.status.is_cloaked(), "firing ends Blackout")
	await _frames(60)
	target.health.current = target.stats.max_health

	# Rivet Storm: needs RT held through the long code, then the guns can't overheat.
	v.status.reset()
	gun.gun.heat = 0.0
	gun.gun.overheated = false
	used.clear()
	await _tap(drv, _inputs("rivet_storm"))
	check(not v.status.is_overdriven(), "Rivet Storm needs RT held")
	await _frames(40)
	v.status.reset()
	used.clear()
	await _tap(drv, _inputs("rivet_storm"), true)
	check(v.status.is_overdriven() and used == ["rivet_storm"], "held: the long code fires Rivet Storm and nothing else (%s)" % str(used))
	var shp := target.health.current
	drv.frame.fire_gun = true
	var max_heat := 0.0
	var shots_t := 0.0
	while v.status.is_overdriven() and target.is_alive():
		await physics_frame
		shots_t += 1.0 / 60.0
		max_heat = maxf(max_heat, gun.gun.heat)
	drv.frame.fire_gun = false
	check(max_heat == 0.0 and not gun.gun.overheated, "the guns don't heat up during Rivet Storm")
	check(target.health.current < shp or not target.is_alive(), "Rivet Storm shreds the drone")
	_measure["rivet_storm_damage_per_s"] = (shp - maxf(target.health.current, 0.0)) / maxf(shots_t, 0.01)
	if not target.is_alive():
		target.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -22)))
	target.health.current = target.stats.max_health
	target.status.reset()
	await _frames(45)

	# Weapon crates and special weapons.
	check(v.specials.total() == 0, "no special weapons at the start")
	check(v.apply_pickup("weapon", 2), "a weapon crate gives a special")
	check(v.specials.total() == 2 and v.specials.selected != "", "the crate adds two shots and selects them")
	v.specials.clear()
	v.specials.add("seeker", 2)
	v.specials.add("sledge", 1)
	drv.frame.cycle_special = 1
	await _frames(2)
	check(v.specials.selected == "sledge", "next special cycles the weapon")
	drv.frame.cycle_special = -1
	await _frames(2)
	check(v.specials.selected == "seeker", "previous special cycles back")
	# Seeker: a little off line but inside the lock-on cone, it homes in on the drone.
	v.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(5.0)), v.global_position)
	v.reset_physics_interpolation()
	await _frames(10)
	var thp2 := target.health.current
	drv.frame.fire_special = true
	await _frames(2)
	drv.frame.fire_special = false
	t = 0.0
	while target.health.current >= thp2 and t < 2.0:
		await physics_frame
		t += 1.0 / 60.0
	check(target.health.current < thp2, "the Seeker locks on and hits the drone (%.2f s)" % t)
	check(v.specials.count("seeker") == 1, "firing a special uses one shot")
	# Frozen cars can't fire specials or use combos.
	v.status.freeze(1.0)
	drv.frame.fire_special = true
	await _frames(10)
	drv.frame.fire_special = false
	check(v.specials.count("seeker") == 1, "a frozen car cannot fire specials")
	failed.clear()
	await _tap(drv, _inputs("bulwark"))
	check("bulwark:frozen" in failed, "a frozen car cannot use combos")
	world.queue_free()
	await _frames(5)


# --- Weapon curve ------------------------------------------------------------------

## Fires one shot from a parked car facing -Z at a parked target and reports whether
## it hit, plus how far the shot turned in its first 0.3 s.
func _shoot_at(kind: String, off_deg: float, dist: float) -> Dictionary:
	var world := _make_pad()
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 0))
	var v: ArcadeVehicle = pair[0]
	var a := deg_to_rad(off_deg)
	var target_pair := _spawn(world, "rustjaw", Vector3(sin(a) * dist, 1.0, -cos(a) * dist))
	var target: ArcadeVehicle = target_pair[0]
	await _frames(45)
	var hp := target.health.current
	if kind == "cold_snap":
		v.combos.request_move("cold_snap")
	else:
		v.specials.clear()
		v.specials.add(kind, 1)
		v.specials.fire()
	var shot: Projectile = null
	for c in world.get_children():
		if c is Projectile:
			shot = c
	var dir0 := shot.velocity.normalized() if shot != null else Vector3.ZERO
	await _frames(18)
	var turned := rad_to_deg(dir0.angle_to(shot.velocity.normalized())) if shot != null and is_instance_valid(shot) else -1.0
	var t := 0.0
	while target.health.current >= hp and t < 2.5:
		await physics_frame
		t += 1.0 / 60.0
	var out := {"hit": target.health.current < hp, "turned": turned, "frozen": target.status.is_frozen()}
	world.queue_free()
	await _frames(2)
	return out


func _weapon_curve() -> void:
	# 14 deg/s (a tenth of the Seeker's turn) catches a car about 4 degrees off line at 40 m.
	var r := await _shoot_at("firebrand", 4.0, 40.0)
	check(r["hit"], "a Firebrand curves onto a target 4 degrees off line at 40 m")
	check(r["turned"] > 0.5 and r["turned"] <= 14.0 * 0.3 + 0.5, "the Firebrand's curve is slight (%.1f deg in 0.3 s)" % r["turned"])
	_measure["firebrand_turn_in_0_3s_deg"] = r["turned"]
	r = await _shoot_at("firebrand", 35.0, 30.0)
	check(not r["hit"], "a Firebrand ignores a target outside its view")
	r = await _shoot_at("sledge", 4.0, 40.0)
	check(not r["hit"], "the Sledge flies dead straight past a target 4 degrees off line")
	check(r["turned"] >= 0.0 and r["turned"] < 0.1, "the Sledge doesn't turn (%.2f deg)" % r["turned"])
	r = await _shoot_at("cold_snap", 4.0, 40.0)
	check(r["hit"] and r["frozen"], "Cold Snap curves onto a target 4 degrees off line and freezes it")


# --- Cars and their own specials -------------------------------------------------------

func _roster_driving() -> void:
	var dt := 1.0 / 60.0
	for id in GameData.roster():
		var world := _make_pad()
		var drv := ScriptedDriver.new()
		var v := VehicleFactory.create(id, drv, false, false)
		world.add_child(v)
		v.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 300))
		v.reset_physics_interpolation()
		await _frames(45)
		check(v.grounded, "%s settles on its wheels" % id)
		drv.frame.throttle = 1.0
		var t := 0.0
		while t < 9.0:
			await physics_frame
			t += dt
		_measure["%s_top_speed_ms" % id] = v.drive.speed
		near(v.drive.speed, v.stats.max_speed, v.stats.max_speed * 0.04, "%s reaches its top speed" % id)
		drv.frame.steer = 1.0
		await _frames(120)
		check(v.global_transform.basis.y.y > 0.8, "%s stays upright turning at full lock" % id)
		world.queue_free()
		await _frames(2)


## A parked car of `id` facing -Z at the origin with a parked Scrap Drone at `target_at`.
func _sig_range(id: String, target_at: Vector3) -> Array:
	var world := _make_pad()
	var drv := ScriptedDriver.new()
	var v := VehicleFactory.create(id, drv, false, false)
	world.add_child(v)
	v.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))
	v.reset_physics_interpolation()
	var target: ArcadeVehicle = null
	if target_at != Vector3.ZERO:
		target = VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
		world.add_child(target)
		target.global_transform = Transform3D(Basis.IDENTITY, target_at)
		target.reset_physics_interpolation()
	await _frames(45)
	return [world, v, target]


func _projectiles(world: Node) -> Array:
	return world.get_children().filter(func(c): return c is Projectile)


func _signature_specials() -> void:
	# Selection and recharge, on the Rustjaw.
	var r := await _sig_range("rustjaw", Vector3(0, 1.2, -25))
	var world: Node3D = r[0]
	var v: ArcadeVehicle = r[1]
	var target: ArcadeVehicle = r[2]
	var sp := v.specials
	check(sp.selected == "slag_hook" and sp.count("slag_hook") == 1, "a car starts with its own special selected and ready")
	check(sp.total() == 0, "its own special doesn't count as pickup ammo")
	# Slag Hook: hits the drone and drags it toward the car.
	var hp := target.health.current
	var gap := _flat(target.global_position - v.global_position).length()
	check(sp.fire(), "Slag Hook fires")
	check(sp.count("slag_hook") == 0 and sp.selected == "slag_hook", "it then recharges, still selected")
	check(not sp.fire(), "it can't fire again while recharging")
	await _frames(60)
	check(target.health.current < hp, "Slag Hook damages the car it hooks")
	var gap_after := _flat(target.global_position - v.global_position).length()
	_measure["slag_hook_pull_m"] = gap - gap_after
	check(gap - gap_after > 2.0, "Slag Hook drags the car toward you (%.1f m)" % (gap - gap_after))
	var recharge := float(sp.signature.get("recharge_s", 14.0))
	near(sp.signature_charge, 1.0 / recharge, 0.02, "it recharges over %.0f s" % recharge)
	sp.signature_charge = 0.995
	await _frames(10)
	check(sp.count("slag_hook") == 1, "and is ready again once charged")
	# Pickups take over the selection, and it comes back when they run out.
	sp.add("firebrand", 1)
	check(sp.selected == "firebrand", "a weapon crate's special is selected when you get it")
	sp.cycle(1)
	check(sp.selected == "slag_hook", "cycling reaches your own special")
	sp.cycle(1)
	sp.fire()
	check(sp.selected == "slag_hook", "when the pickups run out, your own special is selected again")
	world.queue_free()
	await _frames(2)

	# Ember Fan: five rockets in a fan.
	r = await _sig_range("cinder", Vector3(0, 1.2, -20))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(1)
	check(_projectiles(world).size() == 5, "Ember Fan fires five rockets")
	await _frames(60)
	check(target.health.current < hp, "Ember Fan hits the car ahead")
	world.queue_free()
	await _frames(2)

	# Dead Weight: hurts and throws a close car, leaves a far one alone.
	r = await _sig_range("hogshead", Vector3(5.5, 1.2, -2))
	world = r[0]
	v = r[1]
	target = r[2]
	var far := VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
	world.add_child(far)
	far.global_transform = Transform3D(Basis.IDENTITY, Vector3(-30, 1.2, 0))
	await _frames(30)
	hp = target.health.current
	var far_hp := far.health.current
	gap = _flat(target.global_position - v.global_position).length()
	v.specials.fire()
	await _frames(40)
	check(target.health.current < hp, "Dead Weight damages a car close by")
	gap_after = _flat(target.global_position - v.global_position).length()
	_measure["dead_weight_throw_m"] = gap_after - gap
	check(gap_after - gap > 2.0, "Dead Weight throws it clear (%.1f m)" % (gap_after - gap))
	check(far.health.current == far_hp, "Dead Weight doesn't reach a car 30 m away")
	world.queue_free()
	await _frames(2)

	# Ripsaw: hits a car ahead; off a wall, it bounces instead of breaking.
	r = await _sig_range("sawback", Vector3(0, 1.2, -22))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(60)
	check(target.health.current < hp, "Ripsaw cuts the car ahead")
	world.queue_free()
	await _frames(2)
	r = await _sig_range("sawback", Vector3.ZERO)
	world = r[0]
	v = r[1]
	var wall := StaticBody3D.new()
	wall.collision_layer = ArcadeVehicle.LAYER_WORLD
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(30, 4, 1)
	ws.shape = wb
	wall.add_child(ws)
	world.add_child(wall)
	wall.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), Vector3(0, 2, -14))
	v.specials.fire()
	await _frames(1)
	var saw: Projectile = _projectiles(world)[0]
	var dir0 := Vector3(saw.velocity.x, 0, saw.velocity.z).normalized()
	await _frames(40)
	check(is_instance_valid(saw) and saw.bounces_left == 2, "Ripsaw bounces off a wall")
	if is_instance_valid(saw):
		check(dir0.angle_to(Vector3(saw.velocity.x, 0, saw.velocity.z).normalized()) > deg_to_rad(30.0), "and heads off in a new direction")
		check(saw.global_position.y > 0.2 and saw.global_position.y < 1.0, "it runs along the ground (%.2f m up)" % saw.global_position.y)
	world.queue_free()
	await _frames(2)


func _car_select() -> void:
	var c := CarSelect.new()
	root.add_child(c)
	await process_frame
	check(c.cars == GameData.roster(), "the car select lists the roster")
	var start := c.index
	c._show(c.index + 1)
	check(c.index == (start + 1) % c.cars.size(), "right moves to the next car")
	c._show(c.index - 2)
	check(c.index == (start - 1 + c.cars.size()) % c.cars.size(), "left wraps round")
	var hog := GameData.load_vehicle("hogshead", false)
	var cinder := GameData.load_vehicle("cinder", false)
	check(c.bar_fraction(hog, "armor") > c.bar_fraction(cinder, "armor"), "the armor bar shows Hogshead tougher than Cinder")
	check(c.bar_fraction(cinder, "speed") > c.bar_fraction(hog, "speed"), "the speed bar shows Cinder faster")
	c.queue_free()
	await process_frame
	var m := YardMatch.new()
	m.player_car = "sawback"
	root.add_child(m)
	await _frames(5)
	check(m.player.stats.id == "sawback" and m.player.specials.selected == "ripsaw", "the Yard starts with the chosen car and its special")
	m.queue_free()
	await _frames(5)


# --- Arena smoke test ---------------------------------------------------------------

func _arena_smoke() -> void:
	var m := YardMatch.new()
	root.add_child(m)
	await _frames(30)
	# Laps first: with nobody to hunt, every drone should keep driving its route.
	for d in m.drones:
		(d.driver as DroneDriver).aggressive = false
	var start_pos: Array[Vector3] = []
	var travelled: Array[float] = []
	for d in m.drones:
		start_pos.append(d.global_position)
		travelled.append(0.0)
	var last := start_pos.duplicate()
	for i in 60 * 25:
		await physics_frame
		if i % 30 == 0:
			for k in m.drones.size():
				var d: ArcadeVehicle = m.drones[k]
				travelled[k] += _flat(d.global_position - last[k]).length()
				last[k] = d.global_position
	for k in m.drones.size():
		_measure["drone_%d_travel_25s_m" % (k + 1)] = travelled[k]
		check(travelled[k] > 200.0, "drone %d keeps lapping (%.0f m in 25 s)" % [k + 1, travelled[k]])
		check(m.drones[k].global_transform.basis.y.y > 0.5, "drone %d is on its wheels" % (k + 1))

	# Drones fight back: park the player and let them hunt.
	var player := m.player
	var scripted := ScriptedDriver.new()
	player.driver = scripted
	var drone_moves: Array[String] = []
	for d in m.drones:
		(d.driver as DroneDriver).aggressive = true
		d.combos.move_used.connect(func(_v, id, _n): drone_moves.append(id))
	var hp0 := player.health.current
	var hunt := 0.0
	while player.health.current >= hp0 and hunt < 30.0 and player.is_alive():
		await physics_frame
		hunt += 1.0 / 60.0
	check(player.health.current < hp0 or not player.is_alive(), "drones hunt and damage the player (%.1f s)" % hunt)
	_measure["drones_first_hit_on_player_s"] = hunt
	for d in m.drones:
		(d.driver as DroneDriver).aggressive = false
	player.status.reset()
	if not player.is_alive():
		player.respawn(Transform3D(Basis.IDENTITY, Vector3(-10, 1.2, 70)))
	player.health.current = player.stats.max_health

	# Gun test: park a drone in front of the player and hold the trigger.
	var target: ArcadeVehicle = m.drones[0]
	target.driver = ScriptedDriver.new()
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(-10, 1.2, 70))
	player.linear_velocity = Vector3.ZERO
	target.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-10, 1.2, 50))
	target.linear_velocity = Vector3.ZERO
	await _frames(30)
	scripted.frame.fire_gun = true
	var t := 0.0
	while target.is_alive() and t < 15.0:
		await physics_frame
		t += 1.0 / 60.0
	scripted.frame.fire_gun = false
	check(not target.is_alive(), "the machine gun wrecks a drone (%.1f s)" % t)
	check(m.wrecks == 1, "the wreck is credited to the player")
	_measure["time_to_wreck_drone_s"] = t
	# Pickup test: damage the player, drive into the deck health pickup.
	player.health.current = 40.0
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 4.2, 7.5))
	player.linear_velocity = Vector3.ZERO
	await _frames(20)
	check(player.health.current > 40.0, "driving through a health pickup heals")
	m.queue_free()
	await _frames(5)


# --- Projectile tuning: bigger hitboxes, higher fire-bomb arcs -------------------------

func _projectile_tuning() -> void:
	check(is_equal_approx(Projectile.HITBOX_SCALE, 1.15), "projectile hitboxes are 15% bigger")
	# Lob arcs: Fire Jug 25 degrees (was 20), Tar Pot 29 (was 24).
	var jug: Dictionary = GameData.load_json(GameData.COMBOS_PATH)["moves"]["fire_jug"]
	var tar: Dictionary = GameData.load_json(GameData.SPECIALS_PATH)["weapons"]["tar_pot"]
	var jv := Projectile.lob_velocity(Vector3.FORWARD, float(jug["speed"]), float(jug["arc_deg"]))
	var tv := Projectile.lob_velocity(Vector3.FORWARD, float(tar["speed"]), float(tar["arc_deg"]))
	var old_jug := rad_to_deg(atan2(8.0, 22.0))
	var old_tar := rad_to_deg(atan2(8.0, 18.0))
	near(rad_to_deg(atan2(jv.y, Vector3(jv.x, 0, jv.z).length())), old_jug + 5.0, 0.2, "Fire Jug is thrown 5 degrees higher")
	near(rad_to_deg(atan2(tv.y, Vector3(tv.x, 0, tv.z).length())), old_tar + 5.0, 0.2, "Tar Pot is lobbed 5 degrees higher")
	near(jv.length(), Vector2(22.0, 8.0).length(), 0.1, "Fire Jug leaves at the same speed as before")
	near(tv.length(), Vector2(18.0, 8.0).length(), 0.1, "Tar Pot leaves at the same speed as before")

	# A rocket that passes just wide of a car (inside the extra 15%, outside the body) hits it.
	var r := await _sig_range("rustjaw", Vector3.ZERO)
	var world: Node3D = r[0]
	var shooter: ArcadeVehicle = r[1]
	var car := VehicleFactory.create("rustjaw", ScriptedDriver.new(), false, false)
	world.add_child(car)
	car.global_transform = Transform3D(Basis.IDENTITY, Vector3(20, 1.2, -30))
	car.reset_physics_interpolation()
	await _frames(45)
	var half_w := car.stats.body_width * 0.5
	var c := car.global_transform * Projectile.BODY_OFFSET
	var graze_x := c.x - half_w * 1.07   # 7% outside the body, inside the 15% margin
	check(Projectile.in_hitbox(car, Vector3(graze_x, c.y, c.z)), "a point just outside the body is inside the hitbox")
	check(not Projectile.in_hitbox(car, Vector3(c.x - half_w * 1.25, c.y, c.z)), "a point well outside isn't")
	var hp := car.health.current
	var shot := Projectile.new()
	shot.setup("sledge", shooter, {"damage": 20.0, "speed": 70.0, "life_s": 3.0})
	world.add_child(shot)
	shot.launch(Vector3(graze_x, c.y, c.z + 30.0), Vector3(0, 0, -70.0))
	await _frames(40)
	check(car.health.current < hp, "a fast shot grazing within the margin hits (%.0f -> %.0f)" % [hp, car.health.current])
	hp = car.health.current
	var miss := Projectile.new()
	miss.setup("sledge", shooter, {"damage": 20.0, "speed": 70.0, "life_s": 3.0})
	world.add_child(miss)
	miss.launch(Vector3(c.x - half_w * 1.4, c.y, c.z + 30.0), Vector3(0, 0, -70.0))
	await _frames(40)
	check(car.health.current == hp, "a shot well wide still misses")
	world.queue_free()
	await _frames(2)


func _write_report() -> void:
	var targets: Dictionary = GameData.load_json("res://data/handling_targets.json")["rustjaw"]
	var lines: Array[String] = []
	lines.append("# Handling report: Rustjaw")
	lines.append("")
	lines.append("Generated by `tests/run_tests.gd` on a flat test pad at 60 physics ticks per second.")
	lines.append("Targets are our own design windows from `data/handling_targets.json`.")
	lines.append("")
	lines.append("| Measurement | Result | Target |")
	lines.append("| --- | --- | --- |")
	for k in _measure.keys():
		var want := ""
		if targets.has(k):
			var w: Variant = targets[k]
			want = ("%s to %s" % [w[0], w[1]]) if typeof(w) == TYPE_ARRAY else str(w)
		lines.append("| %s | %s | %s |" % [k, _fmt(_measure[k]), want])
	lines.append("")
	var f := FileAccess.open("res://docs/handling_report.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))


# --- Iron Carnage update 1: the eight new cars and four new pickups ---------------------

func _new_car_specials() -> void:
	# Taser Pulse: a ring of current that hits up to four cars nearby, throws them
	# up and spins them. A fifth car in range, and one out of range, are left alone.
	var r := await _sig_range("warrant", Vector3.ZERO)
	var world: Node3D = r[0]
	var v: ArcadeVehicle = r[1]
	var target: ArcadeVehicle = null
	var hp := 0.0
	check(v.specials.selected == "taser_pulse", "Warrant's own special is the Taser Pulse")
	var near_cars: Array[ArcadeVehicle] = []
	for at in [Vector3(6, 1.2, 0), Vector3(-6, 1.2, 2), Vector3(0, 1.2, -7), Vector3(3, 1.2, 8), Vector3(-9, 1.2, -8), Vector3(0, 1.2, 30)]:
		var drone := VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
		world.add_child(drone)
		drone.global_transform = Transform3D(Basis.IDENTITY, at)
		drone.reset_physics_interpolation()
		near_cars.append(drone)
	await _frames(45)
	var hps: Array[float] = []
	var yaws: Array[float] = []
	for c in near_cars:
		hps.append(c.health.current)
		yaws.append(c.global_rotation.y)
	check(v.specials.fire(), "Taser Pulse fires")
	await _frames(12)
	var hit := 0
	var lifted := 0
	var shocked := 0
	for i in 5:
		if near_cars[i].health.current < hps[i]:
			hit += 1
		if near_cars[i].global_position.y > 1.8:
			lifted += 1
		if near_cars[i].status.is_shocked():
			shocked += 1
	check(hit == 4, "it hurts four of the five cars nearby, no more (%d)" % hit)
	check(lifted == 4, "and throws those four up into the air (%d)" % lifted)
	check(shocked == 4, "they're SHOCKED while they hang there (%d)" % shocked)
	check(near_cars[4].health.current == hps[4], "the furthest of the five is the one left out")
	check(near_cars[5].health.current == hps[5] and not near_cars[5].status.is_shocked(), "a car out of range isn't touched")
	check(v.health.current == v.stats.max_health and not v.status.is_shocked(), "the Warrant itself isn't hurt")
	await _frames(80)
	var turned := 0
	for i in 4:
		if absf(wrapf(near_cars[i].global_rotation.y - yaws[i], -PI, PI)) > deg_to_rad(20.0):
			turned += 1
	check(turned >= 3, "they come down turned to face somewhere new (%d of 4)" % turned)
	var landed := 0
	for i in 4:
		if near_cars[i].global_position.y < 2.0 and near_cars[i].global_transform.basis.y.dot(Vector3.UP) > 0.5:
			landed += 1
	check(landed == 4, "and land back on their wheels (%d)" % landed)
	_measure["taser_turn_deg"] = rad_to_deg(absf(wrapf(near_cars[0].global_rotation.y - yaws[0], -PI, PI)))
	world.queue_free()
	await _frames(2)

	# Bots use it when a car is close.
	var td: Dictionary = GameData.signature("warrant")
	check(str(td.get("kind", "")) == "taser" and int(td.get("max_targets", 0)) == 4, "warrant.json: the taser hits up to four cars")

	# A snared car is held well under its top speed.
	var pad := _make_pad()
	var drv := ScriptedDriver.new()
	var car := VehicleFactory.create("rustjaw", drv, false, false)
	pad.add_child(car)
	car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 300))
	car.reset_physics_interpolation()
	await _frames(40)
	drv.frame.throttle = 1.0
	await _frames(240)
	car.status.snare(2.0, 0.3)
	await _frames(60)
	_measure["snared_speed_ms"] = car.drive.speed
	check(car.drive.speed < car.stats.max_speed * 0.45, "a snared car slows right down (%.1f m/s)" % car.drive.speed)
	pad.queue_free()
	await _frames(2)

	# Mortar Spread: five lobbed charges that come down on the car ahead.
	r = await _sig_range("bastion", Vector3(0, 1.2, -16))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(1)
	check(_projectiles(world).size() == 5, "Mortar Spread lobs five charges")
	var shell: Projectile = _projectiles(world)[0]
	await _frames(15)
	check(is_instance_valid(shell) and shell.global_position.y > 2.0, "they arc up over the bonnet")
	await _frames(90)
	check(target.health.current < hp, "Mortar Spread hurts the car ahead")
	world.queue_free()
	await _frames(2)

	# Pall: a casket out the back that bursts into a burning cloud.
	r = await _sig_range("mourner", Vector3(0, 1.2, 9))
	world = r[0]
	v = r[1]
	target = r[2]
	v.specials.fire()
	await _frames(70)
	var clouds := world.get_tree().get_nodes_in_group("pall_clouds")
	check(clouds.size() == 1, "Pall leaves a cloud behind the hearse")
	await _frames(20)
	check(target.status.is_burning(), "the car behind, inside the cloud, burns")
	check(not v.status.is_burning(), "the Mourner itself doesn't")
	# A homing shot tracking a car in the cloud loses its lock.
	var seeker := Projectile.new()
	seeker.setup("seeker", null, {"turn_rate_deg": 140.0, "life_s": 3.0, "speed": 1.0})
	world.add_child(seeker)
	seeker.homing_target = target
	seeker.launch(target.global_position + Vector3(0, 6, 30), Vector3(0, 0, -1))
	await _frames(15)
	check(seeker.homing_target == null, "a rocket loses its lock on a car inside the cloud")
	world.queue_free()
	await _frames(2)

	# Scoop and Hurl: grabs the car right in front and throws it back over the cab.
	r = await _sig_range("bucketmouth", Vector3(0, 1.2, -6.5))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(30)
	check(target.health.current < hp, "Scoop and Hurl hurts the car it scoops")
	check(target.global_position.z > -4.0, "and flings it back toward the cab (z %.1f)" % target.global_position.z)
	world.queue_free()
	await _frames(2)

	# Rockslide: boulders that roll out behind and hit the car following.
	r = await _sig_range("tonnage", Vector3(0, 1.2, 14))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(1)
	check(_projectiles(world).size() == 4, "Rockslide dumps four boulders")
	var rock: Projectile = _projectiles(world)[0]
	await _frames(20)
	check(is_instance_valid(rock) and rock.global_position.z > 4.0 and rock.global_position.y < 1.6, "they roll out along the ground behind the truck")
	await _frames(80)
	check(target.health.current < hp, "Rockslide hits the car behind")
	world.queue_free()
	await _frames(2)

	# Shrapnel Ring: hits cars on every side at once.
	r = await _sig_range("vandal", Vector3(0, 1.2, 8))
	world = r[0]
	v = r[1]
	target = r[2]
	var side := VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
	world.add_child(side)
	side.global_transform = Transform3D(Basis.IDENTITY, Vector3(-8, 1.2, 0))
	await _frames(30)
	hp = target.health.current
	var side_hp := side.health.current
	v.specials.fire()
	await _frames(1)
	check(_projectiles(world).size() == 16, "Shrapnel Ring throws sixteen shards")
	await _frames(30)
	check(target.health.current < hp and side.health.current < side_hp, "it hits the car behind and the car beside")
	world.queue_free()
	await _frames(2)

	# Ghost Run: cloaked, untargetable, turbo topped up.
	r = await _sig_range("lancet", Vector3(0, 1.2, -20))
	world = r[0]
	v = r[1]
	target = r[2]
	v.drive.turbo = 20.0
	v.specials.fire()
	check(v.status.is_cloaked(), "Ghost Run cloaks the Lancet")
	check(v.drive.turbo > 50.0, "and tops up its turbo")
	check(Targeting.in_cone(target, Vector3(0, 0, 1), 60.0, 80.0) == null, "nothing can lock on to it")
	world.queue_free()
	await _frames(2)

	# Hydraulic Hop: up in the air, then a slam that hurts a car beside the landing.
	r = await _sig_range("sermon", Vector3(4.5, 1.2, -6))
	world = r[0]
	v = r[1]
	target = r[2]
	hp = target.health.current
	v.specials.fire()
	await _frames(12)
	check(not v.grounded and v.global_position.y > 1.8, "Hydraulic Hop launches the car")
	check(target.health.current == hp, "nothing is hurt while it's in the air")
	await _frames(120)
	check(target.health.current < hp, "the landing slam hurts the car beside it")
	world.queue_free()
	await _frames(2)


func _new_pickup_weapons() -> void:
	var data: Dictionary = GameData.load_json(GameData.SPECIALS_PATH)
	for id in ["satchel", "tar_pot", "skipper", "arc_coil"]:
		check((data["weapons"] as Dictionary).has(id), "specials.json has %s" % id)

	# Satchel: lay three, then set them all off with one press.
	var r := await _sig_range("rustjaw", Vector3(0, 1.2, 9))
	var world: Node3D = r[0]
	var v: ArcadeVehicle = r[1]
	var target: ArcadeVehicle = r[2]
	var sp := v.specials
	sp.add("satchel", 3)
	var hp := target.health.current
	for i in 3:
		check(sp.fire(), "lay satchel %d" % (i + 1))
		await _frames(25)
	check(sp.live_satchels().size() == 3, "three satchels sit on the ground")
	check(target.health.current == hp, "they don't go off on their own straight away")
	check(sp.selected == "satchel" and sp.has_shot(), "Satchel stays selected while charges are down")
	await _frames(40)
	check(sp.fire(), "a later press sets them off")
	await _frames(5)
	check(sp.live_satchels().is_empty(), "every satchel blew")
	check(target.health.current < hp, "and hurt the car parked behind")
	check(sp.selected != "satchel", "then Satchel is put away")
	world.queue_free()
	await _frames(2)

	# Tar Pot: a lobbed canister that leaves a fire pool.
	r = await _sig_range("rustjaw", Vector3(0, 1.2, -14))
	world = r[0]
	v = r[1]
	target = r[2]
	v.specials.add("tar_pot", 1)
	v.specials.fire()
	await _frames(90)
	var pools := world.get_children().filter(func(c): return c is FirePool)
	check(pools.size() == 1, "Tar Pot leaves a pool of burning tar")
	check(target.status.is_burning(), "the car it lands near burns")
	world.queue_free()
	await _frames(2)

	# Skipper: bounces off a wall instead of blowing up on it.
	r = await _sig_range("rustjaw", Vector3.ZERO)
	world = r[0]
	v = r[1]
	var wall := StaticBody3D.new()
	wall.collision_layer = ArcadeVehicle.LAYER_WORLD
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(30, 6, 1)
	ws.shape = wb
	wall.add_child(ws)
	world.add_child(wall)
	wall.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 3, -12))
	v.specials.add("skipper", 1)
	v.specials.fire()
	await _frames(1)
	var bomb: Projectile = _projectiles(world)[0]
	await _frames(30)
	check(is_instance_valid(bomb) and bomb.bounces_left < 3, "Skipper bounces")
	if is_instance_valid(bomb):
		check(bomb.velocity.z > 0.0, "and comes back off the wall")
	await _frames(240)
	check(not is_instance_valid(bomb), "it blows once it runs out of bounces or time")
	world.queue_free()
	await _frames(2)

	# Arc Coil: hits the car ahead, jumps to the one next to it, kills both turbos.
	r = await _sig_range("rustjaw", Vector3(0, 1.2, -20))
	world = r[0]
	v = r[1]
	target = r[2]
	var next_to := VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
	world.add_child(next_to)
	next_to.global_transform = Transform3D(Basis.IDENTITY, Vector3(8, 1.2, -22))
	var far := VehicleFactory.create("scrap_drone", ScriptedDriver.new(), false, false)
	world.add_child(far)
	far.global_transform = Transform3D(Basis.IDENTITY, Vector3(-60, 1.2, -20))
	await _frames(30)
	hp = target.health.current
	var hp2 := next_to.health.current
	var hp3 := far.health.current
	v.specials.add("arc_coil", 1)
	check(v.specials.fire(), "Arc Coil fires at the car ahead")
	check(target.health.current < hp and next_to.health.current < hp2, "it hits the target and jumps to the car beside it")
	check(far.health.current == hp3, "it doesn't reach a car 40 m from the target")
	check(target.status.is_jammed() and next_to.status.is_jammed(), "both lose their turbo")
	world.queue_free()
	await _frames(2)
	r = await _sig_range("rustjaw", Vector3.ZERO)
	world = r[0]
	v = r[1]
	v.specials.add("arc_coil", 1)
	check(not v.specials.fire() and v.specials.count("arc_coil") == 1, "with nobody ahead Arc Coil holds its charge")
	world.queue_free()
	await _frames(2)


# --- Update 2: arenas, surfaces, bot difficulty ----------------------------------------

func _all_arenas() -> void:
	for id in Arenas.ids():
		var m := YardMatch.new()
		m.arena_id = id
		m.bot_count = 3
		m.difficulty = "iron"
		m.bot_cars = "drones"
		root.add_child(m)
		await _frames(30)
		check(m.arena is ArenaBase and m.arena.display_name != "", "%s loads" % id)
		check(m.arena.pickup_spots().size() >= 10, "%s has pickups" % id)
		check(m.arena.spawn_points.size() >= 4 and m.arena.drone_routes.size() >= 3, "%s has spawns and bot routes" % id)
		check(m.player.global_transform.basis.y.y > 0.8 and m.player.global_position.y > 0.0, "%s: the player starts on its wheels" % id)
		for d in m.drones:
			(d.driver as DroneDriver).aggressive = false
		var last: Array = []
		var travelled: Array[float] = []
		for d in m.drones:
			last.append(d.global_position)
			travelled.append(0.0)
		for i in 60 * 20:
			await physics_frame
			if i % 30 == 0:
				for k in m.drones.size():
					travelled[k] += _flat(m.drones[k].global_position - last[k]).length()
					last[k] = m.drones[k].global_position
		for k in m.drones.size():
			_measure["%s_bot_%d_travel_20s_m" % [id, k + 1]] = travelled[k]
			check(travelled[k] > 140.0, "%s: bot %d keeps lapping (%.0f m in 20 s)" % [id, k + 1, travelled[k]])
			var pos: Vector3 = m.drones[k].global_position
			check(absf(pos.x) < 82.0 and absf(pos.z) < 82.0 and pos.y > -2.0, "%s: bot %d stays inside the arena" % [id, k + 1])
		m.queue_free()
		await _frames(3)


func _surfaces() -> void:
	# Ice: a car turning hard on the Frozen Wharf basin slides much more than on the pier.
	var slides := {}
	for where in [["pier", Vector3(-70, 1.2, 66)], ["ice", Vector3(-70, 1.2, -54)]]:
		var m := YardMatch.new()
		m.arena_id = "frozen_wharf"
		m.bot_count = 1
		root.add_child(m)
		await _frames(20)
		m.drones[0].driver = ScriptedDriver.new()
		m.drones[0].global_position = Vector3(70, 1.2, 70)
		var drv := ScriptedDriver.new()
		m.player.driver = drv
		m.player.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), where[1])
		m.player.linear_velocity = Vector3.ZERO
		await _frames(30)
		check(m.player.surface == ("ice" if where[0] == "ice" else ""), "the car knows it's on the %s" % where[0])
		drv.frame.throttle = 1.0
		await _frames(110)
		drv.frame.steer = 1.0
		var peak := 0.0
		for i in 40:
			await physics_frame
			peak = maxf(peak, absf(m.player.drive.lateral))
		slides[where[0]] = peak
		m.queue_free()
		await _frames(3)
	_measure["slide_on_pier_ms"] = slides["pier"]
	_measure["slide_on_ice_ms"] = slides["ice"]
	check(slides["ice"] > slides["pier"] * 1.5, "cars slide more on ice (%.1f vs %.1f m/s)" % [slides["ice"], slides["pier"]])

	# Mud: top speed in the Blackwater Bog mud is about half.
	var m2 := YardMatch.new()
	m2.arena_id = "blackwater_bog"
	m2.bot_count = 1
	root.add_child(m2)
	await _frames(20)
	m2.drones[0].driver = ScriptedDriver.new()
	m2.drones[0].global_position = Vector3(70, 1.2, -70)
	var d2 := ScriptedDriver.new()
	m2.player.driver = d2
	m2.player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(10, 1.2, 0))
	m2.player.linear_velocity = Vector3.ZERO
	await _frames(30)
	check(m2.player.surface == "mud", "the car knows it's in the mud")
	d2.frame.throttle = 1.0
	await _frames(70)
	_measure["mud_speed_ms"] = m2.player.drive.speed
	check(m2.player.drive.speed < m2.player.stats.max_speed * 0.62, "mud holds the car to about half speed (%.1f m/s)" % m2.player.drive.speed)
	m2.queue_free()
	await _frames(3)


func _bot_settings() -> void:
	var scrap := DroneDriver.new([Vector3.ZERO, Vector3.FORWARD] as Array[Vector3], 0, 0.8)
	scrap.set_difficulty("scrap")
	var carnage := DroneDriver.new([Vector3.ZERO, Vector3.FORWARD] as Array[Vector3], 0, 0.8)
	carnage.set_difficulty("carnage")
	check(scrap.hunt_range < 38.0 and carnage.hunt_range > 38.0, "Scrap bots notice you later, Carnage bots sooner")
	check(carnage.uses_turbo and not scrap.uses_turbo, "Carnage bots use turbo")
	# Roster bots: real cars with their own specials, never the player's own car.
	var m := YardMatch.new()
	m.arena_id = "foundry_yard"
	m.bot_count = 5
	m.bot_cars = "roster"
	m.difficulty = "carnage"
	m.player_car = "rustjaw"
	root.add_child(m)
	await _frames(30)
	check(m.drones.size() == 5, "five bots when asked for five")
	var ok := true
	for d in m.drones:
		ok = ok and d.stats.id != "scrap_drone" and d.stats.id != "rustjaw" and d.specials.signature_id != ""
	check(ok, "roster bots drive roster cars with their own specials, not yours")
	# Carnage roster bots fire their specials at you.
	var fired := []
	for d in m.drones:
		d.specials.fired.connect(func(_v, id): fired.append(id))
	m.player.driver = ScriptedDriver.new()
	var t := 0.0
	while fired.is_empty() and t < 40.0:
		await physics_frame
		t += 1.0 / 60.0
	check(not fired.is_empty(), "bots fire their specials (first after %.1f s)" % t)
	m.queue_free()
	await _frames(3)
