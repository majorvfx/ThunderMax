class_name BlackwaterBog
extends ArenaBase
## "Blackwater Bog": a drowned swamp at night. Patches of sucking mud slow cars
## right down; a boardwalk on stilts loops round the middle with ramps up to it;
## dead trees stand everywhere; a school bus has sunk nose-first by the shack.
##
## Layout (top view, north = -Z): 160 m square. Boardwalk square 3 m up with
## sides at +/-24, 8 m wide, ramps on the east and west sides. Mud pools in the
## middle and in two corners.

const HALF := 80.0

var _mud_ground: StandardMaterial3D
var _wall: StandardMaterial3D
var _wood: StandardMaterial3D
var _mud: StandardMaterial3D
var _bark: StandardMaterial3D
var _bus: StandardMaterial3D


func _ready() -> void:
	display_name = "BLACKWATER BOG"
	tagline = "Keep moving. The mud keeps what stops."
	_rng.seed = 9031
	_mud_ground = surface_material(Color(0.2, 0.19, 0.13), 401, 0.55, 0.15)
	_wall = surface_material(Color(0.18, 0.14, 0.1), 409, 0.6, 0.12, 0.1, 0.95)
	_wood = surface_material(Color(0.28, 0.2, 0.13), 419, 0.6, 0.3, 0.0, 0.95)
	_bark = surface_material(Color(0.14, 0.12, 0.1), 421, 0.6, 0.4, 0.0, 1.0)
	_bus = surface_material(Color(0.45, 0.34, 0.1), 431, 0.65, 0.15, 0.4, 0.8)
	_mud = StandardMaterial3D.new()
	_mud.albedo_color = Color(0.09, 0.08, 0.05)
	_mud.albedo_texture = VehicleVisualParts.grime_texture(433, 0.4)
	_mud.uv1_triplanar = true
	_mud.uv1_scale = Vector3(0.1, 0.1, 0.1)
	_mud.roughness = 0.25
	_mud.metallic = 0.3
	_make_container_mats([Color(0.2, 0.22, 0.16), Color(0.3, 0.14, 0.08)])
	_make_environment({
		"sky_top": Color(0.01, 0.015, 0.02), "horizon": Color(0.08, 0.11, 0.1), "ground": Color(0.04, 0.05, 0.04),
		"fog": Color(0.1, 0.14, 0.11), "fog_density": 0.02, "sun_color": Color(0.55, 0.65, 0.8),
		"sun_energy": 0.5, "sun_rot": Vector3(-50, 120, 0), "ambient": 0.65, "exposure": 1.45, "saturation": 0.7,
	})
	# A ring of dead swamp instead of walls you can see over: dark timber palisade.
	_walled_floor(HALF, 5.0, _mud_ground, _wall)
	_floor_patch(Rect2(-14, -14, 28, 28), _mud, "mud")
	_floor_patch(Rect2(-76, -76, 26, 22), _mud, "mud")
	_floor_patch(Rect2(50, 52, 26, 24), _mud, "mud")
	_build_boardwalk()
	_build_trees()
	_build_shack_and_bus()
	_build_lanterns()
	_ring_routes(62.0, 36.0)
	_four_spawns(52.0)
	barrel_spots = [Vector3(-40, 0.6, 40), Vector3(40, 0.6, -40), Vector3(-6, 3.6, -24), Vector3(60, 0.6, 0), Vector3(-60, 0.6, 10)]


func _build_boardwalk() -> void:
	var h := 3.0
	var w := 8.0
	var s := 24.0
	# Four sides of a square walkway on stilts.
	_block(Vector3(s * 2 + w, 0.5, w), Vector3(0, h - 0.25, -s), _wood)
	_block(Vector3(s * 2 + w, 0.5, w), Vector3(0, h - 0.25, s), _wood)
	_block(Vector3(w, 0.5, s * 2 - w), Vector3(-s, h - 0.25, 0), _wood)
	_block(Vector3(w, 0.5, s * 2 - w), Vector3(s, h - 0.25, 0), _wood)
	for x in [-s, -s / 2.0, 0.0, s / 2.0, s]:
		for z in [-s, s]:
			for d in [-3.2, 3.2]:
				_block(Vector3(0.5, h - 0.5, 0.5), Vector3(x, (h - 0.5) * 0.5, z + d), _bark)
	for z in [-s / 2.0, 0.0, s / 2.0]:
		for x in [-s, s]:
			for d in [-3.2, 3.2]:
				_block(Vector3(0.5, h - 0.5, 0.5), Vector3(x + d, (h - 0.5) * 0.5, z), _bark)
	# Ramps up from the east and west.
	_ramp(Vector3(-s - 18, 0, 0), Vector3(-s - w * 0.5, h, 0), w, _wood)
	_ramp(Vector3(s + 18, 0, 0), Vector3(s + w * 0.5, h, 0), w, _wood)


func _build_trees() -> void:
	var spots := [
		Vector3(-50, 0, -30), Vector3(-44, 0, 22), Vector3(46, 0, 26), Vector3(52, 0, -26), Vector3(-10, 0, 46),
		Vector3(14, 0, -48), Vector3(-30, 0, -54), Vector3(32, 0, 52), Vector3(-56, 0, 52), Vector3(66, 0, -58),
		Vector3(8, 0, 40), Vector3(-36, 0, 4),
	]
	for p in spots:
		var height := _rng.randf_range(9.0, 15.0)
		_pillar(_rng.randf_range(0.5, 0.9), height, p, _bark)
		# Bare branches.
		for i in 3:
			var b := VehicleVisualParts.box(self, Vector3(0.25, 0.25, _rng.randf_range(3.0, 5.0)), p + Vector3(0, height * _rng.randf_range(0.55, 0.9), 0), _bark)
			b.rotation_degrees = Vector3(_rng.randf_range(-35, 35), _rng.randf_range(0, 360), 0)
			b.position += b.basis.z * -1.5
		# Hanging moss.
		var moss := VehicleVisualParts.box(self, Vector3(1.2, 2.5, 0.05), p + Vector3(0.8, height * 0.6, 0), surface_material(Color(0.2, 0.24, 0.16), 441, 0.5, 0.5))
		moss.rotation_degrees.y = _rng.randf_range(0, 180)


func _build_shack_and_bus() -> void:
	# A stilt shack in the south-west corner with a ramp to its porch.
	_block(Vector3(12, 3, 10), Vector3(-60, 1.5, 62), _wood)
	_block(Vector3(10, 4, 7), Vector3(-61, 5, 63.5), _wood)
	_ramp(Vector3(-60, 0, 46), Vector3(-60, 3, 57), 6.0, _wood)
	var window := VehicleVisualParts.box(self, Vector3(1.5, 1.0, 0.1), Vector3(-58, 5.2, 59.95), glow_material(Color(1.0, 0.7, 0.3), 2.0))
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The sunken bus: nose down in the mud, tail up as a ramp to jump from.
	var bus := _block(Vector3(3, 3, 12), Vector3(44, 1.2, 44), _bus, Vector3(-14, 30, 0))
	bus.name = "SunkenBus"
	_flame(Vector3(-50, 0.6, 50), 0.6)   # a burning drum by the shack


func _build_lanterns() -> void:
	for p in [Vector3(-24, 3, -24), Vector3(24, 3, -24), Vector3(-24, 3, 24), Vector3(24, 3, 24), Vector3(0, 0, -70), Vector3(0, 0, 70), Vector3(-72, 0, -10), Vector3(72, 0, 10)]:
		var light := _lamp_post(p, Color(0.95, 0.65, 0.3), 3.0, 1.6, _bark)
		light.omni_range = 16.0
	# Fireflies over the water.
	var flies := CPUParticles3D.new()
	flies.amount = 120
	flies.lifetime = 5.0
	flies.position = Vector3(0, 2, 0)
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(70, 2, 70)
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.5
	flies.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	q.material = VehicleVisualParts.soft_puff(true)
	flies.mesh = q
	flies.color = Color(0.8, 1.0, 0.4, 0.9)
	add_child(flies)


func pickup_spots() -> Array:
	return [
		["health", Vector3(0, 4.0, -24)],         # boardwalk
		["health", Vector3(-60, 4.0, 60)],        # shack porch
		["health", Vector3(60, 1.0, -60)],
		["turbo", Vector3(0, 1.0, 0)],            # middle of the mud
		["turbo", Vector3(-62, 1.0, -64)],        # corner mud
		["turbo", Vector3(62, 1.0, 64)],
		["turbo", Vector3(-24, 4.0, 0)],
		["weapon", Vector3(24, 4.0, 0)],
		["weapon", Vector3(0, 4.0, 24)],
		["weapon", Vector3(-50, 1.0, -10)],
		["weapon", Vector3(50, 1.0, 10)],
		["weapon", Vector3(0, 1.0, -62)],
	]
