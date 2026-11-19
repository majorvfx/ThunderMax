class_name VehicleFactory
extends RefCounted
## Builds a playable vehicle from its data file: body, collision, visual, gun, engine sound.


static func create(vehicle_id: String, driver: RefCounted, is_player: bool, with_visual: bool = true) -> ArcadeVehicle:
	var stats := GameData.load_vehicle(vehicle_id, is_player)
	if stats == null:
		push_error("VehicleFactory: unknown vehicle %s" % vehicle_id)
		return null
	var v := ArcadeVehicle.new()
	v.name = stats.display_name.replace(" ", "")
	v.setup(stats, driver, is_player)
	v.add_to_group("vehicles")
	v.add_to_group("targets")

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.75, 4.3)
	shape.shape = box
	shape.position = Vector3(0, 0.12, 0)
	v.add_child(shape)

	if with_visual:
		var visual := VehicleVisual.new()
		visual.name = "Visual"
		v.add_child(visual)
		visual.build(v, stats.paint)

	var gun := MachineGun.new()
	gun.name = "MachineGun"
	v.add_child(gun)
	gun.setup(v, GameData.weapon("machine_gun"))

	if with_visual:
		var engine := EngineSound.new()
		engine.name = "EngineSound"
		v.add_child(engine)
		engine.setup(v)
	return v
