class_name RefineryRow
extends ArenaBase
## "Refinery Row": a burnt-out refinery at dusk. Two tank farms east and west, a
## raised pipe bridge running north-south down the middle with ramps at both ends,
## flare stacks still burning, and fuel drums everywhere.
##
## Layout (top view, north = -Z): 160 m square. Pipe bridge from z -34 to +34 at
## 4 m up, 12 m wide. Tank farms at x = +/-40. Flare stacks in the corners.

const HALF := 80.0

var _ground: StandardMaterial3D
var _wall: StandardMaterial3D
var _steel: StandardMaterial3D
var _tank: StandardMaterial3D
var _pipe: StandardMaterial3D


func _ready() -> void:
	display_name = "REFINERY ROW"
	tagline = "The flares never go out. Neither do the drums."
	_rng.seed = 4410
	_ground = surface_material(Color(0.25, 0.23, 0.21), 211, 0.6, 0.2)
	_wall = surface_material(Color(0.3, 0.2, 0.13), 223, 0.6, 0.12, 0.4, 0.85)
	_steel = surface_material(Color(0.24, 0.23, 0.22), 227, 0.4, 0.2, 0.7, 0.6)
	_tank = surface_material(Color(0.42, 0.4, 0.34), 229, 0.5, 0.08, 0.5, 0.7)
	_pipe = surface_material(Color(0.35, 0.18, 0.1), 233, 0.6, 0.3, 0.5, 0.7)
	_make_container_mats([Color(0.36, 0.14, 0.08), Color(0.22, 0.24, 0.2), Color(0.4, 0.32, 0.12)])
	_make_environment({
		"sky_top": Color(0.08, 0.05, 0.04), "horizon": Color(0.5, 0.22, 0.08), "ground": Color(0.25, 0.12, 0.06),
		"fog": Color(0.35, 0.18, 0.08), "fog_density": 0.01, "sun_color": Color(1.0, 0.55, 0.3),
		"sun_energy": 0.8, "sun_rot": Vector3(-20, 60, 0), "saturation": 0.85,
	})
	_walled_floor(HALF, 7.0, _ground, _wall)
	_build_pipe_bridge()
	_build_tank_farms()
	_build_flares()
	_build_cover()
	for p in [Vector3(-60, 0, -72), Vector3(60, 0, -72), Vector3(-60, 0, 72), Vector3(60, 0, 72), Vector3(-73, 0, 30), Vector3(73, 0, -30)]:
		_lamp_post(p, Color(1.0, 0.6, 0.28), 9.0, 2.0, _steel)
	_ring_routes(62.0, 22.0)
	# The inner loop circles the bridge ramps instead of the middle.
	drone_routes[2] = [Vector3(-20, 0, -50), Vector3(20, 0, -50), Vector3(20, 0, 50), Vector3(-20, 0, 50)] as Array[Vector3]
	_four_spawns(55.0)
	barrel_spots = [
		Vector3(-28, 0.6, -10), Vector3(28, 0.6, 10), Vector3(-52, 0.6, 0), Vector3(52, 0.6, 0),
		Vector3(-30, 0.6, 50), Vector3(30, 0.6, -50), Vector3(0, 0.6, -60), Vector3(0, 0.6, 62),
		Vector3(-70, 0.6, -50), Vector3(70, 0.6, 50),
	]


func _build_pipe_bridge() -> void:
	# A 12 m wide deck 4 m up on steel legs; cars can drive underneath between the legs.
	var h := 4.0
	_block(Vector3(12, 0.6, 52), Vector3(0, h - 0.3, 0), _steel)
	for z in [-24.0, -8.0, 8.0, 24.0]:
		for x in [-5.0, 5.0]:
			_block(Vector3(1.0, h - 0.6, 1.0), Vector3(x, (h - 0.6) * 0.5, z), _steel)
	_ramp(Vector3(0, 0, -46), Vector3(0, h, -26), 12.0, _steel)
	_ramp(Vector3(0, 0, 46), Vector3(0, h, 26), 12.0, _steel)
	# Pipes along both rails: knee-high cover on the deck.
	for x in [-5.6, 5.6]:
		var pipe := StaticBody3D.new()
		pipe.collision_layer = ArcadeVehicle.LAYER_WORLD
		pipe.position = Vector3(x, h + 0.45, 0)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.8, 0.9, 50)
		cs.shape = b
		pipe.add_child(cs)
		VehicleVisualParts.cylinder(pipe, 0.45, 50.0, Vector3.ZERO, Vector3(90, 0, 0), _pipe)
		add_child(pipe)


func _build_tank_farms() -> void:
	for side in [-1.0, 1.0]:
		var cx: float = 40.0 * side
		for pz in [-30.0, 0.0, 30.0]:
			var r := 6.0 if pz == 0.0 else 4.5
			_pillar(r, 9.0 if pz == 0.0 else 7.0, Vector3(cx, 0, pz), _tank)
			# Rust streaks and a catwalk ring at the top.
			VehicleVisualParts.cylinder(self, r + 0.3, 0.25, Vector3(cx, (9.0 if pz == 0.0 else 7.0) - 0.5, pz), Vector3.ZERO, _steel)
		# Low bund wall around each farm with gaps to drive in.
		_block(Vector3(1.0, 1.2, 22), Vector3(cx - 12.0 * side, 0.6, -25), _wall)
		_block(Vector3(1.0, 1.2, 22), Vector3(cx - 12.0 * side, 0.6, 25), _wall)


func _build_flares() -> void:
	for p in [Vector3(-68, 0, -68), Vector3(68, 0, -68), Vector3(-68, 0, 68), Vector3(68, 0, 68)]:
		_pillar(1.2, 16.0, p, _pipe)
		_flame(p + Vector3(0, 16.5, 0), 1.6)
		_smoke_column(p + Vector3(0, 19, 0), 4.0)


func _build_cover() -> void:
	_container(Vector3(-22, 0, -62), false, 10.0)
	_container(Vector3(22, 0, 62), false, 10.0)
	_container(Vector3(-62, 0, 40), true, 10.0, 15.0)
	_container(Vector3(62, 0, -40), true, 10.0, -15.0)
	# Burnt-out tanker trailers.
	for p in [Vector3(-20, 0, 20), Vector3(20, 0, -20)]:
		var t := _pillar(1.3, 9.0, p + Vector3(0, 0, 0), _tank)
		t.rotation_degrees = Vector3(90, 0, 0)
		t.position = p + Vector3(0, 1.3, 0)


func pickup_spots() -> Array:
	return [
		["health", Vector3(0, 5.0, 0)],           # middle of the pipe bridge
		["health", Vector3(-40, 1.0, -15)],
		["health", Vector3(40, 1.0, 15)],
		["turbo", Vector3(0, 1.0, -60)],
		["turbo", Vector3(0, 1.0, 62)],
		["turbo", Vector3(-62, 1.0, 0)],
		["turbo", Vector3(0, 1.0, 0)],            # under the bridge
		["weapon", Vector3(0, 5.0, -18)],
		["weapon", Vector3(0, 5.0, 18)],
		["weapon", Vector3(-40, 1.0, 15)],
		["weapon", Vector3(40, 1.0, -15)],
		["weapon", Vector3(-70, 1.0, -70)],
		["weapon", Vector3(70, 1.0, 70)],
	]
