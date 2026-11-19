class_name DroneDriver
extends RefCounted
## Milestone 1 target drones: drive a loop of waypoints, back out when stuck.
## They do not shoot yet; real bot AI arrives in Milestone 2.

var waypoints: Array[Vector3] = []
var index := 0
var throttle_level := 0.8
var _frame := ArcadeHandling.ControlFrame.new()
var _stuck := 0.0
var _reverse := 0.0
var _reverse_steer := 0.0


func _init(points: Array[Vector3], start_index: int = 0, throttle: float = 0.8) -> void:
	waypoints = points
	index = start_index % maxi(points.size(), 1)
	throttle_level = throttle


func get_frame(vehicle: Node, dt: float) -> ArcadeHandling.ControlFrame:
	var f := _frame
	f.steer_digital = false
	f.turbo = false
	f.fire_gun = false
	if waypoints.is_empty():
		f.throttle = 0.0
		return f
	var car := vehicle as ArcadeVehicle
	var xf := car.global_transform
	var to := waypoints[index] - xf.origin
	to.y = 0.0
	if to.length() < 10.0:
		index = (index + 1) % waypoints.size()
		to = waypoints[index] - xf.origin
		to.y = 0.0
	var fwd := -xf.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(to.normalized(), Vector3.UP)
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
	if absf(car.drive.speed) < 1.5:
		_stuck += dt
	else:
		_stuck = maxf(0.0, _stuck - dt)
	if _stuck > 1.2:
		_stuck = 0.0
		_reverse = 1.1
		_reverse_steer = -signf(steer) if absf(steer) > 0.1 else 1.0
	return f
