class_name DroneDriver
extends RefCounted
## Scrap Drones: lap the yard on waypoints, but turn on the player when they get close.
## They fire their guns in bursts, drop mines when chased, raise a Bulwark when hurt
## and throw Cold Snaps at a player in front of them. One difficulty for now.

var waypoints: Array[Vector3] = []
var index := 0
var throttle_level := 0.8
var aggressive := true
var hunt_range := 38.0
var fire_range := 48.0
var fire_cone_deg := 10.0

var _frame := ArcadeHandling.ControlFrame.new()
var _stuck := 0.0
var _reverse := 0.0
var _reverse_steer := 0.0
var _burst := 0.0
var _rest := 0.0
var _think := 0.0
var _rng := RandomNumberGenerator.new()


func _init(points: Array[Vector3], start_index: int = 0, throttle: float = 0.8) -> void:
	waypoints = points
	index = start_index % maxi(points.size(), 1)
	throttle_level = throttle
	_rng.randomize()


func get_frame(vehicle: Node, dt: float) -> ArcadeHandling.ControlFrame:
	var f := _frame
	f.steer_digital = false
	f.turbo = false
	f.fire_gun = false
	f.fire_special = false
	if waypoints.is_empty():
		f.throttle = 0.0
		return f
	var car := vehicle as ArcadeVehicle
	var xf := car.global_transform
	var fwd := -xf.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	var prey := _find_prey(car) if aggressive else null
	var target_pos := waypoints[index]
	if prey != null:
		target_pos = prey.global_position
	else:
		var to_wp := waypoints[index] - xf.origin
		to_wp.y = 0.0
		if to_wp.length() < 10.0:
			index = (index + 1) % waypoints.size()
			target_pos = waypoints[index]

	var to := target_pos - xf.origin
	to.y = 0.0
	var dist := to.length()
	var angle := fwd.signed_angle_to(to.normalized(), Vector3.UP) if dist > 0.1 else 0.0
	var steer := clampf(-angle * 2.2, -1.0, 1.0)

	if _reverse > 0.0:
		_reverse -= dt
		f.throttle = 0.0
		f.brake = 1.0
		f.steer = _reverse_steer
		return f

	f.brake = 0.0
	f.steer = steer
	f.throttle = throttle_level * (0.5 if absf(angle) > 0.9 else 1.0)
	if prey != null and dist < 9.0 and absf(angle) < 0.5:
		f.throttle = 1.0   # ram

	if prey != null:
		_combat(car, prey, dist, absf(angle), dt, f)

	if absf(car.drive.speed) < 1.5:
		_stuck += dt
	else:
		_stuck = maxf(0.0, _stuck - dt)
	if _stuck > 1.2:
		_stuck = 0.0
		_reverse = 1.1
		_reverse_steer = -signf(steer) if absf(steer) > 0.1 else 1.0
	return f


func _find_prey(car: ArcadeVehicle) -> ArcadeVehicle:
	var best: ArcadeVehicle = null
	var best_d := hunt_range
	for n in car.get_tree().get_nodes_in_group("players"):
		var p := n as ArcadeVehicle
		if p == null or not p.is_alive():
			continue
		var d := p.global_position.distance_to(car.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _combat(car: ArcadeVehicle, prey: ArcadeVehicle, dist: float, angle: float, dt: float, f: ArcadeHandling.ControlFrame) -> void:
	# Gun in bursts while the player is in front.
	if dist < fire_range and angle < deg_to_rad(fire_cone_deg):
		if _rest > 0.0:
			_rest -= dt
		else:
			_burst += dt
			f.fire_gun = true
			if _burst > 1.1:
				_burst = 0.0
				_rest = _rng.randf_range(0.9, 1.8)
	# Combo moves, considered a few times a second.
	_think -= dt
	if _think > 0.0 or car.combos == null:
		return
	_think = _rng.randf_range(0.35, 0.6)
	if car.health.fraction() < 0.35 and car.status.can_afford(60.0):
		car.combos.request_move("bulwark")
		return
	var behind := (prey.global_position - car.global_position).dot(car.global_transform.basis.z) > 0.0
	if behind and dist < 16.0 and _rng.randf() < 0.5:
		car.combos.request_move("scrap_mine")
	elif not behind and dist > 10.0 and dist < 40.0 and angle < 0.2 and _rng.randf() < 0.18:
		car.combos.request_move("cold_snap")
