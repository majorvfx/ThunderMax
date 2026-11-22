class_name SpecialWeapons
extends Node
## Special weapons: the pickups (Seeker, Firebrand, Sledge) and each car's own
## signature special. Weapon crates add pickup ammo; the signature holds one shot
## and recharges on its own. Cycle with the special prev/next controls; hold the
## special button to fire.

signal changed(specials: SpecialWeapons)
signal fired(vehicle: ArcadeVehicle, weapon_id: String)

var vehicle: ArcadeVehicle
var weapons := {}          ## id -> data
var order: Array[String] = []
var ammo := {}             ## id -> count
var selected := ""
var max_ammo := 6
var signature := {}           ## this car's own special ("signature" in its data file)
var signature_id := ""
var signature_charge := 1.0   ## 0..1, ready at 1
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _satchels: Array[SatchelCharge] = []
var _last_satchel_drop := -100.0
var _clock := 0.0
var _hop := {}           ## Hydraulic Hop in progress: its data while the car is up
var _hop_airborne := false
var _hop_time := 0.0


func setup(v: ArcadeVehicle) -> void:
	vehicle = v
	_rng.randomize()
	var data: Variant = GameData.load_json(GameData.SPECIALS_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		weapons = data.get("weapons", {})
		max_ammo = int(data.get("max_ammo", 6))
	for id in weapons.keys():
		order.append(String(id))
	signature = GameData.signature(v.stats.id) if v.stats != null else {}
	if not signature.is_empty():
		signature_id = str(signature.get("id", "signature"))
		weapons[signature_id] = signature
		order.insert(0, signature_id)
		selected = signature_id


func clear() -> void:
	ammo.clear()
	_satchels.clear()
	_hop.clear()
	selected = signature_id
	signature_charge = 1.0
	changed.emit(self)


func is_signature(id: String) -> bool:
	return id != "" and id == signature_id


func count(id: String) -> int:
	if is_signature(id):
		return 1 if signature_charge >= 1.0 else 0
	return int(ammo.get(id, 0))


## Satchels on the ground that this car can still set off.
func live_satchels() -> Array[SatchelCharge]:
	var out: Array[SatchelCharge] = []
	for s in _satchels:
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			out.append(s)
	_satchels = out
	return out


func total() -> int:
	var n := 0
	for id in ammo:
		n += int(ammo[id])
	return n


func display_name(id: String) -> String:
	return str(weapons.get(id, {}).get("name", id))


func add(id: String, n: int) -> bool:
	if not weapons.has(id) or is_signature(id) or count(id) >= max_ammo:
		return false
	ammo[id] = mini(max_ammo, count(id) + n)
	if selected == "" or count(selected) == 0 or is_signature(selected):
		selected = id
	changed.emit(self)
	return true


## Weapon crate: a random weapon that isn't already full.
func add_random(n: int) -> bool:
	var options: Array[String] = []
	for id in order:
		if not is_signature(id) and count(id) < max_ammo:
			options.append(id)
	if options.is_empty():
		return false
	return add(options[_rng.randi() % options.size()], n)


func cycle(step: int) -> void:
	var owned: Array[String] = []
	for id in order:
		if count(id) > 0 or is_signature(id) or (id == "satchel" and not live_satchels().is_empty()):   # the signature stays selectable while it recharges
			owned.append(id)
	if owned.is_empty():
		return
	var i := owned.find(selected)
	selected = owned[(i + step + owned.size()) % owned.size()]
	changed.emit(self)
	GameAudio.play_at("ui_click", vehicle.global_position, 0.4)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_clock += delta
	if vehicle == null or not vehicle.is_alive():
		return
	if not _hop.is_empty():
		_update_hop(delta)
	if signature_id != "" and signature_charge < 1.0:
		var was := signature_charge
		signature_charge = minf(1.0, signature_charge + delta / maxf(float(signature.get("recharge_s", 12.0)), 0.1))
		if signature_charge >= 1.0 and was < 1.0:
			changed.emit(self)
	var f := vehicle.frame
	if f.cycle_special != 0:
		cycle(f.cycle_special)
		f.cycle_special = 0
	if f.fire_special and _cooldown <= 0.0 and not vehicle.status.is_frozen():
		fire()


func has_shot() -> bool:
	if selected == "satchel" and not live_satchels().is_empty():
		return true
	return selected != "" and count(selected) > 0


## Fires the selected special. `backward` fires it out the back (Tailgunner),
## aimed at the nearest car behind.
func fire(backward: bool = false) -> bool:
	if not has_shot():
		return false
	var id := selected
	if is_signature(id):
		return _fire_signature(backward)
	var w: Dictionary = weapons[id]
	match str(w.get("kind", "")):
		"satchel":
			return _fire_satchel(w)
		"arc":
			return _fire_arc(w)
	_cooldown = float(w.get("cooldown", 0.6))
	ammo[id] = count(id) - 1
	vehicle.status.reveal()
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var aim := xf.basis.z if backward else fwd
	var start := xf.origin + aim * (2.8 if backward else 2.6) + xf.basis.y * 0.8
	var target: Node3D = null
	if backward:
		target = Targeting.in_cone(vehicle, aim, 30.0, 70.0)
	else:
		var gun := vehicle.get_node_or_null("MachineGun") as MachineGun
		if gun != null:
			target = gun.current_target
	var curves := w.has("curve_deg_per_s")
	if target == null and curves:
		target = Targeting.in_cone(vehicle, aim, float(w.get("view_cone_deg", 25.0)), 90.0)
	var p := Projectile.new()
	p.setup(id, vehicle, w)
	var lobbed := w.has("lift")
	# The Seeker locks on and turns hard; curving shots (Firebrand) leave straight
	# and bend gently toward the target; the Sledge ignores targets entirely.
	if id == "seeker" or curves:
		p.homing_target = target
	vehicle.get_parent().add_child(p)
	var dir := aim
	if target != null and id == "seeker":
		dir = (target.global_position + Vector3.UP * 0.3 - start).normalized()
	# Forward shots get a share of the car's speed; rear shots carry all of it so
	# they leave the car cleanly.
	var carry := vehicle.linear_velocity if backward else fwd * maxf(vehicle.drive.speed, 0.0) * 0.5
	var vel := dir * float(w.get("speed", 40.0)) + carry
	if lobbed:
		vel += Vector3.UP * float(w.get("lift", 8.0))
	p.launch(start, vel)
	GameAudio.play_at("launch", start, 0.9, 0.7 if id == "sledge" else 1.0)
	_spent(id)
	fired.emit(vehicle, id)
	return true


## After a pickup shot: when it's out of ammo, move on to the next weapon.
func _spent(id: String) -> void:
	if count(id) <= 0 and not (id == "satchel" and not live_satchels().is_empty()):
		ammo.erase(id)
		selected = ""
		cycle(1)
	changed.emit(self)


## Satchel: quick presses lay up to three charges; a press a second or more after
## the last drop sets every one of them off. Any left go off on their own after 8 s.
func _fire_satchel(w: Dictionary) -> bool:
	var live := live_satchels()
	var since := _clock - _last_satchel_drop
	if not live.is_empty() and (since >= float(w.get("detonate_after_s", 1.0)) or count("satchel") <= 0 or live.size() >= int(w.get("max_live", 3))):
		if since < 0.3:
			return false   # don't blow the string the moment it's laid
		for s in live:
			s.detonate()
		_satchels.clear()
		_cooldown = 0.4
		_spent("satchel")
		fired.emit(vehicle, "satchel")
		return true
	if count("satchel") <= 0:
		return false
	ammo["satchel"] = count("satchel") - 1
	_cooldown = float(w.get("cooldown", 0.3))
	_last_satchel_drop = _clock
	vehicle.status.reveal()
	var charge := SatchelCharge.new()
	charge.setup(vehicle, w)
	vehicle.get_parent().add_child(charge)
	var xf := vehicle.global_transform
	var at := xf.origin + xf.basis.z * (vehicle.stats.body_length * 0.5 + 0.8)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP * 5.0, ArcadeVehicle.LAYER_WORLD)
	var ground := vehicle.get_world_3d().direct_space_state.intersect_ray(q)
	charge.global_position = ground["position"] if not ground.is_empty() else at
	_satchels.append(charge)
	GameAudio.play_at("mine_drop", at, 0.9)
	_spent("satchel")
	fired.emit(vehicle, "satchel")
	return true


## Arc Coil: a bolt to the car ahead, then on to the car nearest it. Both lose
## their turbo for a moment. With nobody in front it doesn't fire.
func _fire_arc(w: Dictionary) -> bool:
	var fwd := -vehicle.global_transform.basis.z
	var range_m := float(w.get("range", 40.0))
	var first: Node3D = null
	var gun := vehicle.get_node_or_null("MachineGun") as MachineGun
	if gun != null and gun.current_target != null and gun.current_target.global_position.distance_to(vehicle.global_position) <= range_m:
		first = gun.current_target
	if first == null:
		first = Targeting.in_cone(vehicle, fwd, float(w.get("cone_deg", 35.0)), range_m)
	if first == null:
		GameAudio.play_at("denied", vehicle.global_position, 0.6)
		_cooldown = 0.3
		return false
	ammo["arc_coil"] = count("arc_coil") - 1
	_cooldown = float(w.get("cooldown", 0.7))
	vehicle.status.reveal()
	var start := vehicle.global_position + Vector3.UP * 1.2
	_zap(first, start, float(w.get("damage", 14.0)), w)
	var second: Node3D = null
	var best := float(w.get("chain_range", 15.0))
	for node in vehicle.get_tree().get_nodes_in_group("targets"):
		if node == vehicle or node == first or not (node is ArcadeVehicle) or not (node as ArcadeVehicle).is_alive():
			continue
		var d := (node as Node3D).global_position.distance_to(first.global_position)
		if d < best:
			best = d
			second = node
	if second != null:
		_zap(second, first.global_position + Vector3.UP * 0.8, float(w.get("chain_damage", 8.0)), w)
	GameAudio.play_at("overdrive", start, 0.9, 1.6)
	_spent("arc_coil")
	fired.emit(vehicle, "arc_coil")
	return true


func _zap(target: Node3D, from: Vector3, dmg: float, w: Dictionary) -> void:
	Effects.arc(vehicle.get_parent(), from, target.global_position + Vector3.UP * 0.6)
	if target.has_method("take_damage"):
		target.take_damage(dmg, vehicle)
	if target is ArcadeVehicle:
		var v := target as ArcadeVehicle
		v.status.jam(float(w.get("jam_s", 2.0)))
		v.drive.boosting = false


# --- Signature specials ----------------------------------------------------------------

## Picks what a shot should bend toward: the gun's lock-on target, else the
## nearest car inside the shot's view cone.
func _shot_target(aim: Vector3, backward: bool, data: Dictionary) -> Node3D:
	var target: Node3D = null
	if backward:
		return Targeting.in_cone(vehicle, aim, 30.0, 70.0)
	var gun := vehicle.get_node_or_null("MachineGun") as MachineGun
	if gun != null:
		target = gun.current_target
	if target == null and data.has("curve_deg_per_s"):
		target = Targeting.in_cone(vehicle, aim, float(data.get("view_cone_deg", 25.0)), 90.0)
	return target


func _fire_signature(backward: bool) -> bool:
	if signature_charge < 1.0:
		return false
	var w := signature
	signature_charge = 0.0
	_cooldown = float(w.get("cooldown", 0.6))
	vehicle.status.reveal()
	match str(w.get("kind", "")):
		"shockwave":
			_shockwave(w)
		"volley":
			_shots("ember", w, backward, int(w.get("count", 5)), float(w.get("spread_deg", 24.0)))
		"hook":
			_shots("hook", w, backward, 1, 0.0)
		"sawblade":
			_shots("saw", w, backward, 1, 0.0)
		"net":
			_shots("net", w, backward, 1, 0.0)
		"mortar":
			_lob("mortar", w, backward)
		"rockslide":
			_rockslide(w)
		"ring":
			_ring(w)
		"pall":
			_pall(w)
		"scoop":
			_scoop(w)
		"cloak":
			vehicle.status.cloak(float(w.get("cloak_s", 4.0)))
			vehicle.drive.turbo = minf(vehicle.stats.turbo_capacity, vehicle.drive.turbo + float(w.get("turbo_refill", 35.0)))
			Effects.smog_burst(vehicle.get_parent(), vehicle.global_position)
			GameAudio.play_at("cloak", vehicle.global_position, 0.9, 1.2)
		"hop":
			_start_hop(w)
	changed.emit(self)
	fired.emit(vehicle, signature_id)
	return true


## Launches `n` shots of one kind, fanned across `spread_deg`, straight out the
## front (or back) of the car, each bending slightly toward the target.
func _shots(kind: String, w: Dictionary, backward: bool, n: int, spread_deg: float) -> void:
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var aim := xf.basis.z if backward else fwd
	var target := _shot_target(aim, backward, w)
	var height := 0.45 if kind == "saw" else 0.8
	var start := xf.origin + aim * (vehicle.stats.body_length * 0.5 + 0.6) + Vector3.UP * height
	var carry := vehicle.linear_velocity if backward else fwd * maxf(vehicle.drive.speed, 0.0) * 0.5
	carry.y = 0.0
	for i in n:
		var yaw := 0.0
		if n > 1:
			yaw = deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, float(i) / float(n - 1)))
		var dir := aim.rotated(Vector3.UP, yaw)
		dir.y = 0.0
		dir = dir.normalized()
		var p := Projectile.new()
		p.setup(kind, vehicle, w)
		p.homing_target = target
		vehicle.get_parent().add_child(p)
		p.launch(start, dir * float(w.get("speed", 50.0)) + carry)
	var sound := {"ember": "launch", "hook": "hook", "saw": "saw", "net": "hook"}
	GameAudio.play_at(sound.get(kind, "launch"), start, 0.9, 1.4 if kind == "ember" else 1.0)


## Dead Weight: a blast centred on the car. Damage and shove fall off with distance.
func _shockwave(w: Dictionary) -> void:
	var origin := vehicle.global_position
	var radius := float(w.get("radius", 12.0))
	for node in vehicle.get_tree().get_nodes_in_group("targets"):
		if node == vehicle or not (node is Node3D):
			continue
		var to: Vector3 = (node as Node3D).global_position - origin
		var d := to.length()
		if d > radius:
			continue
		var f := 1.0 - d / radius
		if node.has_method("take_damage"):
			node.take_damage(lerpf(float(w.get("min_damage", 8.0)), float(w.get("damage", 24.0)), f), vehicle)
		if node is ArcadeVehicle and (node as ArcadeVehicle).is_alive():
			var flat := Vector3(to.x, 0.0, to.z)
			var push := (flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD) + Vector3.UP * 0.55
			(node as ArcadeVehicle).apply_central_impulse(push.normalized() * float(w.get("impulse", 16000.0)) * (0.4 + 0.6 * f))
	var v := vehicle.linear_velocity
	v.y = maxf(v.y, 0.0) + 3.0   # the truck jolts as the tank drops
	vehicle.linear_velocity = v
	vehicle.last_impact = 18.0
	Effects.shockwave(vehicle.get_parent(), origin, radius)
	GameAudio.play_at("slam", origin, 1.0)


## Mortar Spread: charges lobbed high over the bonnet in a fan.
func _lob(kind: String, w: Dictionary, backward: bool) -> void:
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var aim := xf.basis.z if backward else fwd
	var n := int(w.get("count", 5))
	var spread := float(w.get("spread_deg", 30.0))
	var start := xf.origin + aim * (vehicle.stats.body_length * 0.3) + Vector3.UP * 1.6
	var carry := vehicle.linear_velocity * 0.6
	carry.y = 0.0
	for i in n:
		var yaw := deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / float(maxi(n - 1, 1))))
		var dir := Vector3(aim.x, 0.0, aim.z).normalized().rotated(Vector3.UP, yaw)
		var p := Projectile.new()
		p.setup(kind, vehicle, w)
		vehicle.get_parent().add_child(p)
		var speed := float(w.get("speed", 26.0)) * (0.85 + 0.3 * float(i % 2))
		p.launch(start, dir * speed + Vector3.UP * float(w.get("lift", 10.0)) + carry)
	GameAudio.play_at("launch", start, 1.0, 0.6)


## Rockslide: slag boulders rolled out of the tipped bed, behind the truck.
func _rockslide(w: Dictionary) -> void:
	var xf := vehicle.global_transform
	var back := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z).normalized()
	var n := int(w.get("count", 4))
	var spread := float(w.get("spread_deg", 40.0))
	for i in n:
		var yaw := deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / float(maxi(n - 1, 1))))
		var dir := back.rotated(Vector3.UP, yaw)
		var side := xf.basis.x * lerpf(-0.8, 0.8, float(i) / float(maxi(n - 1, 1)))
		var start := xf.origin + back * (vehicle.stats.body_length * 0.5 + 1.2) + side + Vector3.UP * 1.0
		var p := Projectile.new()
		p.setup("boulder", vehicle, w)
		vehicle.get_parent().add_child(p)
		p.launch(start, dir * float(w.get("speed", 16.0)) + Vector3(vehicle.linear_velocity.x, 0.0, vehicle.linear_velocity.z) * 0.3)
	GameAudio.play_at("slam", xf.origin, 0.9, 0.7)


## Shrapnel Ring: scrap blown out of the body in every direction at once.
func _ring(w: Dictionary) -> void:
	var xf := vehicle.global_transform
	var n := int(w.get("count", 16))
	var reach := maxf(vehicle.stats.body_length, vehicle.stats.body_width) * 0.5 + 0.6
	for i in n:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / float(n))
		var p := Projectile.new()
		p.setup("shard", vehicle, w)
		vehicle.get_parent().add_child(p)
		p.launch(xf.origin + dir * reach + Vector3.UP * 0.6, dir * float(w.get("speed", 48.0)) + vehicle.linear_velocity)
	Effects.explosion(vehicle.get_parent(), xf.origin + Vector3.UP * 0.6, 0.35)
	GameAudio.play_at("explosion", xf.origin, 0.8, 1.6)


## Pall: a casket kicked out the back doors.
func _pall(w: Dictionary) -> void:
	var xf := vehicle.global_transform
	var c := PallCasket.new()
	c.setup(vehicle, w)
	vehicle.get_parent().add_child(c)
	c.global_position = xf.origin + xf.basis.z * (vehicle.stats.body_length * 0.5 + 1.0) + Vector3.UP * 0.6
	c.global_rotation.y = vehicle.global_rotation.y
	c.velocity = xf.basis.z * 6.0 + vehicle.linear_velocity * 0.5 + Vector3.UP * 2.0
	GameAudio.play_at("mine_drop", c.global_position, 1.0, 0.7)


## Scoop and Hurl: the car right in front is lifted and thrown back over the cab.
func _scoop(w: Dictionary) -> void:
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var target := Targeting.in_cone(vehicle, fwd, float(w.get("cone_deg", 40.0)), float(w.get("range", 8.0)) + vehicle.stats.body_length * 0.5)
	Effects.sparks(vehicle.get_parent(), xf.origin + fwd * (vehicle.stats.body_length * 0.5 + 0.6), Vector3.UP)
	GameAudio.play_at("slam", xf.origin, 0.8, 1.2)
	if target == null:
		return
	if target.has_method("take_damage"):
		target.take_damage(float(w.get("damage", 22.0)), vehicle)
	if target is ArcadeVehicle and (target as ArcadeVehicle).is_alive():
		var t := target as ArcadeVehicle
		var back := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z).normalized()
		var push := (back + Vector3.UP * float(w.get("lift", 0.9))).normalized()
		t.apply_central_impulse(push * float(w.get("impulse", 15000.0)))
		t.apply_torque_impulse(xf.basis.x * t.mass * 2.0)


## Hydraulic Hop: up and over, then the slam when the wheels touch down.
func _start_hop(w: Dictionary) -> void:
	var v := vehicle.linear_velocity
	v.y = maxf(v.y, 0.0) + float(w.get("launch_speed", 12.0))
	v += -vehicle.global_transform.basis.z * float(w.get("forward_speed", 6.0))
	vehicle.linear_velocity = v
	_hop = w
	_hop_airborne = false
	_hop_time = 0.0
	Effects.sparks(vehicle.get_parent(), vehicle.global_position - Vector3.UP * 0.5, Vector3.UP)
	GameAudio.play_at("jump", vehicle.global_position, 1.0, 0.8)


func _update_hop(delta: float) -> void:
	_hop_time += delta
	if not vehicle.grounded:
		_hop_airborne = true
	elif _hop_airborne or _hop_time > 2.5:
		var w := _hop
		_hop = {}
		if _hop_airborne:
			_slam(w)


## The landing: like Dead Weight, smaller, and without the jolt upward.
func _slam(w: Dictionary) -> void:
	var origin := vehicle.global_position
	var radius := float(w.get("radius", 6.0))
	for node in vehicle.get_tree().get_nodes_in_group("targets"):
		if node == vehicle or not (node is Node3D):
			continue
		var to: Vector3 = (node as Node3D).global_position - origin
		var d := to.length()
		if d > radius:
			continue
		var f := 1.0 - d / radius
		if node.has_method("take_damage"):
			node.take_damage(lerpf(float(w.get("min_damage", 8.0)), float(w.get("damage", 20.0)), f), vehicle)
		if node is ArcadeVehicle and (node as ArcadeVehicle).is_alive():
			var flat := Vector3(to.x, 0.0, to.z)
			var push := (flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD) + Vector3.UP * 0.6
			(node as ArcadeVehicle).apply_central_impulse(push.normalized() * float(w.get("impulse", 11000.0)) * (0.4 + 0.6 * f))
	vehicle.last_impact = 14.0
	Effects.shockwave(vehicle.get_parent(), origin, radius)
	GameAudio.play_at("slam", origin, 0.9, 1.15)
