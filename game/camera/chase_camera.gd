class_name ChaseCamera
extends Camera3D
## Tight third-person chase camera. Follows the car's heading (not its slide),
## widens its field of view with speed, flips for look-back, and pulls in
## when a wall gets between it and the car.

var target: ArcadeVehicle
var distance := 7.5
var height := 3.0
var look_height := 1.1
var look_ahead := 4.0
var follow_sharpness := 7.0
var base_fov := 70.0
var speed_fov := 12.0

## Camera views: [name, distance, height, look height]. "Hood" sits on the roof.
const VIEWS := [
	["CHASE", 7.5, 3.0, 1.1],
	["FAR CHASE", 11.0, 4.6, 1.3],
	["HOOD", 0.0, 1.55, 1.45],
]
var view := 0

var _yaw := 0.0
var _shake := 0.0
var _initialised := false


func _ready() -> void:
	fov = base_fov
	near = 0.1
	far = 600.0


func snap() -> void:
	_initialised = false


## Steps through the camera views. Returns the new view's name.
func cycle_view(step: int) -> String:
	view = (view + step + VIEWS.size()) % VIEWS.size()
	distance = VIEWS[view][1]
	height = VIEWS[view][2]
	look_height = VIEWS[view][3]
	_initialised = false
	return VIEWS[view][0]


func is_hood_view() -> bool:
	return distance < 0.5


func _process(delta: float) -> void:
	if target == null:
		return
	var xf := target.get_global_transform_interpolated()
	var heading := -xf.basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	var car_yaw := atan2(-heading.x, -heading.z)
	if target.frame.look_back:
		car_yaw += PI
	if not _initialised:
		_yaw = car_yaw
		_initialised = true
	else:
		_yaw = lerp_angle(_yaw, car_yaw, 1.0 - exp(-follow_sharpness * delta))

	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var focus := xf.origin + Vector3.UP * look_height
	var desired := focus + back * distance + Vector3.UP * (height - look_height)
	if is_hood_view():
		# On the roof, a little forward of centre (or rearward when looking back).
		_yaw = car_yaw
		back = Vector3(sin(_yaw), 0.0, cos(_yaw))
		desired = xf.origin + xf.basis.y * height - back * 0.6
		focus = desired - back * 20.0 + Vector3.DOWN * 1.5

	# Keep the camera on the car's side of walls.
	if not is_hood_view():
		var q := PhysicsRayQueryParameters3D.create(focus, desired, ArcadeVehicle.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			desired = hp + (focus - hp).normalized() * 0.4

	if target.last_impact > 0.0:
		_shake = clampf(target.last_impact / 30.0, 0.0, 0.6)
		target.last_impact = 0.0
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.3

	global_position = desired + shake
	look_at(focus - back * (0.0 if is_hood_view() else look_ahead), Vector3.UP)
	var boost := 0.4 if target.drive.boosting else 0.0
	fov = lerpf(fov, base_fov + speed_fov * clampf(target.speed_fraction() + boost, 0.0, 1.4), 1.0 - exp(-4.0 * delta))
