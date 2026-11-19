class_name ExplosiveBarrel
extends RigidBody3D
## Fuel drum. Shoot it or hit it hard and it goes up, hurting and shoving anything nearby.

signal exploded(barrel: ExplosiveBarrel)

var hit_points := 6.0
var radius := 8.0
var max_damage := 30.0
var impulse := 9000.0
var _done := false


func _ready() -> void:
	var cfg := GameData.weapon("barrel_explosion")
	radius = float(cfg.get("radius", radius))
	max_damage = float(cfg.get("damage", max_damage))
	impulse = float(cfg.get("impulse", impulse))
	mass = 90.0
	collision_layer = ArcadeVehicle.LAYER_PROPS
	collision_mask = ArcadeVehicle.LAYER_WORLD | ArcadeVehicle.LAYER_VEHICLES | ArcadeVehicle.LAYER_PROPS
	contact_monitor = true
	max_contacts_reported = 2
	add_to_group("targets")
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 1.2
	shape.shape = cyl
	add_child(shape)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.12, 0.06)
	m.albedo_texture = VehicleVisualParts.grime_texture(71, 0.6)
	m.metallic = 0.5
	m.roughness = 0.7
	var mi := VehicleVisualParts.cylinder(self, 0.45, 1.2, Vector3.ZERO, Vector3.ZERO, m)
	mi.name = "Drum"
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.85, 0.65, 0.1)
	band.roughness = 0.8
	VehicleVisualParts.cylinder(self, 0.46, 0.12, Vector3(0, 0.25, 0), Vector3.ZERO, band)
	body_entered.connect(_on_body_entered)


func is_alive() -> bool:
	return not _done


func take_damage(amount: float, source: Node) -> void:
	if _done:
		return
	hit_points -= amount
	if hit_points <= 0.0:
		explode(source)


func _on_body_entered(body: Node) -> void:
	if body is ArcadeVehicle and (body as ArcadeVehicle).linear_velocity.length() > 14.0:
		explode.call_deferred(body)


func explode(source: Node) -> void:
	if _done:
		return
	_done = true
	var pos := global_position
	var world := get_parent()
	Effects.explosion(world, pos, 0.8)
	GameAudio.play_at("explosion", pos, 0.9, 1.15)
	for node in get_tree().get_nodes_in_group("vehicles"):
		var v := node as ArcadeVehicle
		if v == null or not v.is_alive():
			continue
		var d := v.global_position.distance_to(pos)
		var dmg := CombatRules.splash_damage(d, radius, max_damage)
		if dmg > 0.0:
			v.take_damage(dmg, source)
			var push := (v.global_position - pos + Vector3.UP * 1.5).normalized()
			v.apply_central_impulse(push * impulse * (1.0 - d / radius))
	for node in get_tree().get_nodes_in_group("targets"):
		if node is ExplosiveBarrel and node != self and node.is_alive():
			var bd := (node as Node3D).global_position.distance_to(pos)
			if bd < radius * 0.6:
				node.take_damage.call_deferred(100.0, source)
	exploded.emit(self)
	queue_free()
