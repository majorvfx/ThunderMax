class_name VehicleVisualParts
extends RefCounted
## Shared placeholder materials and mesh helpers (rust, steel, concrete, glass...).

const WHEEL_RADIUS := 0.42

static var _materials := {}


static func material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"rust":
			m.albedo_color = Color(0.42, 0.2, 0.1)
			m.albedo_texture = grime_texture(11, 0.55)
			m.metallic = 0.35
			m.roughness = 0.85
		"steel":
			m.albedo_color = Color(0.26, 0.26, 0.27)
			m.albedo_texture = grime_texture(23, 0.35)
			m.metallic = 0.7
			m.roughness = 0.55
		"primer":
			m.albedo_color = Color(0.3, 0.32, 0.27)
			m.albedo_texture = grime_texture(37, 0.5)
			m.metallic = 0.2
			m.roughness = 0.9
		"glass":
			m.albedo_color = Color(0.05, 0.06, 0.07)
			m.metallic = 0.6
			m.roughness = 0.15
		"tire":
			m.albedo_color = Color(0.06, 0.06, 0.06)
			m.roughness = 0.95
		"headlight":
			m.albedo_color = Color(1.0, 0.85, 0.55)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.45)
			m.emission_energy_multiplier = 3.0
		"taillight":
			m.albedo_color = Color(0.6, 0.02, 0.02)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.05, 0.02)
			m.emission_energy_multiplier = 2.0
		"beacon":
			m.albedo_color = Color(1.0, 0.1, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.05)
			m.emission_energy_multiplier = 5.0
		"smoke_puff":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
		"flame":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			m.emission_enabled = true
			m.emission = Color(1.0, 0.5, 0.15)
			m.emission_energy_multiplier = 3.0
	_materials[kind] = m
	return m


## Tileable noise used to break up flat colours with rust and grime.
static func grime_texture(seed_value: int, contrast: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var low := 1.0 - contrast
	g.colors = PackedColorArray([Color(low, low * 0.92, low * 0.85), Color(1, 1, 1)])
	tex.color_ramp = g
	return tex


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	c.material = mat
	mi.mesh = c
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi
