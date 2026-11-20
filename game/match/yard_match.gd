class_name YardMatch
extends Node3D
## Milestone 1 sandbox: Rustjaw vs. Scrap Drones in the Foundry Yard.
## Wreck drones, grab pickups, tune the handling. Drones respawn; so do you.

signal quit_to_title
signal restart_requested

const DRONE_COUNT := 3
const DRONE_RESPAWN := 5.0
const PLAYER_RESPAWN := 3.0
const BARREL_RESPAWN := 25.0

const WRECK_LINES := [
	"%s recycled.",
	"%s: another one for the furnace.",
	"The Yard keeps what's left of %s.",
	"%s. No driver. No funeral.",
	"%s scrapped. Nobody will ask.",
]
const PLAYER_WRECKED_LINES := [
	"WRECKED. The Yard is patient.",
	"WRECKED. Back on the road.",
	"WRECKED. The furnace will have to wait.",
]

var arena: FoundryYard
var player: ArcadeVehicle
var player_driver: PlayerDriver
var camera: ChaseCamera
var hud: Hud
var pause_menu: PauseMenu
var tuning: TuningPanel
var mirror: RearMirror
var governor: FrameGovernor
var drones: Array[ArcadeVehicle] = []
var wrecks := 0
var _ui: CanvasLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.apply_controls()
	_rng.randomize()

	arena = FoundryYard.new()
	arena.name = "FoundryYard"
	add_child(arena)

	governor = FrameGovernor.new()
	governor.name = "FrameGovernor"
	add_child(governor)

	player_driver = PlayerDriver.new(1, -1)
	player = VehicleFactory.create("rustjaw", player_driver, true)
	add_child(player)
	player.global_transform = arena.player_spawn
	player.reset_physics_interpolation()
	player.add_to_group("players")
	player.wrecked.connect(_on_player_wrecked)
	player.combos.move_used.connect(_on_player_move)
	player.combos.move_failed.connect(_on_player_move_failed)
	player.shield_blocked.connect(_on_shield_blocked)
	player.pickup_taken.connect(_on_pickup)
	player.damaged.connect(_on_player_damaged)

	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.target = player
	camera.current = true

	for i in DRONE_COUNT:
		_spawn_drone(i)
	_spawn_pickups()
	for spot in arena.barrel_spots:
		_spawn_barrel_cluster(spot)

	_build_ui()
	_apply_quality()
	Input.joy_connection_changed.connect(_on_joy_changed)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	hud = Hud.new()
	hud.vehicle = player
	hud.gun = player.get_node("MachineGun") as MachineGun
	hud.camera = camera
	hud.governor = governor
	_ui.add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.governor = governor
	_ui.add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.quit_requested.connect(_quit)
	pause_menu.settings_changed.connect(_apply_quality)
	mirror = RearMirror.new()
	mirror.target = player
	_ui.add_child(mirror)
	_ui.move_child(mirror, hud.get_index())
	tuning = TuningPanel.new()
	_ui.add_child(tuning)
	hud.message("THE FOUNDRY YARD", 3.0)
	hud.message("Wreck the drones. Mind the drums.", 3.5)


func _apply_quality() -> void:
	GameSettings.apply_quality(get_viewport(), arena.environment, arena.sun, arena.lamps)


func _physics_process(_delta: float) -> void:
	# Anything that falls out of the world comes back.
	for v in [player] + drones:
		var car := v as ArcadeVehicle
		if car.is_alive() and car.global_position.y < -15.0:
			car.respawn(arena.safe_spawn(_all_vehicles_except(car)))
			if car == player:
				camera.snap()


func _process(delta: float) -> void:
	for cmd in player_driver.poll_commands(delta):
		run_command(cmd)


## View and info commands: Menu + D-pad on the pad, or their own keys.
func run_command(cmd: String) -> void:
	match cmd:
		"view_next", "view_prev":
			hud.message("VIEW: " + camera.cycle_view(1 if cmd == "view_next" else -1), 1.2)
		"radar":
			hud.show_radar = not hud.show_radar
			hud.message("RADAR " + ("ON" if hud.show_radar else "OFF"), 1.0)
		"rear_mirror":
			hud.message("REAR-VIEW MIRROR " + ("ON" if mirror.toggle() else "OFF"), 1.0)
		"enemies_left":
			var alive := drones.filter(func(d): return d.is_alive()).size()
			hud.message("%d %s STILL RUNNING" % [alive, "DRONE" if alive == 1 else "DRONES"], 2.0)
		"pause":
			pause_menu.open()
	if cmd != "pause":
		GameAudio.play_at("ui_click", player.global_position, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed(InputSetup.action(1, "pause")):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed(InputSetup.action(1, "tuning")):
		get_viewport().set_input_as_handled()
		tuning.open(player)
	elif event.is_action_pressed(InputSetup.action(1, "debug")):
		hud.show_debug = not hud.show_debug
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Spawning -----------------------------------------------------------------------

func _spawn_drone(i: int) -> void:
	var route: Array[Vector3] = arena.drone_routes[i % arena.drone_routes.size()]
	var driver := DroneDriver.new(route, (i * 3) % route.size(), _rng.randf_range(0.7, 0.9))
	var drone := VehicleFactory.create("scrap_drone", driver, false)
	drone.name = "ScrapDrone%d" % (i + 1)
	add_child(drone)
	drone.global_transform = _route_transform(route, driver.index)
	drone.reset_physics_interpolation()
	drone.wrecked.connect(_on_drone_wrecked)
	drones.append(drone)


func _route_transform(route: Array[Vector3], index: int) -> Transform3D:
	var from := route[(index - 1 + route.size()) % route.size()]
	var to := route[index]
	var pos := from.lerp(to, 0.5) + Vector3.UP * 1.2
	var dir := (to - from)
	dir.y = 0.0
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), pos)


func _spawn_pickups() -> void:
	var data := GameData.pickups()
	for entry in arena.pickup_spots():
		var p := Pickup.new()
		p.setup(entry[0], data.get(entry[0], {}))
		p.position = entry[1]
		add_child(p)


func _spawn_barrel_cluster(center: Vector3) -> void:
	var offsets := [Vector3(0, 0, 0), Vector3(1.0, 0, 0.3), Vector3(0.4, 0, -0.95)]
	for o in offsets:
		_spawn_barrel(center + o)


func _spawn_barrel(at: Vector3) -> void:
	var b := ExplosiveBarrel.new()
	b.position = at
	add_child(b)
	b.exploded.connect(func(_b): get_tree().create_timer(BARREL_RESPAWN, false).timeout.connect(_spawn_barrel.bind(at)))


func _all_vehicles_except(v: ArcadeVehicle) -> Array:
	var out: Array = []
	for car in [player] + drones:
		if car != v and (car as ArcadeVehicle).is_alive():
			out.append(car)
	return out


# --- Events ---------------------------------------------------------------------------

func _on_drone_wrecked(drone: ArcadeVehicle, killer: Node) -> void:
	if killer == player:
		wrecks += 1
		hud.wrecks = wrecks
		hud.message(WRECK_LINES[_rng.randi() % WRECK_LINES.size()] % drone.stats.display_name)
	get_tree().create_timer(DRONE_RESPAWN, false).timeout.connect(func():
		var route: Array[Vector3] = arena.drone_routes[drones.find(drone) % arena.drone_routes.size()]
		var at := _rng.randi() % route.size()
		var d := drone.driver as DroneDriver
		if d != null:   # tools and tests sometimes drive a drone with a scripted driver
			d.index = at
		drone.respawn(_route_transform(route, at)))


func _on_player_wrecked(_v: ArcadeVehicle, _killer: Node) -> void:
	hud.message(PLAYER_WRECKED_LINES[_rng.randi() % PLAYER_WRECKED_LINES.size()], PLAYER_RESPAWN)
	get_tree().create_timer(PLAYER_RESPAWN, false).timeout.connect(func():
		player.respawn(arena.safe_spawn(_all_vehicles_except(player)))
		camera.snap())


func _on_player_move(_v: ArcadeVehicle, _id: String, move_name: String) -> void:
	hud.flash_move(move_name.to_upper())


func _on_player_move_failed(_v: ArcadeVehicle, id: String, reason: String) -> void:
	match reason:
		"energy":
			hud.flash_move("NOT ENOUGH ENERGY", true)
			GameAudio.play_ui("denied", 0.7)
		"airborne":
			hud.flash_move("%s NEEDS THE GROUND" % player.combos.move_name(id).to_upper(), true)
		"frozen":
			GameAudio.play_ui("denied", 0.5)


func _on_shield_blocked(_v: ArcadeVehicle, _amount: float) -> void:
	hud.shield_hit()


func _on_pickup(_v: ArcadeVehicle, kind: String) -> void:
	var labels := GameData.pickups()
	var label := str(labels.get(kind, {}).get("label", kind))
	if kind == "weapon" and player.specials.selected != "":
		label = "%s x%d" % [player.specials.display_name(player.specials.selected), player.specials.count(player.specials.selected)]
	hud.message("+ %s" % label, 1.4)


func _on_player_damaged(_v: ArcadeVehicle, amount: float, _source: Node) -> void:
	if amount >= 5.0:
		for pad in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, 0.4, 0.7, 0.18)


func _on_joy_changed(device: int, connected: bool) -> void:
	if connected:
		hud.message("Controller connected: %s" % Input.get_joy_name(device), 2.5)
	else:
		hud.message("Controller disconnected", 2.5)


func _restart() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _quit() -> void:
	get_tree().paused = false
	quit_to_title.emit()
