extends SceneTree
## Headless test runner for Thunder Max.
##
##   godot --headless --path . --import
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
##
## 1. Core rule tests (pure logic, no physics).
## 2. Handling measurements on a flat test pad, checked against
##    data/handling_targets.json and written to docs/handling_report.md.
## 3. Arena smoke test: drones lap the Foundry Yard and the gun wrecks a drone.

var _pass := 0
var _fail := 0
var _failures: Array[String] = []
var _measure := {}


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
	print("== Handling measurements ==")
	await _handling_measurements()
	print("== Arena smoke test ==")
	await _arena_smoke()
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
	var t := s.to_tuning_dict()
	check(t.size() == VehicleStats.TUNABLE.size(), "tuning dict has every tunable")


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
	near(state.turbo, 50.0 - s.turbo_drain, 0.001, "turbo drains while boosting")
	c.turbo = false
	ArcadeHandling.step(s, state, c, true, 1.0)
	near(state.turbo, 50.0 - s.turbo_drain + s.turbo_regen, 0.001, "turbo regenerates when released")
	state.turbo = 0.0
	c.turbo = true
	ArcadeHandling.step(s, state, c, true, dt)
	check(not state.boosting, "no boost with an empty meter")
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
	# Modern: RT accelerates. Classic: A accelerates.
	InputSetup.apply_preset(1, -1, "modern", false)
	var rt := false
	for ev in InputMap.action_get_events(InputSetup.action(1, "accelerate")):
		if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_TRIGGER_RIGHT:
			rt = true
	check(rt, "modern: right trigger accelerates")
	InputSetup.apply_preset(1, -1, "classic", false)
	var a_btn := false
	for ev in InputMap.action_get_events(InputSetup.action(1, "accelerate")):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			a_btn = true
	check(a_btn, "classic: A accelerates")
	InputSetup.apply_preset(1, -1, "modern", true)


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
	world = _make_pad()
	_add_ramp(world, Vector3(0, 0, -100), Vector3(0, 2.2, -109), 8.0)
	pair = await _spawn_settled(world, Vector3(0, 1.0, 60))
	v = pair[0]
	drv = pair[1]
	drv.frame.throttle = 1.0
	var left_ground := false
	var takeoff := Vector3.ZERO
	var air_t := 0.0
	var landed := Vector3.ZERO
	var max_tilt := 0.0
	t = 0.0
	while t < 12.0:
		await physics_frame
		t += dt
		if not left_ground and not v.grounded and v.global_position.z < -100.0:
			left_ground = true
			takeoff = v.global_position
			_measure["ramp_takeoff_speed_ms"] = v.linear_velocity.length()
		elif left_ground and v.grounded and landed == Vector3.ZERO:
			landed = v.global_position
		if left_ground and landed == Vector3.ZERO:
			air_t += dt
		if left_ground:
			max_tilt = maxf(max_tilt, rad_to_deg(acos(clampf(v.global_transform.basis.y.y, -1.0, 1.0))))
		if landed != Vector3.ZERO and t > 0.0 and v.global_position.z < landed.z - 20.0:
			break
	_measure["ramp_jump_distance_m"] = _flat(landed - takeoff).length() if landed != Vector3.ZERO else -1.0
	_measure["ramp_airtime_s"] = air_t
	_measure["upright_after_landing"] = v.global_transform.basis.y.y > 0.9
	_measure["max_tilt_in_air_deg"] = max_tilt
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
	check(float(_measure["ram_damage_to_parked"]) > 0.0, "a top-speed T-bone damages the parked car")
	for k in _measure.keys():
		print("  %-30s %s" % [k, _fmt(_measure[k])])


func _spawn_settled(world: Node3D, at: Vector3, yaw: float = 0.0) -> Array:
	var pair := _spawn(world, "rustjaw", at, yaw)
	await _frames(45)
	return pair


func _turn_circle(throttle: float) -> float:
	var world := _make_pad()
	var pair := await _spawn_settled(world, Vector3(0, 1.0, 0))
	var v: ArcadeVehicle = pair[0]
	var drv: ScriptedDriver = pair[1]
	drv.frame.throttle = throttle
	await _frames(240)
	drv.frame.steer = 1.0
	drv.frame.steer_digital = false
	await _frames(240)
	var pts: Array[Vector3] = []
	var yaw_total := 0.0
	var last_fwd := _flat(-v.global_transform.basis.z).normalized()
	var guard := 0
	while yaw_total < TAU and guard < 2000:
		await physics_frame
		guard += 1
		var f := _flat(-v.global_transform.basis.z).normalized()
		yaw_total += absf(last_fwd.signed_angle_to(f, Vector3.UP))
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


# --- Arena smoke test ---------------------------------------------------------------

func _arena_smoke() -> void:
	var m := YardMatch.new()
	root.add_child(m)
	await _frames(30)
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

	# Gun test: park a drone in front of the player and hold the trigger.
	var player := m.player
	var scripted := ScriptedDriver.new()
	player.driver = scripted
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
