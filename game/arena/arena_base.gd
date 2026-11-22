class_name ArenaBase
extends Node3D
## Shared base for every arena: the spawn and route data a match needs, the
## block / ramp / container helpers arenas are built from, sky and fog setup,
## and surface zones (ice, mud) that change how cars drive.
##
## An arena fills in spawn_points, player_spawn, drone_routes, barrel_spots and
## pickup_spots() in its _ready().

var display_name := "ARENA"
var tagline := ""
var spawn_points: Array[Transform3D] = []
var player_spawn := Transform3D()
var drone_routes: Array = []   ## Array of Array[Vector3]
var barrel_spots: Array[Vector3] = []
var environment: Environment
var sun: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
## Surface zones on the ground: [Rect2 on X/Z, "ice" or "mud"].
var surface_zones: Array = []

var _container_mats: Array[StandardMaterial3D] = []
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	add_to_group("arena")


## Pickup positions: [kind, position]
func pickup_spots() -> Array:
	return []


## What the ground is like at `pos`: "", "ice" or "mud".
func surface_at(pos: Vector3) -> String:
	for z in surface_zones:
		if (z[0] as Rect2).has_point(Vector2(pos.x, pos.z)):
			return z[1]
	return ""


## Nearest spawn point that has no vehicle close by.
func safe_spawn(avoid: Array) -> Transform3D:
	var best := spawn_points[0]
	var best_score := -1.0
	for sp in spawn_points:
		var nearest := 999.0
		for n in avoid:
			if n is Node3D and n.is_inside_tree():
				nearest = minf(nearest, (n as Node3D).global_position.distance_to(sp.origin))
		if nearest > best_score:
			best_score = nearest
			best = sp
	return best


# --- Materials and environment ------------------------------------------------

static func surface_material(color: Color, seed_value: int, contrast: float, uv: float, metallic: float = 0.0, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = VehicleVisualParts.grime_texture(seed_value, contrast)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(uv, uv, uv)
	m.metallic = metallic
	m.roughness = roughness
	return m


static func glow_material(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _make_container_mats(colors: Array) -> void:
	for c in colors:
		var m := surface_material(c, 17 + _container_mats.size(), 0.55, 0.15, 0.45, 0.8)
		_container_mats.append(m)


## Sky, fog, grading and a low sun. `p` keys: sky_top, horizon, ground, fog, fog_density,
## sun_color, sun_energy, sun_rot, ambient, exposure, saturation.
func _make_environment(p: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = p.get("sky_top", Color(0.07, 0.06, 0.06))
	sky_mat.sky_horizon_color = p.get("horizon", Color(0.32, 0.18, 0.1))
	sky_mat.ground_horizon_color = p.get("ground", Color(0.2, 0.12, 0.08))
	sky_mat.ground_bottom_color = Color(0.04, 0.03, 0.03)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = p.get("ambient", 0.6)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = p.get("exposure", 1.1)
	environment.fog_enabled = true
	environment.fog_light_color = p.get("fog", Color(0.3, 0.2, 0.14))
	environment.fog_density = p.get("fog_density", 0.008)
	environment.fog_sky_affect = 0.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.adjustment_enabled = true
	environment.adjustment_saturation = p.get("saturation", 0.8)
	environment.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = p.get("sun_color", Color(1.0, 0.72, 0.5))
	sun.light_energy = p.get("sun_energy", 0.9)
	sun.rotation_degrees = p.get("sun_rot", Vector3(-38, -35, 0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# --- Geometry helpers ------------------------------------------------------------

func _block(size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = ArcadeVehicle.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	VehicleVisualParts.box(body, size, Vector3.ZERO, mat)
	add_child(body)
	return body


## A solid upright cylinder (tanks, stacks, pilings, tree trunks).
func _pillar(radius: float, height: float, base: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = ArcadeVehicle.LAYER_WORLD
	body.collision_mask = 0
	body.position = base + Vector3(0, height * 0.5, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	VehicleVisualParts.cylinder(body, radius, height, Vector3.ZERO, Vector3.ZERO, mat)
	add_child(body)
	return body


## A ramp whose top surface runs from `bottom` (on the ground) to `top`.
func _ramp(bottom: Vector3, top: Vector3, width: float, mat: Material) -> StaticBody3D:
	var thickness := 1.0
	var dir := top - bottom
	var zz := -dir.normalized()
	var xx := Vector3.UP.cross(zz).normalized()
	var yy := zz.cross(xx).normalized()
	var basis := Basis(xx, yy, zz)
	var center := (bottom + top) * 0.5 - yy * thickness * 0.5
	var size := Vector3(width, thickness, dir.length())
	var body := StaticBody3D.new()
	body.collision_layer = ArcadeVehicle.LAYER_WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, center)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	VehicleVisualParts.box(body, size, Vector3.ZERO, mat)
	add_child(body)
	return body


func _container(pos: Vector3, along_z: bool, length: float = 12.0, yaw_deg: float = 0.0) -> void:
	var size := Vector3(2.6, 2.6, length) if along_z else Vector3(length, 2.6, 2.6)
	_block(size, pos + Vector3(0, 1.3, 0), _container_mats[_rng.randi() % _container_mats.size()], Vector3(0, yaw_deg, 0))


## A square yard: floor plus four walls `height` high, inner half-size `half`.
func _walled_floor(half: float, height: float, floor_mat: Material, wall_mat: Material) -> void:
	_block(Vector3(half * 2.0 + 20.0, 1.0, half * 2.0 + 20.0), Vector3(0, -0.5, 0), floor_mat)
	var t := 2.0
	_block(Vector3(half * 2.0 + t * 2.0, height, t), Vector3(0, height * 0.5, -half - t * 0.5), wall_mat)
	_block(Vector3(half * 2.0 + t * 2.0, height, t), Vector3(0, height * 0.5, half + t * 0.5), wall_mat)
	_block(Vector3(t, height, half * 2.0), Vector3(-half - t * 0.5, height * 0.5, 0), wall_mat)
	_block(Vector3(t, height, half * 2.0), Vector3(half + t * 0.5, height * 0.5, 0), wall_mat)


## A flat patch drawn on the floor (ice sheet, mud), slightly above it, no collision.
func _floor_patch(rect: Rect2, mat: Material, kind: String) -> void:
	var mi := VehicleVisualParts.box(self, Vector3(rect.size.x, 0.04, rect.size.y), Vector3(rect.get_center().x, 0.02, rect.get_center().y), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface_zones.append([rect, kind])


## A lamp post with a light on top.
func _lamp_post(p: Vector3, color: Color, height: float = 9.0, energy: float = 2.2, post_mat: Material = null) -> OmniLight3D:
	if post_mat != null:
		_block(Vector3(0.4, height, 0.4), p + Vector3(0, height * 0.5, 0), post_mat)
	VehicleVisualParts.box(self, Vector3(1.2, 0.25, 0.6), p + Vector3(0, height + 0.1, 0), glow_material(color, 3.0))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 22.0
	light.position = p + Vector3(0, height - 0.4, 0)
	add_child(light)
	lamps.append(light)
	return light


## Rising smoke from a stack or a fire.
func _smoke_column(at: Vector3, size: float = 3.0, color: Color = Color(0.08, 0.07, 0.07, 0.6)) -> void:
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 6.0
	smoke.position = at
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(1.2, 0.4, 0.3)
	smoke.scale_amount_min = size * 0.66
	smoke.scale_amount_max = size * 1.33
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = VehicleVisualParts.material("smoke_puff")
	smoke.mesh = q
	smoke.color_ramp = Effects._ramp([Color(color, 0.0), color, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.0)])
	add_child(smoke)


## A standing flame (flare stack tip, burning barrel) with its light.
func _flame(at: Vector3, size: float = 1.0) -> void:
	var f := CPUParticles3D.new()
	f.amount = 24
	f.lifetime = 0.7
	f.position = at
	f.direction = Vector3.UP
	f.spread = 12.0
	f.initial_velocity_min = 2.0 * size
	f.initial_velocity_max = 4.0 * size
	f.gravity = Vector3(0, 2, 0)
	f.scale_amount_min = 0.8 * size
	f.scale_amount_max = 1.6 * size
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2) * size
	q.material = VehicleVisualParts.material("flame")
	f.mesh = q
	f.color_ramp = Effects._ramp([Color(1, 0.85, 0.4, 1), Color(1, 0.35, 0.05, 0.8), Color(0.2, 0.05, 0.0, 0.0)])
	add_child(f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 2.5 * size
	light.omni_range = 14.0 * size
	light.position = at + Vector3.UP
	add_child(light)
	lamps.append(light)


## Standard drone routes: a lap near the walls each way, and an inner loop.
func _ring_routes(outer: float, inner: float) -> void:
	var ring: Array[Vector3] = [
		Vector3(-outer, 0, -outer), Vector3(0, 0, -outer - 4), Vector3(outer, 0, -outer), Vector3(outer + 4, 0, 0),
		Vector3(outer, 0, outer), Vector3(0, 0, outer + 6), Vector3(-outer, 0, outer), Vector3(-outer - 4, 0, 0),
	]
	var ring_reverse: Array[Vector3] = ring.duplicate()
	ring_reverse.reverse()
	var inner_loop: Array[Vector3] = [Vector3(-inner, 0, -inner), Vector3(inner, 0, -inner), Vector3(inner, 0, inner), Vector3(-inner, 0, inner)]
	drone_routes = [ring, ring_reverse, inner_loop]


func _four_spawns(d: float) -> void:
	player_spawn = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, d))
	spawn_points = [
		player_spawn,
		Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.2, -d)),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(d, 1.2, 0)),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-d, 1.2, 0)),
	]
