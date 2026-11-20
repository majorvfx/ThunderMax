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


func fire() -> bool:
	if selected == "" or count(selected) <= 0:
		return false
	var id := selected
	var w: Dictionary = weapons[id]
	_cooldown = float(w.get("cooldown", 0.6))
	ammo[id] = count(id) - 1
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var start := xf.origin + fwd * 2.6 + xf.basis.y * 0.8
	var target: Node3D = null
	var gun := vehicle.get_node_or_null("MachineGun") as MachineGun
	if gun != null:
		target = gun.current_target
	var p := Projectile.new()
	p.setup(id, vehicle, w)
	if id == "seeker":
		p.homing_target = target
	vehicle.get_parent().add_child(p)
	var dir := fwd
	if target != null and id != "sledge":
		dir = (target.global_position + Vector3.UP * 0.3 - start).normalized()
	p.launch(start, dir * float(w.get("speed", 40.0)) + fwd * maxf(vehicle.drive.speed, 0.0) * 0.5)
	GameAudio.play_at("launch", start, 0.9, 0.7 if id == "sledge" else 1.0)
	if count(id) <= 0:
		ammo.erase(id)
		selected = ""
		cycle(1)
	changed.emit(self)
	fired.emit(vehicle, id)
	return true
