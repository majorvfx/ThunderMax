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
var _shield_shell: MeshInstance3D
var _ice_shell: MeshInstance3D
var _shell_time := 0.0
var _ghost_shell: MeshInstance3D
var _cloaked := false
var _body_parts: Array[Node3D] = []
# Rocket turbo: nozzles on the back bumper and the flames that come out of them.
var _nozzles: Array[Vector3] = []
var _flames: Array[Node3D] = []
var _flame_fire: Array[CPUParticles3D] = []
var _flame_light: OmniLight3D
var _flame_level := 0.0
var _flare_time := 0.0
var _was_boosting := false


func build(v: ArcadeVehicle, paint_name: String) -> void:
	vehicle = v
	paint = paint_name
	if paint == "drone":
		_build_drone()
	else:
		_build_rustjaw()
	_build_wheels()
	_build_damage_fx()
	for c in get_children():
		if c is Node3D and not (c is CPUParticles3D):
			_body_parts.append(c)
	_build_status_shells()
	if not _nozzles.is_empty():
		_build_flames()


## Fires the rockets briefly without using turbo (Spring Jack's kick-off).
func flare(seconds: float) -> void:
	_flare_time = maxf(_flare_time, seconds)


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
	_fire.emitting = vehicle.is_alive() and (hp < 0.25 or vehicle.status.is_burning())
	_shell_time += delta
	var shielded := vehicle.status.is_shielded()
	_shield_shell.visible = shielded
	if shielded:
		# Flickers in its last second so you know it's about to drop.
		var t := vehicle.status.shield_time
		_shield_shell.visible = t > 1.0 or fmod(_shell_time, 0.16) < 0.1
		_shield_shell.rotation.y = sin(_shell_time * 3.0) * 0.05
	_ice_shell.visible = vehicle.status.is_frozen()
	# Blackout: the car itself disappears. Your own car leaves a faint dark ghost so you
	# can still drive; other cars leave only a heat shimmer you have to look hard for.
	# (Hiding parts works on every renderer; per-mesh fading doesn't on Compatibility.)
	var cloaked := vehicle.status.is_cloaked()
	if cloaked != _cloaked:
		_cloaked = cloaked
		for part in _body_parts:
			part.visible = not cloaked
	_ghost_shell.visible = cloaked
	if cloaked:
		var flicker := 0.85 + 0.15 * sin(_shell_time * 23.0)
		var mat := _ghost_shell.material_override as StandardMaterial3D
		mat.albedo_color.a = (0.32 if vehicle.is_player else 0.05) * flicker
	if _beacon != null:
		_beacon_time += delta
		_beacon.visible = not _cloaked and fmod(_beacon_time, 0.9) < 0.45
	if not _flames.is_empty():
		_update_flames(delta)


## Turbo flames: short and hot on the ground, longer in the air so a boosted jump
## looks like a little rocket. They flare up for a moment when the turbo lights.
func _update_flames(delta: float) -> void:
	_flare_time = maxf(0.0, _flare_time - delta)
	var boosting := vehicle.drive.boosting
	var on := vehicle.is_alive() and not _cloaked and (boosting or _flare_time > 0.0)
	var target := 0.0
	if on:
		target = 1.0 if vehicle.grounded else 1.5
	if on and boosting and not _was_boosting:
		_flame_level = 2.0   # ignition flare
	_was_boosting = boosting
	_flame_level = move_toward(_flame_level, target, delta * (6.0 if target < _flame_level else 12.0))
	var lvl := _flame_level
	var shown := lvl > 0.03
	for f in _flames:
		f.visible = shown
		if shown:
			var flicker := randf_range(0.8, 1.15)
			var width := 0.75 + 0.25 * minf(lvl, 1.5)
			f.scale = Vector3(width, maxf(lvl * flicker, 0.05), width)
	for p in _flame_fire:
		p.emitting = on
	_flame_light.visible = shown
	if shown:
		_flame_light.light_energy = 2.2 * minf(lvl, 1.6) * randf_range(0.8, 1.2)


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
	# Rocket nozzles bolted under the back bumper (the turbo).
	for x in [-0.45, 0.45]:
		P.cylinder(self, 0.16, 0.34, Vector3(x, 0.0, 2.24), Vector3(90, 0, 0), steel)
		P.cylinder(self, 0.11, 0.04, Vector3(x, 0.0, 2.42), Vector3(90, 0, 0), VehicleVisualParts.material("soot"))
		_nozzles.append(Vector3(x, 0.0, 2.44))
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


func _build_flames() -> void:
	var outer_mat := _flame_material(Color(1.0, 0.4, 0.06, 0.7), 1.6)
	var core_mat := _flame_material(Color(1.0, 0.85, 0.5, 0.9), 2.5)
	for pos in _nozzles:
		# A pivot at the nozzle; its local +Y points out the back, so scaling Y
		# stretches the flame without moving its base.
		var pivot := Node3D.new()
		pivot.position = pos
		pivot.rotation_degrees.x = 90.0
		add_child(pivot)
		_flame_cone(pivot, 0.15, 1.1, outer_mat)
		_flame_cone(pivot, 0.08, 0.6, core_mat)
		pivot.visible = false
		_flames.append(pivot)
		# Fire and smoke left behind in the world, so the trail streams off the car.
		var fire := CPUParticles3D.new()
		fire.amount = 16
		fire.lifetime = 0.35
		fire.local_coords = false
		fire.emitting = false
		fire.position = pos + Vector3(0, 0, 0.3)
		fire.direction = Vector3(0, 0, 1)
		fire.spread = 10.0
		fire.initial_velocity_min = 4.0
		fire.initial_velocity_max = 8.0
		fire.gravity = Vector3(0, 1.5, 0)
		fire.scale_amount_min = 0.5
		fire.scale_amount_max = 1.0
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		q.material = _exhaust_puff_material()
		fire.mesh = q
		fire.color_ramp = Effects._ramp([Color(1, 0.8, 0.4, 0.9), Color(1, 0.38, 0.06, 0.6), Color(0.35, 0.12, 0.04, 0.25), Color(0.1, 0.08, 0.06, 0)])
		add_child(fire)
		_flame_fire.append(fire)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.5, 0.18)
	_flame_light.omni_range = 6.0
	_flame_light.position = Vector3(0, 0.2, _nozzles[0].z + 0.8)
	_flame_light.visible = false
	add_child(_flame_light)


func _flame_cone(pivot: Node3D, radius: float, length: float, mat: Material) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 10
	cone.rings = 1
	cone.cap_bottom = false
	cone.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position = Vector3(0, length * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)


## Soft round puff for the exhaust trail: additive, tinted by the particle colour.
static func _exhaust_puff_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	return m


static func _flame_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	return m


func _build_status_shells() -> void:
	# Bulwark: a cage of glowing welded plates around the car.
	var plate := StandardMaterial3D.new()
	plate.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate.albedo_color = Color(1.0, 0.55, 0.15, 0.28)
	plate.emission_enabled = true
	plate.emission = Color(1.0, 0.5, 0.12)
	plate.emission_energy_multiplier = 1.5
	plate.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_shell = VehicleVisualParts.box(self, Vector3(2.9, 1.9, 5.3), Vector3(0, 0.35, 0), plate)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(1.0, 0.7, 0.3)
	frame_mat.emission_enabled = true
	frame_mat.emission = Color(1.0, 0.6, 0.2)
	frame_mat.emission_energy_multiplier = 3.0
	for x in [-1.45, 1.45]:
		for z in [-2.65, 0.0, 2.65]:
			VehicleVisualParts.box(_shield_shell, Vector3(0.08, 1.9, 0.08), Vector3(x, 0, z), frame_mat)
	for z in [-2.65, 2.65]:
		VehicleVisualParts.box(_shield_shell, Vector3(2.9, 0.08, 0.08), Vector3(0, 0.95, z), frame_mat)
	_shield_shell.visible = false
	# Cold Snap: the car is caked in frost.
	var ice := StandardMaterial3D.new()
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color = Color(0.75, 0.9, 1.0, 0.55)
	ice.roughness = 0.1
	ice.metallic = 0.2
	ice.emission_enabled = true
	ice.emission = Color(0.5, 0.75, 1.0)
	ice.emission_energy_multiplier = 0.6
	_ice_shell = VehicleVisualParts.box(self, Vector3(2.2, 1.5, 4.6), Vector3(0, 0.3, 0), ice)
	_ice_shell.visible = false
	# Blackout: a dark, barely-there ghost of the car's shape.
	var ghost := StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = Color(0.06, 0.06, 0.07, 0.3)
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_shell = VehicleVisualParts.box(self, Vector3(2.0, 1.2, 4.4), Vector3(0, 0.25, 0), ghost)
	_ghost_shell.material_override = ghost
	_ghost_shell.visible = false
