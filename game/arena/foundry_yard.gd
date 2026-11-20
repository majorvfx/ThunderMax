class_name FoundryYard
extends Node3D
## Milestone 1 test arena: "The Foundry Yard", a dead steelworks walled in with
## scrap, under a magenta dusk and the neon nobody switched off (see Neon).
## Built in code from placeholder blocks so layout changes are quick; it will be
## rebuilt as an authored scene with real art later.
##
## Layout (top view, north = -Z): a 160 m square yard. A raised furnace deck
## in the middle with ramps north and south, container cover east and west, a
## kicker ramp in the east lane, and a hidden pocket in the north-west corner.

const HALF := 80.0
const WALL_HEIGHT := 7.0

var spawn_points: Array[Transform3D] = []
var player_spawn := Transform3D()
var drone_routes: Array = []   ## Array of Array[Vector3]
var barrel_spots: Array[Vector3] = []
var environment: Environment
var sun: DirectionalLight3D
var lamps: Array[OmniLight3D] = []

var _concrete: StandardMaterial3D
var _wall: StandardMaterial3D
var _steel: StandardMaterial3D
var _container_mats: Array[StandardMaterial3D] = []
var _flicker: OmniLight3D
var _flicker_tube: MeshInstance3D
var _flicker_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1977
	_make_materials()
	_build_environment()
	_build_ground_and_walls()
	_build_furnace_deck()
	_build_cover()
	_build_kicker()
	_build_hidden_pocket()
	_build_lamps()
	_build_signs()
	_define_routes_and_spawns()


func _process(delta: float) -> void:
	# One failing neon lamp, for unease.
	if _flicker == null:
		return
	_flicker_time -= delta
	if _flicker_time <= 0.0:
		var on := _rng.randf() >= 0.35
		_flicker.light_energy = _rng.randf_range(1.5, 3.0) if on else 0.0
		if _flicker_tube != null:
			_flicker_tube.visible = on
		_flicker_time = _rng.randf_range(0.04, 0.5)


# --- Materials and environment ------------------------------------------------

func _make_materials() -> void:
	# Cracked asphalt with a failing neon grid set into it, one tile per 8 m.
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.2, 0.18, 0.22)
	_concrete.albedo_texture = VehicleVisualParts.grime_texture(5, 0.5)
	_concrete.uv1_triplanar = true
	_concrete.uv1_scale = Vector3(0.125, 0.125, 0.125)
	_concrete.roughness = 0.85
	_concrete.emission_enabled = true
	_concrete.emission = Neon.CYAN
	_concrete.emission_energy_multiplier = 1.6
	_concrete.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # only the lines glow
	_concrete.emission_texture = _grid_texture()

	_wall = StandardMaterial3D.new()
	_wall.albedo_color = Color(0.26, 0.14, 0.1)
	_wall.albedo_texture = VehicleVisualParts.grime_texture(9, 0.6)
	_wall.uv1_triplanar = true
	_wall.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_wall.metallic = 0.4
	_wall.roughness = 0.85

	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.2, 0.2, 0.25)
	_steel.albedo_texture = VehicleVisualParts.grime_texture(13, 0.4)
	_steel.uv1_triplanar = true
	_steel.uv1_scale = Vector3(0.2, 0.2, 0.2)
	_steel.metallic = 0.7
	_steel.roughness = 0.6

	for c in [Color(0.32, 0.08, 0.16), Color(0.08, 0.2, 0.24), Color(0.3, 0.22, 0.1), Color(0.16, 0.13, 0.26)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.albedo_texture = VehicleVisualParts.grime_texture(17 + _container_mats.size(), 0.55)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.15, 0.15, 0.15)
		m.metallic = 0.45
		m.roughness = 0.8
		_container_mats.append(m)


## The floor grid: thin lines on the tile edges with gaps where sections have died.
func _grid_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	var dead_x := []
	var dead_y := []
	for run in n / 16:
		dead_x.append(rng.randf() < 0.2)
		dead_y.append(rng.randf() < 0.2)
	for i in n:
		# Each 16-pixel run of line is either lit or dead.
		var lit_x: bool = not dead_x[i / 16]
		var lit_y: bool = not dead_y[i / 16]
		for w in 2:
			if lit_x:
				img.set_pixel(i, w, Color.WHITE)
			if lit_y:
				img.set_pixel(w, i, Color.WHITE)
	img.generate_mipmaps()   # lines fade into the distance instead of shimmering
	return ImageTexture.create_from_image(img)


func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = Neon.sky_material()

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.3, 0.6)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.32, 0.12, 0.38)
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.1
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.15
	environment.adjustment_contrast = 1.12

	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	# Low dusk sun from the north, where the banded sun sits in the sky.
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.5, 0.62)
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-24, 160, 0)
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


# --- Layout ----------------------------------------------------------------------

func _build_ground_and_walls() -> void:
	_block(Vector3(HALF * 2.0 + 20.0, 1.0, HALF * 2.0 + 20.0), Vector3(0, -0.5, 0), _concrete)
	var t := 2.0
	_block(Vector3(HALF * 2.0 + t * 2.0, WALL_HEIGHT, t), Vector3(0, WALL_HEIGHT * 0.5, -HALF - t * 0.5), _wall)
	_block(Vector3(HALF * 2.0 + t * 2.0, WALL_HEIGHT, t), Vector3(0, WALL_HEIGHT * 0.5, HALF + t * 0.5), _wall)
	_block(Vector3(t, WALL_HEIGHT, HALF * 2.0), Vector3(-HALF - t * 0.5, WALL_HEIGHT * 0.5, 0), _wall)
	_block(Vector3(t, WALL_HEIGHT, HALF * 2.0), Vector3(HALF + t * 0.5, WALL_HEIGHT * 0.5, 0), _wall)
	# Buttresses along the walls break up the long flat runs; each wears a neon cap.
	for i in range(-3, 4):
		var p := float(i) * 22.0
		for at in [Vector3(p, 0, -HALF + 0.3), Vector3(p, 0, HALF - 0.3), Vector3(-HALF + 0.3, 0, p), Vector3(HALF - 0.3, 0, p)]:
			_block(Vector3(1.5, WALL_HEIGHT + 1.5, 1.5), at + Vector3(0, (WALL_HEIGHT + 1.5) * 0.5, 0), _steel)
			Neon.strip(self, at + Vector3(-0.8, WALL_HEIGHT + 1.55, 0), at + Vector3(0.8, WALL_HEIGHT + 1.55, 0), Neon.MAGENTA, 0.12, 4.0)
	# A neon tube along the inside top of every wall, and a dimmer one at bumper height.
	var walls := [
		[Vector3(-HALF, 0, -HALF + 0.05), Vector3(HALF, 0, -HALF + 0.05), Neon.MAGENTA],
		[Vector3(-HALF, 0, HALF - 0.05), Vector3(HALF, 0, HALF - 0.05), Neon.CYAN],
		[Vector3(-HALF + 0.05, 0, -HALF), Vector3(-HALF + 0.05, 0, HALF), Neon.VIOLET],
		[Vector3(HALF - 0.05, 0, -HALF), Vector3(HALF - 0.05, 0, HALF), Neon.CYAN],
	]
	for w in walls:
		Neon.strip(self, w[0] + Vector3.UP * (WALL_HEIGHT - 0.4), w[1] + Vector3.UP * (WALL_HEIGHT - 0.4), w[2], 0.12, 3.5)
		Neon.strip(self, w[0] + Vector3.UP * 1.2, w[1] + Vector3.UP * 1.2, w[2], 0.06, 1.5)


func _build_furnace_deck() -> void:
	# Raised deck, 24 x 24 m, 3 m high, with ramps north and south.
	_block(Vector3(24, 3, 24), Vector3(0, 1.5, 0), _concrete)
	_ramp(Vector3(0, 0, -28), Vector3(0, 3, -12), 10.0, _steel)
	_ramp(Vector3(0, 0, 28), Vector3(0, 3, 12), 10.0, _steel)
	# The furnace stack: the Yard's landmark, still glowing.
	var stack := StaticBody3D.new()
	stack.collision_layer = ArcadeVehicle.LAYER_WORLD
	stack.position = Vector3(0, 3 + 9, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.0
	cyl.height = 18.0
	cs.shape = cyl
	stack.add_child(cs)
	VehicleVisualParts.cylinder(stack, 3.0, 18.0, Vector3.ZERO, Vector3.ZERO, _wall)
	add_child(stack)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.4, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.08)
	glow.emission_energy_multiplier = 4.0
	for a in [0.0, 90.0, 180.0, 270.0]:
		var vent := VehicleVisualParts.box(stack, Vector3(1.6, 0.9, 0.2), Vector3(0, -7.5, 0), glow)
		vent.rotation_degrees.y = a
		vent.position = Vector3(sin(deg_to_rad(a)) * 3.02, -7.5, cos(deg_to_rad(a)) * 3.02)
	for h in [-3.0, 2.0, 7.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 3.02
		torus.outer_radius = 3.18
		torus.rings = 32
		torus.ring_segments = 4
		torus.material = Neon.tube(Neon.CYAN, 3.0)
		ring.mesh = torus
		ring.position = Vector3(0, h, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stack.add_child(ring)
	for z in [-1.0, 1.0]:
		for x in [-5.05, 5.05]:
			Neon.strip(self, Vector3(x, 0.15, z * 28.0), Vector3(x, 3.15, z * 12.0), Neon.CYAN, 0.1, 3.0)
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.45, 0.15)
	fire_light.light_energy = 3.0
	fire_light.omni_range = 18.0
	fire_light.position = Vector3(0, 4.5, 0)
	add_child(fire_light)
	lamps.append(fire_light)
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 6.0
	smoke.position = Vector3(0, 21.5, 0)
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(1.2, 0.4, 0.3)
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(3, 3)
	q.material = VehicleVisualParts.material("smoke_puff")
	smoke.mesh = q
	smoke.color_ramp = Effects._ramp([Color(0.1, 0.09, 0.08, 0.0), Color(0.08, 0.07, 0.07, 0.6), Color(0.05, 0.05, 0.05, 0.0)])
	add_child(smoke)
	# Guard rails on the deck edges beside the ramps.
	for z in [-11.6, 11.6]:
		_block(Vector3(7, 0.6, 0.3), Vector3(-8.5, 3.3, z), _steel)
		_block(Vector3(7, 0.6, 0.3), Vector3(8.5, 3.3, z), _steel)


func _build_cover() -> void:
	_container(Vector3(-45, 0, -20), true)
	_container(Vector3(-45, 0, 20), true)
	_container(Vector3(45, 0, -25), true)
	_container(Vector3(45, 2.6, -25), true, 9.0)
	_container(Vector3(45, 0, 22), true)
	_container(Vector3(-20, 0, -50), false)
	_container(Vector3(25, 0, -40), false, 12.0, 30.0)
	_container(Vector3(-25, 0, 52), false)
	_container(Vector3(20, 0, 48), false)
	# Wrecked car husks as low cover.
	for p in [Vector3(-48, 0, -40), Vector3(48, 0, 40), Vector3(-8, 0, -24)]:
		_block(Vector3(1.9, 1.1, 4.2), p + Vector3(0, 0.55, 0), _container_mats[0], Vector3(0, _rng.randf_range(0, 180), 6))


func _build_kicker() -> void:
	# East-lane kicker: launches northbound cars over the lane.
	_ramp(Vector3(68, 0, 34), Vector3(68, 2.2, 25), 8.0, _steel)
	_block(Vector3(8, 2.2, 1.0), Vector3(68, 1.1, 24.5), _steel)
	for x in [64.05, 71.95]:
		Neon.strip(self, Vector3(x, 0.1, 34), Vector3(x, 2.3, 25), Neon.AMBER, 0.1, 3.5)
	Neon.strip(self, Vector3(64, 2.3, 24.95), Vector3(72, 2.3, 24.95), Neon.AMBER, 0.1, 3.5)


func _build_hidden_pocket() -> void:
	# North-west pocket behind a long container wall; the way in is a 4 m gap on its south side.
	_container(Vector3(-66, 0, -65), true, 26.0)
	_block(Vector3(8.5, 2.6, 2.6), Vector3(-75.75, 1.3, -50), _container_mats[1])


func _build_lamps() -> void:
	var spots := [Vector3(-38, 0, -71), Vector3(38, 0, -71), Vector3(-72, 0, 0), Vector3(73, 0, 10), Vector3(-38, 0, 71), Vector3(38, 0, 71)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		_block(Vector3(0.4, 9.0, 0.4), p + Vector3(0, 4.5, 0), _steel)
		var col: Color = Neon.MAGENTA if i % 2 == 0 else Neon.CYAN
		var tube := Neon.strip(self, p + Vector3(0.3, 3.0, 0.3), p + Vector3(0.3, 9.6, 0.3), col, 0.16, 4.0)
		VehicleVisualParts.box(self, Vector3(1.4, 0.18, 0.18), p + Vector3(0, 9.7, 0), Neon.tube(col, 4.0))
		var light := OmniLight3D.new()
		light.light_color = col.lerp(Color.WHITE, 0.25)
		light.light_energy = 2.4
		light.omni_range = 22.0
		light.position = p + Vector3(0, 8.6, 0)
		add_child(light)
		lamps.append(light)
		if i == 3:
			_flicker = light
			_flicker_tube = tube


## Neon signs on the walls. The Yard's management still advertises.
func _build_signs() -> void:
	var signs := [
		# Centred between buttresses (every 22 m) so none of them hides a letter.
		["FOUNDRY YARD", Vector3(11, 4.6, -HALF + 0.1), 0.0, Neon.MAGENTA, 170],
		["SALVAGE RIGHTS ENFORCED", Vector3(-HALF + 0.1, 4.2, -33), PI * 0.5, Neon.CYAN, 92],
		["NO REFUNDS  NO RETURNS", Vector3(HALF - 0.1, 4.2, 33), -PI * 0.5, Neon.AMBER, 92],
		["THE YARD PROVIDES", Vector3(-11, 4.2, HALF - 0.1), PI, Neon.VIOLET, 120],
	]
	for sg in signs:
		var l := Label3D.new()
		l.text = sg[0]
		l.font = Neon.display_font()
		l.font_size = sg[4]
		l.pixel_size = 0.012
		l.modulate = Color(sg[3].r * 2.2, sg[3].g * 2.2, sg[3].b * 2.2)
		l.outline_size = 18
		l.outline_modulate = Color(sg[3], 0.35)
		l.shaded = false
		l.double_sided = false
		l.position = sg[1]
		l.rotation.y = sg[2]
		add_child(l)


func _define_routes_and_spawns() -> void:
	player_spawn = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 50))
	var ring: Array[Vector3] = [
		Vector3(-58, 0, -58), Vector3(0, 0, -62), Vector3(58, 0, -58), Vector3(62, 0, 0),
		Vector3(58, 0, 58), Vector3(0, 0, 64), Vector3(-58, 0, 58), Vector3(-62, 0, 0),
	]
	var ring_reverse: Array[Vector3] = ring.duplicate()
	ring_reverse.reverse()
	var inner: Array[Vector3] = [Vector3(-32, 0, -34), Vector3(32, 0, -32), Vector3(34, 0, 30), Vector3(-34, 0, 32)]
	drone_routes = [ring, ring_reverse, inner]
	spawn_points = [
		player_spawn,
		Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.2, -50)),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(50, 1.2, 0)),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-50, 1.2, 0)),
	]
	barrel_spots = [
		Vector3(-22, 0.6, -20), Vector3(22, 0.6, -20), Vector3(-22, 0.6, 20), Vector3(22, 0.6, 20),
		Vector3(0, 0.6, -40), Vector3(70, 0.6, 70), Vector3(-72, 0.6, 40),
	]


## Pickup positions: [kind, position]
func pickup_spots() -> Array:
	return [
		["health", Vector3(0, 4.0, 7.5)],
		["health", Vector3(-60, 1.0, 0)],
		["health", Vector3(60, 1.0, -60)],
		["health", Vector3(-73, 1.0, -70)],   # hidden pocket
		["turbo", Vector3(0, 1.0, -45)],
		["turbo", Vector3(70, 1.0, 0)],
		["turbo", Vector3(-40, 1.0, 62)],
		["turbo", Vector3(-73, 1.0, -62)],    # hidden pocket
		["weapon", Vector3(-8, 4.0, -7.5)],   # furnace deck
		["weapon", Vector3(45, 1.0, 0)],
		["weapon", Vector3(-45, 1.0, 0)],
		["weapon", Vector3(0, 1.0, 70)],
		["weapon", Vector3(68, 3.4, 22)],     # top of the kicker
	]


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
