class_name FrameGovernor
extends Node
## Caps the frame rate per GameSettings.fps_mode. In "auto" it runs at 60 and,
## if the average over a few seconds can't hold about 55 fps, settles at 30 for
## the rest of the session (a steady 30 feels better than a ragged 45).

var current_cap := 60
var auto_dropped := false
var _warmup := 2.0
var _window_time := 0.0
var _window_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply()


func apply() -> void:
	match GameSettings.fps_mode:
		"30":
			current_cap = 30
		"60":
			current_cap = 60
		_:
			current_cap = 30 if auto_dropped else 60
	Engine.max_fps = current_cap
	_window_time = 0.0
	_window_frames = 0
	_warmup = 2.0


func _process(delta: float) -> void:
	if GameSettings.fps_mode != "auto" or auto_dropped:
		return
	if _warmup > 0.0:
		_warmup -= delta
		return
	_window_time += delta
	_window_frames += 1
	if _window_time >= 3.0:
		var avg := float(_window_frames) / _window_time
		if avg < 55.0:
			auto_dropped = true
			apply()
		_window_time = 0.0
		_window_frames = 0


func label() -> String:
	if GameSettings.fps_mode == "auto":
		return "Auto (%d fps)" % current_cap
	return "%s fps" % GameSettings.fps_mode
