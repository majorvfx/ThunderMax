class_name ArcadeHandling
extends RefCounted
## Engine-agnostic arcade drive model for Iron Carnage.
##
## Works in "car space": forward speed (m/s), sideways slide speed (m/s) and a
## target yaw rate (rad/s). The engine layer reads those from the physics body,
## calls step(), and writes the result back. Nothing here touches nodes, so the
## same math ports line for line to C++ or Blueprint.
##
## Feel goals (our own design): instant throttle, tight turns that loosen a little
## at speed, cars that stay planted, a brake-and-steer power slide, digital
## steering that ramps in over a fraction of a second instead of snapping, and a
## turbo that behaves like a rocket: a nitrous kick when it lights, a push that
## doesn't fade with speed, and thrust that still drives you forward in the air.


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
	var combo_hold := false                ## combo hold control down (RT by default)
	var tight_turn := false                ## tight turn: a handbrake-style slide
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
	var vertical := 0.0        ## world up speed (m/s); set by the engine layer, read in the air
	var drifting := false
	var boosting := false
	var turbo := 100.0         ## turbo meter
	var ignited := false       ## true on the step the turbo lights
	var air_push := 0.0        ## forward m/s the rocket adds this step while airborne
	var air_lift := 0.0        ## upward m/s the rocket adds this step while falling


## Advances the drive state by dt. `grounded` is false while airborne.
static func step(s: VehicleStats, st: DriveState, c: ControlFrame, grounded: bool, dt: float) -> void:
	st.steer = step_steer(s, st.steer, c.steer, c.steer_digital, dt)

	# Turbo meter: the rocket burns fuel on the ground and in the air.
	var was_boosting := st.boosting
	st.boosting = c.turbo and st.turbo > 0.0
	st.ignited = st.boosting and not was_boosting
	if st.boosting:
		st.turbo = maxf(0.0, st.turbo - s.turbo_drain * dt)
	elif not c.turbo:
		st.turbo = minf(s.turbo_capacity, st.turbo + s.turbo_regen * dt)
	# Nitrous kick: a shove forward when the turbo lights. It costs a slug of the
	# meter, so tapping the button over and over isn't free speed.
	var kick := 0.0
	if st.ignited and st.turbo >= s.turbo_kick_cost:
		st.turbo -= s.turbo_kick_cost
		kick = s.turbo_kick
	var boost_top := s.max_speed * s.turbo_speed_mult
	if kick > 0.0 and st.speed < boost_top:
		kick = minf(kick, boost_top - st.speed)
	else:
		kick = 0.0
	st.air_push = 0.0
	st.air_lift = 0.0
	if st.boosting and not grounded:
		var push := air_thrust(s, st.speed, st.vertical, dt)
		st.air_push = push.x + kick
		st.air_lift = push.y

	# Tight turn: hold the button and steer to swing the car round, sliding at speed.
	var tight := grounded and c.tight_turn and absf(st.steer) > 0.2 and absf(st.speed) > 2.0
	# Power slide: brake + steer at speed, or a tight turn at speed.
	var power_slide := c.brake > 0.5 and absf(st.steer) > 0.5
	st.drifting = grounded and (power_slide or tight) and st.speed > s.drift_min_speed

	if grounded:
		st.speed = step_forward_speed(s, st.speed + kick, c.throttle, c.brake, st.boosting, st.drifting, dt)
		if tight:
			st.speed = move_toward(st.speed, 0.0, s.tight_turn_drag * dt)
		st.lateral = step_lateral(s, st.lateral, st.drifting, dt)
	var yaw := target_yaw_rate(s, st.speed, st.steer)
	if tight:
		yaw *= s.tight_turn_boost
	elif st.drifting:
		yaw *= s.drift_turn_boost
	st.yaw_rate = yaw


## Rocket thrust while airborne: (forward m/s, upward m/s) to add this step.
## Forward thrust tops out at turbo top speed. Lift only works against a fall, so
## the turbo stretches a jump out without launching you any higher.
static func air_thrust(s: VehicleStats, speed: float, vertical: float, dt: float) -> Vector2:
	var top := s.max_speed * s.turbo_speed_mult
	var forward := clampf(top - speed, 0.0, s.turbo_air_thrust * dt)
	var up := 0.0
	if vertical < 0.0:
		up = minf(s.turbo_air_lift * dt, -vertical)
	return Vector2(forward, up)


## Forward speed update: throttle, brake, reverse, coast, turbo.
static func step_forward_speed(s: VehicleStats, speed: float, throttle: float, brake: float, boosting: bool, drifting: bool, dt: float) -> float:
	var vmax := s.max_speed
	var acc := s.accel
	var thrust := 0.0
	if boosting:
		vmax *= s.turbo_speed_mult
		thrust = s.turbo_thrust   # the rocket's push doesn't fade as you speed up
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
			var t := clampf(speed / s.max_speed, 0.0, 1.0)
			var a := acc * (1.0 - s.accel_falloff * t * t) + thrust
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
