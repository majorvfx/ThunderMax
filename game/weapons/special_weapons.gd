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
	selected = signature_id
	signature_charge = 1.0
	changed.emit(self)


func is_signature(id: String) -> bool:
	return id != "" and id == signature_id


func count(id: String) -> int:
	if is_signature(id):
		return 1 if signature_charge >= 1.0 else 0
	return int(ammo.get(id, 0))


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
		if count(id) > 0 or is_signature(id):   # the signature stays selectable while it recharges
			owned.append(id)
	if owned.is_empty():
		return
	var i := owned.find(selected)
	selected = owned[(i + step + owned.size()) % owned.size()]
	changed.emit(self)
	GameAudio.play_at("ui_click", vehicle.global_position, 0.4)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if vehicle == null or not vehicle.is_alive():
		return
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
	p.launch(start, dir * float(w.get("speed", 40.0)) + carry)
	GameAudio.play_at("launch", start, 0.9, 0.7 if id == "sledge" else 1.0)
	if count(id) <= 0:
		ammo.erase(id)
		selected = ""
		cycle(1)
	changed.emit(self)
	fired.emit(vehicle, id)
	return true


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
	var sound := {"ember": "launch", "hook": "hook", "saw": "saw"}
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
