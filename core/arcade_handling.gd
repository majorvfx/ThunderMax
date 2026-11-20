class_name ArcadeHandling
extends RefCounted
## Engine-agnostic arcade drive model for Thunder Max.
##
## Works in "car space": forward speed (m/s), sideways slide speed (m/s) and a
## target yaw rate (rad/s). The engine layer reads those from the physics body,
## calls step(), and writes the result back. Nothing here touches nodes, so the
## same math ports line for line to C++ or Blueprint.
##
## Feel goals (our own design): instant throttle, tight turns that loosen a little
## at speed, cars that stay planted, a brake-and-steer power slide, and digital
## steering that ramps in over a fraction of a second instead of snapping.


## Driver intent for one physics step. Filled by a player pad, keyboard or bot.
class ControlFrame:
	var throttle := 0.0        ## 0..1
	var brake := 0.0           ## 0..1 (brake, then reverse when stopped)
	var steer := 0.0           ## -1 left .. 1 right
	var steer_digital := true  ## true for D-pad / keys (ramped), false for stick
	var turbo := false
	var fire_gun := false
	var fire_special := false
	var look_back := false
	var combo_presses: Array[String] = []  ## D-pad combo presses this step, in order
	var cycle_special := 0                 ## -1 previous, +1 next, 0 none

	## Copy with the driving zeroed (used while frozen).
	func idle() -> ControlFrame:
		var f := ControlFrame.new()
		f.look_back = look_back
		return f


## Persistent drive state for one vehicle.
class DriveState:
	var speed := 0.0           ## forward speed along the car's heading (m/s)
	var lateral := 0.0         ## sideways slide speed (m/s), + = right
	var steer := 0.0           ## smoothed steering value actually used
	var yaw_rate := 0.0        ## target yaw rate (rad/s), + = turning left
	var drifting := false
	var boosting := false
	var turbo := 100.0         ## turbo meter


## Advances the drive state by dt. `grounded` is false while airborne.
static func step(s: VehicleStats, st: DriveState, c: ControlFrame, grounded: bool, dt: float) -> void:
	st.steer = step_steer(s, st.steer, c.steer, c.steer_digital, dt)

	# Turbo meter: boost only with fuel, on the ground.
	st.boosting = c.turbo and st.turbo > 0.0 and grounded
	if st.boosting:
		st.turbo = maxf(0.0, st.turbo - s.turbo_drain * dt)
	elif not c.turbo:
		st.turbo = minf(s.turbo_capacity, st.turbo + s.turbo_regen * dt)

	# Power slide: brake + steer at speed.
	st.drifting = grounded and c.brake > 0.5 and absf(st.steer) > 0.5 and st.speed > s.drift_min_speed

	if grounded:
		st.speed = step_forward_speed(s, st.speed, c.throttle, c.brake, st.boosting, st.drifting, dt)
		st.lateral = step_lateral(s, st.lateral, st.drifting, dt)
	var yaw := target_yaw_rate(s, st.speed, st.steer)
	if st.drifting:
		yaw *= s.drift_turn_boost
	st.yaw_rate = yaw


## Forward speed update: throttle, brake, reverse, coast, turbo.
static func step_forward_speed(s: VehicleStats, speed: float, throttle: float, brake: float, boosting: bool, drifting: bool, dt: float) -> float:
	var vmax := s.max_speed
	var acc := s.accel
	if boosting:
		vmax *= s.turbo_speed_mult
		acc *= s.turbo_accel_mult
		throttle = 1.0

	# Brake pedal: slow down while rolling forward, reverse once stopped.
	if brake > 0.05 and not boosting:
		if speed > 0.5:
			var decel := s.brake_decel * (s.drift_brake_scale if drifting else 1.0)
			return maxf(0.0, speed - decel * brake * dt)
		if throttle < 0.05:
			if speed > -s.reverse_max_speed:
				return maxf(-s.reverse_max_speed, speed - s.reverse_accel * brake * dt)
			return move_toward(speed, -s.reverse_max_speed, s.coast_decel * dt)

	if throttle > 0.01:
		if speed < 0.0:
			# Rolling backwards: throttle brakes first.
			return minf(0.0, speed + s.brake_decel * throttle * dt)
		var target := vmax * clampf(throttle, 0.0, 1.0)
		if speed < target:
			var t := clampf(speed / vmax, 0.0, 1.0)
			var a := acc * (1.0 - s.accel_falloff * t * t)
			return minf(target, speed + a * dt)
		# Above target (turbo ended, partial throttle, downhill): ease back.
		return move_toward(speed, target, s.coast_decel * 2.0 * dt)

	# Coasting.
	return move_toward(speed, 0.0, s.coast_decel * dt)


## Sideways slide decays toward zero; much slower while power-sliding.
static func step_lateral(s: VehicleStats, lateral: float, drifting: bool, dt: float) -> float:
	var g := s.drift_grip if drifting else s.grip
	return lateral * exp(-g * dt)


## Target yaw rate (rad/s, + = left) for the current speed and steering.
static func target_yaw_rate(s: VehicleStats, speed: float, steer: float) -> float:
	var abs_v := absf(speed)
	var low_factor := lerpf(s.pivot_turn, 1.0, clampf(abs_v / maxf(s.full_turn_speed, 0.01), 0.0, 1.0))
	var high_factor := lerpf(1.0, s.high_speed_turn_scale, clampf(abs_v / maxf(s.max_speed, 0.01), 0.0, 1.0))
	var dir := -1.0 if speed < -0.5 else 1.0
	return -steer * deg_to_rad(s.turn_rate_deg) * low_factor * high_factor * dir


## Digital steering ramps toward the input; analog sticks pass through a response curve.
static func step_steer(s: VehicleStats, current: float, target: float, digital: bool, dt: float) -> float:
	target = clampf(target, -1.0, 1.0)
	if not digital:
		return signf(target) * pow(absf(target), s.analog_steer_curve)
	var rate: float
	if absf(target) < 0.01 or (signf(target) != signf(current) and absf(current) > 0.01):
		rate = 1.0 / maxf(s.steer_return_time, 0.001)
	else:
		rate = 1.0 / maxf(s.steer_ramp_time, 0.001)
	return move_toward(current, target, rate * dt)
