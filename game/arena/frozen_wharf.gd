class_name FrozenWharf
extends ArenaBase
## "Frozen Wharf": a harbour iced over under a grey sky. The south half is pier
## concrete with container canyons; the north half is the frozen basin, sheet ice
## where cars slide. A beached freighter lies across the basin with a ramp up
## onto its deck. Dead cranes stand along the quay.
##
## Layout (top view, north = -Z): 160 m square. Ice basin z < -8. Freighter deck
## from x -30 to +30 at z -40, 5 m up, ramps at both ends.

const HALF := 80.0

var _pier: StandardMaterial3D
var _wall: StandardMaterial3D
var _steel: StandardMaterial3D
var _ice: StandardMaterial3D
var _hull: StandardMaterial3D


func _ready() -> void:
	display_name = "FROZEN WHARF"
	tagline = "The sea froze. The bodies didn't sink."
	_rng.seed = 7203
	_pier = surface_material(Color(0.42, 0.42, 0.42), 307, 0.5, 0.2)
	_wall = surface_material(Color(0.24, 0.25, 0.27), 311, 0.55, 0.12, 0.5, 0.8)
	_steel = surface_material(Color(0.22, 0.23, 0.25), 313, 0.4, 0.2, 0.7, 0.6)
	_hull = surface_material(Color(0.3, 0.14, 0.1), 317, 0.65, 0.08, 0.5, 0.8)
	_ice = StandardMaterial3D.new()
	_ice.albedo_color = Color(0.62, 0.72, 0.8)
	_ice.albedo_texture = VehicleVisualParts.grime_texture(331, 0.25)
	_ice.uv1_triplanar = true
	_ice.uv1_scale = Vector3(0.08, 0.08, 0.08)
	_ice.roughness = 0.12
	_ice.metallic = 0.25
	_make_container_mats([Color(0.16, 0.24, 0.3), Color(0.38, 0.14, 0.1), Color(0.3, 0.3, 0.32), Color(0.36, 0.3, 0.14)])
	_make_environment({
		"sky_top": Color(0.18, 0.2, 0.23), "horizon": Color(0.5, 0.53, 0.56), "ground": Color(0.3, 0.32, 0.34),
		"fog": Color(0.55, 0.58, 0.62), "fog_density": 0.012, "sun_color": Color(0.8, 0.85, 0.95),
		"sun_energy": 0.7, "sun_rot": Vector3(-30, 20, 0), "ambient": 0.75, "saturation": 0.6,
	})
	_walled_floor(HALF, 6.0, _pier, _wall)
	_floor_patch(Rect2(-HALF, -HALF, HALF * 2.0, HALF - 8.0), _ice, "ice")
	_build_freighter()
	_build_container_canyons()
	_build_cranes()
	_build_snow()
	for p in [Vector3(-72, 0, 10), Vector3(72, 0, 10), Vector3(-30, 0, 72), Vector3(30, 0, 72)]:
		_lamp_post(p, Color(0.85, 0.9, 1.0), 9.0, 1.8, _steel)
	_ring_routes(62.0, 22.0)
	drone_routes[2] = [Vector3(-50, 0, 20), Vector3(50, 0, 20), Vector3(50, 0, -62), Vector3(-50, 0, -62)] as Array[Vector3]
	_four_spawns(55.0)
	spawn_points[1] = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.2, -64))
	barrel_spots = [Vector3(-12, 0.6, 30), Vector3(12, 0.6, 50), Vector3(-60, 0.6, 50), Vector3(60, 0.6, 30), Vector3(0, 0.6, 14)]


func _build_freighter() -> void:
	# A beached hull lying east-west across the ice. Its deck is 5 m up.
	var h := 5.0
	_block(Vector3(60, h, 14), Vector3(0, h * 0.5, -40), _hull)
	_ramp(Vector3(-52, 0, -40), Vector3(-30, h, -40), 10.0, _steel)
	_ramp(Vector3(52, 0, -40), Vector3(30, h, -40), 10.0, _steel)
	# Superstructure at the east end, cover on the deck.
	_block(Vector3(10, 6, 10), Vector3(18, h + 3, -40), _steel)
	VehicleVisualParts.box(self, Vector3(8, 0.8, 0.1), Vector3(18, h + 4.5, -45.06), glow_material(Color(0.9, 0.8, 0.5), 1.2))
	_container(Vector3(-8, h, -40), false, 8.0)
	_container(Vector3(-20, h, -44), false, 6.0)
	# Deck rails.
	for z in [-47.2, -32.8]:
		_block(Vector3(56, 0.6, 0.3), Vector3(0, h + 0.3, z), _steel)


func _build_container_canyons() -> void:
	# Three rows of stacked containers on the pier, with lanes between them.
	for x in [-36.0, 0.0, 36.0]:
		_container(Vector3(x, 0, 30), true, 18.0)
		_container(Vector3(x, 2.6, 30), true, 12.0)
	_container(Vector3(-18, 0, 54), false, 12.0)
	_container(Vector3(18, 0, 54), false, 12.0)
	# Ice ridges: low pressure ridges on the basin you can hop.
	for p in [Vector3(-40, 0, -14), Vector3(40, 0, -20), Vector3(0, 0, -64)]:
		_ramp(p + Vector3(0, 0, 5), p + Vector3(0, 1.2, 0), 14.0, _ice)
		_ramp(p + Vector3(0, 0, -5), p + Vector3(0, 1.2, 0), 14.0, _ice)


func _build_cranes() -> void:
	for x in [-60.0, 60.0]:
		for dx in [-3.0, 3.0]:
			_block(Vector3(1.2, 18, 1.2), Vector3(x + dx, 9, 6), _steel)
		_block(Vector3(8, 1.5, 1.5), Vector3(x, 18.5, 6), _steel)
		var boom := VehicleVisualParts.box(self, Vector3(1.2, 1.2, 30), Vector3(x, 19.5, -8), _hull)
		boom.rotation_degrees.x = -6.0


func _build_snow() -> void:
	var snow := CPUParticles3D.new()
	snow.amount = 400
	snow.lifetime = 8.0
	snow.position = Vector3(0, 30, 0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(80, 1, 80)
	snow.direction = Vector3(0.3, -1, 0.1)
	snow.spread = 10.0
	snow.initial_velocity_min = 3.0
	snow.initial_velocity_max = 5.0
	snow.gravity = Vector3(0, -0.5, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = VehicleVisualParts.soft_puff(false)
	snow.mesh = q
	snow.color = Color(0.9, 0.93, 1.0, 0.8)
	add_child(snow)


func pickup_spots() -> Array:
	return [
		["health", Vector3(0, 6.0, -40)],         # freighter deck
		["health", Vector3(-62, 1.0, 40)],
		["health", Vector3(62, 1.0, -62)],
		["turbo", Vector3(-18, 1.0, 30)],
		["turbo", Vector3(18, 1.0, 30)],
		["turbo", Vector3(0, 1.0, -64)],
		["turbo", Vector3(-62, 1.0, -62)],
		["weapon", Vector3(-24, 6.0, -36)],
		["weapon", Vector3(0, 1.0, 64)],
		["weapon", Vector3(-50, 1.0, 0)],
		["weapon", Vector3(50, 1.0, 0)],
		["weapon", Vector3(40, 2.2, -20)],        # top of an ice ridge
	]
