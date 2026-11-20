class_name ScrapMine
extends Area3D
## A spiked charge dropped behind a car. Arms after a moment, then blows on the
## first car to touch it. Its owner is safe until it has been armed for a second.

var owner_vehicle: ArcadeVehicle
var damage := 25.0
var radius := 2.4
var arm_s := 0.5
var life_s := 30.0
var _age := 0.0
var _done := false
var _lamp: MeshInstance3D


func setup(from: ArcadeVehicle, data: Dictionary) -> void:
	owner_vehicle = from
	damage = float(data.get("damage", damage))
	radius = float(data.get("radius", radius))
	arm_s = float(data.get("arm_s", arm_s))
	life_s = float(data.get("life_s", life_s))


func _ready() -> void:
	collision_layer = 0
	collision_mask = ArcadeVehicle.LAYER_VEHICLES
	monitoring = true
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	shape.shape = s
	add_child(shape)
	var steel := VehicleVisualParts.material("steel")
	VehicleVisualParts.cylinder(self, 0.45, 0.22, Vector3.ZERO, Vector3.ZERO, steel)
	for a in range(0, 360, 60):
		var spike := VehicleVisualParts.box(self, Vector3(0.08, 0.08, 0.35), Vector3(cos(deg_to_rad(a)) * 0.5, 0.0, sin(deg_to_rad(a)) * 0.5), steel)
		spike.rotation.y = -deg_to_rad(a)
	_lamp = VehicleVisualParts.box(self, Vector3(0.14, 0.1, 0.14), Vector3(0, 0.15, 0), VehicleVisualParts.material("beacon"))
	add_to_group("mines")


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_lamp.visible = _age < arm_s or fmod(_age, 0.6) < 0.2
	if _age >= life_s:
		queue_free()
		return
	if _age < arm_s:
		return
	for b in get_overlapping_bodies():
		if b is ArcadeVehicle and (b as ArcadeVehicle).is_alive():
			if b == owner_vehicle and _age < arm_s + 1.0:
				continue
			_explode(b as ArcadeVehicle)
			return


func _explode(victim: ArcadeVehicle) -> void:
	_done = true
	var src: Node = owner_vehicle if is_instance_valid(owner_vehicle) else null
	Effects.explosion(get_parent(), global_position, 0.7)
	GameAudio.play_at("explosion", global_position, 0.9, 1.1)
	victim.take_damage(damage, src)
	if not victim.status.is_shielded():
		victim.apply_central_impulse(Vector3.UP * victim.mass * 6.0)
	queue_free()
