class_name FoundryYard
extends ArenaBase
## Milestone 1 test arena: "The Foundry Yard", a dead steelworks walled in with
## scrap. Built in code from placeholder blocks so layout changes are quick;
## it will be rebuilt as an authored scene with real art later.
##
## Layout (top view, north = -Z): a 160 m square yard. A raised furnace deck
## in the middle with ramps north and south, container cover east and west, a
## kicker ramp in the east lane, and a hidden pocket in the north-west corner.

const HALF := 80.0
const WALL_HEIGHT := 7.0

var _concrete: StandardMaterial3D
var _wall: StandardMaterial3D
var _steel: StandardMaterial3D
var _flicker: OmniLight3D
var _flicker_time := 0.0


func _ready() -> void:
	display_name = "THE FOUNDRY YARD"
	tagline = "Wreck the drones. Mind the drums."
	_rng.seed = 1977
	_make_materials()
	_build_environment()
	_build_ground_and_walls()
	_build_furnace_deck()
	_build_cover()
	_build_kicker()
	_build_hidden_pocket()
	_build_lamps()
	_define_routes_and_spawns()


func _process(delta: float) -> void:
	# One failing sodium lamp, for unease.
	if _flicker == null:
		return
	_flicker_time -= delta
	if _flicker_time <= 0.0:
		_flicker.light_energy = 0.0 if _rng.randf() < 0.35 else _rng.randf_range(1.5, 3.0)
		_flicker_time = _rng.randf_range(0.04, 0.5)


# --- Materials and environment ------------------------------------------------

func _make_materials() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.36, 0.34, 0.31)
	_concrete.albedo_texture = VehicleVisualParts.grime_texture(5, 0.5)
	_concrete.uv1_triplanar = true
	_concrete.uv1_scale = Vector3(0.22, 0.22, 0.22)
	_concrete.roughness = 0.95

	_wall = StandardMaterial3D.new()
	_wall.albedo_color = Color(0.33, 0.17, 0.09)
	_wall.albedo_texture = VehicleVisualParts.grime_texture(9, 0.6)
	_wall.uv1_triplanar = true
	_wall.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_wall.metallic = 0.4
	_wall.roughness = 0.85

	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.22, 0.22, 0.23)
	_steel.albedo_texture = VehicleVisualParts.grime_texture(13, 0.4)
	_steel.uv1_triplanar = true
	_steel.uv1_scale = Vector3(0.2, 0.2, 0.2)
	_steel.metallic = 0.7
	_steel.roughness = 0.6

	for c in [Color(0.4, 0.12, 0.08), Color(0.16, 0.24, 0.24), Color(0.38, 0.3, 0.12), Color(0.2, 0.2, 0.22)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.albedo_texture = VehicleVisualParts.grime_texture(17 + _container_mats.size(), 0.55)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.15, 0.15, 0.15)
		m.metallic = 0.45
		m.roughness = 0.8
		_container_mats.append(m)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.06, 0.06)
	sky_mat.sky_horizon_color = Color(0.32, 0.18, 0.1)
	sky_mat.ground_horizon_color = Color(0.2, 0.12, 0.08)
	sky_mat.ground_bottom_color = Color(0.04, 0.03, 0.03)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.3, 0.2, 0.14)
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.8
	environment.adjustment_contrast = 1.1

	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# --- Layout ----------------------------------------------------------------------

func _build_ground_and_walls() -> void:
	_block(Vector3(HALF * 2.0 + 20.0, 1.0, HALF * 2.0 + 20.0), Vector3(0, -0.5, 0), _concrete)
	var t := 2.0
	_block(Vector3(HALF * 2.0 + t * 2.0, WALL_HEIGHT, t), Vector3(0, WALL_HEIGHT * 0.5, -HALF - t * 0.5), _wall)
	_block(Vector3(HALF * 2.0 + t * 2.0, WALL_HEIGHT, t), Vector3(0, WALL_HEIGHT * 0.5, HALF + t * 0.5), _wall)
	_block(Vector3(t, WALL_HEIGHT, HALF * 2.0), Vector3(-HALF - t * 0.5, WALL_HEIGHT * 0.5, 0), _wall)
	_block(Vector3(t, WALL_HEIGHT, HALF * 2.0), Vector3(HALF + t * 0.5, WALL_HEIGHT * 0.5, 0), _wall)
	# Buttresses along the walls break up the long flat runs.
	for i in range(-3, 4):
		var p := float(i) * 22.0
		_block(Vector3(1.5, WALL_HEIGHT + 1.5, 1.5), Vector3(p, (WALL_HEIGHT + 1.5) * 0.5, -HALF + 0.3), _steel)
		_block(Vector3(1.5, WALL_HEIGHT + 1.5, 1.5), Vector3(p, (WALL_HEIGHT + 1.5) * 0.5, HALF - 0.3), _steel)
		_block(Vector3(1.5, WALL_HEIGHT + 1.5, 1.5), Vector3(-HALF + 0.3, (WALL_HEIGHT + 1.5) * 0.5, p), _steel)
		_block(Vector3(1.5, WALL_HEIGHT + 1.5, 1.5), Vector3(HALF - 0.3, (WALL_HEIGHT + 1.5) * 0.5, p), _steel)


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


func _build_hidden_pocket() -> void:
	# North-west pocket behind a long container wall; the way in is a 4 m gap on its south side.
	_container(Vector3(-66, 0, -65), true, 26.0)
	_block(Vector3(8.5, 2.6, 2.6), Vector3(-75.75, 1.3, -50), _container_mats[1])


func _build_lamps() -> void:
	var spots := [Vector3(-38, 0, -71), Vector3(38, 0, -71), Vector3(-72, 0, 0), Vector3(73, 0, 10), Vector3(-38, 0, 71), Vector3(38, 0, 71)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		_block(Vector3(0.4, 9.0, 0.4), p + Vector3(0, 4.5, 0), _steel)
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = Color(1.0, 0.7, 0.35)
		head_mat.emission_enabled = true
		head_mat.emission = Color(1.0, 0.6, 0.25)
		head_mat.emission_energy_multiplier = 3.0
		VehicleVisualParts.box(self, Vector3(1.2, 0.25, 0.6), p + Vector3(0, 9.1, 0), head_mat)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.3)
		light.light_energy = 2.2
		light.omni_range = 22.0
		light.position = p + Vector3(0, 8.6, 0)
		add_child(light)
		lamps.append(light)
		if i == 3:
			_flicker = light


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
