class_name SpecialWeapons
extends Node
## Pickup special weapons: Seeker (homing), Firebrand (burning) and Sledge (heavy).
## Weapon crates add ammo; cycle with the special prev/next controls; hold the
## special button to fire.

signal changed(specials: SpecialWeapons)
signal fired(vehicle: ArcadeVehicle, weapon_id: String)

var vehicle: ArcadeVehicle
var weapons := {}          ## id -> data
var order: Array[String] = []
var ammo := {}             ## id -> count
var selected := ""
var max_ammo := 6
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


func clear() -> void:
	ammo.clear()
	selected = ""
	changed.emit(self)


func count(id: String) -> int:
	return int(ammo.get(id, 0))


func total() -> int:
	var n := 0
	for id in ammo:
		n += int(ammo[id])
	return n


func display_name(id: String) -> String:
	return str(weapons.get(id, {}).get("name", id))


func add(id: String, n: int) -> bool:
	if not weapons.has(id) or count(id) >= max_ammo:
		return false
	ammo[id] = mini(max_ammo, count(id) + n)
	if selected == "" or count(selected) == 0:
		selected = id
	changed.emit(self)
	return true


## Weapon crate: a random weapon that isn't already full.
func add_random(n: int) -> bool:
	var options: Array[String] = []
	for id in order:
		if count(id) < max_ammo:
			options.append(id)
	if options.is_empty():
		return false
	return add(options[_rng.randi() % options.size()], n)


func cycle(step: int) -> void:
	var owned: Array[String] = []
	for id in order:
		if count(id) > 0:
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
