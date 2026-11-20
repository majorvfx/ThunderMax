class_name Effects
extends RefCounted
## Placeholder visual effects built from simple particles and meshes.
## CPU particles are used so the same effects run on the Mobile renderer,
## the OpenGL fallback and iPad.

static var _mats := {}


static func _particle_material(key: String, color: Color, emission: float) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	return g


static func _burst(parent: Node, pos: Vector3, amount: int, lifetime: float, mat: StandardMaterial3D, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	p.mesh = q
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	var tree := parent.get_tree()
	if tree != null:
		tree.create_timer(lifetime + 0.5, false).timeout.connect(p.queue_free)
	return p


## Fireball, smoke, debris and a flash of light.
static func explosion(parent: Node, pos: Vector3, scale: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fire := _burst(parent, pos, 28, 0.8, _particle_material("fire", Color(1.0, 0.6, 0.2), 3.0), 1.6 * scale)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.8 * scale
	fire.direction = Vector3.UP
	fire.spread = 180.0
	fire.initial_velocity_min = 3.0 * scale
	fire.initial_velocity_max = 9.0 * scale
	fire.gravity = Vector3(0, 3, 0)
	fire.damping_min = 4.0
	fire.damping_max = 6.0
	fire.scale_amount_min = 0.8
	fire.scale_amount_max = 1.8
	fire.color_ramp = _ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.9), Color(0.5, 0.1, 0.02, 0.6), Color(0.1, 0.05, 0.03, 0)])

	var smoke := _burst(parent, pos + Vector3.UP, 18, 2.4, _particle_material("smoke", Color(0.12, 0.11, 0.1), 0.0), 2.6 * scale)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.0 * scale
	smoke.explosiveness = 0.7
	smoke.direction = Vector3.UP
	smoke.spread = 60.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 4.0
	smoke.gravity = Vector3(0, 1.5, 0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.2
	smoke.color_ramp = _ramp([Color(0.2, 0.18, 0.16, 0.0), Color(0.15, 0.14, 0.13, 0.8), Color(0.08, 0.08, 0.08, 0.0)])

	var debris := _burst(parent, pos, 14, 1.6, _particle_material("debris", Color(0.25, 0.2, 0.17), 0.0), 0.35)
	debris.direction = Vector3.UP
	debris.spread = 75.0
	debris.initial_velocity_min = 6.0
	debris.initial_velocity_max = 14.0
	debris.gravity = Vector3(0, -20, 0)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 10.0
	light.omni_range = 16.0 * scale
	light.position = pos + Vector3.UP
	parent.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	tw.tween_callback(light.queue_free)


static func sparks(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _burst(parent, pos, 6, 0.3, _particle_material("spark", Color(1.0, 0.8, 0.4), 4.0), 0.12)
	p.direction = normal
	p.spread = 50.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -12, 0)


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.2:
		return
	if not _mats.has("tracer"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.85, 0.5)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.3)
		m.emission_energy_multiplier = 4.0
		_mats["tracer"] = m
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, length)
	box.material = _mats["tracer"]
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mid := (from + to) * 0.5
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	mi.global_transform = Transform3D(Basis.looking_at(dir, up), mid)
	parent.get_tree().create_timer(0.05, false).timeout.connect(mi.queue_free)


## Pale burst of frost where a Cold Snap round lands.
static func frost_burst(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _burst(parent, pos, 18, 0.6, _particle_material("frost", Color(0.7, 0.9, 1.0), 2.0), 0.5)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6, 0)
	p.color_ramp = _ramp([Color(0.9, 0.97, 1.0, 1.0), Color(0.5, 0.8, 1.0, 0.0)])


## Black smog cloud for Blackout.
static func smog_burst(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _burst(parent, pos + Vector3.UP * 0.6, 22, 1.4, _particle_material("smoke", Color(0.12, 0.11, 0.1), 0.0), 1.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.4
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = _ramp([Color(0.16, 0.15, 0.14, 0.6), Color(0.2, 0.19, 0.18, 0.35), Color(0.25, 0.24, 0.22, 0.0)])


## Dead Weight: a ring of dust and grit that races out across the ground.
static func shockwave(parent: Node, pos: Vector3, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.55, 0.45, 0.35, 0.7)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	torus.material = mat
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = pos + Vector3.UP * 0.3
	ring.scale = Vector3(0.5, 0.6, 0.5)
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.4, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)

	var dust := _burst(parent, pos + Vector3.UP * 0.3, 30, 1.2, _particle_material("smoke", Color(0.12, 0.11, 0.1), 0.0), 1.6)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = 1.5
	dust.emission_ring_inner_radius = 1.0
	dust.emission_ring_height = 0.2
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 180.0
	dust.flatness = 0.85
	dust.initial_velocity_min = radius * 0.8
	dust.initial_velocity_max = radius * 1.3
	dust.damping_min = radius * 0.8
	dust.damping_max = radius * 1.2
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.8
	dust.color_ramp = _ramp([Color(0.45, 0.38, 0.3, 0.8), Color(0.3, 0.26, 0.22, 0.5), Color(0.2, 0.18, 0.16, 0.0)])
	sparks(parent, pos, Vector3.UP)
