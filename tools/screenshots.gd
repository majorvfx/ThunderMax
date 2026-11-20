extends SceneTree
## Renders review screenshots of the current build into docs/screenshots.
## Needs a display (or xvfb-run on Linux):
##   godot --path . --resolution 1280x720 --script res://tools/screenshots.gd

const OUT := "res://docs/screenshots/"
const ScriptedDriver = preload("res://tests/run_tests.gd").ScriptedDriver


func _initialize() -> void:
	_run.call_deferred()


func _sim(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame
	# Wait for a frame drawn after the simulation, so the shot isn't one frame stale.
	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t := TitleScreen.new()
	root.add_child(t)
	await _sim(0.3)
	_save("title")
	t.queue_free()

	var m := YardMatch.new()
	root.add_child(m)
	await _sim(1.5)
	var drv := ScriptedDriver.new()
	m.player.driver = drv
	# Line up behind a drone on the west side and open fire.
	var drone: ArcadeVehicle = m.drones[0]
	drone.driver = ScriptedDriver.new()
	drone.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(-52, 1.2, -6))
	m.player.global_transform = Transform3D(Basis(Vector3.UP, -0.15), Vector3(-56, 1.2, 22))
	m.player.reset_physics_interpolation()
	m.camera.snap()
	await _sim(0.6)
	drv.frame.fire_gun = true
	await _sim(1.2)
	_save("gunfight")
	drv.frame.fire_gun = false
	# Combo moves, closer in: Bulwark up, a Spring Jack being entered, a special loaded.
	drone.health.reset()
	drone.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(-52, 1.2, -6))
	drone.linear_velocity = Vector3.ZERO
	drone.reset_physics_interpolation()
	m.player.global_transform = Transform3D(Basis(Vector3.UP, -0.15), Vector3(-54, 1.2, 9))
	m.player.linear_velocity = Vector3.ZERO
	m.player.reset_physics_interpolation()
	m.camera.snap()
	m.player.specials.add("seeker", 3)
	m.player.specials.add("sledge", 1)
	m.player.status.reset()
	m.player.combos.request_move("bulwark")
	await _sim(0.4)
	drv.frame.combo_presses.append("up")
	await _sim(0.1)
	drv.frame.combo_presses.append("up")
	await _sim(0.1)
	_save("combo_bulwark")
	await _sim(0.6)
	# Cold Snap freezes the drone ahead.
	m.player.status.reset()
	drone.health.reset()
	m.player.combos.request_move("cold_snap")
	await _sim(0.6)
	_save("cold_snap")
	# Fire Jug leaves burning fuel on the ground.
	m.player.status.reset()
	m.player.combos.request_move("fire_jug")
	await _sim(1.4)
	_save("fire_jug")
	await _sim(1.5)
	# Rivet Storm: the guns at double rate with no heat.
	m.player.status.reset()
	drone.status.reset()
	drone.health.reset()
	m.player.combos.request_move("rivet_storm")
	drv.frame.fire_gun = true
	await _sim(0.5)
	_save("rivet_storm")
	drv.frame.fire_gun = false
	# Blackout: smog and a faded car.
	m.player.status.reset()
	m.player.combos.request_move("blackout")
	await _sim(0.8)
	_save("blackout")
	m.player.status.reset()
	# Menu + D-pad left / right: radar and rear-view mirror.
	m.run_command("radar")
	m.run_command("rear_mirror")
	await _sim(0.6)
	_save("radar_mirror")
	m.run_command("radar")
	m.run_command("rear_mirror")
	# Menu + D-pad up twice: hood view.
	m.run_command("view_next")
	m.run_command("view_next")
	await _sim(0.4)
	_save("hood_view")
	m.camera.cycle_view(1)
	# Kicker jump in the east lane.
	m.player.global_transform = Transform3D(Basis.IDENTITY, Vector3(68, 1.2, 75))
	m.player.reset_physics_interpolation()
	m.camera.snap()
	drv.frame.throttle = 1.0
	drv.frame.turbo = true
	var guard := 0
	while m.player.global_position.z > 25.0 and guard < 600:
		await physics_frame
		guard += 1
	await _sim(0.35)
	_save("kicker_jump")
	drv.frame.throttle = 0.0
	drv.frame.turbo = false
	# Spring Jack from a standstill, then the rocket turbo in the air.
	await _sim(1.5)
	m.player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(40, 1.2, 60))
	m.player.linear_velocity = Vector3.ZERO
	m.player.reset_physics_interpolation()
	m.player.drive.turbo = m.player.stats.turbo_capacity
	m.player.status.reset()
	m.camera.snap()
	await _sim(0.8)
	m.player.combos.request_move("spring_jack")
	await _sim(0.25)
	drv.frame.turbo = true
	await _sim(0.45)
	_save("rocket_hop")
	drv.frame.turbo = false
	await _sim(1.5)
	m.pause_menu.open()
	await process_frame
	await process_frame
	_save("pause_menu")
	m.pause_menu._open_remap()
	await process_frame
	await process_frame
	_save("remap_controls")
	m.pause_menu._remap.close()
	m.pause_menu._resume()
	m.tuning.open(m.player)
	await process_frame
	await process_frame
	_save("tuning_panel")
	quit()


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + shot + ".png"))
	print("saved ", shot)
