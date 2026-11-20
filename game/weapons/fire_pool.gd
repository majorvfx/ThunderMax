class_name FirePool
extends Area3D
## Burning fuel left by a Fire Jug. Sets any car inside alight while it lasts.

var owner_vehicle: Node
var radius := 4.5
var duration := 4.0
var burn_s := 3.0
var burn_dps := 6.0
var _age := 0.0
var _tick := 0.0
var _flames: CPUParticles3D
var _light: OmniLight3D


func setup(from: Node, data: Dictionary) -> void:
	owner_vehicle = from
	radius = float(data.get("pool_radius", radius))
	duration = float(data.get("pool_s", duration))
	burn_s = float(data.get("burn_s", burn_s))
	burn_dps = float(data.get("burn_dps", burn_dps))


func _ready() -> void:
	collision_layer = 0
	collision_mask = ArcadeVehicle.LAYER_VEHICLES
	monitoring = true
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = 3.0
	shape.shape = c
	shape.position = Vector3(0, 1.0, 0)
	add_child(shape)
	_flames = CPUParticles3D.new()
	_flames.amount = 40
	_flames.lifetime = 0.8
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = radius * 0.8
	_flames.direction = Vector3.UP
	_flames.spread = 10.0
	_flames.initial_velocity_min = 1.0
	_flames.initial_velocity_max = 3.0
	_flames.gravity = Vector3(0, 2, 0)
	_flames.scale_amount_min = 0.8
	_flames.scale_amount_max = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	q.material = VehicleVisualParts.material("flame")
	_flames.mesh = q
	_flames.color_ramp = Effects._ramp([Color(1, 0.85, 0.4, 1), Color(1, 0.35, 0.05, 0.8), Color(0.2, 0.05, 0.0, 0.0)])
	_flames.position = Vector3(0, 0.2, 0)
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.12)
	_light.light_energy = 3.0
	_light.omni_range = radius * 2.5
	_light.position = Vector3(0, 1.0, 0)
	add_child(_light)


func _physics_process(delta: float) -> void:
	_age += delta
	_tick -= delta
	if _age >= duration:
		queue_free()
		return
	_light.light_energy = 3.0 * (1.0 - _age / duration) + randf_range(-0.3, 0.3)
	if _tick > 0.0:
		return
	_tick = 0.25
	for b in get_overlapping_bodies():
		if b is ArcadeVehicle and (b as ArcadeVehicle).is_alive():
			(b as ArcadeVehicle).status.ignite(burn_s, burn_dps, owner_vehicle)
