class_name Projectile
extends Node3D
## Rockets, coolant rounds and fire jugs. Moves itself each physics step and
## sweeps a ray along the step, so fast shots never pass through thin walls.

var kind := ""
var owner_vehicle: ArcadeVehicle
var data := {}
var velocity := Vector3.ZERO
var gravity := 0.0
var life := 4.0
var homing_target: Node3D = null
var turn_rate := 0.0
var _done := false
var _trail: CPUParticles3D


func setup(projectile_kind: String, from: ArcadeVehicle, projectile_data: Dictionary) -> void:
	kind = projectile_kind
	owner_vehicle = from
	data = projectile_data
	life = float(data.get("life_s", 4.0))
	turn_rate = deg_to_rad(float(data.get("turn_rate_deg", 0.0)))


func launch(at: Vector3, vel: Vector3) -> void:
	global_position = at
	velocity = vel
	_build_visual()
	if velocity.length_squared() > 0.01:
		look_at(at + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)


func _build_visual() -> void:
	var col := Color(1.0, 0.55, 0.2)
	var size := Vector3(0.22, 0.22, 0.9)
	match kind:
		"cold_snap":
			col = Color(0.55, 0.85, 1.0)
			size = Vector3(0.3, 0.3, 0.6)
		"fire_jug":
			col = Color(1.0, 0.4, 0.1)
			size = Vector3(0.45, 0.55, 0.45)
		"sledge":
			col = Color(1.0, 0.3, 0.15)
			size = Vector3(0.4, 0.4, 1.3)
		"firebrand":
			col = Color(1.0, 0.6, 0.15)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	VehicleVisualParts.box(self, size, Vector3.ZERO, m)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 5.0
	add_child(light)
	_trail = CPUParticles3D.new()
	_trail.amount = 20
	_trail.lifetime = 0.5
	_trail.local_coords = false
	_trail.direction = Vector3.BACK
	_trail.spread = 10.0
	_trail.initial_velocity_min = 0.5
	_trail.initial_velocity_max = 1.5
	_trail.gravity = Vector3(0, 0.5, 0)
	_trail.scale_amount_min = 0.5
	_trail.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.material = VehicleVisualParts.material("smoke_puff")
	_trail.mesh = q
	var trail_col := Color(0.8, 0.95, 1.0, 0.5) if kind == "cold_snap" else Color(0.5, 0.45, 0.4, 0.6)
	_trail.color_ramp = Effects._ramp([trail_col, Color(trail_col, 0.0)])
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	if life <= 0.0:
		_finish(global_position, Vector3.UP, null)
		return
	if homing_target != null and is_instance_valid(homing_target) and turn_rate > 0.0:
		if homing_target.has_method("is_alive") and not homing_target.is_alive():
			homing_target = null
		elif homing_target is ArcadeVehicle and (homing_target as ArcadeVehicle).status.is_cloaked():
			homing_target = null   # Blackout breaks the lock
		else:
			var want := (homing_target.global_position + Vector3.UP * 0.3 - global_position).normalized()
			var speed := velocity.length()
			var cur := velocity.normalized()
			var angle := cur.angle_to(want)
			if angle > 0.0001:
				var step := minf(1.0, turn_rate * delta / angle)
				velocity = cur.slerp(want, step).normalized() * speed
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var exclude: Array[RID] = []
	if owner_vehicle != null and is_instance_valid(owner_vehicle):
		exclude.append(owner_vehicle.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to,
		ArcadeVehicle.LAYER_WORLD | ArcadeVehicle.LAYER_VEHICLES | ArcadeVehicle.LAYER_PROPS, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_finish(hit["position"], hit["normal"], hit["collider"])
		return
	global_position = to
	if velocity.length_squared() > 0.01:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)


func _finish(at: Vector3, normal: Vector3, collider: Object) -> void:
	_done = true
	var world := get_parent()
	var src: Node = owner_vehicle if is_instance_valid(owner_vehicle) else null
	match kind:
		"cold_snap":
			Effects.frost_burst(world, at)
			GameAudio.play_at("freeze", at, 0.9)
			if collider is ArcadeVehicle:
				var v := collider as ArcadeVehicle
				v.take_damage(float(data.get("damage", 4.0)), src)
				v.status.freeze(float(data.get("freeze_s", 2.2)))
		"fire_jug":
			Effects.explosion(world, at, 0.45)
			GameAudio.play_at("explosion", at, 0.6, 1.4)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 10.0)), src)
			var pool := FirePool.new()
			pool.setup(src, data)
			world.add_child(pool)
			var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 6.0, ArcadeVehicle.LAYER_WORLD)
			var ground := get_world_3d().direct_space_state.intersect_ray(q)
			pool.global_position = ground["position"] if not ground.is_empty() else at
		_:
			Effects.explosion(world, at, 0.6 if kind != "sledge" else 0.9)
			GameAudio.play_at("explosion", at, 0.8, 1.2 if kind != "sledge" else 0.85)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 12.0)), src)
			if collider is ArcadeVehicle:
				var v := collider as ArcadeVehicle
				if data.has("burn_s"):
					v.status.ignite(float(data["burn_s"]), float(data.get("burn_dps", 5.0)), src)
				if data.has("impulse"):
					var push := (velocity.normalized() + Vector3.UP * 0.6).normalized()
					v.apply_central_impulse(push * float(data["impulse"]))
	queue_free()
