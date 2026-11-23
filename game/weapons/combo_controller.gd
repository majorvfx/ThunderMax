class_name ComboController
extends Node
## Turns D-pad combo presses into Iron Carnage's combo moves (data/combos.json):
## Scrap Mine, Cold Snap, Spring Jack, Rivet Storm, Fire Jug, Tailgunner, Blackout
## and Bulwark. Moves cost combo energy, which refills on its own. Bots call
## request_move() directly.

signal move_used(vehicle: ArcadeVehicle, move_id: String, move_name: String)
signal move_failed(vehicle: ArcadeVehicle, move_id: String, reason: String)

var vehicle: ArcadeVehicle
var moves := {}
var buffer := ComboBuffer.new()
var _clock := 0.0
var _mines: Array[Node] = []


func setup(v: ArcadeVehicle) -> void:
	vehicle = v
	var data: Variant = GameData.load_json(GameData.COMBOS_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		moves = data.get("moves", {})
		buffer.configure(moves, float(data.get("window_s", 0.45)))


func _physics_process(delta: float) -> void:
	_clock += delta
	if vehicle == null:
		return
	var presses := vehicle.frame.combo_presses
	if presses.is_empty():
		return
	var holding := vehicle.frame.combo_hold
	for p in presses:
		var id := buffer.push(p, _clock, holding)
		if id != "":
			request_move(id)
	presses.clear()


func move_name(id: String) -> String:
	return str(moves.get(id, {}).get("name", id))


## Inputs for a move as words, e.g. "Down, Down, Up" or "Hold RT + Up, Down, ...".
func inputs_text(id: String) -> String:
	return ComboController.describe_inputs(moves.get(id, {}))


static func describe_inputs(move: Dictionary, hold_name: String = "RT") -> String:
	var out := []
	for d in move.get("inputs", []):
		out.append(str(d).capitalize())
	var text := ", ".join(out)
	if bool(move.get("hold", false)):
		text = "Hold %s + %s" % [hold_name, text]
	return text


func request_move(id: String) -> bool:
	if not moves.has(id) or vehicle == null or not vehicle.is_alive():
		return false
	var m: Dictionary = moves[id]
	if vehicle.status.is_frozen():
		move_failed.emit(vehicle, id, "frozen")
		return false
	if id == "spring_jack" and not vehicle.grounded:
		move_failed.emit(vehicle, id, "airborne")
		return false
	if id == "tailgunner":
		return _tailgunner(m)
	if not vehicle.status.try_spend(id, float(m.get("cost", 0.0)), float(m.get("cooldown", 0.5))):
		move_failed.emit(vehicle, id, "energy")
		return false
	match id:
		"spring_jack":
			_spring_jack(m)
		"bulwark":
			vehicle.status.shield(float(m.get("duration", 3.0)))
			GameAudio.play_at("shield", vehicle.global_position, 0.9)
		"cold_snap":
			_fire_projectile("cold_snap", m)
		"scrap_mine":
			_drop_mine(m)
		"fire_jug":
			_fire_projectile("fire_jug", m)
		"blackout":
			vehicle.status.cloak(float(m.get("duration", 4.0)))
			Effects.smog_burst(vehicle.get_parent(), vehicle.global_position)
			GameAudio.play_at("cloak", vehicle.global_position, 0.9)
		"rivet_storm":
			vehicle.status.overdrive(float(m.get("duration", 4.0)))
			GameAudio.play_at("overdrive", vehicle.global_position, 0.9)
	move_used.emit(vehicle, id, move_name(id))
	return true


func _spring_jack(m: Dictionary) -> void:
	var launch := float(m.get("launch_speed", 11.0))
	var v := vehicle.linear_velocity
	v.y = maxf(v.y, 0.0) + launch
	vehicle.linear_velocity = v
	Effects.sparks(vehicle.get_parent(), vehicle.global_position - Vector3.UP * 0.5, Vector3.UP)
	GameAudio.play_at("jump", vehicle.global_position, 0.9)
	# The rockets cough a burst of flame as you leave the ground (no turbo used).
	var visual := vehicle.get_node_or_null("Visual") as VehicleVisual
	if visual != null:
		visual.flare(0.4)


func _fire_projectile(kind: String, m: Dictionary) -> void:
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	var target: Node3D = null
	var gun := vehicle.get_node_or_null("MachineGun") as MachineGun
	if gun != null:
		target = gun.current_target
	if target == null and m.has("curve_deg_per_s"):
		target = Targeting.in_cone(vehicle, fwd, float(m.get("view_cone_deg", 25.0)), 90.0)
	var p := Projectile.new()
	p.setup(kind, vehicle, m)
	var start := xf.origin + fwd * 2.6 + xf.basis.y * 0.7
	# Cold Snap leaves straight ahead and bends slightly toward the target.
	if kind == "cold_snap":
		p.homing_target = target
	var dir := fwd
	var vel := dir * float(m.get("speed", 40.0))
	if kind == "fire_jug":
		vel = Projectile.lob_velocity(fwd, float(m.get("speed", 23.4)), float(m.get("arc_deg", 25.0))) + vehicle.linear_velocity * 0.6
		p.gravity = float(m.get("gravity", 22.0))
	vehicle.get_parent().add_child(p)
	p.launch(start, vel)
	GameAudio.play_at("launch", start, 0.8, 1.3 if kind == "cold_snap" else 0.8)


## Tailgunner: fires the selected special weapon out the back, using its ammo and
## no energy. With no special (or none left) it fires a Cold Snap freeze blast out
## the back instead, which costs the move's energy.
func _tailgunner(m: Dictionary) -> bool:
	var cooldown := float(m.get("cooldown", 0.6))
	var sp := vehicle.specials
	if sp != null and sp.has_shot():
		if not vehicle.status.try_spend("tailgunner", 0.0, cooldown):
			return false   # still cooling down from the last rear shot
		var weapon := sp.display_name(sp.selected)
		sp.fire(true)
		move_used.emit(vehicle, "tailgunner", "%s: %s" % [move_name("tailgunner"), weapon])
		return true
	if not vehicle.status.try_spend("tailgunner", float(m.get("cost", 35.0)), cooldown):
		move_failed.emit(vehicle, "tailgunner", "energy")
		return false
	var freeze: Dictionary = moves.get("cold_snap", {})
	var xf := vehicle.global_transform
	var back := xf.basis.z
	var start := xf.origin + back * 2.8 + xf.basis.y * 0.7
	var dir := back
	var target := Targeting.in_cone(vehicle, back, float(m.get("aim_cone_deg", 30.0)), float(m.get("aim_range_m", 70.0)))
	var p := Projectile.new()
	p.setup("cold_snap", vehicle, freeze)
	p.homing_target = target   # leaves straight back and bends slightly toward them
	vehicle.get_parent().add_child(p)
	# Carry the car's own velocity so the shot leaves cleanly when you're driving away.
	p.launch(start, dir * float(freeze.get("speed", 75.0)) + vehicle.linear_velocity)
	GameAudio.play_at("launch", start, 0.8, 1.3)
	move_used.emit(vehicle, "tailgunner", "%s: Freeze Blast" % move_name("tailgunner"))
	return true


func _drop_mine(m: Dictionary) -> void:
	_mines = _mines.filter(func(n): return is_instance_valid(n))
	var max_mines := int(m.get("max_per_car", 3))
	while _mines.size() >= max_mines:
		var oldest: Node = _mines.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var xf := vehicle.global_transform
	var mine := ScrapMine.new()
	mine.setup(vehicle, m)
	vehicle.get_parent().add_child(mine)
	var behind := xf.origin + xf.basis.z * 2.8
	var q := PhysicsRayQueryParameters3D.create(behind + Vector3.UP, behind - Vector3.UP * 4.0, ArcadeVehicle.LAYER_WORLD)
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(q)
	mine.global_position = (hit["position"] as Vector3) + Vector3.UP * 0.15 if not hit.is_empty() else behind
	_mines.append(mine)
	GameAudio.play_at("mine_drop", mine.global_position, 0.8)
