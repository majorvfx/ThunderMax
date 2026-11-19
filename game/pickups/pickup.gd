class_name Pickup
extends Area3D
## Health or turbo pickup. Spins, bobs, disappears when used and comes back later.

var kind := "health"
var amount := 35.0
var respawn_seconds := 15.0
var _visual: Node3D
var _active := true
var _time := 0.0
var _base_y := 0.0


func setup(pickup_kind: String, data: Dictionary) -> void:
	kind = pickup_kind
	amount = float(data.get("amount", amount))
	respawn_seconds = float(data.get("respawn_seconds", respawn_seconds))


func _ready() -> void:
	collision_layer = ArcadeVehicle.LAYER_PICKUPS
	collision_mask = ArcadeVehicle.LAYER_VEHICLES
	monitoring = true
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.8
	shape.shape = s
	add_child(shape)
	_build_visual()
	_base_y = _visual.position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.roughness = 0.4
	if kind == "health":
		m.albedo_color = Color(0.85, 0.82, 0.72)
		m.emission = Color(0.9, 0.2, 0.15)
		m.emission_energy_multiplier = 1.4
		VehicleVisualParts.box(_visual, Vector3(1.0, 0.32, 0.32), Vector3.ZERO, m)
		VehicleVisualParts.box(_visual, Vector3(0.32, 1.0, 0.32), Vector3.ZERO, m)
	else:
		m.albedo_color = Color(0.25, 0.3, 0.32)
		m.emission = Color(0.95, 0.6, 0.15)
		m.emission_energy_multiplier = 1.6
		VehicleVisualParts.cylinder(_visual, 0.32, 0.9, Vector3.ZERO, Vector3(0, 0, 18), m)
	var light := OmniLight3D.new()
	light.light_color = m.emission
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.name = "Glow"
	_visual.add_child(light)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y += delta * 1.8
	_visual.position.y = _base_y + sin(_time * 2.2) * 0.18


func _on_body_entered(body: Node3D) -> void:
	_try_give(body)


func _try_give(body: Node3D) -> void:
	if not _active or not (body is ArcadeVehicle):
		return
	if (body as ArcadeVehicle).apply_pickup(kind, amount):
		_set_active(false)
		GameAudio.play_at("pickup", global_position, 0.8, 1.0 if kind == "health" else 1.25)
		get_tree().create_timer(respawn_seconds, false).timeout.connect(_respawn)


func _respawn() -> void:
	_set_active(true)
	for b in get_overlapping_bodies():
		_try_give(b)
		if not _active:
			break


func _set_active(on: bool) -> void:
	_active = on
	_visual.visible = on


func is_active() -> bool:
	return _active
