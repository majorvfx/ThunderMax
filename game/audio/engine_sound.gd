class_name EngineSound
extends AudioStreamPlayer3D
## Looping engine hum; pitch follows speed, louder under throttle and turbo.

var vehicle: ArcadeVehicle


func setup(v: ArcadeVehicle) -> void:
	vehicle = v
	stream = GameAudio.looped("engine")
	unit_size = 10.0
	max_distance = 90.0
	volume_db = -8.0 if v.is_player else -12.0
	autoplay = true


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	if not vehicle.is_alive():
		if playing:
			stop()
		return
	if not playing and stream != null:
		play()
	var sp := vehicle.speed_fraction()
	var target_pitch := 0.6 + sp * 0.9 + (0.15 if vehicle.drive.boosting else 0.0)
	pitch_scale = lerpf(pitch_scale, target_pitch, 0.15)
	var load := clampf(vehicle.frame.throttle + (0.5 if vehicle.drive.boosting else 0.0), 0.0, 1.0)
	var base := -8.0 if vehicle.is_player else -12.0
	volume_db = lerpf(volume_db, base + load * 4.0, 0.1)
