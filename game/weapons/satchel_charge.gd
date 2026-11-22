class_name SatchelCharge
extends Node3D
## Satchel pickup: a canvas bag of blasting charge left on the ground. It sits
## blinking until its owner sets it off (fire again) or 8 s pass.

var owner_vehicle: ArcadeVehicle
var damage := 26.0
var radius := 7.0
var impulse := 10000.0
var life_s := 8.0
var _age := 0.0
var _done := false
var _lamp: MeshInstance3D


func setup(from: ArcadeVehicle, data: Dictionary) -> void:
	owner_vehicle = from
	damage = float(data.get("damage", damage))
	radius = float(data.get("splash_radius", radius))
	impulse = float(data.get("impulse", impulse))
	life_s = float(data.get("life_s", life_s))


func _ready() -> void:
	add_to_group("satchels")
	VehicleVisualParts.box(self, Vector3(0.6, 0.35, 0.45), Vector3(0, 0.17, 0), VehicleVisualParts.material("canvas"))
	VehicleVisualParts.box(self, Vector3(0.62, 0.06, 0.1), Vector3(0, 0.36, 0), VehicleVisualParts.material("steel"))
	_lamp = VehicleVisualParts.box(self, Vector3(0.1, 0.08, 0.1), Vector3(0.18, 0.4, 0), VehicleVisualParts.material("beacon"))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_lamp.visible = fmod(_age, 0.5) < 0.15 + 0.2 * clampf(_age / life_s, 0.0, 1.0)
	if _age >= life_s:
		detonate()


func detonate() -> void:
	if _done:
		return
	_done = true
	var src: Node = owner_vehicle if is_instance_valid(owner_vehicle) else null
	Projectile.splash(get_parent(), global_position, radius, damage, impulse, src)
	Effects.explosion(get_parent(), global_position, 0.9)
	GameAudio.play_at("explosion", global_position, 1.0, 0.9)
	queue_free()
