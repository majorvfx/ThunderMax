class_name ArcadeVehicle
extends RigidBody3D
## Godot layer for a Thunder Max vehicle.
##
## Raycast suspension holds the body up; ArcadeHandling (engine-agnostic) decides
## forward speed, slide and yaw; this script converts between world space and car
## space each physics step. Rams and wall hits are detected from sudden changes
## in velocity and turned into damage by CombatRules.

signal wrecked(vehicle: ArcadeVehicle, killer: Node)
signal damaged(vehicle: ArcadeVehicle, amount: float, source: Node)
signal pickup_taken(vehicle: ArcadeVehicle, kind: String)
signal shield_blocked(vehicle: ArcadeVehicle, amount: float)

const LAYER_WORLD := 1
const LAYER_VEHICLES := 2
const LAYER_PICKUPS := 4
const LAYER_PROPS := 8

const WHEEL_RADIUS := 0.42
const RAM_THRESHOLD := 7.0
const WALL_POWER := 0.35

var stats: VehicleStats
var drive := ArcadeHandling.DriveState.new()
var health := CombatRules.Health.new()
var driver: RefCounted   ## anything with get_frame(vehicle, dt) -> ControlFrame
var team := 0
var is_player := false
var frame := ArcadeHandling.ControlFrame.new()
var status := StatusEffects.new()
var combos: ComboController
var specials: SpecialWeapons

var grounded := false
var ground_normal := Vector3.UP
var wheel_offsets: Array[Vector3] = [
	Vector3(-0.85, -0.1, -1.3), Vector3(0.85, -0.1, -1.3),
	Vector3(-0.85, -0.1, 1.3), Vector3(0.85, -0.1, 1.3),
]
var wheel_distance: Array[float] = [0.6, 0.6, 0.6, 0.6]
var wheel_contact: Array[bool] = [false, false, false, false]
var last_impact := 0.0   ## m/s of the latest impact, for camera shake and sound
var last_attacker: Node = null

var _last_out_velocity := Vector3.ZERO
var _has_last := false
var _alive := true
var _stuck_flipped := 0.0
var _impact_cooldown := 0.0


func setup(vehicle_stats: VehicleStats, vehicle_driver: RefCounted, player: bool) -> void:
	stats = vehicle_stats
	driver = vehicle_driver
	is_player = player
	health = CombatRules.Health.new(stats.max_health)
	drive = ArcadeHandling.DriveState.new()
	drive.turbo = stats.turbo_capacity
	var tx := stats.wheel_track
	var tz := stats.wheel_base
	wheel_offsets = [Vector3(-tx, -0.1, -tz), Vector3(tx, -0.1, -tz), Vector3(-tx, -0.1, tz), Vector3(tx, -0.1, tz)]
	var combo_data: Variant = GameData.load_json(GameData.COMBOS_PATH)
	if typeof(combo_data) == TYPE_DICTIONARY:
		status.configure(float(combo_data.get("energy_max", 100.0)), float(combo_data.get("energy_regen", 6.0)))
	apply_stats()


## Re-applies body settings after stats change (tuning panel).
func apply_stats() -> void:
	mass = stats.mass
	gravity_scale = stats.gravity_scale
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.3, 0.0)
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.5
	collision_layer = LAYER_VEHICLES
	collision_mask = LAYER_WORLD | LAYER_VEHICLES | LAYER_PROPS
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.15
	physics_material_override.bounce = 0.0


func is_alive() -> bool:
	return _alive


func speed() -> float:
	return drive.speed


func speed_fraction() -> float:
	return clampf(absf(drive.speed) / maxf(stats.max_speed, 0.01), 0.0, 1.5)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if stats == null or not _alive:
		return
	var dt := state.step
	var xf := state.transform
	var up := xf.basis.y

	if driver != null:
		frame = driver.get_frame(self, dt)
	var drive_frame := frame.idle() if status.is_frozen() else frame

	_impact_cooldown = maxf(0.0, _impact_cooldown - dt)
	_detect_impacts(state, up)
	_suspension(state, xf, up)
	if _recover_if_flipped(state, up, dt):
		return

	var n := ground_normal if grounded else Vector3.UP
	var fwd := -xf.basis.z
	fwd = (fwd - n * fwd.dot(n))
	if fwd.length_squared() < 0.0001:
		fwd = -xf.basis.z
	fwd = fwd.normalized()
	var right := fwd.cross(n).normalized()

	var v := state.linear_velocity
	drive.speed = v.dot(fwd)
	drive.lateral = v.dot(right)
	var along_normal := v.dot(n)
	drive.vertical = v.y

	ArcadeHandling.step(stats, drive, drive_frame, grounded, dt)

	if grounded:
		v = fwd * drive.speed + right * drive.lateral + n * along_normal
	else:
		# Turbo in the air: the rocket pushes along the car's heading and holds off the fall.
		v += fwd * drive.air_push + Vector3.UP * drive.air_lift
	state.linear_velocity = v

	# Yaw follows the handling model; pitch and roll are pulled upright.
	var w := state.angular_velocity
	var yaw_now := w.dot(n)
	var target_yaw := drive.yaw_rate * (1.0 if grounded else stats.air_control)
	var yaw_blend := 1.0 - exp(-stats.yaw_response * dt * (1.0 if grounded else 0.4))
	var yaw_new := lerpf(yaw_now, target_yaw, yaw_blend)
	var w_other := w - n * yaw_now
	var desired_up := ground_normal if grounded else Vector3.UP
	var correction := up.cross(desired_up) * (stats.upright_strength if grounded else stats.air_upright)
	var upright_blend := 1.0 - exp(-(8.0 if grounded else 2.5) * dt)
	w_other = w_other.lerp(correction, upright_blend)
	state.angular_velocity = n * yaw_new + w_other

	_last_out_velocity = state.linear_velocity
	_has_last = true


func _suspension(state: PhysicsDirectBodyState3D, xf: Transform3D, up: Vector3) -> void:
	var space := state.get_space_state()
	var rest := stats.ride_height
	var reach := rest + 0.35
	var quarter := stats.mass * 0.25
	var omega := TAU * stats.suspension_hz
	var k := quarter * omega * omega
	var c := 2.0 * stats.suspension_damping * sqrt(k * quarter)
	var hits := 0
	var normal_sum := Vector3.ZERO
	for i in 4:
		var origin: Vector3 = xf * wheel_offsets[i]
		var q := PhysicsRayQueryParameters3D.create(origin, origin - up * reach, LAYER_WORLD, [get_rid()])
		var r := space.intersect_ray(q)
		if r.is_empty():
			wheel_distance[i] = rest
			wheel_contact[i] = false
			continue
		var hit_pos: Vector3 = r["position"]
		var hit_normal: Vector3 = r["normal"]
		var dist := origin.distance_to(hit_pos)
		wheel_distance[i] = minf(dist, rest)
		wheel_contact[i] = true
		hits += 1
		normal_sum += hit_normal
		if dist < rest:
			var offset := origin - xf.origin
			var point_vel := state.linear_velocity + state.angular_velocity.cross(offset)
			var force := k * (rest - dist) - c * point_vel.dot(up)
			if force > 0.0:
				state.apply_force(up * force, offset)
	grounded = hits >= 2
	if hits > 0:
		ground_normal = ground_normal.lerp(normal_sum.normalized(), 0.5).normalized()
	else:
		ground_normal = Vector3.UP


## A car stuck on its roof or side for 2 s is set back on its wheels where it lies.
func _recover_if_flipped(state: PhysicsDirectBodyState3D, up: Vector3, dt: float) -> bool:
	if up.y > 0.35 or state.linear_velocity.length() > 4.0:
		_stuck_flipped = 0.0
		return false
	_stuck_flipped += dt
	if _stuck_flipped < 2.0:
		return false
	_stuck_flipped = 0.0
	var fwd := -state.transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	state.transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), state.transform.origin + Vector3.UP * 1.5)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_has_last = false
	return true


func _detect_impacts(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	if not _has_last or _impact_cooldown > 0.0:
		return
	var delta := state.linear_velocity - _last_out_velocity
	delta -= up * delta.dot(up)   # ignore landings and suspension
	var dv := delta.length()
	if dv <= RAM_THRESHOLD:
		return
	_impact_cooldown = 0.25
	last_impact = dv
	var other_vehicle: ArcadeVehicle = null
	for i in state.get_contact_count():
		var obj := state.get_contact_collider_object(i)
		if obj is ArcadeVehicle:
			other_vehicle = obj
			break
	var power := WALL_POWER
	var source: Node = null
	if other_vehicle != null:
		power = other_vehicle.stats.ram_power
		source = other_vehicle
	var dmg := CombatRules.impact_damage(dv, power, stats.ram_armor, RAM_THRESHOLD)
	if dmg > 0.0:
		take_damage.call_deferred(dmg, source)
	_play_impact.call_deferred(clampf(dv / 25.0, 0.3, 1.0))


func _play_impact(volume: float) -> void:
	GameAudio.play_at("impact", global_position, volume)


func _physics_process(delta: float) -> void:
	if not _alive or stats == null:
		return
	var burn := status.tick(delta)
	if burn > 0.0:
		take_damage(burn, status.burn_source as Node)


func take_damage(amount: float, source: Node) -> void:
	if not _alive:
		return
	if status.is_shielded():
		shield_blocked.emit(self, amount)
		return
	var taken := health.damage(amount)
	if taken <= 0.0:
		return
	if source != null and source != self:
		last_attacker = source
	damaged.emit(self, taken, source)
	if health.is_dead():
		_wreck(source if source != null else last_attacker)


func apply_pickup(kind: String, amount: float) -> bool:
	if not _alive:
		return false
	var used := false
	if kind == "weapon":
		used = specials != null and specials.add_random(int(amount))
	else:
		used = CombatRules.apply_pickup(kind, amount, health, drive, stats.turbo_capacity)
	if used:
		pickup_taken.emit(self, kind)
	return used


func _wreck(killer: Node) -> void:
	_alive = false
	Effects.explosion(get_parent(), global_position, 1.0)
	GameAudio.play_at("explosion", global_position, 1.0)
	visible = false
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	wrecked.emit(self, killer)


## Puts the vehicle back in play at a spawn point with full health.
func respawn(at: Transform3D) -> void:
	health.reset()
	status.reset()
	if specials != null:
		specials.clear()
	drive = ArcadeHandling.DriveState.new()
	drive.turbo = stats.turbo_capacity
	last_attacker = null
	_has_last = false
	freeze = false
	collision_layer = LAYER_VEHICLES
	collision_mask = LAYER_WORLD | LAYER_VEHICLES | LAYER_PROPS
	global_transform = at
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	visible = true
	_alive = true
