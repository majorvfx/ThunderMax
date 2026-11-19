class_name MachineGun
extends Node3D
## Hitscan machine gun with heat, light aim assist and tracers.
## Fire rules (rate, heat, damage) live in CombatRules.GunState.

var vehicle: ArcadeVehicle
var gun := CombatRules.GunState.new()
var muzzles: Array[Vector3] = [Vector3(-0.45, 0.62, -2.1), Vector3(0.45, 0.62, -2.1)]
var current_target: Node3D = null
var _next_muzzle := 0
var _rng := RandomNumberGenerator.new()


func setup(v: ArcadeVehicle, weapon_data: Dictionary) -> void:
	vehicle = v
	gun.configure(weapon_data)


func _physics_process(delta: float) -> void:
	if vehicle == null or not vehicle.is_alive():
		current_target = null
		return
	current_target = _find_target()
	var shots := gun.tick(delta, vehicle.frame.fire_gun)
	for i in shots:
		_fire()


func _find_target() -> Node3D:
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var best: Node3D = null
	var best_angle := deg_to_rad(gun.aim_assist_deg)
	for node in get_tree().get_nodes_in_group("targets"):
		if node == vehicle or not (node is Node3D):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var to: Vector3 = (node as Node3D).global_position - xf.origin
		var dist := to.length()
		if dist > gun.range_m or dist < 1.0:
			continue
		var angle := fwd.angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = node
	return best


func _fire() -> void:
	var xf := vehicle.global_transform
	var muzzle: Vector3 = xf * muzzles[_next_muzzle]
	_next_muzzle = (_next_muzzle + 1) % muzzles.size()
	var dir := -xf.basis.z
	if current_target != null:
		dir = (current_target.global_position + Vector3.UP * 0.3 - muzzle).normalized()
	var spread := deg_to_rad(gun.spread_deg)
	dir = dir.rotated(xf.basis.y, _rng.randf_range(-spread, spread))
	dir = dir.rotated(xf.basis.x, _rng.randf_range(-spread, spread) * 0.5)
	var end := muzzle + dir * gun.range_m
	var q := PhysicsRayQueryParameters3D.create(muzzle, end,
		ArcadeVehicle.LAYER_WORLD | ArcadeVehicle.LAYER_VEHICLES | ArcadeVehicle.LAYER_PROPS, [vehicle.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var world := vehicle.get_parent()
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(gun.damage, vehicle)
		Effects.sparks(world, end, hit["normal"])
	Effects.tracer(world, muzzle, end)
	GameAudio.play_at("gun", muzzle, 0.55)
