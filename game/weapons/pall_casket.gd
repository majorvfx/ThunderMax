class_name PallCasket
extends Node3D
## Mourner's Pall: a casket kicked out the back. After a moment it bursts into a
## black cloud. Anyone inside (except the Mourner) starts to burn, and any rocket
## or curving shot that is tracking a car inside the cloud loses its lock.

var owner_vehicle: ArcadeVehicle
var delay_s := 0.6
var radius := 7.0
var cloud_s := 5.0
var burn_s := 1.2
var burn_dps := 6.0
var damage := 8.0
var velocity := Vector3.ZERO
var _age := 0.0
var _burst := false
var _tick := 0.0
var _casket: Node3D
var _cloud: CPUParticles3D


func setup(from: ArcadeVehicle, data: Dictionary) -> void:
	owner_vehicle = from
	delay_s = float(data.get("delay_s", delay_s))
	radius = float(data.get("cloud_radius", radius))
	cloud_s = float(data.get("cloud_s", cloud_s))
	burn_s = float(data.get("burn_s", burn_s))
	burn_dps = float(data.get("burn_dps", burn_dps))
	damage = float(data.get("damage", damage))


func _ready() -> void:
	add_to_group("pall_clouds")
	_casket = Node3D.new()
	add_child(_casket)
	var wood := VehicleVisualParts.material("casket")
	VehicleVisualParts.box(_casket, Vector3(0.75, 0.5, 2.0), Vector3.ZERO, wood)
	VehicleVisualParts.box(_casket, Vector3(0.8, 0.08, 2.05), Vector3(0, 0.27, 0), VehicleVisualParts.material("steel"))
	for z in [-0.7, 0.7]:
		VehicleVisualParts.box(_casket, Vector3(0.85, 0.06, 0.08), Vector3(0, 0.0, z), VehicleVisualParts.material("steel"))


func is_covering(pos: Vector3) -> bool:
	return _burst and _age < delay_s + cloud_s and Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z).length() <= radius


func _physics_process(delta: float) -> void:
	_age += delta
	if not _burst:
		# Tumbling out of the back doors, then sliding to a stop.
		velocity.y -= 22.0 * delta
		var next := global_position + velocity * delta
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, next - Vector3.UP * 0.25, ArcadeVehicle.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			next = hit["position"] + Vector3.UP * 0.25
			velocity = Vector3(velocity.x, 0.0, velocity.z) * maxf(0.0, 1.0 - 6.0 * delta)
		global_position = next
		_casket.rotation.x += delta * 2.0 * velocity.length() * 0.1
		if _age >= delay_s:
			_burst_open()
		return
	if _age >= delay_s + cloud_s:
		# The smoke thins out, then the whole thing goes.
		if _cloud != null:
			_cloud.emitting = false
		if _age >= delay_s + cloud_s + 2.5:
			queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.2
	for node in get_tree().get_nodes_in_group("targets"):
		if node is ArcadeVehicle and node != owner_vehicle and (node as ArcadeVehicle).is_alive() and is_covering((node as Node3D).global_position):
			(node as ArcadeVehicle).status.ignite(burn_s, burn_dps, owner_vehicle)
	for p in get_tree().get_nodes_in_group("projectiles"):
		var shot := p as Projectile
		if shot != null and shot.homing_target != null and is_instance_valid(shot.homing_target) and is_covering(shot.homing_target.global_position):
			shot.homing_target = null


func _burst_open() -> void:
	_burst = true
	_casket.visible = false
	var world := get_parent()
	Effects.explosion(world, global_position, 0.35)
	_cloud = Effects.pall_cloud(self, global_position, radius)
	GameAudio.play_at("cloak", global_position, 1.0, 0.7)
	for node in get_tree().get_nodes_in_group("targets"):
		if node != owner_vehicle and node.has_method("take_damage") and node is Node3D and (node as Node3D).global_position.distance_to(global_position) < radius * 0.5:
			node.take_damage(damage, owner_vehicle)
