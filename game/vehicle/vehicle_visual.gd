class_name VehicleVisual
extends Node3D
## Placeholder vehicle model built from boxes and cylinders in the rust-and-grit style.
## Swap for a real model later by setting "model" in the vehicle's JSON file.

var vehicle: ArcadeVehicle
var paint := "rust"
var _wheels: Array[Node3D] = []
var _wheel_spin := 0.0
var _smoke: CPUParticles3D
var _fire: CPUParticles3D
var _beacon: MeshInstance3D
var _beacon_time := 0.0


func build(v: ArcadeVehicle, paint_name: String) -> void:
	vehicle = v
	paint = paint_name
	if paint == "drone":
		_build_drone()
	else:
		_build_rustjaw()
	_build_wheels()
	_build_damage_fx()


func _process(delta: float) -> void:
	if vehicle == null:
		return
	_wheel_spin += vehicle.drive.speed / VehicleVisualParts.WHEEL_RADIUS * delta
	for i in _wheels.size():
		var w := _wheels[i]
		var off: Vector3 = vehicle.wheel_offsets[i]
		var y := off.y - vehicle.wheel_distance[i] + VehicleVisualParts.WHEEL_RADIUS
		w.position = Vector3(off.x * 1.12, lerpf(w.position.y, y, 0.6), off.z)
		var steer_angle := -vehicle.drive.steer * 0.45 if i < 2 else 0.0
		w.rotation = Vector3(0.0, steer_angle, 0.0)
		w.get_child(0).rotation.x = -_wheel_spin
	var hp := vehicle.health.fraction()
	_smoke.emitting = vehicle.is_alive() and hp < 0.5
	_fire.emitting = vehicle.is_alive() and hp < 0.25
	if _beacon != null:
		_beacon_time += delta
		_beacon.visible = fmod(_beacon_time, 0.9) < 0.45


func _build_rustjaw() -> void:
	var rust := VehicleVisualParts.material("rust")
	var steel := VehicleVisualParts.material("steel")
	var glass := VehicleVisualParts.material("glass")
	var P := VehicleVisualParts
	P.box(self, Vector3(1.9, 0.5, 4.2), Vector3(0, 0.0, 0), rust)              # lower body
	P.box(self, Vector3(1.8, 0.32, 1.5), Vector3(0, 0.38, -1.2), rust)         # hood
	P.box(self, Vector3(1.5, 0.5, 1.5), Vector3(0, 0.55, 0.3), glass)          # cabin glass
	P.box(self, Vector3(1.56, 0.08, 1.4), Vector3(0, 0.83, 0.3), rust)         # roof
	P.box(self, Vector3(1.8, 0.28, 1.0), Vector3(0, 0.36, 1.6), rust)          # trunk
	# Plow nose
	var plow := P.box(self, Vector3(2.3, 0.65, 0.18), Vector3(0, -0.02, -2.3), steel)
	plow.rotation_degrees.x = -22.0
	for x in [-0.8, -0.27, 0.27, 0.8]:
		var tooth := P.box(self, Vector3(0.14, 0.14, 0.4), Vector3(x, -0.28, -2.45), steel)
		tooth.rotation_degrees.x = -10.0
	# Roof cage
	for x in [-0.72, 0.72]:
		P.box(self, Vector3(0.07, 0.07, 1.8), Vector3(x, 0.92, 0.2), steel)
	for z in [-0.6, 0.2, 1.0]:
		P.box(self, Vector3(1.5, 0.07, 0.07), Vector3(0, 0.92, z), steel)
	# Twin guns on the hood
	for x in [-0.45, 0.45]:
		P.cylinder(self, 0.07, 1.0, Vector3(x, 0.62, -1.55), Vector3(90, 0, 0), steel)
		P.box(self, Vector3(0.24, 0.16, 0.4), Vector3(x, 0.6, -1.1), steel)
	# Exhaust stacks
	for x in [-0.72, 0.72]:
		P.cylinder(self, 0.09, 0.9, Vector3(x, 0.75, 1.15), Vector3(0, 0, 0), steel)
	# Lights
	for x in [-0.62, 0.62]:
		P.box(self, Vector3(0.3, 0.14, 0.06), Vector3(x, 0.18, -2.11), VehicleVisualParts.material("headlight"))
		P.box(self, Vector3(0.35, 0.1, 0.06), Vector3(x, 0.25, 2.11), VehicleVisualParts.material("taillight"))


func _build_drone() -> void:
	var primer := VehicleVisualParts.material("primer")
	var steel := VehicleVisualParts.material("steel")
	var P := VehicleVisualParts
	P.box(self, Vector3(1.8, 0.55, 3.8), Vector3(0, 0.0, 0), primer)
	P.box(self, Vector3(1.6, 0.6, 2.0), Vector3(0, 0.55, 0.4), primer)
	P.box(self, Vector3(1.62, 0.3, 1.0), Vector3(0, 0.6, -0.3), VehicleVisualParts.material("glass"))
	P.box(self, Vector3(1.9, 0.25, 0.2), Vector3(0, -0.05, -1.95), steel)
	P.box(self, Vector3(1.9, 0.25, 0.2), Vector3(0, -0.05, 1.95), steel)
	P.box(self, Vector3(0.5, 0.3, 0.5), Vector3(0, 0.95, 0.6), steel)          # rig box on the roof
	P.cylinder(self, 0.03, 0.8, Vector3(0.5, 1.2, 1.0), Vector3(0, 0, 0), steel)  # antenna
	_beacon = P.box(self, Vector3(0.22, 0.16, 0.22), Vector3(0, 1.18, 0.6), VehicleVisualParts.material("beacon"))
	for x in [-0.6, 0.6]:
		P.box(self, Vector3(0.25, 0.1, 0.06), Vector3(x, 0.12, -1.91), VehicleVisualParts.material("headlight"))


func _build_wheels() -> void:
	var tire := VehicleVisualParts.material("tire")
	var steel := VehicleVisualParts.material("steel")
	for i in 4:
		var pivot := Node3D.new()
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		VehicleVisualParts.cylinder(spin, VehicleVisualParts.WHEEL_RADIUS, 0.36, Vector3.ZERO, Vector3(0, 0, 90), tire)
		VehicleVisualParts.box(spin, Vector3(0.38, 0.5, 0.12), Vector3.ZERO, steel)
		pivot.position = vehicle.wheel_offsets[i]
		_wheels.append(pivot)


func _build_damage_fx() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.amount = 14
	_smoke.lifetime = 1.4
	_smoke.emitting = false
	_smoke.position = Vector3(0, 0.6, -1.3)
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 1.5
	_smoke.initial_velocity_max = 3.0
	_smoke.gravity = Vector3(0, 1.0, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var sq := QuadMesh.new()
	sq.size = Vector2(1.2, 1.2)
	sq.material = VehicleVisualParts.material("smoke_puff")
	_smoke.mesh = sq
	_smoke.color_ramp = Effects._ramp([Color(0.2, 0.2, 0.2, 0.0), Color(0.15, 0.15, 0.15, 0.7), Color(0.1, 0.1, 0.1, 0.0)])
	add_child(_smoke)

	_fire = CPUParticles3D.new()
	_fire.amount = 12
	_fire.lifetime = 0.5
	_fire.emitting = false
	_fire.position = Vector3(0, 0.55, -1.2)
	_fire.direction = Vector3.UP
	_fire.spread = 15.0
	_fire.initial_velocity_min = 1.5
	_fire.initial_velocity_max = 3.0
	_fire.gravity = Vector3(0, 2.0, 0)
	_fire.scale_amount_min = 0.5
	_fire.scale_amount_max = 1.0
	var fq := QuadMesh.new()
	fq.size = Vector2(0.7, 0.7)
	fq.material = VehicleVisualParts.material("flame")
	_fire.mesh = fq
	_fire.color_ramp = Effects._ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.1, 0.8), Color(0.3, 0.05, 0.0, 0.0)])
	add_child(_fire)
