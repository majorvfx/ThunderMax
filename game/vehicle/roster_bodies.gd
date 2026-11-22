class_name RosterBodies
extends RefCounted
## Placeholder bodies for the Iron Carnage cars added in update 1, built from boxes
## and cylinders in the same soot-and-rust style as the first four. Front is -Z.


static func build(v: VehicleVisual, paint: String) -> void:
	match paint:
		"warrant":
			_warrant(v)
		"bastion":
			_bastion(v)
		"mourner":
			_mourner(v)
		"bucketmouth":
			_bucketmouth(v)
		"tonnage":
			_tonnage(v)
		"vandal":
			_vandal(v)
		"lancet":
			_lancet(v)
		"sermon":
			_sermon(v)


static func _m(kind: String) -> StandardMaterial3D:
	return VehicleVisualParts.material(kind)


static func _lights(v: VehicleVisual, x: float, front_z: float, back_z: float, y: float = 0.2) -> void:
	for sx in [-x, x]:
		VehicleVisualParts.box(v, Vector3(0.3, 0.13, 0.06), Vector3(sx, y, front_z), _m("headlight"))
		VehicleVisualParts.box(v, Vector3(0.32, 0.1, 0.06), Vector3(sx, y + 0.06, back_z), _m("taillight"))


static func _nozzles(v: VehicleVisual, x: float, y: float, z: float, r: float = 0.15) -> void:
	for sx in [-x, x]:
		VehicleVisualParts.cylinder(v, r, 0.32, Vector3(sx, y, z), Vector3(90, 0, 0), _m("steel"))
		VehicleVisualParts.cylinder(v, r * 0.7, 0.04, Vector3(sx, y, z + 0.17), Vector3(90, 0, 0), _m("soot"))
		v.add_nozzle(Vector3(sx, y, z + 0.19))


## Warrant: a long armoured interceptor. Push bar, plated windows, a smashed light bar.
static func _warrant(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("warrant")
	var steel := _m("steel")
	P.box(v, Vector3(1.9, 0.5, 4.5), Vector3(0, 0.0, 0), paint)
	P.box(v, Vector3(1.8, 0.25, 1.4), Vector3(0, 0.36, -1.4), paint)        # hood
	P.box(v, Vector3(1.6, 0.48, 1.7), Vector3(0, 0.55, 0.2), _m("glass"))    # cabin
	P.box(v, Vector3(1.64, 0.08, 1.6), Vector3(0, 0.82, 0.2), paint)         # roof
	P.box(v, Vector3(1.8, 0.24, 1.0), Vector3(0, 0.34, 1.75), paint)         # trunk
	# Plate over the side glass, slotted.
	for x in [-0.82, 0.82]:
		P.box(v, Vector3(0.05, 0.36, 1.5), Vector3(x, 0.56, 0.2), steel)
		P.box(v, Vector3(0.06, 0.05, 1.1), Vector3(x, 0.6, 0.2), _m("soot"))
	# Push bar.
	P.box(v, Vector3(1.7, 0.12, 0.12), Vector3(0, 0.3, -2.45), steel)
	P.box(v, Vector3(1.7, 0.12, 0.12), Vector3(0, -0.05, -2.45), steel)
	for x in [-0.6, 0.0, 0.6]:
		P.box(v, Vector3(0.1, 0.45, 0.1), Vector3(x, 0.12, -2.45), steel)
	# The light bar, shot out: a dead housing with one cracked red lens.
	P.box(v, Vector3(1.2, 0.12, 0.28), Vector3(0, 0.92, 0.0), steel)
	P.box(v, Vector3(0.28, 0.08, 0.22), Vector3(-0.38, 0.99, 0.0), _m("taillight"))
	P.box(v, Vector3(0.28, 0.08, 0.22), Vector3(0.38, 0.99, 0.0), _m("soot"))
	# Net launcher on the roof.
	P.cylinder(v, 0.16, 0.8, Vector3(0, 1.0, -0.55), Vector3(90, 0, 0), steel)
	_lights(v, 0.62, -2.26, 2.26)
	_nozzles(v, 0.45, 0.0, 2.3)


## Bastion: a six-wheel troop carrier. Sloped armour, welded turret, mortar tube.
static func _bastion(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("bastion")
	var steel := _m("steel")
	P.box(v, Vector3(2.3, 0.9, 5.4), Vector3(0, 0.25, 0), paint)
	var glacis := P.box(v, Vector3(2.25, 0.7, 1.1), Vector3(0, 0.45, -2.6), paint)
	glacis.rotation_degrees.x = 35.0
	P.box(v, Vector3(2.0, 0.35, 3.6), Vector3(0, 0.85, 0.5), paint)          # upper hull
	P.box(v, Vector3(1.4, 0.12, 0.08), Vector3(0, 0.85, -1.6), _m("glass"))   # vision slit
	# Welded-shut turret and the mortar tube that replaced the hatch.
	P.cylinder(v, 0.6, 0.45, Vector3(0, 1.2, 0.3), Vector3.ZERO, steel)
	var tube := P.cylinder(v, 0.18, 1.1, Vector3(0, 1.6, 0.0), Vector3(-35, 0, 0), steel)
	tube.name = "MortarTube"
	# Middle wheels (the outer four come with every car).
	for x in [-1.05, 1.05]:
		P.cylinder(v, 0.52, 0.42, Vector3(x * 1.12, -0.05, 0.0), Vector3(0, 0, 90), _m("tire"))
	# Spare track links and jerry cans down the sides.
	for x in [-1.17, 1.17]:
		for z in [-0.9, 0.9]:
			P.box(v, Vector3(0.12, 0.4, 0.5), Vector3(x, 0.55, z), _m("primer"))
	_lights(v, 0.8, -2.72, 2.72, 0.45)
	_nozzles(v, 0.55, 0.1, 2.75, 0.18)


## Mourner: a long, low hearse. Plated side glass, chrome trim, casket in the back.
static func _mourner(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("mourner")
	var steel := _m("steel")
	P.box(v, Vector3(1.9, 0.55, 4.9), Vector3(0, 0.0, 0), paint)
	P.box(v, Vector3(1.8, 0.25, 1.3), Vector3(0, 0.38, -1.75), paint)        # long hood
	P.box(v, Vector3(1.7, 0.72, 3.0), Vector3(0, 0.62, 0.65), paint)         # tall rear box
	P.box(v, Vector3(1.6, 0.4, 0.06), Vector3(0, 0.62, -0.88), _m("glass"))  # windscreen
	for x in [-0.86, 0.86]:
		P.box(v, Vector3(0.04, 0.45, 2.4), Vector3(x, 0.62, 0.7), steel)     # plate over the glass
		P.box(v, Vector3(0.05, 0.05, 4.6), Vector3(x * 1.1, 0.2, 0.0), _m("chrome"))
		# Landau bars, the old hearse ornament.
		var bar := P.box(v, Vector3(0.05, 0.05, 0.7), Vector3(x * 1.0, 0.78, 1.6), _m("chrome"))
		bar.rotation_degrees.x = 25.0
	P.box(v, Vector3(1.72, 0.08, 3.05), Vector3(0, 1.0, 0.65), steel)        # roof
	# Back doors, one hanging a little open.
	var door := P.box(v, Vector3(0.82, 0.62, 0.05), Vector3(0.45, 0.62, 2.18), paint)
	door.rotation_degrees.y = -12.0
	P.box(v, Vector3(0.82, 0.62, 0.05), Vector3(-0.42, 0.62, 2.16), paint)
	P.box(v, Vector3(0.55, 0.3, 0.9), Vector3(0, 0.45, 1.6), _m("casket"))   # the casket inside
	_lights(v, 0.62, -2.46, 2.46)
	_nozzles(v, 0.5, -0.05, 2.5)


## Bucketmouth: a wheel loader. Big toothed bucket on arms, cab high at the back.
static func _bucketmouth(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("bucketmouth")
	var steel := _m("steel")
	P.box(v, Vector3(2.0, 0.7, 3.6), Vector3(0, 0.25, 0.6), paint)          # chassis
	P.box(v, Vector3(1.4, 1.1, 1.3), Vector3(0, 1.05, 0.5), paint)          # cab
	P.box(v, Vector3(1.3, 0.6, 1.2), Vector3(0, 1.15, 0.5), _m("glass"))
	P.box(v, Vector3(1.55, 0.1, 1.45), Vector3(0, 1.62, 0.5), steel)        # roll-over roof
	P.box(v, Vector3(1.9, 0.9, 1.1), Vector3(0, 0.55, 2.0), _m("rust"))     # engine box
	# Lift arms and the bucket.
	for x in [-0.8, 0.8]:
		var arm := P.box(v, Vector3(0.18, 0.2, 1.8), Vector3(x, 0.45, -1.3), steel)
		arm.rotation_degrees.x = -10.0
	var bucket := Node3D.new()
	bucket.position = Vector3(0, 0.05, -2.3)
	v.add_child(bucket)
	P.box(bucket, Vector3(2.5, 0.9, 0.12), Vector3(0, 0.25, 0.2), steel)    # back of the bucket
	P.box(bucket, Vector3(2.5, 0.12, 0.8), Vector3(0, -0.2, -0.15), steel)  # floor
	for x in [-1.22, 1.22]:
		P.box(bucket, Vector3(0.08, 0.8, 0.8), Vector3(x, 0.2, -0.15), steel)
	for i in 7:
		var tooth := P.box(bucket, Vector3(0.14, 0.1, 0.32), Vector3(-1.05 + 0.35 * i, -0.22, -0.66), _m("blade"))
		tooth.rotation_degrees.x = 8.0
	var beacon := P.box(v, Vector3(0.25, 0.14, 0.25), Vector3(0.5, 1.72, 0.5), _m("amber"))
	v.set_beacon(beacon)
	for sx in [-0.7, 0.7]:
		P.box(v, Vector3(0.25, 0.14, 0.06), Vector3(sx, 1.4, -0.17), _m("headlight"))
		P.box(v, Vector3(0.3, 0.1, 0.06), Vector3(sx, 0.6, 2.56), _m("taillight"))
	P.cylinder(v, 0.1, 1.0, Vector3(0.6, 1.4, 1.8), Vector3.ZERO, steel)    # stack
	_nozzles(v, 0.5, 0.25, 2.62, 0.17)


## Tonnage: a monster truck on a dump-truck frame. Huge tyres, tipping slag bed.
static func _tonnage(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("tonnage")
	var steel := _m("steel")
	P.box(v, Vector3(1.8, 0.4, 4.6), Vector3(0, 0.35, 0), steel)            # frame, high up
	P.box(v, Vector3(1.9, 0.9, 1.4), Vector3(0, 1.0, -1.6), paint)          # cab
	P.box(v, Vector3(1.8, 0.4, 0.06), Vector3(0, 1.15, -2.31), _m("glass"))
	# The dump bed, tipped very slightly, full of slag.
	var bed := Node3D.new()
	bed.position = Vector3(0, 1.0, 0.75)
	bed.rotation_degrees.x = 4.0
	v.add_child(bed)
	P.box(bed, Vector3(2.2, 0.1, 3.0), Vector3(0, -0.1, 0), paint)
	for x in [-1.1, 1.1]:
		P.box(bed, Vector3(0.1, 0.9, 3.0), Vector3(x, 0.35, 0), paint)
	P.box(bed, Vector3(2.2, 0.9, 0.1), Vector3(0, 0.35, -1.5), paint)
	for i in 5:
		var lump := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.8
		sm.radial_segments = 6
		sm.rings = 4
		sm.material = _m("slag")
		lump.mesh = sm
		lump.position = Vector3(-0.6 + 0.3 * i, 0.35 + 0.1 * (i % 2), -0.9 + 0.45 * i)
		bed.add_child(lump)
	# Light pod on the cab roof and a huge bumper.
	for x in [-0.6, -0.2, 0.2, 0.6]:
		P.box(v, Vector3(0.18, 0.14, 0.08), Vector3(x, 1.52, -2.0), _m("headlight"))
	P.box(v, Vector3(2.4, 0.4, 0.25), Vector3(0, 0.3, -2.45), steel)
	for sx in [-0.7, 0.7]:
		P.box(v, Vector3(0.3, 0.12, 0.06), Vector3(sx, 0.45, 2.33), _m("taillight"))
	_nozzles(v, 0.5, 0.35, 2.35, 0.18)


## Vandal: a muscle car. Long bonnet, blower through it, zip-tied panels, wing.
static func _vandal(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("vandal")
	var steel := _m("steel")
	P.box(v, Vector3(1.95, 0.5, 4.4), Vector3(0, 0.0, 0), paint)
	P.box(v, Vector3(1.85, 0.2, 1.8), Vector3(0, 0.33, -1.2), paint)        # long bonnet
	P.box(v, Vector3(1.55, 0.42, 1.2), Vector3(0, 0.5, 0.45), _m("glass"))
	P.box(v, Vector3(1.6, 0.08, 1.1), Vector3(0, 0.74, 0.45), paint)
	P.box(v, Vector3(1.85, 0.22, 1.0), Vector3(0, 0.32, 1.6), paint)
	# The blower sticking out of the bonnet.
	P.box(v, Vector3(0.55, 0.3, 0.7), Vector3(0, 0.55, -1.2), _m("chrome"))
	P.box(v, Vector3(0.6, 0.18, 0.4), Vector3(0, 0.78, -1.25), steel)
	# Mismatched panels zip-tied on, and a rear wing on struts.
	P.box(v, Vector3(0.06, 0.35, 1.2), Vector3(-0.99, 0.1, -0.6), _m("primer"))
	P.box(v, Vector3(0.06, 0.35, 1.0), Vector3(0.99, 0.1, 0.9), _m("rust"))
	for x in [-0.6, 0.6]:
		P.box(v, Vector3(0.06, 0.35, 0.06), Vector3(x, 0.58, 2.0), steel)
	P.box(v, Vector3(1.8, 0.05, 0.4), Vector3(0, 0.77, 2.05), steel)
	# Side pipes.
	for x in [-1.02, 1.02]:
		P.cylinder(v, 0.08, 1.5, Vector3(x, -0.15, 0.3), Vector3(90, 0, 0), _m("chrome"))
	_lights(v, 0.65, -2.21, 2.21)
	_nozzles(v, 0.45, 0.0, 2.24)


## Lancet: an open-wheel racer. Needle nose, open seat, a jet behind the driver.
static func _lancet(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("lancet")
	var steel := _m("steel")
	P.box(v, Vector3(0.7, 0.35, 3.0), Vector3(0, 0.05, 0.2), paint)         # tub
	var nose := P.box(v, Vector3(0.45, 0.22, 1.4), Vector3(0, 0.0, -1.85), paint)
	nose.rotation_degrees.x = 4.0
	P.box(v, Vector3(1.7, 0.05, 0.35), Vector3(0, -0.08, -2.4), steel)      # front wing
	for x in [-0.85, 0.85]:
		P.box(v, Vector3(0.05, 0.22, 0.4), Vector3(x, 0.0, -2.4), steel)
	for x in [-0.55, 0.55]:
		P.box(v, Vector3(0.5, 0.3, 1.5), Vector3(x, 0.05, 0.4), paint)      # side pods
	P.box(v, Vector3(0.42, 0.3, 0.5), Vector3(0, 0.3, -0.3), _m("tire"))    # seat and driver
	P.box(v, Vector3(0.6, 0.08, 0.06), Vector3(0, 0.42, -0.65), _m("glass"))
	# The jet engine bolted on behind the seat.
	P.cylinder(v, 0.34, 1.6, Vector3(0, 0.45, 1.2), Vector3(90, 0, 0), steel)
	P.cylinder(v, 0.36, 0.1, Vector3(0, 0.45, 0.42), Vector3(90, 0, 0), _m("soot"))
	P.box(v, Vector3(1.4, 0.05, 0.4), Vector3(0, 0.95, 1.9), paint)         # rear wing
	P.box(v, Vector3(0.06, 0.5, 0.06), Vector3(0, 0.7, 1.9), steel)
	P.box(v, Vector3(0.3, 0.1, 0.05), Vector3(0, 0.12, -2.56), _m("headlight"))
	P.box(v, Vector3(0.3, 0.08, 0.05), Vector3(0, 0.88, 2.11), _m("taillight"))
	P.cylinder(v, 0.24, 0.04, Vector3(0, 0.45, 2.01), Vector3(90, 0, 0), _m("soot"))
	v.add_nozzle(Vector3(0, 0.45, 2.03))


## Sermon: a long lowrider. Chrome, deep paint, PA horns on the roof, a cross of rivets.
static func _sermon(v: VehicleVisual) -> void:
	var P := VehicleVisualParts
	var paint := _m("sermon")
	var chrome := _m("chrome")
	P.box(v, Vector3(1.95, 0.42, 4.8), Vector3(0, -0.05, 0), paint)
	P.box(v, Vector3(1.85, 0.2, 1.6), Vector3(0, 0.25, -1.55), paint)
	P.box(v, Vector3(1.6, 0.4, 1.5), Vector3(0, 0.42, 0.25), _m("glass"))
	P.box(v, Vector3(1.66, 0.08, 1.45), Vector3(0, 0.64, 0.25), paint)
	P.box(v, Vector3(1.85, 0.18, 1.3), Vector3(0, 0.22, 1.7), paint)
	for x in [-0.99, 0.99]:
		P.box(v, Vector3(0.04, 0.06, 4.7), Vector3(x, 0.05, 0), chrome)
	P.box(v, Vector3(2.0, 0.14, 0.12), Vector3(0, -0.05, -2.42), chrome)    # bumpers
	P.box(v, Vector3(2.0, 0.14, 0.12), Vector3(0, -0.05, 2.42), chrome)
	# PA horns on the roof, pointing every way.
	for a in [-35.0, 35.0, 145.0, 215.0]:
		var horn := P.cylinder(v, 0.14, 0.5, Vector3(0, 0.82, 0.25), Vector3(90, a, 0), _m("steel"))
		horn.position += Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a))) * -0.3
	# A rivet cross on the bonnet.
	P.box(v, Vector3(0.1, 0.03, 0.9), Vector3(0, 0.36, -1.55), chrome)
	P.box(v, Vector3(0.5, 0.03, 0.1), Vector3(0, 0.36, -1.7), chrome)
	_lights(v, 0.65, -2.41, 2.41, 0.1)
	_nozzles(v, 0.45, -0.1, 2.45)
