class_name EngineSound
extends AudioStreamPlayer3D
## Looping engine hum; pitch follows speed, louder under throttle and turbo.
## Cars with a turbo also get a rocket roar that fades in while boosting, with a
## nitrous hit each time it lights.

var vehicle: ArcadeVehicle
var _thrust: AudioStreamPlayer3D
var _was_boosting := false
const THRUST_SILENT_DB := -40.0


func setup(v: ArcadeVehicle) -> void:
	vehicle = v
	stream = GameAudio.looped("engine")
	unit_size = 10.0
	max_distance = 90.0
	volume_db = -8.0 if v.is_player else -12.0
	autoplay = true
	if v.stats.turbo_capacity > 0.0:
		_thrust = AudioStreamPlayer3D.new()
		_thrust.stream = GameAudio.looped("thruster")
		_thrust.unit_size = 10.0
		_thrust.max_distance = 90.0
		_thrust.volume_db = THRUST_SILENT_DB
		add_child(_thrust)


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	if not vehicle.is_alive():
		if playing:
			stop()
		if _thrust != null and _thrust.playing:
			_thrust.stop()
		return
	_update_thrust()
	if not playing and stream != null:
		play()
	var sp := vehicle.speed_fraction()
	var target_pitch := 0.6 + sp * 0.9 + (0.15 if vehicle.drive.boosting else 0.0)
	pitch_scale = lerpf(pitch_scale, target_pitch, 0.15)
	var load := clampf(vehicle.frame.throttle + (0.5 if vehicle.drive.boosting else 0.0), 0.0, 1.0)
	var base := -8.0 if vehicle.is_player else -12.0
	volume_db = lerpf(volume_db, base + load * 4.0, 0.1)


func _update_thrust() -> void:
	if _thrust == null:
		return
	var boosting := vehicle.drive.boosting
	if boosting and not _was_boosting:
		GameAudio.play_at("nitro", vehicle.global_position, 0.9)
	_was_boosting = boosting
	var target := (-3.0 if vehicle.is_player else -8.0) if boosting else THRUST_SILENT_DB
	_thrust.volume_db = lerpf(_thrust.volume_db, target, 0.25 if boosting else 0.12)
	_thrust.pitch_scale = 0.9 + vehicle.speed_fraction() * 0.25 + (0.1 if not vehicle.grounded else 0.0)
	if boosting and not _thrust.playing and _thrust.stream != null:
		_thrust.play()
	elif not boosting and _thrust.playing and _thrust.volume_db < THRUST_SILENT_DB + 2.0:
		_thrust.stop()
