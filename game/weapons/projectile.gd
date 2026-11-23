class_name Projectile
extends Node3D
## Rockets, coolant rounds and fire jugs. Moves itself each physics step and
## sweeps a ray along the step, so fast shots never pass through thin walls.
##
## Steering toward homing_target comes in two strengths from the shot's data:
## "turn_rate_deg" is a real homing missile (the Seeker); "curve_deg_per_s" with
## "view_cone_deg" is a slight curve that only bends toward a target still in
## front of the shot. A shot with neither flies dead straight (the Sledge).

## Every shot reaches 15% further out from a car than the car's own body: a
## shot that grazes within that margin counts as a hit. Shots with their own
## "hit_radius" (boulders, shrapnel) get the same 15% on top.
const HITBOX_SCALE := 1.15
## The collision box sits this far above the car's origin (VehicleFactory).
const BODY_OFFSET := Vector3(0, 0.12, 0)

var kind := ""
var owner_vehicle: ArcadeVehicle
var data := {}
var velocity := Vector3.ZERO
var gravity := 0.0
var life := 4.0
var homing_target: Node3D = null
var turn_rate := 0.0
var view_cone := PI        ## only steer while the target is within this angle of the heading
var bounces_left := 0      ## Ripsaw: wall bounces before it shatters
var _done := false
var _trail: CPUParticles3D
var _chain: MeshInstance3D  ## Slag Hook: the chain back to the car
var _disc: Node3D           ## Ripsaw: the spinning blade
var _run_speed := 0.0
var _boulder: MeshInstance3D


func setup(projectile_kind: String, from: ArcadeVehicle, projectile_data: Dictionary) -> void:
	kind = projectile_kind
	owner_vehicle = from
	data = projectile_data
	life = float(data.get("life_s", 4.0))
	turn_rate = deg_to_rad(float(data.get("turn_rate_deg", data.get("curve_deg_per_s", 0.0))))
	view_cone = deg_to_rad(float(data.get("view_cone_deg", 180.0)))
	bounces_left = int(data.get("bounces", 0))
	gravity = float(data.get("gravity", 0.0))
	if kind == "saw" or kind == "boulder":
		gravity = 20.0   # it rides along the ground
	add_to_group("projectiles")


## Launch velocity for a lobbed shot: `speed` along `dir` tipped up by `arc_deg`.
static func lob_velocity(dir: Vector3, speed: float, arc_deg: float) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var a := deg_to_rad(arc_deg)
	return flat * cos(a) * speed + Vector3.UP * sin(a) * speed


func launch(at: Vector3, vel: Vector3) -> void:
	global_position = at
	velocity = vel
	_run_speed = Vector3(vel.x, 0.0, vel.z).length()
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
		"ember":
			col = Color(1.0, 0.5, 0.12)
			size = Vector3(0.14, 0.14, 0.5)
		"hook":
			_build_hook()
			return
		"saw":
			_build_saw()
			return
		"net":
			_build_net()
			return
		"boulder":
			_build_boulder()
			return
		"mortar", "skipper":
			col = Color(0.9, 0.5, 0.15) if kind == "mortar" else Color(0.95, 0.75, 0.2)
			size = Vector3(0.34, 0.34, 0.34)
		"tar_pot":
			col = Color(0.6, 0.25, 0.05)
			size = Vector3(0.5, 0.6, 0.5)
		"shard":
			col = Color(1.0, 0.7, 0.35)
			size = Vector3(0.1, 0.1, 0.35)
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
	q.material = VehicleVisualParts.soft_puff(false)
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
	if _disc != null:
		_disc.rotate_y(delta * 40.0)
	if kind == "boulder" and _boulder != null:
		_boulder.rotate_x(-delta * _run_speed / 0.8)
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
			if angle > 0.0001 and angle <= view_cone:
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
	if hit.is_empty() or not (hit["collider"] is ArcadeVehicle):
		# A near miss on a car before the shot reaches the wall counts.
		var graze := _graze_hit(from, hit["position"] if not hit.is_empty() else to)
		if not graze.is_empty():
			hit = graze
	if hit.is_empty() and data.has("hit_radius"):
		hit = _near_hit(to, float(data["hit_radius"]) * HITBOX_SCALE)
	if not hit.is_empty():
		if (kind == "saw" or kind == "boulder") and _saw_contact(hit):
			_update_chain()
			return
		if kind == "skipper" and _skip(hit):
			return
		_finish(hit["position"], hit["normal"], hit["collider"])
		return
	global_position = to
	if velocity.length_squared() > 0.01:
		var flat := kind == "saw" or kind == "boulder"
		var look := Vector3(velocity.x, 0.0, velocity.z) if flat else velocity
		if look.length_squared() > 0.01:
			look_at(to + look, Vector3.UP if absf(look.normalized().y) < 0.99 else Vector3.FORWARD)
	_update_chain()


## Ripsaw against the world: rides along floors and ramps, bounces off walls.
## Returns false when it should shatter (out of bounces) or hit something breakable.
func _saw_contact(hit: Dictionary) -> bool:
	var collider: Object = hit["collider"]
	if collider != null and collider.has_method("take_damage"):
		return false
	var n: Vector3 = hit["normal"]
	var at: Vector3 = hit["position"]
	if n.y > 0.5:
		# Ground or a ramp: follow the surface at blade height.
		var along := velocity - n * velocity.dot(n)
		velocity = along.normalized() * _run_speed if along.length() > 0.1 else velocity
		global_position = at + n * (0.8 if kind == "boulder" else 0.45)
		return true
	if bounces_left <= 0:
		return false
	bounces_left -= 1
	var out := velocity.bounce(n)
	out.y = 0.0
	velocity = out.normalized() * _run_speed
	global_position = at + n * 0.3
	Effects.sparks(get_parent(), at, n)
	GameAudio.play_at("impact", at, 0.7, 1.6)
	return true


## The first car whose body, grown by HITBOX_SCALE, the step from `from` to
## `to` passes through. Walks the step in short hops so fast shots can't skip
## over the thin margin.
func _graze_hit(from: Vector3, to: Vector3) -> Dictionary:
	var cars: Array[ArcadeVehicle] = []
	for node in get_tree().get_nodes_in_group("targets"):
		if node == owner_vehicle or not (node is ArcadeVehicle):
			continue
		var car := node as ArcadeVehicle
		if car.is_alive() and car.stats != null and car.global_position.distance_to(to) < car.stats.body_length + from.distance_to(to):
			cars.append(car)
	if cars.is_empty():
		return {}
	var steps := maxi(1, ceili(from.distance_to(to) / 0.2))
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		for car in cars:
			if in_hitbox(car, p):
				var c := car.global_transform * BODY_OFFSET
				return {"position": p, "normal": (p - c).normalized() if p.distance_to(c) > 0.01 else Vector3.UP, "collider": car}
	return {}


## Whether `at` is inside the car's body box grown by HITBOX_SCALE.
static func in_hitbox(car: ArcadeVehicle, at: Vector3) -> bool:
	var local := car.global_transform.affine_inverse() * at - BODY_OFFSET
	var half := Vector3(car.stats.body_width, car.stats.body_height, car.stats.body_length) * 0.5 * HITBOX_SCALE
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Chunky shots (boulders, shrapnel) hit a car that comes within `radius` of
## them, not only one the centre line touches.
func _near_hit(at: Vector3, radius: float) -> Dictionary:
	for node in get_tree().get_nodes_in_group("targets"):
		if node == owner_vehicle or not (node is ArcadeVehicle) or not (node as ArcadeVehicle).is_alive():
			continue
		var c := (node as Node3D).global_position
		if Vector3(c.x - at.x, (c.y - at.y) * 0.5, c.z - at.z).length() <= radius:
			return {"position": at, "normal": (at - c).normalized(), "collider": node}
	return {}


## Skipper: bounces off floors and walls (not cars) until it runs out of bounces.
func _skip(hit: Dictionary) -> bool:
	var collider: Object = hit["collider"]
	if collider is ArcadeVehicle or (collider != null and collider.has_method("take_damage")):
		return false
	if bounces_left <= 0:
		return false
	bounces_left -= 1
	var n: Vector3 = hit["normal"]
	velocity = velocity.bounce(n) * 0.85
	if n.y > 0.5:
		velocity.y = maxf(velocity.y, 7.0)   # a lively hop off the ground
	global_position = (hit["position"] as Vector3) + n * 0.3
	Effects.sparks(get_parent(), hit["position"], n)
	GameAudio.play_at("impact", hit["position"], 0.6, 1.9)
	return true


## Damage and a shove to everything within `radius` of `at`, falling off with
## distance (a direct hit is dealt separately). Used by blasts that splash.
static func splash(world: Node, at: Vector3, radius: float, damage: float, impulse: float, src: Node, skip: Object = null) -> void:
	if world == null or not world.is_inside_tree():
		return
	for node in world.get_tree().get_nodes_in_group("targets"):
		if node == skip or not (node is Node3D):
			continue
		var to: Vector3 = (node as Node3D).global_position - at
		var d := to.length()
		if d > radius:
			continue
		var f := 1.0 - d / radius
		if node.has_method("take_damage"):
			node.take_damage(damage * (0.35 + 0.65 * f), src)
		if impulse > 0.0 and node is ArcadeVehicle and (node as ArcadeVehicle).is_alive():
			var flat := Vector3(to.x, 0.0, to.z)
			var push := (flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD) + Vector3.UP * 0.5
			(node as ArcadeVehicle).apply_central_impulse(push.normalized() * impulse * f)


func _update_chain() -> void:
	if _chain == null or owner_vehicle == null or not is_instance_valid(owner_vehicle):
		return
	var from := owner_vehicle.global_position + Vector3.UP * 0.6
	var to := global_position
	var length := from.distance_to(to)
	if length < 0.3:
		_chain.visible = false
		return
	_chain.visible = true
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	_chain.global_transform = Transform3D(Basis.looking_at(dir, up).scaled_local(Vector3(1, 1, length)), (from + to) * 0.5)


func _build_hook() -> void:
	var steel := VehicleVisualParts.material("steel")
	VehicleVisualParts.box(self, Vector3(0.12, 0.12, 0.9), Vector3.ZERO, steel)
	for x in [-1.0, 1.0]:
		var barb := VehicleVisualParts.box(self, Vector3(0.06, 0.06, 0.45), Vector3(x * 0.14, 0, -0.32), steel)
		barb.rotation.y = x * 0.6
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.45, 0.15)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.1)
	glow.emission_energy_multiplier = 2.0
	VehicleVisualParts.box(self, Vector3(0.16, 0.16, 0.16), Vector3(0, 0, -0.5), glow)   # red-hot tip
	_chain = MeshInstance3D.new()
	var link := BoxMesh.new()
	link.size = Vector3(0.06, 0.06, 1.0)
	link.material = VehicleVisualParts.material("steel")
	_chain.mesh = link
	_chain.top_level = true
	_chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chain)
	_update_chain()


## Spike Net: a square of chain with spikes at the corners, spinning flat.
func _build_net() -> void:
	_disc = Node3D.new()
	add_child(_disc)
	var steel := VehicleVisualParts.material("steel")
	for i in 4:
		var off := -0.6 + 0.4 * i
		VehicleVisualParts.box(_disc, Vector3(1.4, 0.04, 0.04), Vector3(0, 0, off), steel)
		VehicleVisualParts.box(_disc, Vector3(0.04, 0.04, 1.4), Vector3(off, 0, 0), steel)
	for c in [Vector3(-0.7, 0, -0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, 0.7)]:
		VehicleVisualParts.box(_disc, Vector3(0.16, 0.16, 0.16), c, VehicleVisualParts.material("blade"))


## Rockslide: a lump of slag, still glowing in the cracks.
func _build_boulder() -> void:
	_boulder = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.5
	sphere.radial_segments = 8
	sphere.rings = 5
	sphere.material = VehicleVisualParts.material("slag")
	_boulder.mesh = sphere
	add_child(_boulder)


func _build_saw() -> void:
	_disc = Node3D.new()
	add_child(_disc)
	VehicleVisualParts.cylinder(_disc, 0.45, 0.05, Vector3.ZERO, Vector3.ZERO, VehicleVisualParts.material("blade"))
	for i in 10:
		var a := TAU * float(i) / 10.0
		var tooth := VehicleVisualParts.box(_disc, Vector3(0.12, 0.05, 0.08), Vector3(cos(a) * 0.48, 0, sin(a) * 0.48), VehicleVisualParts.material("steel"))
		tooth.rotation.y = -a
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.75, 0.4)
	spark.light_energy = 1.5
	spark.omni_range = 4.0
	add_child(spark)
	# A spray of sparks off the blade as it runs.
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.35
	sparks.local_coords = false
	sparks.direction = Vector3(0, 0.6, 1)
	sparks.spread = 35.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -14, 0)
	var sq := QuadMesh.new()
	sq.size = Vector2(0.12, 0.12)
	sq.material = VehicleVisualParts.soft_puff(true)
	sparks.mesh = sq
	sparks.color_ramp = Effects._ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.1, 0.8), Color(0.6, 0.2, 0.05, 0)])
	add_child(sparks)
	sparks.emitting = true


func _spill_fire(world: Node, at: Vector3, src: Node) -> void:
	var pool := FirePool.new()
	pool.setup(src, data)
	world.add_child(pool)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 6.0, ArcadeVehicle.LAYER_WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(q)
	pool.global_position = ground["position"] if not ground.is_empty() else at


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
		"hook":
			Effects.sparks(world, at, normal)
			GameAudio.play_at("impact", at, 0.9, 1.3)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 10.0)), src)
			if collider is ArcadeVehicle and src != null:
				# Reel them in: a hard yank toward the car that fired.
				var v := collider as ArcadeVehicle
				var to_me := (src as Node3D).global_position - v.global_position
				to_me.y = 0.0
				var pull := float(data.get("pull_impulse", 11000.0))
				v.apply_central_impulse(to_me.normalized() * pull + Vector3.UP * pull * 0.12)
		"net":
			Effects.sparks(world, at, normal)
			GameAudio.play_at("hook", at, 0.8, 0.8)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 6.0)), src)
			if collider is ArcadeVehicle:
				(collider as ArcadeVehicle).status.snare(float(data.get("snare_s", 2.0)), float(data.get("snare_speed_scale", 0.3)))
		"boulder":
			Effects.shockwave(world, at, 3.0)
			GameAudio.play_at("slam", at, 0.7, 1.3)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 16.0)), src)
			if collider is ArcadeVehicle:
				var push := (Vector3(velocity.x, 0.0, velocity.z).normalized() + Vector3.UP * 0.5).normalized()
				(collider as ArcadeVehicle).apply_central_impulse(push * float(data.get("impulse", 9000.0)))
		"shard":
			Effects.sparks(world, at, normal)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 7.0)), src)
		"mortar", "skipper", "tar_pot":
			Effects.explosion(world, at, 0.55 if kind != "tar_pot" else 0.45)
			GameAudio.play_at("explosion", at, 0.7, 1.25)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 10.0)), src)
			if data.has("splash_radius"):
				splash(world, at, float(data["splash_radius"]), float(data.get("splash_damage", 8.0)), float(data.get("impulse", 4000.0)), src, collider)
			if kind == "tar_pot":
				_spill_fire(world, at, src)
		"saw":
			Effects.sparks(world, at, normal)
			Effects.sparks(world, at, Vector3.UP)
			GameAudio.play_at("impact", at, 1.0, 1.7)
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(data.get("damage", 20.0)), src)
		_:
			var boom := 0.6
			if kind == "sledge":
				boom = 0.9
			elif kind == "ember":
				boom = 0.3
			Effects.explosion(world, at, boom)
			GameAudio.play_at("explosion", at, 0.5 if kind == "ember" else 0.8, 1.2 if kind != "sledge" else 0.85)
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
